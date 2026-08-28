import Foundation
import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length type_body_length trailing_comma

@MainActor
final class ISI101PersistenceMigrationTests: XCTestCase {
    func testIndependentV3ThroughV6FalseStoresPreserveChoiceAndRecords() throws {
        try assertHistoricalStoreMatrix(inferredFastDetectionEnabled: false)
    }

    func testIndependentV3ThroughV6TrueStoresPreserveChoiceAndRecords() throws {
        try assertHistoricalStoreMatrix(inferredFastDetectionEnabled: true)
    }

    func testHistoricalSettingsSchemasAreFrozenAndV7MetadataRemainsCurrent() throws {
        let expectedProperties = [
            "id",
            "fastingGoalHours",
            "hasCompletedOnboarding",
            "waterFavouriteMillilitres",
            "teaFavouriteMillilitres",
            "coffeeFavouriteMillilitres",
            "automaticLiveActivityPreferenceRawValue",
            "inferredFastDetectionEnabled",
        ]
        let historicalSchemas = [
            ISI101HistoricalSchema(
                version: "V3",
                schema: Schema(versionedSchema: UFastSchemaV3.self),
                modelType: UFastSchemaV3.AppSettingsRecord.self
            ),
            ISI101HistoricalSchema(
                version: "V4",
                schema: Schema(versionedSchema: UFastSchemaV4.self),
                modelType: UFastSchemaV4.AppSettingsRecord.self
            ),
            ISI101HistoricalSchema(
                version: "V5",
                schema: Schema(versionedSchema: UFastSchemaV5.self),
                modelType: UFastSchemaV5.AppSettingsRecord.self
            ),
            ISI101HistoricalSchema(
                version: "V6",
                schema: Schema(versionedSchema: UFastSchemaV6.self),
                modelType: UFastSchemaV6.AppSettingsRecord.self
            ),
        ]

        for historicalSchema in historicalSchemas {
            let version = historicalSchema.version
            let settings = try XCTUnwrap(
                historicalSchema.schema.entitiesByName["AppSettingsRecord"],
                version
            )
            XCTAssertEqual(settings.storedProperties.map(\.name), expectedProperties, version)
            XCTAssertNotEqual(
                ObjectIdentifier(historicalSchema.modelType),
                ObjectIdentifier(AppSettingsRecord.self),
                version + " must not use the production settings type"
            )
            let inferred = try XCTUnwrap(
                settings.storedPropertiesByName["inferredFastDetectionEnabled"] as? Schema.Attribute,
                version
            )
            XCTAssertTrue(inferred.valueType == Bool.self, version)
            XCTAssertFalse(inferred.isOptional, version)
            XCTAssertEqual(inferred.defaultValue as? Bool, false, version)
        }

        let currentSettings = try XCTUnwrap(
            PersistenceContainer.schema.entitiesByName["AppSettingsRecord"]
        )
        XCTAssertEqual(currentSettings.storedProperties.map(\.name), expectedProperties)
        let currentInferred = try XCTUnwrap(
            currentSettings.storedPropertiesByName["inferredFastDetectionEnabled"] as? Schema.Attribute
        )
        XCTAssertEqual(currentInferred.defaultValue as? Bool, true)
        XCTAssertEqual(PersistenceContainer.schema.entities.count, 9)
        XCTAssertEqual(
            Set(PersistenceContainer.schema.entities.map(\.name)),
            [
                "AppSettingsRecord",
                "FastRecord",
                "FoodEntryRecord",
                "HydrationEntryRecord",
                "HydrationFavouriteRecord",
                "FoodFavouriteRecord",
                "UnknownPeriodRecord",
                "HydrationFavouriteMigrationRecord",
                "InferredFastSuppressionRecord",
            ]
        )
    }

    func testCurrentV7SavedChoicesSurviveCloseReopenAndOrdinaryBootstrap() throws {
        for enabled in [false, true] {
            let directory = try makeDirectory(prefix: "uFast-v7-choice-\(enabled)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let storeURL = directory.appending(path: "production.store")
            let now = Date(timeIntervalSince1970: 1_900_000_000)

            do {
                let container = try PersistenceContainer.make(storeURL: storeURL, now: now)
                let settings = AppSettingsRecord(
                    hasCompletedOnboarding: true,
                    automaticLiveActivityPreference: .enabled,
                    inferredFastDetectionEnabled: enabled
                )
                container.mainContext.insert(settings)
                try container.mainContext.save()
            }

            let result = PersistenceBootstrapResult.open {
                try PersistenceContainer.make(storeURL: storeURL, now: now)
            }
            guard case let .ready(reopened) = result else {
                return XCTFail("Expected V7 bootstrap to reopen saved (enabled) choice")
            }
            let settings = try XCTUnwrap(
                reopened.mainContext.fetch(FetchDescriptor<AppSettingsRecord>()).first
            )
            XCTAssertEqual(settings.inferredFastDetectionEnabled, enabled)
            XCTAssertEqual(settings.automaticLiveActivityPreference, .enabled)
            XCTAssertTrue(settings.hasCompletedOnboarding)
        }
    }

    func testSimulatedMigrationFailurePreservesEverySourceBundleByteAndReopensSource() throws {
        let directory = try makeDirectory(prefix: "uFast-isi101-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try ISI101FixtureWriter.writeV3(
            to: storeURL,
            inferredFastDetectionEnabled: false
        )
        let before = try storeContents(in: directory)

        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(
                storeURL: storeURL,
                simulateMigrationFailure: true
            )
        }
        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected simulated migration failure to produce unavailable state")
        }
        XCTAssertFalse(failure.diagnosticDescription.isEmpty)
        XCTAssertEqual(try storeContents(in: directory), before)

