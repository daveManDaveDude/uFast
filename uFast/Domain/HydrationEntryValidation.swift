import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_parameter_count line_length trailing_comma

enum HydrationEntryValidator {
    static let minimumVolumeMillilitres = 1
    static let maximumVolumeMillilitres = 5000
    static let customNameLimit = 80

    static func isValid(volumeMillilitres: Int) -> Bool {
        (minimumVolumeMillilitres ... maximumVolumeMillilitres).contains(volumeMillilitres)
    }

    static func validatedCustomName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= customNameLimit ? trimmed : nil
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
                  occurredAt < calendar.startOfDay(for: now)
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

struct HydrationFavourite: Equatable {
    let type: HydrationDrinkType
    let volumeMillilitres: Int
}

enum HydrationFavouriteProvider {
    static func favourites(settings: AppSettingsRecord?) -> [HydrationFavourite] {
        [
            HydrationFavourite(type: .water, volumeMillilitres: settings?.waterFavouriteMillilitres ?? 500),
            HydrationFavourite(type: .tea, volumeMillilitres: settings?.teaFavouriteMillilitres ?? 300),
            HydrationFavourite(type: .coffee, volumeMillilitres: settings?.coffeeFavouriteMillilitres ?? 300),
        ]
    }
}

enum HydrationTimelineCalculations {
    static func fluidTotal(_ entries: [HydrationEntryRecord]) -> Int {
        entries.reduce(0) { $0 + $1.volumeMillilitres }
    }
}
