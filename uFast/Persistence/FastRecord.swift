import Foundation
import SwiftData

@Model
final class FastRecord {
    @Attribute(.unique) var id: UUID
    private(set) var startDate: Date
    private(set) var endDate: Date?
    private(set) var goalHoursAtStart: Int

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        goalAtStart: FastingGoal
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        goalHoursAtStart = goalAtStart.hours
    }

    var isActive: Bool {
        endDate == nil
    }

    var historicalGoal: FastingGoal {
        FastingGoal(hours: goalHoursAtStart) ?? .default
    }

    var duration: TimeInterval? {
        endDate.map { $0.timeIntervalSince(startDate) }
    }

    func presentationGoal(currentGoal: FastingGoal) -> FastingGoal {
        isActive ? currentGoal : historicalGoal
    }

    func targetDate(currentGoal: FastingGoal) -> Date {
        let goal = presentationGoal(currentGoal: currentGoal)
        return startDate.addingTimeInterval(TimeInterval(goal.hours * 60 * 60))
    }
}