        let sourceSchema = Schema(versionedSchema: ISI101V3SourceSchema.self)
        let source = try ModelContainer(
            for: sourceSchema,
            configurations: [
                ModelConfiguration(schema: sourceSchema, url: storeURL, cloudKitDatabase: .none),
            ]
        )
        let settings = try XCTUnwrap(
            source.mainContext.fetch(FetchDescriptor<ISI101V3SourceSchema.AppSettingsRecord>()).first
        )
        XCTAssertFalse(settings.inferredFastDetectionEnabled)
    }

    private func assertHistoricalStoreMatrix(
        inferredFastDetectionEnabled: Bool
    ) throws {
        for version in 3 ... 6 {
            let directory = try makeDirectory(
                prefix: "uFast-isi101-v\(version)-\(inferredFastDetectionEnabled)"
            )
            defer { try? FileManager.default.removeItem(at: directory) }
            let storeURL = directory.appending(path: "production.store")
            try ISI101FixtureWriter.write(
                version: version,
                to: storeURL,
                inferredFastDetectionEnabled: inferredFastDetectionEnabled
            )
            let sourceSnapshot = try ISI101FixtureSnapshot.source(
                version: version,
                storeURL: storeURL
            )
            let expectedSnapshot = sourceSnapshot.expectedProductionSnapshot(
                for: version,
                migrationDate: ISI101FixtureWriter.now
            )

            do {
                let migrated = try PersistenceContainer.make(
                    storeURL: storeURL,
                    now: ISI101FixtureWriter.now
                )
                let migratedSnapshot = try ISI101FixtureSnapshot.production(migrated.mainContext)
                assertSeededSnapshot(
                    migratedSnapshot,
                    matches: expectedSnapshot,
                    version: version,
                    phase: "migration"
                )
                try assertNoSuppressionRows(in: migrated.mainContext, version: version)
            }

            let reopened = try PersistenceContainer.make(
                storeURL: storeURL,
                now: ISI101FixtureWriter.now
            )
            let reopenedSnapshot = try ISI101FixtureSnapshot.production(reopened.mainContext)
            assertSeededSnapshot(
                reopenedSnapshot,
                matches: expectedSnapshot,
                version: version,
                phase: "reopen"
            )
            try assertNoSuppressionRows(in: reopened.mainContext, version: version)
            print(
                "ISI-101 V\(version) inferred=\(inferredFastDetectionEnabled) " +
                    "migration/reopen preserved the complete seeded snapshot"
            )
        }
    }

    private func assertNoSuppressionRows(in context: ModelContext, version: Int) throws {
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).count,
            0,
            "V\(version) must not fabricate suppressions"
        )
    }

    private func assertSeededSnapshot(
        _ actual: ISI101DomainSnapshot,
        matches source: ISI101DomainSnapshot,
        version: Int,
        phase: String
    ) {
        let actualSeeded = actual.withoutMigrationMarkers
        let expectedSeeded = source.withoutMigrationMarkers
        XCTAssertEqual(
            actualSeeded.completeFieldValues,
            expectedSeeded.completeFieldValues,
            "V\(version) \(phase) complete-field fingerprint must match"
        )
        XCTAssertEqual(
            actualSeeded,
            expectedSeeded,
            "V\(version) \(phase) must preserve the complete seeded snapshot"
        )

        if version <= 4 {
            XCTAssertEqual(
                actual.migrationMarkers.count,
                1,
                "V\(version) \(phase) must create exactly one hydration favourite migration marker"
            )
        } else {
            XCTAssertEqual(
                actual.migrationMarkers,
                source.migrationMarkers,
                "V\(version) \(phase) must preserve the seeded migration marker"
            )
        }
    }
}

private struct ISI101DomainSnapshot: Equatable {
    let settings: [ISI101SettingsSnapshot]
    let fasts: [ISI101FastSnapshot]
    let foods: [ISI101FoodSnapshot]
    let hydrationEntries: [ISI101HydrationSnapshot]
    let hydrationFavourites: [ISI101HydrationFavouriteSnapshot]
    let unknownPeriods: [ISI101UnknownPeriodSnapshot]
    let migrationMarkers: [ISI101MigrationMarkerSnapshot]
    let foodFavourites: [ISI101FoodFavouriteSnapshot]

    init(
        settings: [ISI101SettingsSnapshot],
        fasts: [ISI101FastSnapshot],
        foods: [ISI101FoodSnapshot],
        hydrationEntries: [ISI101HydrationSnapshot],
        hydrationFavourites: [ISI101HydrationFavouriteSnapshot],
        unknownPeriods: [ISI101UnknownPeriodSnapshot],
        migrationMarkers: [ISI101MigrationMarkerSnapshot],
        foodFavourites: [ISI101FoodFavouriteSnapshot]
    ) {
        self.settings = settings.sorted { $0.id.uuidString < $1.id.uuidString }
        self.fasts = fasts.sorted { $0.id.uuidString < $1.id.uuidString }
        self.foods = foods.sorted { $0.id.uuidString < $1.id.uuidString }
        self.hydrationEntries = hydrationEntries.sorted { $0.id.uuidString < $1.id.uuidString }
        self.hydrationFavourites = hydrationFavourites.sorted {
            if $0.creationOrder != $1.creationOrder {
                return $0.creationOrder < $1.creationOrder
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        self.unknownPeriods = unknownPeriods.sorted { $0.id.uuidString < $1.id.uuidString }
        self.migrationMarkers = migrationMarkers.sorted { $0.id.uuidString < $1.id.uuidString }
        self.foodFavourites = foodFavourites.sorted {
            if $0.creationOrder != $1.creationOrder {
                return $0.creationOrder < $1.creationOrder
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var withoutMigrationMarkers: ISI101DomainSnapshot {
        ISI101DomainSnapshot(
            settings: settings,
            fasts: fasts,
            foods: foods,
            hydrationEntries: hydrationEntries,
            hydrationFavourites: hydrationFavourites,
            unknownPeriods: unknownPeriods,
            migrationMarkers: [],
            foodFavourites: foodFavourites
        )
    }

    var completeFieldValues: [String] {
        settings.flatMap(\.allFieldValues)
            + fasts.flatMap(\.allFieldValues)
            + foods.flatMap(\.allFieldValues)
            + hydrationEntries.flatMap(\.allFieldValues)
            + hydrationFavourites.flatMap(\.allFieldValues)
            + unknownPeriods.flatMap(\.allFieldValues)
            + migrationMarkers.flatMap(\.allFieldValues)
            + foodFavourites.flatMap(\.allFieldValues)
    }

    func expectedProductionSnapshot(
        for version: Int,
        migrationDate: Date
    ) -> ISI101DomainSnapshot {
        guard version <= 4, let settings = settings.first else { return self }

        let canonicalFavourites = [
            ISI101HydrationFavouriteSnapshot(
                id: ISI101FixtureConstants.waterFavourite,
                name: "Water",
                volumeMillilitres: settings.waterFavouriteMillilitres,
                isCaloric: false,
                createdAt: migrationDate,
                updatedAt: migrationDate,
                creationOrder: -3
            ),
            ISI101HydrationFavouriteSnapshot(
                id: ISI101FixtureConstants.teaFavourite,
                name: "Tea",
                volumeMillilitres: settings.teaFavouriteMillilitres,
                isCaloric: false,
                createdAt: migrationDate,
                updatedAt: migrationDate,
                creationOrder: -2
            ),
            ISI101HydrationFavouriteSnapshot(
                id: ISI101FixtureConstants.coffeeFavourite,
                name: "Coffee",
                volumeMillilitres: settings.coffeeFavouriteMillilitres,
                isCaloric: false,
                createdAt: migrationDate,
                updatedAt: migrationDate,
                creationOrder: -1
            ),
        ]
        let canonicalizedLegacyFavourites = hydrationFavourites
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt < $1.createdAt
                }
                if $0.creationOrder != $1.creationOrder {
                    return $0.creationOrder < $1.creationOrder
                }
                return $0.id.uuidString < $1.id.uuidString
            }
            .enumerated()
            .map { index, favourite in
                ISI101HydrationFavouriteSnapshot(
                    id: favourite.id,
                    name: favourite.name,
                    volumeMillilitres: favourite.volumeMillilitres,
                    isCaloric: favourite.isCaloric,
                    createdAt: favourite.createdAt,
                    updatedAt: favourite.updatedAt,
                    creationOrder: Int64(index)
                )
            }

        return ISI101DomainSnapshot(
            settings: self.settings,
            fasts: fasts,
            foods: foods,
            hydrationEntries: hydrationEntries,
            hydrationFavourites: canonicalFavourites + canonicalizedLegacyFavourites,
            unknownPeriods: unknownPeriods,
            migrationMarkers: migrationMarkers,
            foodFavourites: foodFavourites
        )
    }
}

private struct ISI101SettingsSnapshot: Equatable {
    let id: UUID
    let fastingGoalHours: Int
    let hasCompletedOnboarding: Bool
    let waterFavouriteMillilitres: Int
    let teaFavouriteMillilitres: Int
    let coffeeFavouriteMillilitres: Int
    let automaticLiveActivityPreferenceRawValue: String
    let inferredFastDetectionEnabled: Bool

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(fastingGoalHours)",
            "\(hasCompletedOnboarding)",
            "\(waterFavouriteMillilitres)",
            "\(teaFavouriteMillilitres)",
            "\(coffeeFavouriteMillilitres)",
            "\(automaticLiveActivityPreferenceRawValue)",
            "\(inferredFastDetectionEnabled)",
        ]
    }
}

private struct ISI101FastSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let goalHoursAtStart: Int
    let originRaw: String
    let reviewStateRaw: String
    let wasAdjustedByUser: Bool
    let hasHistoricalGoal: Bool
    let startBoundaryKindRaw: String?
    let startBoundaryID: UUID?
    let endBoundaryKindRaw: String?
    let endBoundaryID: UUID?
    let reviewBoundaryKindRaw: String?
    let reviewBoundaryID: UUID?

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(startDate)",
            "\(endDate as Any)",
            "\(goalHoursAtStart)",
            "\(originRaw)",
            "\(reviewStateRaw)",
            "\(wasAdjustedByUser)",
            "\(hasHistoricalGoal)",
            "\(startBoundaryKindRaw as Any)",
            "\(startBoundaryID as Any)",
            "\(endBoundaryKindRaw as Any)",
            "\(endBoundaryID as Any)",
            "\(reviewBoundaryKindRaw as Any)",
            "\(reviewBoundaryID as Any)",
        ]
    }
}

