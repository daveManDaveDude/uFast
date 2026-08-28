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

@MainActor
final class InferredFastSuppressionStore {
    private let modelContext: ModelContext
    private let diagnosticSink: any DiagnosticEventSink

    init(
        modelContext: ModelContext,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) {
        self.modelContext = modelContext
        self.diagnosticSink = diagnosticSink
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
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let boundaries = try planner.allBoundaries()
        let recordedFasts = try planner.fasts().map {
            RecordedFastInterval(id: $0.id, startDate: $0.startDate, endDate: $0.endDate)
        }
        var changedCount = 0

        for record in records {
            guard let suppression = record.suppression else {
                modelContext.delete(record)
                changedCount += 1
                continue
            }
            switch InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: boundaries,
                recordedFasts: recordedFasts,
                currentGoal: currentGoal,
                enabled: enabled,
                mode: mode,
                now: now,
                updatedAt: updatedAt
            ) {
            case .remove:
                modelContext.delete(record)
                changedCount += 1
            case let .retain(updated):
                if updated != suppression {
                    record.restore(from: updated)
                    changedCount += 1
                }
            }
        }

        return SuppressionReconciliationResult(
            scannedCount: records.count,
            changedCount: changedCount
        )
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
