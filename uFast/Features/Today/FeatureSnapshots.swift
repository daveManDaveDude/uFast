import Foundation
import UFastCore

struct AppSettingsSnapshot: Equatable {
    let id: UUID
    let fastingGoal: FastingGoal
    let automaticLiveActivityPreference: AutomaticLiveActivityPreference
    let inferredFastDetectionEnabled: Bool

    init(
        id: UUID = UUID(),
        fastingGoal: FastingGoal = .default,
        automaticLiveActivityPreference: AutomaticLiveActivityPreference = .notAsked,
        inferredFastDetectionEnabled: Bool = false
    ) {
        self.id = id
        self.fastingGoal = fastingGoal
        self.automaticLiveActivityPreference = automaticLiveActivityPreference
        self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
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
    let foodFavourites: [FoodFavouriteSnapshot]

    init(
        settings: [AppSettingsSnapshot],
        activeFasts: [ActiveFastSnapshot],
        foodEntries: [FoodEntrySnapshot],
        hydrationEntries: [HydrationEntrySnapshot],
        hydrationFavourites: [HydrationFavouriteSnapshot] = [],
        foodFavourites: [FoodFavouriteSnapshot] = []
    ) {
        self.settings = settings
        self.activeFasts = activeFasts
        self.foodEntries = foodEntries
        self.hydrationEntries = hydrationEntries
        self.hydrationFavourites = hydrationFavourites
        self.foodFavourites = foodFavourites
    }
}

struct SettingsFeatureSnapshot: Equatable {
    let settings: [AppSettingsSnapshot]
    let hydrationFavourites: [HydrationFavouriteSnapshot]
    let foodFavourites: [FoodFavouriteSnapshot]

    init(
        settings: [AppSettingsSnapshot],
        hydrationFavourites: [HydrationFavouriteSnapshot] = [],
        foodFavourites: [FoodFavouriteSnapshot] = []
    ) {
        self.settings = settings
        self.hydrationFavourites = hydrationFavourites
        self.foodFavourites = foodFavourites
    }
}
