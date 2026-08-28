import Foundation

/// The lifecycle state of a derived interval.  A candidate at its maximum is
/// historical, even when there is no later food event.
public enum InferredFastState: String, Equatable, Hashable, Sendable {
    case inProgress
    case historical
}

/// A read-only interval derived from one saved caloric boundary.  This value is
/// intentionally independent of SwiftData and UI frameworks; it is safe to
/// rebuild whenever local authoritative state or AppClock.now changes.
public struct InferredFastInterval: Equatable, Hashable, Sendable {
    public let sourceBoundaryReference: CaloricBoundaryReference
    public let sourceDate: Date
    public let sourceDescription: String
    public let nextBoundaryReference: CaloricBoundaryReference?
    public let nextBoundaryDate: Date?
    public let startDate: Date
    public let endDate: Date
    public let goal: FastingGoal
    public let state: InferredFastState

    public var sourceFoodID: UUID {
        sourceBoundaryReference.id
    }

    public var sourceKind: CaloricBoundaryKind {
        sourceBoundaryReference.kind
    }

    public var nextFoodID: UUID? {
        nextBoundaryReference?.id
    }

    public var nextFoodDate: Date? {
        nextBoundaryDate
    }

    public init(
        sourceBoundaryReference: CaloricBoundaryReference,
        sourceDate: Date,
        sourceDescription: String,
        nextBoundaryReference: CaloricBoundaryReference?,
        nextBoundaryDate: Date?,
        startDate: Date,
        endDate: Date,
        goal: FastingGoal,
        state: InferredFastState
    ) {
        self.sourceBoundaryReference = sourceBoundaryReference
        self.sourceDate = sourceDate
        self.sourceDescription = sourceDescription
        self.nextBoundaryReference = nextBoundaryReference
        self.nextBoundaryDate = nextBoundaryDate
        self.startDate = startDate
        self.endDate = endDate
        self.goal = goal
        self.state = state
    }

    public init(
        sourceFoodID: UUID,
        sourceDate: Date,
        sourceDescription: String,
        nextFoodID: UUID?,
        nextFoodDate: Date?,
        startDate: Date,
        endDate: Date,
        goal: FastingGoal,
        state: InferredFastState
    ) {
        self.init(
            sourceBoundaryReference: CaloricBoundaryReference(kind: .food, id: sourceFoodID),
            sourceDate: sourceDate,
            sourceDescription: sourceDescription,
            nextBoundaryReference: nextFoodID.map {
                CaloricBoundaryReference(kind: .food, id: $0)
            },
            nextBoundaryDate: nextFoodDate,
            startDate: startDate,
            endDate: endDate,
            goal: goal,
            state: state
        )
    }

    public var id: UUID {
        sourceFoodID
    }

    public var interval: Range<Date> {
        startDate ..< endDate
    }

    public var isInProgress: Bool {
        state == .inProgress
    }

    public var offersStart: Bool {
        isInProgress
    }

    public var offersSave: Bool {
        state == .historical
    }

    /// Refreshes the disposable interval while a conversion sheet remains
    /// foregrounded. A punctuating food boundary is fixed; an unpunctuated
    /// candidate advances to the current instant until its goal-plus-grace cap.
    public func refreshed(at now: Date) -> Self {
        let maximumDate = sourceDate.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: goal)
        )
        let refreshedEndDate = min(nextFoodDate ?? now, maximumDate)
        let refreshedState: InferredFastState = nextFoodDate == nil && now < maximumDate
            ? .inProgress
            : .historical
        return Self(
            sourceBoundaryReference: sourceBoundaryReference,
            sourceDate: sourceDate,
            sourceDescription: sourceDescription,
            nextBoundaryReference: nextBoundaryReference,
            nextBoundaryDate: nextBoundaryDate,
            startDate: startDate,
            endDate: refreshedEndDate,
            goal: goal,
            state: refreshedState
        )
    }
}

public enum InferredFastProjector {
    public static let eligibilityDuration: TimeInterval = 8 * 60 * 60
    public static let postGoalGraceDuration: TimeInterval = 12 * 60 * 60

    public static func maximumDuration(for goal: FastingGoal) -> TimeInterval {
        TimeInterval(goal.hours * 60 * 60) + postGoalGraceDuration
    }

