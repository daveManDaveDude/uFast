import Foundation

@MainActor
protocol SettingsFoodFavouriteCommanding: AnyObject {
    func settingsCreateFoodFavourite(description: String, nutrition: FoodNutrition) throws -> FoodFavouriteSnapshot
    func settingsUpdateFoodFavourite(
        id: UUID,
        expectedRevision: Int64,
        description: String,
        nutrition: FoodNutrition
    ) throws -> FoodFavouriteSnapshot
    func settingsDeleteFoodFavourite(id: UUID, expectedRevision: Int64) throws
}

@MainActor
protocol TodayFoodFavouriteCommanding: AnyObject {
    func todayAddFoodFavourite(_ operation: FoodFavouriteQuickAddOperation, endingActiveFast: Bool) throws
}

extension ApplicationCommands: SettingsFoodFavouriteCommanding, TodayFoodFavouriteCommanding {
    func settingsCreateFoodFavourite(
        description: String,
        nutrition: FoodNutrition
    ) throws -> FoodFavouriteSnapshot {
        try createFoodFavourite(description: description, nutrition: nutrition)
    }

    func settingsUpdateFoodFavourite(
        id: UUID,
        expectedRevision: Int64,
        description: String,
        nutrition: FoodNutrition
    ) throws -> FoodFavouriteSnapshot {
        try updateFoodFavourite(
            id: id,
            expectedRevision: expectedRevision,
            description: description,
            nutrition: nutrition
        )
    }

    func settingsDeleteFoodFavourite(id: UUID, expectedRevision: Int64) throws {
        try deleteFoodFavourite(id: id, expectedRevision: expectedRevision)
    }

    func todayAddFoodFavourite(
        _ operation: FoodFavouriteQuickAddOperation,
        endingActiveFast: Bool
    ) throws {
        let draft = try foodDraft(for: operation.favouriteID, occurredAt: operation.occurredAt)
        try simulateFoodFavStaleAfterConfirmIfNeeded(endingActiveFast: endingActiveFast)
        let goal = try authoritativeSettingsRecord()?.fastingGoal ?? .default
        try saveFood(
            draft,
            replacing: nil,
            goal: goal,
            endingActiveFast: endingActiveFast,
            operationID: operation.id
        )
    }
}

extension ApplicationCommands {
    func createFoodFavourite(
        description: String,
        nutrition: FoodNutrition
    ) throws -> FoodFavouriteSnapshot {
        try requireUnambiguousSettingsAuthority()
        let snapshot = try foodFavouriteStore().create(
            description: description,
            nutrition: nutrition,
            at: clock.now
        )
        projectionCoordinator.publishHistoryInvalidation()
        return snapshot
    }

    func updateFoodFavourite(
        id: UUID,
        expectedRevision: Int64,
        description: String,
        nutrition: FoodNutrition
    ) throws -> FoodFavouriteSnapshot {
        try requireUnambiguousSettingsAuthority()
        try simulateFoodFavouriteStaleIfConfigured()
        let snapshot = try foodFavouriteStore().update(
            id: id,
            expectedRevision: expectedRevision,
            description: description,
            nutrition: nutrition,
            at: clock.now
        )
        projectionCoordinator.publishHistoryInvalidation()
        return snapshot
    }

    func deleteFoodFavourite(id: UUID, expectedRevision: Int64) throws {
        try requireUnambiguousSettingsAuthority()
        try foodFavouriteStore().delete(id: id, expectedRevision: expectedRevision)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func foodDraft(
        for favourite: FoodFavouriteSnapshot,
        occurredAt: Date
    ) throws -> FoodEntryDraft {
        try foodDraft(for: favourite.id, occurredAt: occurredAt)
    }

    func foodDraft(
        for favouriteID: UUID,
        occurredAt: Date
    ) throws -> FoodEntryDraft {
        try requireUnambiguousSettingsAuthority()
        try simulateFoodFavouriteStaleIfConfigured()
        let resolved = try foodFavouriteStore().resolve(id: favouriteID)
        return FoodFavouriteProjection.foodDraft(from: resolved, occurredAt: occurredAt)
    }
}

private extension ApplicationCommands {
    func simulateFoodFavouriteStaleIfConfigured() throws {
        guard configuration.simulateFoodFavouriteStale, !hasSimulatedFoodFavouriteStale else { return }
        hasSimulatedFoodFavouriteStale = true
        throw FoodFavouriteStoreError.stale
    }

    func simulateFoodFavStaleAfterConfirmIfNeeded(endingActiveFast: Bool) throws {
        guard endingActiveFast,
              configuration.simulateFoodFavStaleAfterConfirm,
              !hasSimulatedFoodFavStaleAfterConfirm
        else { return }
        hasSimulatedFoodFavStaleAfterConfirm = true
        // The command has re-resolved the identifier above. This deterministic
        // seam models the record becoming stale before the atomic event/fast
        // commit without changing committed test data.
        throw FoodFavouriteStoreError.stale
    }

    func foodFavouriteStore() -> SwiftDataFoodFavouriteStore {
        SwiftDataFoodFavouriteStore(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFoodFavouriteSaveFailure,
            diagnosticSink: diagnosticSink
        )
    }
}