private struct ISI101FoodSnapshot: Equatable {
    let id: UUID
    let foodDescription: String
    let occurredAt: Date
    let isCaloric: Bool
    let energyKilocalories: Double?
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
    let fibreGrams: Double?
    let sugarGrams: Double?
    let saltGrams: Double?
    let createdAt: Date
    let updatedAt: Date

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(foodDescription)",
            "\(occurredAt)",
            "\(isCaloric)",
            "\(energyKilocalories as Any)",
            "\(proteinGrams as Any)",
            "\(carbohydrateGrams as Any)",
            "\(fatGrams as Any)",
            "\(fibreGrams as Any)",
            "\(sugarGrams as Any)",
            "\(saltGrams as Any)",
            "\(createdAt)",
            "\(updatedAt)",
        ]
    }
}

private struct ISI101HydrationSnapshot: Equatable {
    let id: UUID
    let drinkTypeRaw: String
    let customName: String?
    let volumeMillilitres: Int
    let occurredAt: Date
    let isCaloric: Bool
    let createdAt: Date
    let updatedAt: Date

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(drinkTypeRaw)",
            "\(customName as Any)",
            "\(volumeMillilitres)",
            "\(occurredAt)",
            "\(isCaloric)",
            "\(createdAt)",
            "\(updatedAt)",
        ]
    }
}

private struct ISI101HydrationFavouriteSnapshot: Equatable {
    let id: UUID
    let name: String
    let volumeMillilitres: Int
    let isCaloric: Bool
    let createdAt: Date
    let updatedAt: Date
    let creationOrder: Int64

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(name)",
            "\(volumeMillilitres)",
            "\(isCaloric)",
            "\(createdAt)",
            "\(updatedAt)",
            "\(creationOrder)",
        ]
    }
}

private struct ISI101UnknownPeriodSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let startBoundaryKindRaw: String
    let startBoundaryID: UUID
    let endBoundaryKindRaw: String
    let endBoundaryID: UUID
    let reasonRaw: String
    let createdAt: Date
    let updatedAt: Date

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(startDate)",
            "\(endDate)",
            "\(startBoundaryKindRaw)",
            "\(startBoundaryID)",
            "\(endBoundaryKindRaw)",
            "\(endBoundaryID)",
            "\(reasonRaw)",
            "\(createdAt)",
            "\(updatedAt)",
        ]
    }
}

private struct ISI101MigrationMarkerSnapshot: Equatable {
    let id: UUID
    let migrationVersion: Int
    let completedAt: Date

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(migrationVersion)",
            "\(completedAt)",
        ]
    }
}

private struct ISI101FoodFavouriteSnapshot: Equatable {
    let id: UUID
    let foodDescription: String
    let energyKilocalories: Double?
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
    let fibreGrams: Double?
    let sugarGrams: Double?
    let saltGrams: Double?
    let createdAt: Date
    let updatedAt: Date
    let creationOrder: Int64
    let revision: Int64

    var allFieldValues: [String] {
        [
            "\(id)",
            "\(foodDescription)",
            "\(energyKilocalories as Any)",
            "\(proteinGrams as Any)",
            "\(carbohydrateGrams as Any)",
            "\(fatGrams as Any)",
            "\(fibreGrams as Any)",
            "\(sugarGrams as Any)",
            "\(saltGrams as Any)",
            "\(createdAt)",
            "\(updatedAt)",
            "\(creationOrder)",
            "\(revision)",
        ]
    }
}

