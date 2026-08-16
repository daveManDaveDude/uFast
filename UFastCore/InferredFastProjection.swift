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
}

public enum InferredFastProjector {
    public static let eligibilityDuration: TimeInterval = 8 * 60 * 60
    public static let postGoalGraceDuration: TimeInterval = 12 * 60 * 60

    public static func maximumDuration(for goal: FastingGoal) -> TimeInterval {
        TimeInterval(goal.hours * 60 * 60) + postGoalGraceDuration
    }

    /// Projects food-anchored inferred intervals visible in `visibleInterval`.
    /// Food is always treated as caloric here, including compatibility records
    /// whose old persisted Boolean may not reflect the current food contract.
    public static func project(
        foodEvents: [FoodBoundarySnapshot],
        recordedFasts: [RecordedFastInterval] = [],
        currentGoal: FastingGoal,
        enabled: Bool,
        now: Date,
        visibleInterval: Range<Date> = Date.distantPast ..< Date.distantFuture
    ) -> [InferredFastInterval] {
        guard enabled else { return [] }

        let ordered = foodEvents.sorted {
            if $0.occurredAt != $1.occurredAt {
                return $0.occurredAt < $1.occurredAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        return ordered.compactMap { source in
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
