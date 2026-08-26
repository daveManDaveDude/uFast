import Foundation

extension SettingsFeatureController {
    func createFoodFavourite(description: String, nutrition: FoodNutrition) throws {
        guard let commands = foodCommands else { throw ApplicationCommandError.recordNotFound }
        _ = try commands.settingsCreateFoodFavourite(description: description, nutrition: nutrition)
    }

    func updateFoodFavourite(
        id: UUID,
        expectedRevision: Int64,
        description: String,
        nutrition: FoodNutrition
    ) throws {
        guard let commands = foodCommands else { throw ApplicationCommandError.recordNotFound }
        _ = try commands.settingsUpdateFoodFavourite(
            id: id,
            expectedRevision: expectedRevision,
            description: description,
            nutrition: nutrition
        )
    }

    func deleteFoodFavourite(id: UUID, expectedRevision: Int64) throws {
        guard let commands = foodCommands else { throw ApplicationCommandError.recordNotFound }
        try commands.settingsDeleteFoodFavourite(id: id, expectedRevision: expectedRevision)
    }
}
