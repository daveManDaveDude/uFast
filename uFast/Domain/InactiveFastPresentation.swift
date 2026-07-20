import Foundation

struct InactiveFastPresentation: Equatable, Sendable {
    let goal: FastingGoal
    let targetDate: Date

    init(now: Date, goal: FastingGoal) {
        self.goal = goal
        targetDate = now.addingTimeInterval(TimeInterval(goal.hours * 60 * 60))
    }
}
