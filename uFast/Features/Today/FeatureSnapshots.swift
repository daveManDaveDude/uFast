import Foundation

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

    init(_ record: AppSettingsRecord) {
        id = record.id
        fastingGoal = record.fastingGoal
        automaticLiveActivityPreference = record.automaticLiveActivityPreference
        inferredFastDetectionEnabled = record.inferredFastDetectionEnabled
        waterFavouriteMillilitres = record.waterFavouriteMillilitres
        teaFavouriteMillilitres = record.teaFavouriteMillilitres
        coffeeFavouriteMillilitres = record.coffeeFavouriteMillilitres
    }
}

struct ActiveFastSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?

    init(_ record: FastRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
    }
}

struct FoodEntrySnapshot: Equatable {
    let id: UUID
    let foodDescription: String
    let occurredAt: Date
    let nutrition: FoodNutrition
    let isCaloric: Bool

    init(_ record: FoodEntryRecord) {
        id = record.id
        foodDescription = record.foodDescription
        occurredAt = record.occurredAt
        nutrition = record.nutrition
        isCaloric = record.isCaloric
    }
}

struct HydrationEntrySnapshot: Equatable {
    let id: UUID
    let drinkType: HydrationDrinkType
    let customName: String?
    let displayName: String
    let volumeMillilitres: Int
    let occurredAt: Date
    let isCaloric: Bool

    init(_ record: HydrationEntryRecord) {
        id = record.id
        drinkType = record.drinkType
        customName = record.customName
        displayName = record.displayName
        volumeMillilitres = record.volumeMillilitres
        occurredAt = record.occurredAt
        isCaloric = record.isCaloric
    }
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
