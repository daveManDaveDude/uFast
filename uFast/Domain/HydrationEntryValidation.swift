import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_parameter_count line_length trailing_comma

enum HydrationEntryValidator {
    static let minimumVolumeMillilitres = 1
    static let maximumVolumeMillilitres = 5000
    static let customNameLimit = 80

    static func isValid(volumeMillilitres: Int) -> Bool {
        DomainValidation.contains(
            volumeMillilitres,
            in: minimumVolumeMillilitres ... maximumVolumeMillilitres
        )
    }

    static func validatedCustomName(_ name: String) -> String? {
        DomainValidation.nonEmptyTrimmed(name, maximumLength: customNameLimit)
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

    var isUserCreated: Bool {
        userCreatedID != nil
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
    static func favourites(snapshot: AppSettingsSnapshot?) -> [HydrationFavourite] {
        values(
            water: snapshot?.waterFavouriteMillilitres ?? 500,
            tea: snapshot?.teaFavouriteMillilitres ?? 300,
            coffee: snapshot?.coffeeFavouriteMillilitres ?? 300
        )
    }

    static func favourites(settings: AppSettingsRecord?) -> [HydrationFavourite] {
        values(
            water: settings?.waterFavouriteMillilitres ?? 500,
            tea: settings?.teaFavouriteMillilitres ?? 300,
            coffee: settings?.coffeeFavouriteMillilitres ?? 300
        )
    }

    private static func values(water: Int, tea: Int, coffee: Int) -> [HydrationFavourite] {
        [
            HydrationFavourite(type: .water, volumeMillilitres: water, isCaloric: false),
            HydrationFavourite(type: .tea, volumeMillilitres: tea, isCaloric: false),
            HydrationFavourite(type: .coffee, volumeMillilitres: coffee, isCaloric: false),
        ]
    }

    static func combined(
        settings: AppSettingsSnapshot?,
        userCreated: [HydrationFavouriteSnapshot]
    ) -> [HydrationFavourite] {
        favourites(snapshot: settings) + userCreated
            .sorted { lhs, rhs in
                if lhs.creationOrder != rhs.creationOrder {
                    return lhs.creationOrder < rhs.creationOrder
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map(\.hydrationFavourite)
    }
}

enum HydrationTimelineCalculations {
    static func fluidTotal(_ entries: [HydrationEntryRecord]) -> Int {
        entries.reduce(0) { $0 + $1.volumeMillilitres }
    }
}
