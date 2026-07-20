import Foundation
import SwiftData

@Model
final class FoodEntryRecord {
    @Attribute(.unique) var id: UUID
    private(set) var foodDescription: String
    private(set) var occurredAt: Date
    private(set) var isCaloric: Bool
    private(set) var energyKilocalories: Double?
    private(set) var proteinGrams: Double?
    private(set) var carbohydrateGrams: Double?
    private(set) var fatGrams: Double?
    private(set) var fibreGrams: Double?
    private(set) var sugarGrams: Double?
    private(set) var saltGrams: Double?
    private(set) var createdAt: Date
    private(set) var updatedAt: Date

    init(
        id: UUID = UUID(),
        draft: FoodEntryDraft,
        createdAt: Date
    ) {
        self.id = id
        foodDescription = draft.description
        occurredAt = draft.occurredAt
        isCaloric = draft.isCaloric
        energyKilocalories = draft.nutrition.energyKilocalories
        proteinGrams = draft.nutrition.proteinGrams
        carbohydrateGrams = draft.nutrition.carbohydrateGrams
        fatGrams = draft.nutrition.fatGrams
        fibreGrams = draft.nutrition.fibreGrams
        sugarGrams = draft.nutrition.sugarGrams
        saltGrams = draft.nutrition.saltGrams
        self.createdAt = createdAt
        updatedAt = createdAt
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

    var draft: FoodEntryDraft {
        FoodEntryDraft(
            description: foodDescription,
            occurredAt: occurredAt,
            isCaloric: isCaloric,
            nutrition: nutrition
        )
    }

    func update(from draft: FoodEntryDraft, at updateDate: Date) {
        foodDescription = draft.description
        occurredAt = draft.occurredAt
        isCaloric = draft.isCaloric
        energyKilocalories = draft.nutrition.energyKilocalories
        proteinGrams = draft.nutrition.proteinGrams
        carbohydrateGrams = draft.nutrition.carbohydrateGrams
        fatGrams = draft.nutrition.fatGrams
        fibreGrams = draft.nutrition.fibreGrams
        sugarGrams = draft.nutrition.sugarGrams
        saltGrams = draft.nutrition.saltGrams
        updatedAt = updateDate
    }
}