@MainActor
private enum ISI101FixtureSnapshot {
    static func source(version: Int, storeURL: URL) throws -> ISI101DomainSnapshot {
        let schema: Schema
        switch version {
        case 3:
            schema = Schema(versionedSchema: ISI101V3SourceSchema.self)
        case 4:
            schema = Schema(versionedSchema: ISI101V4SourceSchema.self)
        case 5:
            schema = Schema(versionedSchema: ISI101V5SourceSchema.self)
        case 6:
            schema = Schema(versionedSchema: ISI101V6SourceSchema.self)
        default:
            fatalError("Unexpected ISI-101 source version")
        }
        let container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none),
            ]
        )
        switch version {
        case 3:
            return try sourceV3(container.mainContext)
        case 4:
            return try sourceV4(container.mainContext)
        case 5:
            return try sourceV5(container.mainContext)
        case 6:
            return try sourceV6(container.mainContext)
        default:
            fatalError("Unexpected ISI-101 source version")
        }
    }

    static func production(_ context: ModelContext) throws -> ISI101DomainSnapshot {
        try ISI101DomainSnapshot(
            settings: context.fetch(FetchDescriptor<AppSettingsRecord>()).map {
                ISI101SettingsSnapshot($0)
            },
            fasts: context.fetch(FetchDescriptor<FastRecord>()).map {
                ISI101FastSnapshot($0)
            },
            foods: context.fetch(FetchDescriptor<FoodEntryRecord>()).map {
                ISI101FoodSnapshot($0)
            },
            hydrationEntries: context.fetch(FetchDescriptor<HydrationEntryRecord>()).map {
                ISI101HydrationSnapshot($0)
            },
            hydrationFavourites: context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).map {
                ISI101HydrationFavouriteSnapshot($0)
            },
            unknownPeriods: context.fetch(FetchDescriptor<UnknownPeriodRecord>()).map {
                ISI101UnknownPeriodSnapshot($0)
            },
            migrationMarkers: context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).map {
                ISI101MigrationMarkerSnapshot($0)
            },
            foodFavourites: context.fetch(FetchDescriptor<FoodFavouriteRecord>()).map {
                ISI101FoodFavouriteSnapshot($0)
            }
        )
    }

    private static func sourceV3(_ context: ModelContext) throws -> ISI101DomainSnapshot {
        try commonSource(
            context,
            settings: context.fetch(FetchDescriptor<ISI101V3SourceSchema.AppSettingsRecord>()).map {
                ISI101SettingsSnapshot($0)
            },
            fasts: context.fetch(FetchDescriptor<ISI101V3SourceSchema.FastRecord>()).map {
                ISI101FastSnapshot($0)
            },
            includesMigrationMarker: false,
            includesFoodFavourite: false
        )
    }

    private static func sourceV4(_ context: ModelContext) throws -> ISI101DomainSnapshot {
        try commonSource(
            context,
            settings: context.fetch(FetchDescriptor<ISI101V4SourceSchema.AppSettingsRecord>()).map {
                ISI101SettingsSnapshot($0)
            },
            fasts: context.fetch(FetchDescriptor<ISI101SharedSourceModels.FastRecord>()).map {
                ISI101FastSnapshot($0)
            },
            includesMigrationMarker: false,
            includesFoodFavourite: false
        )
    }

    private static func sourceV5(_ context: ModelContext) throws -> ISI101DomainSnapshot {
        try commonSource(
            context,
            settings: context.fetch(FetchDescriptor<ISI101V5SourceSchema.AppSettingsRecord>()).map {
                ISI101SettingsSnapshot($0)
            },
            fasts: context.fetch(FetchDescriptor<ISI101SharedSourceModels.FastRecord>()).map {
                ISI101FastSnapshot($0)
            },
            includesMigrationMarker: true,
            includesFoodFavourite: false
        )
    }

    private static func sourceV6(_ context: ModelContext) throws -> ISI101DomainSnapshot {
        try commonSource(
            context,
            settings: context.fetch(FetchDescriptor<ISI101V6SourceSchema.AppSettingsRecord>()).map {
                ISI101SettingsSnapshot($0)
            },
            fasts: context.fetch(FetchDescriptor<ISI101SharedSourceModels.FastRecord>()).map {
                ISI101FastSnapshot($0)
            },
            includesMigrationMarker: true,
            includesFoodFavourite: true
        )
    }

    private static func commonSource(
        _ context: ModelContext,
        settings: [ISI101SettingsSnapshot],
        fasts: [ISI101FastSnapshot],
        includesMigrationMarker: Bool,
        includesFoodFavourite: Bool
    ) throws -> ISI101DomainSnapshot {
        try ISI101DomainSnapshot(
            settings: settings,
            fasts: fasts,
            foods: context.fetch(FetchDescriptor<ISI101SharedSourceModels.FoodEntryRecord>()).map {
                ISI101FoodSnapshot($0)
            },
            hydrationEntries: context.fetch(FetchDescriptor<ISI101SharedSourceModels.HydrationEntryRecord>()).map {
                ISI101HydrationSnapshot($0)
            },
            hydrationFavourites: context.fetch(
                FetchDescriptor<ISI101SharedSourceModels.HydrationFavouriteRecord>()
            ).map {
                ISI101HydrationFavouriteSnapshot($0)
            },
            unknownPeriods: context.fetch(FetchDescriptor<ISI101SharedSourceModels.UnknownPeriodRecord>()).map {
                ISI101UnknownPeriodSnapshot($0)
            },
            migrationMarkers: includesMigrationMarker
                ? context.fetch(
                    FetchDescriptor<ISI101SharedSourceModels.HydrationFavouriteMigrationRecord>()
                ).map {
                    ISI101MigrationMarkerSnapshot($0)
                }
                : [],
            foodFavourites: includesFoodFavourite
                ? context.fetch(FetchDescriptor<ISI101SharedSourceModels.FoodFavouriteRecord>()).map {
                    ISI101FoodFavouriteSnapshot($0)
                }
                : []
        )
    }
}

private extension ISI101SettingsSnapshot {
    init(_ record: ISI101V3SourceSchema.AppSettingsRecord) {
        self.init(
            id: record.id,
            fastingGoalHours: record.fastingGoalHours,
            hasCompletedOnboarding: record.hasCompletedOnboarding,
            waterFavouriteMillilitres: record.waterFavouriteMillilitres,
            teaFavouriteMillilitres: record.teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: record.coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: record.automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: record.inferredFastDetectionEnabled
        )
    }

    init(_ record: ISI101V4SourceSchema.AppSettingsRecord) {
        self.init(
            id: record.id,
            fastingGoalHours: record.fastingGoalHours,
            hasCompletedOnboarding: record.hasCompletedOnboarding,
            waterFavouriteMillilitres: record.waterFavouriteMillilitres,
            teaFavouriteMillilitres: record.teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: record.coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: record.automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: record.inferredFastDetectionEnabled
        )
    }

    init(_ record: ISI101V5SourceSchema.AppSettingsRecord) {
        self.init(
            id: record.id,
            fastingGoalHours: record.fastingGoalHours,
            hasCompletedOnboarding: record.hasCompletedOnboarding,
            waterFavouriteMillilitres: record.waterFavouriteMillilitres,
            teaFavouriteMillilitres: record.teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: record.coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: record.automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: record.inferredFastDetectionEnabled
        )
    }

    init(_ record: ISI101V6SourceSchema.AppSettingsRecord) {
        self.init(
            id: record.id,
            fastingGoalHours: record.fastingGoalHours,
            hasCompletedOnboarding: record.hasCompletedOnboarding,
            waterFavouriteMillilitres: record.waterFavouriteMillilitres,
            teaFavouriteMillilitres: record.teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: record.coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: record.automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: record.inferredFastDetectionEnabled
        )
    }

    init(_ record: AppSettingsRecord) {
        self.init(
            id: record.id,
            fastingGoalHours: record.fastingGoalHours,
            hasCompletedOnboarding: record.hasCompletedOnboarding,
            waterFavouriteMillilitres: record.waterFavouriteMillilitres,
            teaFavouriteMillilitres: record.teaFavouriteMillilitres,
            coffeeFavouriteMillilitres: record.coffeeFavouriteMillilitres,
            automaticLiveActivityPreferenceRawValue: record.automaticLiveActivityPreferenceRawValue,
            inferredFastDetectionEnabled: record.inferredFastDetectionEnabled
        )
    }
}

