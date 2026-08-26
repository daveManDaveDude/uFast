import Foundation

enum FoodFavouriteNutritionField: String, CaseIterable, Equatable, Sendable {
    case energyKilocalories
    case proteinGrams
    case carbohydrateGrams
    case fatGrams
    case fibreGrams
    case sugarGrams
    case saltGrams
}

enum FoodFavouriteCommitState: String, Equatable, Sendable {
    case saving
    case success
    case failure
    case stale
}

struct FoodFavouriteQuickAddOperation: Equatable, Identifiable, Sendable {
    let id: UUID
    let favouriteID: UUID
    let occurredAt: Date

    init(id: UUID = UUID(), favouriteID: UUID, occurredAt: Date) {
        self.id = id
        self.favouriteID = favouriteID
        self.occurredAt = occurredAt
    }
}

struct FoodFavouriteSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let description: String
    let nutrition: FoodNutrition
    let createdAt: Date
    let updatedAt: Date
    let creationOrder: Int64
    let revision: Int64

    init(
        id: UUID = UUID(),
        description: String,
        nutrition: FoodNutrition = FoodNutrition(),
        createdAt: Date,
        updatedAt: Date? = nil,
        creationOrder: Int64 = 0,
        revision: Int64 = 0
    ) {
        self.id = id
        self.description = description
        self.nutrition = nutrition
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.creationOrder = creationOrder
        self.revision = revision
    }
}

enum FoodFavouriteValidationError: Error, Equatable {
    case blankDescription
    case descriptionTooLong
    case duplicateDescription
    case invalidNutrition(FoodFavouriteNutritionField)
}

enum FoodFavouriteStoreError: Error, Equatable {
    case blankDescription
    case descriptionTooLong
    case duplicateDescription
    case invalidNutrition(FoodFavouriteNutritionField)
    case recordNotFound
    case stale
    case conflictingAuthorities
    case revisionOverflow
    case simulatedSaveFailure
}

struct FoodFavouriteValidatedValues: Equatable, Sendable {
    let description: String
    let nutrition: FoodNutrition
}

enum FoodFavouriteValidator {
    static let descriptionLimit = FoodEntryValidator.descriptionLimit
    static let maximumNutritionValue = FoodEntryValidator.maximumNutritionValue

    static func trimmedDescription(_ description: String) -> String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedDescription(_ description: String) -> String {
        trimmedDescription(description)
            .precomposedStringWithCompatibilityMapping
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }

    static func validationError(
        description: String,
        nutrition: FoodNutrition,
        existing: [FoodFavouriteSnapshot],
        excluding excludedID: UUID? = nil
    ) -> FoodFavouriteValidationError? {
        let trimmed = trimmedDescription(description)
        guard !trimmed.isEmpty, HydrationEntryValidator.hasVisibleText(trimmed) else {
            return .blankDescription
        }
        guard trimmed.count <= descriptionLimit else { return .descriptionTooLong }
        if existing.contains(where: {
            $0.id != excludedID && normalizedDescription($0.description) == normalizedDescription(trimmed)
        }) {
            return .duplicateDescription
        }
        for field in FoodFavouriteNutritionField.allCases {
            guard let value = nutrition.value(for: field) else { continue }
            guard DomainValidation.isFinite(value, in: 0 ... maximumNutritionValue) else {
                return .invalidNutrition(field)
            }
        }
        return nil
    }

    static func validated(
        description: String,
        nutrition: FoodNutrition,
        existing: [FoodFavouriteSnapshot],
        excluding excludedID: UUID? = nil
    ) throws -> FoodFavouriteValidatedValues {
        if let error = validationError(
            description: description,
            nutrition: nutrition,
            existing: existing,
            excluding: excludedID
        ) {
            throw error
        }
        return FoodFavouriteValidatedValues(
            description: trimmedDescription(description),
            nutrition: nutrition
        )
    }

    static func storeError(for error: FoodFavouriteValidationError) -> FoodFavouriteStoreError {
        switch error {
        case .blankDescription: .blankDescription
        case .descriptionTooLong: .descriptionTooLong
        case .duplicateDescription: .duplicateDescription
        case let .invalidNutrition(field): .invalidNutrition(field)
        }
    }
}

extension FoodNutrition {
    func value(for field: FoodFavouriteNutritionField) -> Double? {
        switch field {
        case .energyKilocalories: energyKilocalories
        case .proteinGrams: proteinGrams
        case .carbohydrateGrams: carbohydrateGrams
        case .fatGrams: fatGrams
        case .fibreGrams: fibreGrams
        case .sugarGrams: sugarGrams
        case .saltGrams: saltGrams
        }
    }
}

enum FoodFavouriteProjection {
    static func foodDraft(
        from favourite: FoodFavouriteSnapshot,
        occurredAt: Date
    ) -> FoodEntryDraft {
        FoodEntryDraft(
            description: favourite.description,
            occurredAt: occurredAt,
            nutrition: favourite.nutrition
        )
    }
}
