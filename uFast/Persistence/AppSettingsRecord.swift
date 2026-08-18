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
    var inferredFastDetectionEnabled: Bool = false

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        hasCompletedOnboarding: Bool = false,
        waterFavouriteMillilitres: Int = 500,
        teaFavouriteMillilitres: Int = 300,
        coffeeFavouriteMillilitres: Int = 300,
        automaticLiveActivityPreference: AutomaticLiveActivityPreference = .notAsked,
        inferredFastDetectionEnabled: Bool = false
    ) {
        self.id = id
        fastingGoalHours = fastingGoal.hours
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.waterFavouriteMillilitres = waterFavouriteMillilitres
        self.teaFavouriteMillilitres = teaFavouriteMillilitres
        self.coffeeFavouriteMillilitres = coffeeFavouriteMillilitres
        automaticLiveActivityPreferenceRawValue = automaticLiveActivityPreference.rawValue
        self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
    }

    var fastingGoal: FastingGoal {
        FastingGoal(hours: fastingGoalHours) ?? .default
    }

    func setFastingGoal(_ goal: FastingGoal) {
        fastingGoalHours = goal.hours
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
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

    func setInferredFastDetectionEnabled(_ enabled: Bool) {
        inferredFastDetectionEnabled = enabled
    }

    var userVisibleSnapshot: AppSettingsUserVisibleSnapshot {
        AppSettingsUserVisibleSnapshot(
            fastingGoalHours: fastingGoalHours,
            hasCompletedOnboarding: hasCompletedOnboarding,
            waterFavouriteMillilitres: waterFavouriteMillilitres,
            teaFavouriteMillilitres: teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: inferredFastDetectionEnabled
        )
    }

    func restore(from snapshot: AppSettingsUserVisibleSnapshot) {
        fastingGoalHours = snapshot.fastingGoalHours
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        waterFavouriteMillilitres = snapshot.waterFavouriteMillilitres
        teaFavouriteMillilitres = snapshot.teaFavouriteMillilitres
        coffeeFavouriteMillilitres = snapshot.coffeeFavouriteMillilitres
        automaticLiveActivityPreferenceRawValue = snapshot.automaticLiveActivityPreferenceRawValue
        inferredFastDetectionEnabled = snapshot.inferredFastDetectionEnabled
    }
}
