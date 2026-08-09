import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    var id: UUID = UUID()
    var fastingGoalHours: Int = FastingGoal.default.hours
    var hasCompletedOnboarding: Bool = false
    var waterFavouriteMillilitres: Int = 500
    var teaFavouriteMillilitres: Int = 300
    var coffeeFavouriteMillilitres: Int = 300
    var automaticLiveActivityPreferenceRawValue: String = "notAsked"

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        hasCompletedOnboarding: Bool = false,
        waterFavouriteMillilitres: Int = 500,
        teaFavouriteMillilitres: Int = 300,
        coffeeFavouriteMillilitres: Int = 300,
        automaticLiveActivityPreference: AutomaticLiveActivityPreference = .notAsked
    ) {
        self.id = id
        fastingGoalHours = fastingGoal.hours
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.waterFavouriteMillilitres = waterFavouriteMillilitres
        self.teaFavouriteMillilitres = teaFavouriteMillilitres
        self.coffeeFavouriteMillilitres = coffeeFavouriteMillilitres
        automaticLiveActivityPreferenceRawValue = automaticLiveActivityPreference.rawValue
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

    var automaticLiveActivityPreference: AutomaticLiveActivityPreference {
        AutomaticLiveActivityPreference(
            persistedRawValue: automaticLiveActivityPreferenceRawValue
        )
    }

    func setAutomaticLiveActivityPreference(_ preference: AutomaticLiveActivityPreference) {
        automaticLiveActivityPreferenceRawValue = preference.rawValue
    }
}
