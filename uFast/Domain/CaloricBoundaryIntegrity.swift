import Foundation

/// A repository-side view of the persisted fast fields needed to calculate a
/// caloric-boundary impact without coupling the rule to SwiftData.
struct PersistedFastBoundarySnapshot: Equatable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let origin: FastOrigin?
    let reviewState: FastReviewState?
    let boundaryPair: CaloricBoundaryPair?
}

struct CaloricEventImpact: Equatable, Sendable {
    let activeFastIDs: [UUID]
    let completedFastIDs: [UUID]
    let reconstructedFastIDs: [UUID]
    let reconstructedReviewIDs: [UUID]

    var affectedPersistedFastCount: Int {
        Set(activeFastIDs + completedFastIDs + reconstructedFastIDs + reconstructedReviewIDs).count
    }

    var affectsActiveFast: Bool {
        !activeFastIDs.isEmpty
    }

    var requiresConfirmation: Bool {
        affectedPersistedFastCount > 0
    }

    static let none = Self(
        activeFastIDs: [],
        completedFastIDs: [],
        reconstructedFastIDs: [],
        reconstructedReviewIDs: []
    )
}

struct CaloricBoundaryMutation: Sendable {
    let oldReference: CaloricBoundaryReference?
    let oldOccurredAt: Date?
    let oldIsCaloric: Bool
    let newBoundary: CaloricBoundary?
    let resultingBoundaries: [CaloricBoundary]
}

enum CaloricBoundaryImpactAnalyzer {
    static func impact(
        for mutation: CaloricBoundaryMutation,
        fasts: [PersistedFastBoundarySnapshot]
    ) -> CaloricEventImpact {
        var active: [UUID] = []
        var completed: [UUID] = []
        var reconstructed: [UUID] = []
        var review: [UUID] = []

        for fast in fasts {
            let earliest = CaloricBoundaryQuery.earliestBoundary(
                after: fast.startDate,
                in: mutation.resultingBoundaries
            )
            if fast.endDate == nil {
                if earliest != nil {
                    active.append(fast.id)
                }
            } else if Self.hasEarlierBoundary(earliest, than: fast.endDate) {
                completed.append(fast.id)
                if fast.origin == .reconstructed {
                    reconstructed.append(fast.id)
                }
            }

            let referencedOldEnd = fast.boundaryPair?.end == mutation.oldReference
            let oldBoundaryWasChanged = mutation.oldReference != nil && (
                mutation.newBoundary == nil
                    || mutation.newBoundary?.occurredAt != mutation.oldOccurredAt
                    || mutation.oldIsCaloric != (mutation.newBoundary != nil)
            )
            let needsReview = fast.origin == .reconstructed
                && referencedOldEnd
                && oldBoundaryWasChanged
            if needsReview {
                review.append(fast.id)
            }
        }

        return CaloricEventImpact(
            activeFastIDs: active,
            completedFastIDs: completed,
            reconstructedFastIDs: reconstructed,
            reconstructedReviewIDs: review
        )
    }

    private static func hasEarlierBoundary(
        _ boundary: CaloricBoundary?,
        than endDate: Date?
    ) -> Bool {
        guard let boundary, let endDate else { return false }
        return boundary.occurredAt < endDate
    }
}

/// Optional repository capability. Existing pure services remain usable with
/// lightweight spies, while SwiftData-backed commands use the authoritative
/// event stream for every boundary-sensitive mutation.
@MainActor
protocol CaloricBoundaryQuerying {
    func savedCaloricBoundaries() throws -> [CaloricBoundary]
}

@MainActor
protocol CaloricBoundaryAwareFoodEntryRepository: CaloricBoundaryQuerying {
    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?
    ) throws -> CaloricEventImpact
    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal
    ) throws
}

@MainActor
protocol CaloricHydrationRepository: CaloricBoundaryQuerying {
    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?
    ) throws -> CaloricEventImpact
    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal
    ) throws
}
