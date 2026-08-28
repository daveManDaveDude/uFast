import Foundation
import SwiftData

struct InferredFastSuppressionRecordSnapshot {
    let id: UUID
    let suppression: InferredFastSuppression
}

struct InferredFastSuppressionStoreSnapshot {
    let records: [InferredFastSuppressionRecordSnapshot]

    func restore(in modelContext: ModelContext) {
        let current = (try? modelContext.fetch(FetchDescriptor<InferredFastSuppressionRecord>())) ?? []
        let expectedIDs = Set(records.map(\.id))
        current.filter { !expectedIDs.contains($0.id) }.forEach(modelContext.delete)

        let currentByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for snapshot in records {
            if let record = currentByID[snapshot.id] {
                record.restore(from: snapshot.suppression)
            } else {
                modelContext.insert(
                    InferredFastSuppressionRecord(
                        id: snapshot.id,
                        suppression: snapshot.suppression
                    )
                )
            }
        }
    }
}

struct SuppressionReconciliationResult: Equatable, Sendable {
    let scannedCount: Int
    let changedCount: Int
}

typealias InferredFastProjection = @MainActor (
    [CaloricBoundary], FastingGoal, Bool, Date
) -> [InferredFastInterval]

private typealias ValidSuppressionRecord = (
    record: InferredFastSuppressionRecord,
    suppression: InferredFastSuppression
)

@MainActor
final class InferredFastSuppressionStore {
    private let modelContext: ModelContext
    private let diagnosticSink: any DiagnosticEventSink
    private let projector: InferredFastProjection

    init(
        modelContext: ModelContext,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        projector: @escaping InferredFastProjection = { boundaries, goal, enabled, now in
            InferredFastProjector.project(
                boundaries: boundaries,
                currentGoal: goal,
                enabled: enabled,
                now: now
            )
        }
    ) {
        self.modelContext = modelContext
        self.diagnosticSink = diagnosticSink
        self.projector = projector
    }

    func all() throws -> [InferredFastSuppression] {
        try modelContext.fetch(FetchDescriptor<InferredFastSuppressionRecord>())
            .compactMap(\.suppression)
    }

    func snapshot() throws -> InferredFastSuppressionStoreSnapshot {
        try InferredFastSuppressionStoreSnapshot(
            records: modelContext.fetch(FetchDescriptor<InferredFastSuppressionRecord>())
                .compactMap { record in
                    record.suppression.map {
                        InferredFastSuppressionRecordSnapshot(id: record.id, suppression: $0)
                    }
                }
        )
    }

    func insert(_ suppression: InferredFastSuppression) throws {
        let existing = try record(for: suppression.sourceBoundaryReference)
        guard existing == nil else { return }
        modelContext.insert(InferredFastSuppressionRecord(suppression: suppression))
    }

    func remove(source: CaloricBoundaryReference) throws {
        for record in try records(for: source) {
            modelContext.delete(record)
        }
    }

    func reconcileInMemory(
        currentGoal: FastingGoal,
        enabled: Bool,
        mode: InferredFastSuppressionMode = .presentation,
        now: Date,
        updatedAt: Date
    ) throws -> SuppressionReconciliationResult {
        let records = try modelContext.fetch(FetchDescriptor<InferredFastSuppressionRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let boundaries = try planner.allBoundaries()
        let shouldReconcile = enabled || mode == .authoritativeMutation
        // Recorded-fast overlap is a presentation concern. The source-bound
        // row remains durable so it can reappear after the overlap ends.
        let projection = shouldReconcile
            ? InferredFastProjectionIndex(candidates: projector(
                boundaries,
                currentGoal,
                true,
                now
            ))
            : InferredFastProjectionIndex(candidates: [])
        let validated = validatedRecords(from: records)

        let batch = InferredFastSuppressionBatchReconciler.reconcile(
            input: InferredFastSuppressionBatchInput(
                suppressions: validated.records.map(\.suppression),
                projection: projection,
                currentGoal: currentGoal,
                enabled: enabled,
                mode: mode,
                updatedAt: updatedAt
            )
        )
        let changedCount = validated.removedCount + apply(
            decisions: batch.decisions,
            to: validated.records
        )

        return SuppressionReconciliationResult(
            scannedCount: records.count,
            changedCount: changedCount
        )
    }

    private func validatedRecords(
        from records: [InferredFastSuppressionRecord]
    ) -> (records: [ValidSuppressionRecord], removedCount: Int) {
        var valid: [ValidSuppressionRecord] = []
        var removedCount = 0
        var canonicalBySource: [CaloricBoundaryReference: InferredFastSuppressionRecord] = [:]
        for record in records {
            guard let suppression = record.suppression else {
                modelContext.delete(record)
                removedCount += 1
                continue
            }

            // Records arrive in stable UUID order, so the first valid row for
            // a source is the canonical survivor. Delete later duplicates in
            // this same in-memory transaction; reconcile() saves the complete
            // cleanup once alongside any other structural changes.
            guard canonicalBySource[suppression.sourceBoundaryReference] == nil else {
                modelContext.delete(record)
                removedCount += 1
                continue
            }
            canonicalBySource[suppression.sourceBoundaryReference] = record
            valid.append((record: record, suppression: suppression))
        }
        return (records: valid, removedCount: removedCount)
    }

    private func apply(
        decisions: [InferredFastSuppressionDecision],
        to records: [ValidSuppressionRecord]
    ) -> Int {
        var changedCount = 0
        for (entry, decision) in zip(records, decisions) {
            switch decision {
            case .remove:
                modelContext.delete(entry.record)
                changedCount += 1
            case let .retain(updated):
                // An open candidate's projected end is presentation-only. Do
                // not dirty SwiftData when only the injected clock advanced;
                // structural metadata still updates transactionally.
                let durableStateChanged = updated.sourceBoundaryReference != entry.suppression.sourceBoundaryReference
                    || updated.projectedStartDate != entry.suppression.projectedStartDate
                    || (updated.nextBoundaryReference != nil
                        && updated.projectedEndDate != entry.suppression.projectedEndDate)
                    || updated.nextBoundaryReference != entry.suppression.nextBoundaryReference
                    || updated.nextBoundaryDate != entry.suppression.nextBoundaryDate
                    || updated.goalHoursSnapshot != entry.suppression.goalHoursSnapshot
                if durableStateChanged {
                    entry.record.restore(from: updated)
                    changedCount += 1
                }
            }
        }
        return changedCount
    }

    func reconcile(
        currentGoal: FastingGoal,
        enabled: Bool,
        mode: InferredFastSuppressionMode = .presentation,
        now: Date,
        updatedAt: Date = .now,
        saveAction: PersistenceTransaction.Save? = nil
    ) throws -> SuppressionReconciliationResult {
        let snapshot = try snapshot()
        let result: SuppressionReconciliationResult
        do {
            result = try reconcileInMemory(
                currentGoal: currentGoal,
                enabled: enabled,
                mode: mode,
                now: now,
                updatedAt: updatedAt
            )
            guard result.changedCount > 0 else { return result }
            try PersistenceTransaction(modelContext: modelContext, saveAction: saveAction)
                .save(recovering: { snapshot.restore(in: modelContext) })
            return result
        } catch {
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
    }

    private func record(for source: CaloricBoundaryReference) throws -> InferredFastSuppressionRecord? {
        try records(for: source).first
    }

    private func records(for source: CaloricBoundaryReference) throws -> [InferredFastSuppressionRecord] {
        try modelContext.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).filter {
            $0.sourceBoundaryKindRaw == source.kind.rawValue && $0.sourceBoundaryID == source.id
        }
    }
}