    /// Projects caloric food-anchored inferred intervals visible in
    /// `visibleInterval`. This overload preserves the OW-410 API while the
    /// boundary overload below is the shared food/drink authority.
    public static func project(
        foodEvents: [FoodBoundarySnapshot],
        recordedFasts: [RecordedFastInterval] = [],
        currentGoal: FastingGoal,
        enabled: Bool,
        now: Date,
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        let boundaries = CaloricBoundaryExtractor.boundaries(food: foodEvents, hydration: [])
        return project(
            boundaries: boundaries,
            recordedFasts: recordedFasts,
            currentGoal: currentGoal,
            enabled: enabled,
            now: now,
            visibleInterval: visibleInterval
        )
    }

    /// Projects over the complete ordered caloric boundary stream. Food and
    /// explicitly caloric hydration use the same source, punctuation, cap and
    /// deterministic identity rules.
    public static func project(
        boundaries: [CaloricBoundary],
        recordedFasts: [RecordedFastInterval] = [],
        currentGoal: FastingGoal,
        enabled: Bool,
        now: Date,
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        guard enabled else { return [] }

        let ordered = CaloricBoundaryOrdering.sorted(boundaries)
        let canonicalBoundaries = ordered.reduce(into: [CaloricBoundary]()) { result, boundary in
            guard result.last?.occurredAt != boundary.occurredAt else { return }
            result.append(boundary)
        }

        return canonicalBoundaries.compactMap { source in
            guard source.occurredAt <= now else { return nil }

            let eligibilityDate = source.occurredAt.addingTimeInterval(eligibilityDuration)
            guard now >= eligibilityDate else { return nil }

            let maximumDate = source.occurredAt.addingTimeInterval(
                maximumDuration(for: currentGoal)
            )
            let laterBoundary = ordered.first {
                $0.occurredAt > source.occurredAt
                    && $0.occurredAt <= now
                    && $0.occurredAt < maximumDate
            }
            if let laterBoundary, laterBoundary.occurredAt < eligibilityDate {
                return nil
            }
            let endDate = min(laterBoundary?.occurredAt ?? now, maximumDate)
            guard source.occurredAt < endDate else { return nil }

            let state: InferredFastState = laterBoundary == nil && now < maximumDate
                ? .inProgress
                : .historical
            let interval = source.occurredAt ..< endDate
            guard intersects(interval, visibleInterval),
                  !recordedFasts.contains(where: { overlaps(interval, $0) })
            else { return nil }

            return InferredFastInterval(
                sourceBoundaryReference: source.reference,
                sourceDate: source.occurredAt,
                sourceDescription: source.description,
                nextBoundaryReference: laterBoundary?.reference,
                nextBoundaryDate: laterBoundary?.occurredAt,
                startDate: source.occurredAt,
                endDate: endDate,
                goal: currentGoal,
                state: state
            )
        }
    }

    public static func project(
        foodEvents: [FoodBoundarySnapshot],
        currentGoal: FastingGoal,
        enabled: Bool,
        clock: any AppClock,
        recordedFasts: [RecordedFastInterval] = [],
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        project(
            foodEvents: foodEvents,
            recordedFasts: recordedFasts,
            currentGoal: currentGoal,
            enabled: enabled,
            now: clock.now,
            visibleInterval: visibleInterval
        )
    }

    public static func project(
        boundaries: [CaloricBoundary],
        currentGoal: FastingGoal,
        enabled: Bool,
        clock: any AppClock,
        recordedFasts: [RecordedFastInterval] = [],
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        project(
            boundaries: boundaries,
            recordedFasts: recordedFasts,
            currentGoal: currentGoal,
            enabled: enabled,
            now: clock.now,
            visibleInterval: visibleInterval
        )
    }

    public static func intersects(_ lhs: Range<Date>, _ rhs: Range<Date>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    public static func overlaps(
        _ interval: Range<Date>,
        _ fast: RecordedFastInterval
    ) -> Bool {
        let existingEndsAfterStart = fast.endDate.map { interval.lowerBound < $0 } ?? true
        return existingEndsAfterStart && fast.startDate < interval.upperBound
    }
}
