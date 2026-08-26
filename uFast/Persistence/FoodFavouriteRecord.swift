import Foundation
import SwiftData

@Model
final class FoodFavouriteRecord {
    var id: UUID = UUID()
    var foodDescription: String = ""
    var energyKilocalories: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?
    var fibreGrams: Double?
    var sugarGrams: Double?
    var saltGrams: Double?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var creationOrder: Int64 = 0
    var revision: Int64 = 0

    init(
        id: UUID = UUID(),
        description: String,
        nutrition: FoodNutrition,
        createdAt: Date,
        updatedAt: Date? = nil,
        creationOrder: Int64 = 0,
        revision: Int64 = 0
    ) {
        self.id = id
        foodDescription = description
        energyKilocalories = nutrition.energyKilocalories
        proteinGrams = nutrition.proteinGrams
        carbohydrateGrams = nutrition.carbohydrateGrams
        fatGrams = nutrition.fatGrams
        fibreGrams = nutrition.fibreGrams
        sugarGrams = nutrition.sugarGrams
        saltGrams = nutrition.saltGrams
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.creationOrder = creationOrder
        self.revision = revision
    }

    var nutrition: FoodNutrition {
        FoodNutrition(
            energyKilocalories: energyKilocalories,
            proteinGrams: proteinGrams,
            carbohydrateGrams: carbohydrateGrams,
            fatGrams: fatGrams,
            fibreGrams: fibreGrams,
            sugarGrams: sugarGrams,
            saltGrams: saltGrams
        )
    }

    var snapshot: FoodFavouriteSnapshot {
        FoodFavouriteSnapshot(
            id: id,
            description: foodDescription,
            nutrition: nutrition,
            createdAt: createdAt,
            updatedAt: updatedAt,
            creationOrder: creationOrder,
            revision: revision
        )
    }

    func update(
        description: String,
        nutrition: FoodNutrition,
        updatedAt: Date,
        revision: Int64
    ) {
        foodDescription = description
        energyKilocalories = nutrition.energyKilocalories
        proteinGrams = nutrition.proteinGrams
        carbohydrateGrams = nutrition.carbohydrateGrams
        fatGrams = nutrition.fatGrams
        fibreGrams = nutrition.fibreGrams
        sugarGrams = nutrition.sugarGrams
        saltGrams = nutrition.saltGrams
        self.updatedAt = updatedAt
        self.revision = revision
    }
}