private extension ISI101FastSnapshot {
    init(_ record: ISI101V3SourceSchema.FastRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            goalHoursAtStart: record.goalHoursAtStart,
            originRaw: record.originRaw,
            reviewStateRaw: record.reviewStateRaw,
            wasAdjustedByUser: record.wasAdjustedByUser,
            hasHistoricalGoal: record.hasHistoricalGoal,
            startBoundaryKindRaw: record.startBoundaryKindRaw,
            startBoundaryID: record.startBoundaryID,
            endBoundaryKindRaw: record.endBoundaryKindRaw,
            endBoundaryID: record.endBoundaryID,
            reviewBoundaryKindRaw: nil,
            reviewBoundaryID: nil
        )
    }

    init(_ record: ISI101SharedSourceModels.FastRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            goalHoursAtStart: record.goalHoursAtStart,
            originRaw: record.originRaw,
            reviewStateRaw: record.reviewStateRaw,
            wasAdjustedByUser: record.wasAdjustedByUser,
            hasHistoricalGoal: record.hasHistoricalGoal,
            startBoundaryKindRaw: record.startBoundaryKindRaw,
            startBoundaryID: record.startBoundaryID,
            endBoundaryKindRaw: record.endBoundaryKindRaw,
            endBoundaryID: record.endBoundaryID,
            reviewBoundaryKindRaw: record.reviewBoundaryKindRaw,
            reviewBoundaryID: record.reviewBoundaryID
        )
    }

    init(_ record: FastRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            goalHoursAtStart: record.goalHoursAtStart,
            originRaw: record.originRaw,
            reviewStateRaw: record.reviewStateRaw,
            wasAdjustedByUser: record.wasAdjustedByUser,
            hasHistoricalGoal: record.hasHistoricalGoal,
            startBoundaryKindRaw: record.startBoundaryKindRaw,
            startBoundaryID: record.startBoundaryID,
            endBoundaryKindRaw: record.endBoundaryKindRaw,
            endBoundaryID: record.endBoundaryID,
            reviewBoundaryKindRaw: record.reviewBoundaryKindRaw,
            reviewBoundaryID: record.reviewBoundaryID
        )
    }
}

