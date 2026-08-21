// SwiftData record-to-value mapping belongs to the persistence adapter boundary.
// Feature views consume the resulting immutable snapshots without importing SwiftData.

extension AppSettingsSnapshot {
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

extension ActiveFastSnapshot {
    init(_ record: FastRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
    }
}

extension FoodEntrySnapshot {
    init(_ record: FoodEntryRecord) {
        id = record.id
        foodDescription = record.foodDescription
        occurredAt = record.occurredAt
        nutrition = record.nutrition
        // Food is always caloric. Older stores may contain a stale persisted flag.
        isCaloric = true
    }
}

extension HydrationEntrySnapshot {
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
