import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    @Attribute(.unique) var id: UUID
    var fastingGoalHours: Int
    var hasCompletedOnboarding: Bool
    var waterFavouriteMillilitres: Int = 500
    var teaFavouriteMillilitres: Int = 300
    var coffeeFavouriteMillilitres: Int = 300

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        hasCompletedOnboarding: Bool = false,
        waterFavouriteMillilitres: Int = 500,
        teaFavouriteMillilitres: Int = 300,
        coffeeFavouriteMillilitres: Int = 300
    ) {
        self.id = id
        fastingGoalHours = fastingGoal.hours
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.waterFavouriteMillilitres = waterFavouriteMillilitres
        self.teaFavouriteMillilitres = teaFavouriteMillilitres
        self.coffeeFavouriteMillilitres = coffeeFavouriteMillilitres
    }

    var fastingGoal: FastingGoal {
        FastingGoal(hours: fastingGoalHours) ?? .default
    }

    func setFastingGoal(_ goal: FastingGoal) {
        fastingGoalHours = goal.hours
    }

    func setHydrationFavourites(water: Int, tea: Int, coffee: Int) {
        waterFavouriteMillilitres = water
        teaFavouriteMillilitres = tea
        coffeeFavouriteMillilitres = coffee
    }
}
