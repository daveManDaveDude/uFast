import Foundation
import SwiftData

// swiftlint:disable trailing_comma

enum HydrationFavouriteMigrationError: Error, Equatable {
    case conflictingSettingsAuthority
    case conflictingFavouriteAuthority
    case invalidLegacyAmount
    case invalidLegacyName
    case invalidLegacyCreationOrder
    case duplicateLegacyName
    case reservedLegacyNameConflict
    case conflictingMigrationMarkers
}

/// Converts the legacy settings-owned defaults after SwiftData has opened the
/// store at V5. The marker and all converted rows are committed together, so a
/// failed conversion can neither expose a partial list nor cause a later
/// launch to guess from an empty row.
enum HydrationFavouriteMigration {
    static let migrationVersion = 1

    static let waterID = deterministicID("00000000-0000-0000-0000-000000000001")
    static let teaID = deterministicID("00000000-0000-0000-0000-000000000002")
    static let coffeeID = deterministicID("00000000-0000-0000-0000-000000000003")

    static func run(
        in context: ModelContext,
        now: Date,
        diagnosticSink _: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) throws {
        let markers = try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>())
        guard markers.count <= 1 else {
            throw HydrationFavouriteMigrationError.conflictingMigrationMarkers
        }
        let settings = try canonicalSettings(in: context)
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
            .sorted(by: canonicalOrder)
        try rejectOrphanedFavouriteRecords(
            markers: markers,
            hasSettings: settings != nil,
            records: records
        )
        guard markers.first == nil else { return }
        guard let settings else { return }

        try validateLegacyAmounts(settings)
        try rejectDuplicateIDs(in: records)
        try rejectDeterministicIDCollisions(in: records)
        try validateLegacyRecords(records)

        let converted = try convertedRecords(settings: settings, before: records, at: now)
        canonicalizeLegacyCreationOrder(records)
        converted.forEach(context.insert)
        context.insert(
            HydrationFavouriteMigrationRecord(
                migrationVersion: migrationVersion,
                completedAt: now
            )
        )

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func seedNewStore(
        in context: ModelContext,
        at date: Date
    ) throws {
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        guard records.isEmpty else { return }
        context.insert(
            HydrationFavouriteRecord(
                id: waterID,
                name: HydrationDrinkType.water.displayName,
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: date,
                creationOrder: 0
            )
        )
    }

    private static func validateLegacyRecords(
        _ records: [HydrationFavouriteRecord]
    ) throws {
        var normalizedNames = Set<String>()
        let legacyNames = Set([
            HydrationFavouriteValidator.normalizedName(HydrationDrinkType.water.displayName),
            HydrationFavouriteValidator.normalizedName(HydrationDrinkType.tea.displayName),
            HydrationFavouriteValidator.normalizedName(HydrationDrinkType.coffee.displayName),
        ])
        for record in records {
            guard HydrationEntryValidator.isValid(volumeMillilitres: record.volumeMillilitres) else {
                throw HydrationFavouriteMigrationError.invalidLegacyAmount
            }
            let trimmedName = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard HydrationEntryValidator.hasVisibleText(trimmedName),
                  trimmedName.count <= HydrationEntryValidator.customNameLimit
            else {
                throw HydrationFavouriteMigrationError.invalidLegacyName
            }
            let normalized = HydrationFavouriteValidator.normalizedName(record.name)
            guard !normalized.isEmpty else {
                throw HydrationFavouriteMigrationError.duplicateLegacyName
            }
            guard normalizedNames.insert(normalized).inserted else {
                throw HydrationFavouriteMigrationError.duplicateLegacyName
            }
            guard !legacyNames.contains(normalized) else {
                throw HydrationFavouriteMigrationError.reservedLegacyNameConflict
            }
        }
    }

    private static func rejectOrphanedFavouriteRecords(
        markers: [HydrationFavouriteMigrationRecord],
        hasSettings: Bool,
        records: [HydrationFavouriteRecord]
    ) throws {
        guard records.isEmpty || !markers.isEmpty || hasSettings else {
            throw HydrationFavouriteMigrationError.conflictingFavouriteAuthority
        }
    }

