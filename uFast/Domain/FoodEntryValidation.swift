import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

struct FoodNutrition: Equatable {
    var energyKilocalories: Double?
    var proteinGrams: Double?
    var carbohydrateGrams: Double?
    var fatGrams: Double?
    var fibreGrams: Double?
    var sugarGrams: Double?
    var saltGrams: Double?

    init(
        energyKilocalories: Double? = nil,
        proteinGrams: Double? = nil,
        carbohydrateGrams: Double? = nil,
        fatGrams: Double? = nil,
        fibreGrams: Double? = nil,
        sugarGrams: Double? = nil,
        saltGrams: Double? = nil
    ) {
        self.energyKilocalories = energyKilocalories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fibreGrams = fibreGrams
        self.sugarGrams = sugarGrams
        self.saltGrams = saltGrams
    }

    var values: [Double] {
        [
            energyKilocalories,
            proteinGrams,
            carbohydrateGrams,
            fatGrams,
            fibreGrams,
            sugarGrams,
            saltGrams,
        ].compactMap(\.self)
    }
}

struct FoodEntryDraft: Equatable {
    let description: String
    let occurredAt: Date
    let nutrition: FoodNutrition

    init(
        description: String,
        occurredAt: Date,
        nutrition: FoodNutrition = FoodNutrition()
    ) {
        self.description = description
        self.occurredAt = occurredAt
        self.nutrition = nutrition
    }

    var isCaloric: Bool {
        true
    }
}

enum FoodEntryValidationError: Error, Equatable {
    case emptyDescription
    case descriptionTooLong
    case invalidNutrition
    case beforeToday
    case futureTime
    case outsideSelectedRange
}

enum FoodEntryValidator {
    static let descriptionLimit = 200
    static let maximumNutritionValue = 1_000_000.0

    static func validated(
        description: String,
        occurredAt: Date,
        nutrition: FoodNutrition,
        now: Date,
        calendar: Calendar,
        allowedRange: Range<Date>? = nil
    ) -> Result<FoodEntryDraft, FoodEntryValidationError> {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            return .failure(.emptyDescription)
        }
        guard trimmedDescription.count <= descriptionLimit else {
            return .failure(.descriptionTooLong)
        }
        guard nutrition.values.allSatisfy({
            DomainValidation.isFinite($0, in: 0 ... maximumNutritionValue)
        }) else {
            return .failure(.invalidNutrition)
        }
        if let allowedRange {
            guard HistoricalEventRangeValidator.contains(
                occurredAt,
                allowedRange: allowedRange
            ) else {
                return .failure(.outsideSelectedRange)
            }
            guard occurredAt <= now else {
                return .failure(.futureTime)
            }
        } else {
            guard occurredAt >= calendar.startOfDay(for: now) else {
                return .failure(.beforeToday)
            }
            guard occurredAt <= now else {
                return .failure(.futureTime)
            }
        }

        return .success(
            FoodEntryDraft(
                description: trimmedDescription,
                occurredAt: occurredAt,
                nutrition: nutrition
            )
        )
    }
}
