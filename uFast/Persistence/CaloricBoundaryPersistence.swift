import Foundation
import SwiftData

extension [CaloricBoundary] {
    func adding(_ boundary: CaloricBoundary?) -> [CaloricBoundary] {
        guard let boundary else { return self }
        return CaloricBoundaryOrdering.sorted(self + [boundary])
    }
}

struct FastRecordMutationSnapshot {
    let startDate: Date
    let endDate: Date?
    let goalHours: Int
    let provenance: FastRecordProvenanceSnapshot

    init(_ fast: FastRecord) {
        startDate = fast.startDate
        endDate = fast.endDate
        goalHours = fast.goalHoursAtStart
        provenance = fast.provenanceSnapshot
    }

    func restore(_ fast: FastRecord) {
        fast.correctBoundaries(startDate: startDate, endDate: endDate ?? startDate)
        if endDate == nil {
            fast.restoreActive(goal: FastingGoal(hours: goalHours) ?? .default)
        } else {
            fast.restorePersistedHistoricalGoal(
                rawHours: goalHours,
                isCaptured: provenance.hasHistoricalGoal
            )
        }
        fast.restoreProvenance(provenance)
    }
}

@MainActor
struct CaloricBoundaryPersistencePlanner {
    let modelContext: ModelContext

    func allBoundaries(excluding excluded: CaloricBoundaryReference? = nil) throws -> [CaloricBoundary] {
        let foods = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>()).map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: true
            )
        }
        let hydration = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>()).map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: $0.isCaloric
            )
        }
        return CaloricBoundaryExtractor.boundaries(food: foods, hydration: hydration)
            .filter { $0.reference != excluded }
    }

    func fasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func snapshots(for fasts: [FastRecord]) -> [UUID: FastRecordMutationSnapshot] {
        Dictionary(uniqueKeysWithValues: fasts.map { ($0.id, FastRecordMutationSnapshot($0)) })
    }

    func impact(
        for mutation: CaloricBoundaryMutation,
        fasts: [FastRecord]
    ) -> CaloricEventImpact {
        CaloricBoundaryImpactAnalyzer.impact(
            for: mutation,
            fasts: fasts.map {
                PersistedFastBoundarySnapshot(
                    id: $0.id,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    origin: $0.origin,
                    reviewState: $0.reviewState,
                    boundaryPair: $0.boundaryPair
                )
            }
        )
    }

    func apply(
        _ mutation: CaloricBoundaryMutation,
        to fasts: [FastRecord],
        currentGoal: FastingGoal
    ) -> CaloricEventImpact {
        let impact = impact(for: mutation, fasts: fasts)
        for fast in fasts {
            let requiresReview = impact.reconstructedReviewIDs.contains(fast.id)
            if requiresReview, let endBoundary = fast.boundaryPair?.end {
                fast.retainReviewBoundary(endBoundary)
                fast.markNeedsReview()
            }
            guard let earliest = CaloricBoundaryQuery.earliestBoundary(
                after: fast.startDate,
                in: mutation.resultingBoundaries
            ) else {
                continue
            }

            if fast.isActive {
                _ = fast.complete(at: earliest.occurredAt, goal: currentGoal)
            } else if Self.hasEarlierBoundary(earliest, than: fast.endDate) {
                fast.correctBoundaries(startDate: fast.startDate, endDate: earliest.occurredAt)
                if fast.origin == .reconstructed {
                    fast.replaceEndBoundary(with: earliest.reference)
                }
            }
        }
        return impact
    }

    private static func hasEarlierBoundary(
        _ boundary: CaloricBoundary?,
        than endDate: Date?
    ) -> Bool {
        guard let boundary, let endDate else { return false }
        return boundary.occurredAt < endDate
    }
}

struct CaloricBoundaryReconciliationResult: Equatable, Sendable {
    let scannedCount: Int
    let changedCount: Int
    let activeFastEnded: Bool
}

enum CaloricBoundaryReconciliationError: Error, Equatable {
    case invalidFastRecord(UUID)
}

@MainActor
struct CaloricBoundaryReconciler {
    let modelContext: ModelContext
    let currentGoal: FastingGoal
    let saveAction: PersistenceTransaction.Save?

    init(
        modelContext: ModelContext,
        currentGoal: FastingGoal,
        saveAction: PersistenceTransaction.Save? = nil
    ) {
        self.modelContext = modelContext
        self.currentGoal = currentGoal
        self.saveAction = saveAction
    }

    func reconcile() throws -> CaloricBoundaryReconciliationResult {
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let boundaries = try planner.allBoundaries()
        let fasts = try planner.fasts()
        try validate(fasts)
        let snapshots = planner.snapshots(for: fasts)
        var changedCount = 0
        var activeFastEnded = false

        for fast in fasts {
            let previousEnd = fast.endDate
            let previousReview = fast.reviewState
            let previousProvenance = fast.provenanceSnapshot
            if reconcile(fast, against: boundaries) {
                activeFastEnded = true
            }

            let changed = previousEnd != fast.endDate
                || previousReview != fast.reviewState
                || previousProvenance != fast.provenanceSnapshot
            if changed {
                changedCount += 1
            }
        }

        guard changedCount > 0 else {
            return CaloricBoundaryReconciliationResult(
                scannedCount: fasts.count,
                changedCount: 0,
                activeFastEnded: false
            )
        }

        let transaction = PersistenceTransaction(modelContext: modelContext, saveAction: saveAction)
        do {
            try transaction.save {
                for fast in fasts {
                    if let snapshot = snapshots[fast.id] {
                        snapshot.restore(fast)
                    }
                }
            }
        } catch {
            throw error
        }

        return CaloricBoundaryReconciliationResult(
            scannedCount: fasts.count,
            changedCount: changedCount,
            activeFastEnded: activeFastEnded
        )
    }

    private func validate(_ fasts: [FastRecord]) throws {
        guard let invalidFast = fasts.first(where: {
            $0.startDate > ($0.endDate ?? Date.distantFuture)
        }) else {
            return
        }
        throw CaloricBoundaryReconciliationError.invalidFastRecord(invalidFast.id)
    }

    private func reconcile(_ fast: FastRecord, against boundaries: [CaloricBoundary]) -> Bool {
        let staleEndReference = reconstructedEndReferenceIfStale(for: fast, in: boundaries)
        guard let earliest = CaloricBoundaryQuery.earliestBoundary(
            after: fast.startDate,
            in: boundaries
        ) else {
            if let staleEndReference {
                fast.retainReviewBoundary(staleEndReference)
                fast.markNeedsReview()
            }
            return false
        }

        if fast.isActive {
            _ = fast.complete(at: earliest.occurredAt, goal: currentGoal)
            return true
        }

        if let endDate = fast.endDate, earliest.occurredAt < endDate {
            fast.correctBoundaries(startDate: fast.startDate, endDate: earliest.occurredAt)
            if fast.origin == .reconstructed {
                fast.replaceEndBoundary(with: earliest.reference)
            }
        }
        if let staleEndReference {
            fast.retainReviewBoundary(staleEndReference)
            fast.markNeedsReview()
        }
        return false
    }

    private func reconstructedEndReferenceIfStale(
        for fast: FastRecord,
        in boundaries: [CaloricBoundary]
    ) -> CaloricBoundaryReference? {
        guard fast.origin == .reconstructed, let pair = fast.boundaryPair else {
            return nil
        }
        guard boundaries.first(where: { $0.reference == pair.end })?.occurredAt == fast.endDate else {
            return pair.end
        }
        return nil
    }
}
