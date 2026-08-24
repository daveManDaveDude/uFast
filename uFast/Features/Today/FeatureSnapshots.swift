import Foundation
import UFastCore

struct AppSettingsSnapshot: Equatable {
    let id: UUID
    let fastingGoal: FastingGoal
    let automaticLiveActivityPreference: AutomaticLiveActivityPreference
    let inferredFastDetectionEnabled: Bool
    let waterFavouriteMillilitres: Int
    let teaFavouriteMillilitres: Int
    let coffeeFavouriteMillilitres: Int

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        automaticLiveActivityPreference: AutomaticLiveActivityPreference = .notAsked,
        inferredFastDetectionEnabled: Bool = false,
        waterFavouriteMillilitres: Int = 500,
        teaFavouriteMillilitres: Int = 300,
        coffeeFavouriteMillilitres: Int = 300
    ) {
        self.id = id
        self.fastingGoal = fastingGoal
        self.automaticLiveActivityPreference = automaticLiveActivityPreference
        self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
        self.waterFavouriteMillilitres = waterFavouriteMillilitres
        self.teaFavouriteMillilitres = teaFavouriteMillilitres
        self.coffeeFavouriteMillilitres = coffeeFavouriteMillilitres
    }
}

struct ActiveFastSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
}

struct FoodEntrySnapshot: Equatable {
    let id: UUID
    let foodDescription: String
    let occurredAt: Date
    let nutrition: FoodNutrition
    let isCaloric: Bool
}

struct HydrationEntrySnapshot: Equatable {
    let id: UUID
    let drinkType: HydrationDrinkType
    let customName: String?
    let displayName: String
    let volumeMillilitres: Int
    let occurredAt: Date
    let isCaloric: Bool
}

struct TodayFeatureSnapshot: Equatable {
    let settings: [AppSettingsSnapshot]
    let activeFasts: [ActiveFastSnapshot]
    let foodEntries: [FoodEntrySnapshot]
    let hydrationEntries: [HydrationEntrySnapshot]
    let hydrationFavourites: [HydrationFavouriteSnapshot]

    init(
        settings: [AppSettingsSnapshot],
        activeFasts: [ActiveFastSnapshot],
        foodEntries: [FoodEntrySnapshot],
        hydrationEntries: [HydrationEntrySnapshot],
        hydrationFavourites: [HydrationFavouriteSnapshot] = []
    ) {
        self.settings = settings
        self.activeFasts = activeFasts
        self.foodEntries = foodEntries
        self.hydrationEntries = hydrationEntries
        self.hydrationFavourites = hydrationFavourites
    }
}

struct SettingsFeatureSnapshot: Equatable {
    let settings: [AppSettingsSnapshot]
    let hydrationFavourites: [HydrationFavouriteSnapshot]

    init(
        settings: [AppSettingsSnapshot],
        hydrationFavourites: [HydrationFavouriteSnapshot] = []
    ) {
        self.settings = settings
        self.hydrationFavourites = hydrationFavourites
    }
}
