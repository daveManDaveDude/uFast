import Foundation
import SwiftData

struct FoodEntryRecordSnapshot {
    let draft: FoodEntryDraft
    let isCaloric: Bool
    let updatedAt: Date
}

@Model
final class FoodEntryRecord {
    var id: UUID = UUID()
    private(set) var foodDescription: String = ""
    private(set) var occurredAt: Date = Date.now
    private(set) var isCaloric: Bool = true
    private(set) var energyKilocalories: Double?
    private(set) var proteinGrams: Double?
    private(set) var carbohydrateGrams: Double?
    private(set) var fatGrams: Double?
    private(set) var fibreGrams: Double?
    private(set) var sugarGrams: Double?
    private(set) var saltGrams: Double?
    private(set) var createdAt: Date = Date.now
    private(set) var updatedAt: Date = Date.now

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
            nutrition: nutrition
        )
    }

    var snapshot: FoodEntryRecordSnapshot {
        FoodEntryRecordSnapshot(
            draft: draft,
            isCaloric: isCaloric,
            updatedAt: updatedAt
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

    func restore(from snapshot: FoodEntryRecordSnapshot) {
        update(from: snapshot.draft, at: snapshot.updatedAt)
        isCaloric = snapshot.isCaloric
    }
}
