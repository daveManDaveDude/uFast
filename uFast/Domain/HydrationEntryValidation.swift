import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_parameter_count line_length trailing_comma

enum HydrationEntryValidator {
    static let minimumVolumeMillilitres = 1
    static let maximumVolumeMillilitres = 5000
    static let customNameLimit = 80

    private static let invisibleNameCharacters = CharacterSet.whitespacesAndNewlines
        .union(.controlCharacters)
        .union(.nonBaseCharacters)

    static func isValid(volumeMillilitres: Int) -> Bool {
        DomainValidation.contains(
            volumeMillilitres,
            in: minimumVolumeMillilitres ... maximumVolumeMillilitres
        )
    }

    static func validatedCustomName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              hasVisibleText(trimmed),
              trimmed.count <= customNameLimit
        else {
            return nil
        }
        return trimmed
    }

    static func hasVisibleText(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            !invisibleNameCharacters.contains($0)
        }
    }

    static func validated(
        type: HydrationDrinkType,
        customName: String,
        volumeMillilitres: Int,
        occurredAt: Date,
        isCaloric: Bool,
        now: Date,
        calendar: Calendar,
        allowedRange: Range<Date>? = nil
    ) -> HydrationEntryDraft? {
        guard isValid(volumeMillilitres: volumeMillilitres) else { return nil }
        if let allowedRange {
            guard allowedRange.contains(occurredAt),
                  occurredAt <= now
            else { return nil }
        } else {
            guard occurredAt <= now,
                  calendar.isDate(occurredAt, inSameDayAs: now)
            else { return nil }
        }
        let name = type == .custom ? validatedCustomName(customName) : nil
        guard type != .custom || name != nil else { return nil }
        return HydrationEntryDraft(
            type: type,
            customName: name,
            volumeMillilitres: volumeMillilitres,
            occurredAt: occurredAt,
            isCaloric: isCaloric
        )
    }
}

struct HydrationEntryDraft: Equatable {
    let type: HydrationDrinkType
    let customName: String?
    let volumeMillilitres: Int
    let occurredAt: Date
    let isCaloric: Bool
}

struct HydrationFavourite: Equatable, Identifiable {
    let type: HydrationDrinkType
    let volumeMillilitres: Int
    let customName: String?
    let isCaloric: Bool
    let userCreatedID: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    let creationOrder: Int64?

    init(
        type: HydrationDrinkType,
        volumeMillilitres: Int,
        customName: String? = nil,
        isCaloric: Bool = false,
        userCreatedID: UUID? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        creationOrder: Int64? = nil
    ) {
        self.type = type
        self.volumeMillilitres = volumeMillilitres
        self.customName = customName
        self.isCaloric = isCaloric
        self.userCreatedID = userCreatedID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creationOrder = creationOrder
    }

    init(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        createdAt: Date,
        updatedAt: Date,
        creationOrder: Int64 = 0
    ) {
        self.init(
            type: .custom,
            volumeMillilitres: volumeMillilitres,
            customName: name,
            isCaloric: isCaloric,
            userCreatedID: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            creationOrder: creationOrder
        )
    }

    var id: UUID {
        userCreatedID ?? Self.builtInID(for: type)
    }

    var name: String {
        customName ?? type.displayName
    }

    var displayName: String {
        name
    }

    static func builtInID(for type: HydrationDrinkType) -> UUID {
        switch type {
        case .water: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        case .tea: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        case .coffee: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
        case .custom: UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()
        }
    }
}

enum HydrationFavouriteProvider {
    /// Record snapshots are the only runtime source for favourite templates.
    /// The legacy overloads remain source-compatible for old fixture code but
    /// deliberately return no synthesized defaults.
    static func favourites(records: [HydrationFavouriteSnapshot]) -> [HydrationFavourite] {
        records.map(\.hydrationFavourite)
    }
}

enum HydrationTimelineCalculations {
    static func fluidTotal(_ entries: [HydrationEntryRecord]) -> Int {
        entries.reduce(0) { $0 + $1.volumeMillilitres }
    }
}