    private static func canonicalSettings(
        in context: ModelContext
    ) throws -> AppSettingsRecord? {
        let settings = try context.fetch(FetchDescriptor<AppSettingsRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        guard let canonical = settings.first else { return nil }
        guard settings.dropFirst().allSatisfy({
            $0.userVisibleSnapshot == canonical.userVisibleSnapshot
                && $0.waterFavouriteMillilitres == canonical.waterFavouriteMillilitres
                && $0.teaFavouriteMillilitres == canonical.teaFavouriteMillilitres
                && $0.coffeeFavouriteMillilitres == canonical.coffeeFavouriteMillilitres
        }) else {
            throw HydrationFavouriteMigrationError.conflictingSettingsAuthority
        }
        return canonical
    }

    private static func validateLegacyAmounts(
        _ settings: AppSettingsRecord
    ) throws {
        let amounts = [
            settings.waterFavouriteMillilitres,
            settings.teaFavouriteMillilitres,
            settings.coffeeFavouriteMillilitres,
        ]
        for amount in amounts {
            guard HydrationEntryValidator.isValid(volumeMillilitres: amount) else {
                throw HydrationFavouriteMigrationError.invalidLegacyAmount
            }
        }
    }

    private static func rejectDeterministicIDCollisions(
        in records: [HydrationFavouriteRecord]
    ) throws {
        let convertedIDs = Set([waterID, teaID, coffeeID])
        guard records.allSatisfy({ !convertedIDs.contains($0.id) }) else {
            throw HydrationFavouriteMigrationError.conflictingFavouriteAuthority
        }
    }

    private static func rejectDuplicateIDs(
        in records: [HydrationFavouriteRecord]
    ) throws {
        var ids = Set<UUID>()
        for record in records {
            guard ids.insert(record.id).inserted else {
                throw HydrationFavouriteMigrationError.conflictingFavouriteAuthority
            }
        }
    }

    private static func convertedOrder(
        before records: [HydrationFavouriteRecord]
    ) throws -> Int64 {
        guard let minimum = records.map(\.creationOrder).min() else { return -3 }
        guard minimum >= Int64.min + 3,
              minimum <= Int64.max - 2
        else {
            throw HydrationFavouriteMigrationError.invalidLegacyCreationOrder
        }
        return -3
    }

    private static func canonicalizeLegacyCreationOrder(
        _ records: [HydrationFavouriteRecord]
    ) {
        for (index, record) in records.enumerated() {
            record.creationOrder = Int64(index)
        }
    }

    private static func convertedRecords(
        settings: AppSettingsRecord,
        before records: [HydrationFavouriteRecord],
        at now: Date
    ) throws -> [HydrationFavouriteRecord] {
        let order = try convertedOrder(before: records)
        return [
            HydrationFavouriteRecord(
                id: waterID,
                name: HydrationDrinkType.water.displayName,
                volumeMillilitres: settings.waterFavouriteMillilitres,
                isCaloric: false,
                createdAt: now,
                creationOrder: order
            ),
            HydrationFavouriteRecord(
                id: teaID,
                name: HydrationDrinkType.tea.displayName,
                volumeMillilitres: settings.teaFavouriteMillilitres,
                isCaloric: false,
                createdAt: now,
                creationOrder: order + 1
            ),
            HydrationFavouriteRecord(
                id: coffeeID,
                name: HydrationDrinkType.coffee.displayName,
                volumeMillilitres: settings.coffeeFavouriteMillilitres,
                isCaloric: false,
                createdAt: now,
                creationOrder: order + 2
            ),
        ]
    }

    private static func deterministicID(_ rawValue: String) -> UUID {
        guard let id = UUID(uuidString: rawValue) else {
            fatalError("Invalid deterministic hydration favourite ID: \(rawValue)")
        }
        return id
    }

    private static func canonicalOrder(
        _ lhs: HydrationFavouriteRecord,
        _ rhs: HydrationFavouriteRecord
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.creationOrder != rhs.creationOrder {
            return lhs.creationOrder < rhs.creationOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
