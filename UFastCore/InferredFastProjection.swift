import Foundation

/// The lifecycle state of a derived interval.  A candidate at its maximum is
/// historical, even when there is no later food event.
public enum InferredFastState: String, Equatable, Hashable, Sendable {
    case inProgress
    case historical
}

/// A read-only interval derived from one saved food event.  This value is
/// intentionally independent of SwiftData and UI frameworks; it is safe to
/// rebuild whenever local authoritative state or AppClock.now changes.
public struct InferredFastInterval: Equatable, Hashable, Sendable {
    public let sourceFoodID: UUID
    public let sourceDate: Date
    public let sourceDescription: String
    public let nextFoodID: UUID?
    public let nextFoodDate: Date?
    public let startDate: Date
    public let endDate: Date
    public let goal: FastingGoal
    public let state: InferredFastState

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
        self.sourceFoodID = sourceFoodID
        self.sourceDate = sourceDate
        self.sourceDescription = sourceDescription
        self.nextFoodID = nextFoodID
        self.nextFoodDate = nextFoodDate
        self.startDate = startDate
        self.endDate = endDate
        self.goal = goal
        self.state = state
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
            sourceFoodID: sourceFoodID,
            sourceDate: sourceDate,
            sourceDescription: sourceDescription,
            nextFoodID: nextFoodID,
            nextFoodDate: nextFoodDate,
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
    /// `visibleInterval`. Non-caloric food is filtered before timestamp
    /// canonicalization so it cannot become a source or punctuate a candidate.
    public static func project(
        foodEvents: [FoodBoundarySnapshot],
        recordedFasts: [RecordedFastInterval] = [],
        currentGoal: FastingGoal,
        enabled: Bool,
        now: Date,
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        guard enabled else { return [] }

        let ordered = foodEvents.filter(\.isCaloric).sorted {
            if $0.occurredAt != $1.occurredAt {
                return $0.occurredAt < $1.occurredAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        let canonicalFoodEvents = ordered.reduce(into: [FoodBoundarySnapshot]()) { result, food in
            guard result.last?.occurredAt != food.occurredAt else { return }
            result.append(food)
        }

        return canonicalFoodEvents.compactMap { source in
            guard source.occurredAt <= now else { return nil }

            let eligibilityDate = source.occurredAt.addingTimeInterval(eligibilityDuration)
            guard now >= eligibilityDate else { return nil }

            let maximumDate = source.occurredAt.addingTimeInterval(
                maximumDuration(for: currentGoal)
            )
            let laterFood = ordered.first {
                $0.occurredAt > source.occurredAt
                    && $0.occurredAt <= now
                    && $0.occurredAt < maximumDate
            }
            if let laterFood, laterFood.occurredAt < eligibilityDate {
                return nil
            }
            let endDate = min(laterFood?.occurredAt ?? now, maximumDate)
            guard source.occurredAt < endDate else { return nil }

            let state: InferredFastState = laterFood == nil && now < maximumDate
                ? .inProgress
                : .historical
            let interval = source.occurredAt ..< endDate
            guard intersects(interval, visibleInterval),
                  !recordedFasts.contains(where: { overlaps(interval, $0) })
            else { return nil }

            return InferredFastInterval(
                sourceFoodID: source.id,
                sourceDate: source.occurredAt,
                sourceDescription: source.description,
                nextFoodID: laterFood?.id,
                nextFoodDate: laterFood?.occurredAt,
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

    public static func intersects(_ lhs: Range<Date>, _ rhs: Range<Date>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func overlaps(
        _ interval: Range<Date>,
        _ fast: RecordedFastInterval
    ) -> Bool {
        let existingEndsAfterStart = fast.endDate.map { interval.lowerBound < $0 } ?? true
        return existingEndsAfterStart && fast.startDate < interval.upperBound
    }
}
