import Foundation

struct HydrationFavouriteSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let volumeMillilitres: Int
    let isCaloric: Bool
    let createdAt: Date
    let updatedAt: Date
    let creationOrder: Int64

    init(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        createdAt: Date,
        updatedAt: Date,
        creationOrder: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.volumeMillilitres = volumeMillilitres
        self.isCaloric = isCaloric
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creationOrder = creationOrder
    }

    var hydrationFavourite: HydrationFavourite {
        HydrationFavourite(
            id: id,
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            createdAt: createdAt,
            updatedAt: updatedAt,
            creationOrder: creationOrder
        )
    }
}

enum HydrationFavouriteValidationError: Error, Equatable {
    case blankName
    case nameTooLong
    case duplicateName
    case invalidAmount
}

enum HydrationFavouriteStoreError: Error, Equatable {
    case invalidName
    case nameTooLong
    case duplicateName
    case invalidAmount
    case recordNotFound
    case conflictingAuthorities
    case simulatedSaveFailure
}

struct HydrationFavouriteValidatedValues: Equatable, Sendable {
    let name: String
    let amount: Int
    let isCaloric: Bool
}

enum HydrationFavouriteValidator {
    static let nameLimit = HydrationEntryValidator.customNameLimit
    static let minimumAmount = HydrationEntryValidator.minimumVolumeMillilitres
    static let maximumAmount = HydrationEntryValidator.maximumVolumeMillilitres

    static func trimmedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedName(_ name: String) -> String {
        // Compatibility mapping converts full-width forms, including U+3000
        // IDEOGRAPHIC SPACE, before the case/diacritic/width fold.
        trimmedName(name).precomposedStringWithCompatibilityMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    static func validationError(
        name: String,
        amount: String,
        existing: [HydrationFavouriteSnapshot],
        excluding excludedID: UUID? = nil
    ) -> HydrationFavouriteValidationError? {
        let trimmed = trimmedName(name)
        guard !trimmed.isEmpty, HydrationEntryValidator.hasVisibleText(trimmed) else {
            return .blankName
        }
        guard trimmed.count <= nameLimit else { return .nameTooLong }
        guard let volume = Int(amount), (minimumAmount ... maximumAmount).contains(volume) else {
            return .invalidAmount
        }
        let normalized = normalizedName(trimmed)
        guard !existing.contains(where: {
            $0.id != excludedID && normalizedName($0.name) == normalized
        }) else { return .duplicateName }
        return nil
    }

    static func validated(
        name: String,
        amount: Int,
        isCaloric: Bool,
        existing: [HydrationFavouriteSnapshot],
        excluding excludedID: UUID? = nil
    ) throws -> HydrationFavouriteValidatedValues {
        guard let error = validationError(
            name: name,
            amount: String(amount),
            existing: existing,
            excluding: excludedID
        ) else {
            return HydrationFavouriteValidatedValues(
                name: trimmedName(name),
                amount: amount,
                isCaloric: isCaloric
            )
        }
        switch error {
        case .blankName: throw HydrationFavouriteStoreError.invalidName
        case .nameTooLong: throw HydrationFavouriteStoreError.nameTooLong
        case .duplicateName: throw HydrationFavouriteStoreError.duplicateName
        case .invalidAmount: throw HydrationFavouriteStoreError.invalidAmount
        }
    }
}

enum HydrationFavouriteProjection {
    static func hydrationDraft(
        from favourite: HydrationFavourite,
        occurredAt: Date
    ) -> HydrationEntryDraft {
        HydrationEntryDraft(
            type: favourite.type,
            customName: favourite.type == .custom ? favourite.displayName : nil,
            volumeMillilitres: favourite.volumeMillilitres,
            occurredAt: occurredAt,
            isCaloric: favourite.isCaloric
        )
    }
}
