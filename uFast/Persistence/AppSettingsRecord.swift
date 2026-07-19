import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    @Attribute(.unique) var id: UUID
    var fastingGoalHours: Int
    var hasCompletedOnboarding: Bool

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        fastingGoalHours = fastingGoal.hours
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    var fastingGoal: FastingGoal {
        FastingGoal(hours: fastingGoalHours) ?? .default
    }

    func setFastingGoal(_ goal: FastingGoal) {
        fastingGoalHours = goal.hours
    }
}