private extension ISI101FoodSnapshot {
    init(_ record: ISI101SharedSourceModels.FoodEntryRecord) {
        self.init(
            id: record.id,
            foodDescription: record.foodDescription,
            occurredAt: record.occurredAt,
            isCaloric: record.isCaloric,
            energyKilocalories: record.energyKilocalories,
            proteinGrams: record.proteinGrams,
            carbohydrateGrams: record.carbohydrateGrams,
            fatGrams: record.fatGrams,
            fibreGrams: record.fibreGrams,
            sugarGrams: record.sugarGrams,
            saltGrams: record.saltGrams,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    init(_ record: FoodEntryRecord) {
        self.init(
            id: record.id,
            foodDescription: record.foodDescription,
            occurredAt: record.occurredAt,
            isCaloric: record.isCaloric,
            energyKilocalories: record.energyKilocalories,
            proteinGrams: record.proteinGrams,
            carbohydrateGrams: record.carbohydrateGrams,
            fatGrams: record.fatGrams,
            fibreGrams: record.fibreGrams,
            sugarGrams: record.sugarGrams,
            saltGrams: record.saltGrams,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

private extension ISI101HydrationSnapshot {
    init(_ record: ISI101SharedSourceModels.HydrationEntryRecord) {
        self.init(
            id: record.id,
            drinkTypeRaw: record.drinkTypeRaw,
            customName: record.customName,
            volumeMillilitres: record.volumeMillilitres,
            occurredAt: record.occurredAt,
            isCaloric: record.isCaloric,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    init(_ record: HydrationEntryRecord) {
        self.init(
            id: record.id,
            drinkTypeRaw: record.drinkTypeRaw,
            customName: record.customName,
            volumeMillilitres: record.volumeMillilitres,
            occurredAt: record.occurredAt,
            isCaloric: record.isCaloric,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

private extension ISI101HydrationFavouriteSnapshot {
    init(_ record: ISI101SharedSourceModels.HydrationFavouriteRecord) {
        self.init(
            id: record.id,
            name: record.name,
            volumeMillilitres: record.volumeMillilitres,
            isCaloric: record.isCaloric,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            creationOrder: record.creationOrder
        )
    }

    init(_ record: HydrationFavouriteRecord) {
        self.init(
            id: record.id,
            name: record.name,
            volumeMillilitres: record.volumeMillilitres,
            isCaloric: record.isCaloric,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            creationOrder: record.creationOrder
        )
    }
}

private extension ISI101UnknownPeriodSnapshot {
    init(_ record: ISI101SharedSourceModels.UnknownPeriodRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            startBoundaryKindRaw: record.startBoundaryKindRaw,
            startBoundaryID: record.startBoundaryID,
            endBoundaryKindRaw: record.endBoundaryKindRaw,
            endBoundaryID: record.endBoundaryID,
            reasonRaw: record.reasonRaw,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    init(_ record: UnknownPeriodRecord) {
        self.init(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            startBoundaryKindRaw: record.startBoundaryKindRaw,
            startBoundaryID: record.startBoundaryID,
            endBoundaryKindRaw: record.endBoundaryKindRaw,
            endBoundaryID: record.endBoundaryID,
            reasonRaw: record.reasonRaw,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }
}

private extension ISI101MigrationMarkerSnapshot {
    init(_ record: ISI101SharedSourceModels.HydrationFavouriteMigrationRecord) {
        self.init(
            id: record.id,
            migrationVersion: record.migrationVersion,
            completedAt: record.completedAt
        )
    }

    init(_ record: HydrationFavouriteMigrationRecord) {
        self.init(
            id: record.id,
            migrationVersion: record.migrationVersion,
            completedAt: record.completedAt
        )
    }
}

private extension ISI101FoodFavouriteSnapshot {
    init(_ record: ISI101SharedSourceModels.FoodFavouriteRecord) {
        self.init(
            id: record.id,
            foodDescription: record.foodDescription,
            energyKilocalories: record.energyKilocalories,
            proteinGrams: record.proteinGrams,
            carbohydrateGrams: record.carbohydrateGrams,
            fatGrams: record.fatGrams,
            fibreGrams: record.fibreGrams,
            sugarGrams: record.sugarGrams,
            saltGrams: record.saltGrams,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            creationOrder: record.creationOrder,
            revision: record.revision
        )
    }

    init(_ record: FoodFavouriteRecord) {
        self.init(
            id: record.id,
            foodDescription: record.foodDescription,
            energyKilocalories: record.energyKilocalories,
            proteinGrams: record.proteinGrams,
            carbohydrateGrams: record.carbohydrateGrams,
            fatGrams: record.fatGrams,
            fibreGrams: record.fibreGrams,
            sugarGrams: record.sugarGrams,
            saltGrams: record.saltGrams,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            creationOrder: record.creationOrder,
            revision: record.revision
        )
    }
}

private func makeDirectory(prefix: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func storeContents(in directory: URL) throws -> [String: Data] {
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey]
    )
    return try Dictionary(uniqueKeysWithValues: urls.compactMap { url in
        guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return try (url.lastPathComponent, Data(contentsOf: url))
    })
}

@MainActor
private enum ISI101FixtureWriter {
    static let now = Date(timeIntervalSince1970: 1_900_000_000)

    static let ids = ISI101FixtureIDs()

    static func write(
        version: Int,
        to storeURL: URL,
        inferredFastDetectionEnabled: Bool
    ) throws {
        switch version {
        case 3:
            try writeV3(to: storeURL, inferredFastDetectionEnabled: inferredFastDetectionEnabled)
        case 4:
            try writeV4(to: storeURL, inferredFastDetectionEnabled: inferredFastDetectionEnabled)
        case 5:
            try writeV5(to: storeURL, inferredFastDetectionEnabled: inferredFastDetectionEnabled)
        case 6:
            try writeV6(to: storeURL, inferredFastDetectionEnabled: inferredFastDetectionEnabled)
        default:
            fatalError("Unexpected ISI-101 fixture version")
        }
    }

    static func writeV3(
        to storeURL: URL,
        inferredFastDetectionEnabled: Bool
    ) throws {
        let schema = Schema(versionedSchema: ISI101V3SourceSchema.self)
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = container.mainContext
        context.insert(
            ISI101V3SourceSchema.AppSettingsRecord(
                id: ids.settings,
                inferredFastDetectionEnabled: inferredFastDetectionEnabled
            )
        )
        ISI101V3SourceSchema.FastRecord.fixtures().forEach(context.insert)
        insertCommonRecords(in: context)
        try context.save()
    }

    private static func writeV4(
        to storeURL: URL,
        inferredFastDetectionEnabled: Bool
    ) throws {
        let schema = Schema(versionedSchema: ISI101V4SourceSchema.self)
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = container.mainContext
        context.insert(
            ISI101V4SourceSchema.AppSettingsRecord(
                id: ids.settings,
                inferredFastDetectionEnabled: inferredFastDetectionEnabled
            )
        )
        ISI101SharedSourceModels.FastRecord.fixtures().forEach(context.insert)
        insertCommonRecords(in: context)
        try context.save()
    }

    private static func writeV5(
        to storeURL: URL,
        inferredFastDetectionEnabled: Bool
    ) throws {
        let schema = Schema(versionedSchema: ISI101V5SourceSchema.self)
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = container.mainContext
        context.insert(
            ISI101V5SourceSchema.AppSettingsRecord(
                id: ids.settings,
                inferredFastDetectionEnabled: inferredFastDetectionEnabled
            )
        )
        ISI101SharedSourceModels.FastRecord.fixtures().forEach(context.insert)
        insertCommonRecords(in: context)
        context.insert(
            ISI101SharedSourceModels.HydrationFavouriteMigrationRecord(
                id: ids.migrationMarker,
                completedAt: now
            )
        )
        try context.save()
    }

    private static func writeV6(
        to storeURL: URL,
        inferredFastDetectionEnabled: Bool
    ) throws {
        let schema = Schema(versionedSchema: ISI101V6SourceSchema.self)
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = container.mainContext
        context.insert(
            ISI101V6SourceSchema.AppSettingsRecord(
                id: ids.settings,
                inferredFastDetectionEnabled: inferredFastDetectionEnabled
            )
        )
        ISI101SharedSourceModels.FastRecord.fixtures().forEach(context.insert)
        insertCommonRecords(in: context)
        context.insert(
            ISI101SharedSourceModels.HydrationFavouriteMigrationRecord(
                id: ids.migrationMarker,
                completedAt: now
            )
        )
        context.insert(
            ISI101SharedSourceModels.FoodFavouriteRecord(
                id: ids.foodFavourite,
                foodDescription: "Saved meal",
                energyKilocalories: 500,
                revision: 2,
                createdAt: now,
                updatedAt: now
            )
        )
        try context.save()
    }

    private static func insertCommonRecords(in context: ModelContext) {
        context.insert(
            ISI101SharedSourceModels.FoodEntryRecord(
                id: ids.food,
                foodDescription: "Legacy supper",
                occurredAt: now.addingTimeInterval(-1000),
                energyKilocalories: 640,
                proteinGrams: 31,
                carbohydrateGrams: 72,
                fatGrams: 22,
                fibreGrams: 8,
                sugarGrams: 6,
                saltGrams: 1.4,
                createdAt: now,
                updatedAt: now
            )
        )
        context.insert(
            ISI101SharedSourceModels.HydrationEntryRecord(
                id: ids.hydration,
                drinkTypeRaw: "custom",
                customName: "Legacy broth",
                volumeMillilitres: 375,
                occurredAt: now,
                isCaloric: true,
                createdAt: now,
                updatedAt: now
            )
        )
        context.insert(
            ISI101SharedSourceModels.HydrationFavouriteRecord(
                id: ids.hydrationFavourite,
                name: "Custom tonic",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: now,
                updatedAt: now,
                creationOrder: 7
            )
        )
        context.insert(
            ISI101SharedSourceModels.UnknownPeriodRecord(
                id: ids.unknownPeriod,
                startDate: now.addingTimeInterval(-80000),
                endDate: now.addingTimeInterval(-75000),
                startBoundaryID: ids.food,
                endBoundaryID: ids.hydration,
                createdAt: now,
                updatedAt: now
            )
        )
    }

    private static func makeContainer(schema: Schema, storeURL: URL) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)]
        )
    }
}

private struct ISI101FixtureIDs {
    let settings = UUID(uuidString: "10100000-0000-0000-0000-000000000001") ?? UUID()
    let activeFast = UUID(uuidString: "10100000-0000-0000-0000-000000000002") ?? UUID()
    let completedFast = UUID(uuidString: "10100000-0000-0000-0000-000000000003") ?? UUID()
    let reconstructedFast = UUID(uuidString: "10100000-0000-0000-0000-000000000004") ?? UUID()
    let food = UUID(uuidString: "10100000-0000-0000-0000-000000000005") ?? UUID()
    let hydration = UUID(uuidString: "10100000-0000-0000-0000-000000000006") ?? UUID()
    let hydrationFavourite = UUID(uuidString: "10100000-0000-0000-0000-000000000007") ?? UUID()
    let unknownPeriod = UUID(uuidString: "10100000-0000-0000-0000-000000000008") ?? UUID()
    let migrationMarker = UUID(uuidString: "10100000-0000-0000-0000-000000000009") ?? UUID()
    let foodFavourite = UUID(uuidString: "10100000-0000-0000-0000-000000000010") ?? UUID()
}

private struct ISI101HistoricalSchema {
    let version: String
    let schema: Schema
    let modelType: Any.Type
}

private enum ISI101FixtureConstants {
    private static func fixedUUID(_ rawValue: String) -> UUID {
        guard let uuid = UUID(uuidString: rawValue) else {
            preconditionFailure("Invalid ISI-101 fixture UUID")
        }
        return uuid
    }

    static let now = Date(timeIntervalSince1970: 1_900_000_000)
    static let ids = ISI101FixtureIDs()
    static let waterFavourite = fixedUUID("00000000-0000-0000-0000-000000000001")
    static let teaFavourite = fixedUUID("00000000-0000-0000-0000-000000000002")
    static let coffeeFavourite = fixedUUID("00000000-0000-0000-0000-000000000003")
}

private enum ISI101SharedSourceModels {
    @Model
    final class FastRecord {
        var id: UUID = UUID()
        var startDate: Date = Date.now
        var endDate: Date?
        var goalHoursAtStart: Int = 12
        var originRaw: String = "recorded"
        var reviewStateRaw: String = "confirmed"
        var wasAdjustedByUser: Bool = false
        var hasHistoricalGoal: Bool = true
        var startBoundaryKindRaw: String?
        var startBoundaryID: UUID?
        var endBoundaryKindRaw: String?
        var endBoundaryID: UUID?
        var reviewBoundaryKindRaw: String?
        var reviewBoundaryID: UUID?

        init(
            id: UUID,
            startDate: Date,
            endDate: Date?,
            goalHoursAtStart: Int,
            originRaw: String,
            reviewStateRaw: String,
            wasAdjustedByUser: Bool,
            hasHistoricalGoal: Bool,
            startBoundaryKindRaw: String?,
            startBoundaryID: UUID?,
            endBoundaryKindRaw: String?,
            endBoundaryID: UUID?,
            reviewBoundaryKindRaw: String?,
            reviewBoundaryID: UUID?
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.goalHoursAtStart = goalHoursAtStart
            self.originRaw = originRaw
            self.reviewStateRaw = reviewStateRaw
            self.wasAdjustedByUser = wasAdjustedByUser
            self.hasHistoricalGoal = hasHistoricalGoal
            self.startBoundaryKindRaw = startBoundaryKindRaw
            self.startBoundaryID = startBoundaryID
            self.endBoundaryKindRaw = endBoundaryKindRaw
            self.endBoundaryID = endBoundaryID
            self.reviewBoundaryKindRaw = reviewBoundaryKindRaw
            self.reviewBoundaryID = reviewBoundaryID
        }

        static func fixtures() -> [ISI101SharedSourceModels.FastRecord] {
            let ids = ISI101FixtureConstants.ids
            let now = ISI101FixtureConstants.now
            return [
                Self(
                    id: ids.activeFast,
                    startDate: now.addingTimeInterval(-20000),
                    endDate: nil,
                    goalHoursAtStart: 17,
                    originRaw: "recorded",
                    reviewStateRaw: "confirmed",
                    wasAdjustedByUser: false,
                    hasHistoricalGoal: true,
                    startBoundaryKindRaw: nil,
                    startBoundaryID: nil,
                    endBoundaryKindRaw: nil,
                    endBoundaryID: nil,
                    reviewBoundaryKindRaw: nil,
                    reviewBoundaryID: nil
                ),
                Self(
                    id: ids.completedFast,
                    startDate: now.addingTimeInterval(-100_000),
                    endDate: now.addingTimeInterval(-90000),
                    goalHoursAtStart: 16,
                    originRaw: "recorded",
                    reviewStateRaw: "confirmed",
                    wasAdjustedByUser: false,
                    hasHistoricalGoal: true,
                    startBoundaryKindRaw: nil,
                    startBoundaryID: nil,
                    endBoundaryKindRaw: nil,
                    endBoundaryID: nil,
                    reviewBoundaryKindRaw: nil,
                    reviewBoundaryID: nil
                ),
                Self(
                    id: ids.reconstructedFast,
                    startDate: now.addingTimeInterval(-200_000),
                    endDate: now.addingTimeInterval(-150_000),
                    goalHoursAtStart: 12,
                    originRaw: "reconstructed",
                    reviewStateRaw: "needsReview",
                    wasAdjustedByUser: true,
                    hasHistoricalGoal: false,
                    startBoundaryKindRaw: "food",
                    startBoundaryID: ids.food,
                    endBoundaryKindRaw: "hydration",
                    endBoundaryID: ids.hydration,
                    reviewBoundaryKindRaw: "food",
                    reviewBoundaryID: ids.food
                ),
            ]
        }
    }

    @Model
    final class FoodEntryRecord {
        var id: UUID = UUID()
        var foodDescription: String = ""
        var occurredAt: Date = Date.now
        var isCaloric: Bool = true
        var energyKilocalories: Double?
        var proteinGrams: Double?
        var carbohydrateGrams: Double?
        var fatGrams: Double?
        var fibreGrams: Double?
        var sugarGrams: Double?
        var saltGrams: Double?
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        init(
            id: UUID,
            foodDescription: String,
            occurredAt: Date,
            energyKilocalories: Double,
            proteinGrams: Double,
            carbohydrateGrams: Double,
            fatGrams: Double,
            fibreGrams: Double,
            sugarGrams: Double,
            saltGrams: Double,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.foodDescription = foodDescription
            self.occurredAt = occurredAt
            self.energyKilocalories = energyKilocalories
            self.proteinGrams = proteinGrams
            self.carbohydrateGrams = carbohydrateGrams
            self.fatGrams = fatGrams
            self.fibreGrams = fibreGrams
            self.sugarGrams = sugarGrams
            self.saltGrams = saltGrams
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class HydrationEntryRecord {
        var id: UUID = UUID()
        var drinkTypeRaw: String = "water"
        var customName: String?
        var volumeMillilitres: Int = 500
        var occurredAt: Date = Date.now
        var isCaloric: Bool = false
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        init(
            id: UUID,
            drinkTypeRaw: String,
            customName: String?,
            volumeMillilitres: Int,
            occurredAt: Date,
            isCaloric: Bool,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.drinkTypeRaw = drinkTypeRaw
            self.customName = customName
            self.volumeMillilitres = volumeMillilitres
            self.occurredAt = occurredAt
            self.isCaloric = isCaloric
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class HydrationFavouriteRecord {
        var id: UUID = UUID()
        var name: String = ""
        var volumeMillilitres: Int = 1
        var isCaloric: Bool = false
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var creationOrder: Int64 = 0

        init(
            id: UUID,
            name: String,
            volumeMillilitres: Int,
            isCaloric: Bool,
            createdAt: Date,
            updatedAt: Date,
            creationOrder: Int64
        ) {
            self.id = id
            self.name = name
            self.volumeMillilitres = volumeMillilitres
            self.isCaloric = isCaloric
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.creationOrder = creationOrder
        }
    }

    @Model
    final class UnknownPeriodRecord {
        var id: UUID = UUID()
        var startDate: Date = Date.now
        var endDate: Date = Date.now
        var startBoundaryKindRaw: String = "food"
        var startBoundaryID: UUID = UUID()
        var endBoundaryKindRaw: String = "hydration"
        var endBoundaryID: UUID = UUID()
        var reasonRaw: String = "insufficientEvidence"
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now

        init(
            id: UUID,
            startDate: Date,
            endDate: Date,
            startBoundaryID: UUID,
            endBoundaryID: UUID,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.startBoundaryID = startBoundaryID
            self.endBoundaryID = endBoundaryID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            reasonRaw = "userChoice"
        }
    }

    @Model
    final class HydrationFavouriteMigrationRecord {
        var id: UUID = UUID()
        var migrationVersion: Int = 1
        var completedAt: Date = Date.now

        init(id: UUID, completedAt: Date) {
            self.id = id
            self.completedAt = completedAt
        }
    }

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
            id: UUID,
            foodDescription: String,
            energyKilocalories: Double,
            revision: Int64,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.foodDescription = foodDescription
            self.energyKilocalories = energyKilocalories
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.revision = revision
        }
    }
}

private enum ISI101V3SourceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false

        init(id: UUID, inferredFastDetectionEnabled: Bool) {
            self.id = id
            fastingGoalHours = 17
            hasCompletedOnboarding = true
            waterFavouriteMillilitres = 750
            teaFavouriteMillilitres = 425
            coffeeFavouriteMillilitres = 225
            automaticLiveActivityPreferenceRawValue = "enabled"
            self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
        }
    }

    @Model
    final class FastRecord {
        var id: UUID = UUID()
        var startDate: Date = Date.now
        var endDate: Date?
        var goalHoursAtStart: Int = 12
        var originRaw: String = "recorded"
        var reviewStateRaw: String = "confirmed"
        var wasAdjustedByUser: Bool = false
        var hasHistoricalGoal: Bool = true
        var startBoundaryKindRaw: String?
        var startBoundaryID: UUID?
        var endBoundaryKindRaw: String?
        var endBoundaryID: UUID?

        init(
            id: UUID,
            startDate: Date,
            endDate: Date?,
            goalHoursAtStart: Int,
            originRaw: String,
            reviewStateRaw: String,
            wasAdjustedByUser: Bool,
            hasHistoricalGoal: Bool,
            startBoundaryKindRaw: String?,
            startBoundaryID: UUID?,
            endBoundaryKindRaw: String?,
            endBoundaryID: UUID?
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.goalHoursAtStart = goalHoursAtStart
            self.originRaw = originRaw
            self.reviewStateRaw = reviewStateRaw
            self.wasAdjustedByUser = wasAdjustedByUser
            self.hasHistoricalGoal = hasHistoricalGoal
            self.startBoundaryKindRaw = startBoundaryKindRaw
            self.startBoundaryID = startBoundaryID
            self.endBoundaryKindRaw = endBoundaryKindRaw
            self.endBoundaryID = endBoundaryID
        }

        static func fixtures() -> [ISI101V3SourceSchema.FastRecord] {
            let ids = ISI101FixtureConstants.ids
            let now = ISI101FixtureConstants.now
            return [
                Self(
                    id: ids.activeFast,
                    startDate: now.addingTimeInterval(-20000),
                    endDate: nil,
                    goalHoursAtStart: 17,
                    originRaw: "recorded",
                    reviewStateRaw: "confirmed",
                    wasAdjustedByUser: false,
                    hasHistoricalGoal: true,
                    startBoundaryKindRaw: nil,
                    startBoundaryID: nil,
                    endBoundaryKindRaw: nil,
                    endBoundaryID: nil
                ),
                Self(
                    id: ids.completedFast,
                    startDate: now.addingTimeInterval(-100_000),
                    endDate: now.addingTimeInterval(-90000),
                    goalHoursAtStart: 16,
                    originRaw: "recorded",
                    reviewStateRaw: "confirmed",
                    wasAdjustedByUser: false,
                    hasHistoricalGoal: true,
                    startBoundaryKindRaw: nil,
                    startBoundaryID: nil,
                    endBoundaryKindRaw: nil,
                    endBoundaryID: nil
                ),
                Self(
                    id: ids.reconstructedFast,
                    startDate: now.addingTimeInterval(-200_000),
                    endDate: now.addingTimeInterval(-150_000),
                    goalHoursAtStart: 12,
                    originRaw: "reconstructed",
                    reviewStateRaw: "needsReview",
                    wasAdjustedByUser: true,
                    hasHistoricalGoal: false,
                    startBoundaryKindRaw: "food",
                    startBoundaryID: ids.food,
                    endBoundaryKindRaw: "hydration",
                    endBoundaryID: ids.hydration
                ),
            ]
        }
    }

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        ISI101SharedSourceModels.FoodEntryRecord.self,
        ISI101SharedSourceModels.HydrationEntryRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteRecord.self,
        ISI101SharedSourceModels.UnknownPeriodRecord.self,
    ]
}

private enum ISI101V4SourceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false

        init(id: UUID, inferredFastDetectionEnabled: Bool) {
            self.id = id
            fastingGoalHours = 17
            hasCompletedOnboarding = true
            waterFavouriteMillilitres = 750
            teaFavouriteMillilitres = 425
            coffeeFavouriteMillilitres = 225
            automaticLiveActivityPreferenceRawValue = "enabled"
            self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
        }
    }

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        ISI101SharedSourceModels.FastRecord.self,
        ISI101SharedSourceModels.FoodEntryRecord.self,
        ISI101SharedSourceModels.HydrationEntryRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteRecord.self,
        ISI101SharedSourceModels.UnknownPeriodRecord.self,
    ]
}

private enum ISI101V5SourceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false

        init(id: UUID, inferredFastDetectionEnabled: Bool) {
            self.id = id
            fastingGoalHours = 17
            hasCompletedOnboarding = true
            waterFavouriteMillilitres = 750
            teaFavouriteMillilitres = 425
            coffeeFavouriteMillilitres = 225
            automaticLiveActivityPreferenceRawValue = "enabled"
            self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
        }
    }

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        ISI101SharedSourceModels.FastRecord.self,
        ISI101SharedSourceModels.FoodEntryRecord.self,
        ISI101SharedSourceModels.HydrationEntryRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteRecord.self,
        ISI101SharedSourceModels.UnknownPeriodRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteMigrationRecord.self,
    ]
}

private enum ISI101V6SourceSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false

        init(id: UUID, inferredFastDetectionEnabled: Bool) {
            self.id = id
            fastingGoalHours = 17
            hasCompletedOnboarding = true
            waterFavouriteMillilitres = 750
            teaFavouriteMillilitres = 425
            coffeeFavouriteMillilitres = 225
            automaticLiveActivityPreferenceRawValue = "enabled"
            self.inferredFastDetectionEnabled = inferredFastDetectionEnabled
        }
    }

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        ISI101SharedSourceModels.FastRecord.self,
        ISI101SharedSourceModels.FoodEntryRecord.self,
        ISI101SharedSourceModels.HydrationEntryRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteRecord.self,
        ISI101SharedSourceModels.UnknownPeriodRecord.self,
        ISI101SharedSourceModels.HydrationFavouriteMigrationRecord.self,
        ISI101SharedSourceModels.FoodFavouriteRecord.self,
    ]
}
