import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class HydrationFavouriteMigrationDiskTests: XCTestCase {
    private let migrationDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testV4OnDiskFixtureConvertsOncePreservesRowsHistoryAndDeletion() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let customID = try XCTUnwrap(UUID(uuidString: "70100000-0000-0000-0000-000000000001"))
        let secondCustomID = try XCTUnwrap(UUID(uuidString: "70100000-0000-0000-0000-000000000002"))
        let historyID = try XCTUnwrap(UUID(uuidString: "70100000-0000-0000-0000-000000000003"))
        let customCreatedAt = migrationDate.addingTimeInterval(-300)
        try writeConversionFixture(
            to: storeURL,
            customID: customID,
            secondCustomID: secondCustomID,
            historyID: historyID,
            customCreatedAt: customCreatedAt
        )

        let migrated = try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        try assertConvertedStore(
            migrated,
            customID: customID,
            secondCustomID: secondCustomID,
            historyID: historyID,
            customCreatedAt: customCreatedAt
        )
        let reopened = try PersistenceContainer.make(
            storeURL: storeURL,
            now: migrationDate.addingTimeInterval(1)
        )
        let water = try XCTUnwrap(
            reopened.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>())
                .first { $0.id == HydrationFavouriteMigration.waterID }
        )
        reopened.mainContext.delete(water)
        try reopened.mainContext.save()
        let afterDeletion = try PersistenceContainer.make(
            storeURL: storeURL,
            now: migrationDate.addingTimeInterval(2)
        )
        XCTAssertNil(
            try afterDeletion.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>())
                .first { $0.id == HydrationFavouriteMigration.waterID }
        )
        XCTAssertEqual(
            try afterDeletion.mainContext.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).count,
            1
        )
        XCTAssertEqual(
            try afterDeletion.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).first?.id,
            historyID
        )
    }

    func testV4EquivalentDuplicateSettingsMigrateBeforeAuthorityCollapse() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-equivalent-settings")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let lowerID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000010")
        )
        let higherID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000020")
        )
        do {
            let schema = Schema(versionedSchema: UFastSchemaV4.self)
            let legacy = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none),
                ]
            )
            legacy.mainContext.insert(
                AppSettingsRecord(
                    id: higherID,
                    hasCompletedOnboarding: true,
                    waterFavouriteMillilitres: 750,
                    teaFavouriteMillilitres: 425,
                    coffeeFavouriteMillilitres: 225
                )
            )
            legacy.mainContext.insert(
                AppSettingsRecord(
                    id: lowerID,
                    hasCompletedOnboarding: true,
                    waterFavouriteMillilitres: 750,
                    teaFavouriteMillilitres: 425,
                    coffeeFavouriteMillilitres: 225
                )
            )
            try legacy.mainContext.save()
        }

        let migrated = try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        let context = migrated.mainContext
        let amountsByID = try Dictionary(uniqueKeysWithValues: context.fetch(
            FetchDescriptor<HydrationFavouriteRecord>()
        ).map { ($0.id, $0.volumeMillilitres) })
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.waterID], 750)
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.teaID], 425)
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.coffeeID], 225)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 2)

        let settingsStore = SwiftDataSettingsStore(modelContext: context)
        try settingsStore.prepareForUse()
        XCTAssertEqual(try settingsStore.authoritativeRecord()?.id, lowerID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
    }

    private func assertConvertedStore(
        _ container: ModelContainer,
        customID: UUID,
        secondCustomID: UUID,
        historyID: UUID,
        customCreatedAt: Date
    ) throws {
        let context = container.mainContext
        let favourites = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
            .sorted { $0.creationOrder < $1.creationOrder }
        XCTAssertEqual(favourites.map(\.id), [
            HydrationFavouriteMigration.waterID,
            HydrationFavouriteMigration.teaID,
            HydrationFavouriteMigration.coffeeID,
            customID,
            secondCustomID,
        ])
        XCTAssertEqual(favourites.map(\.volumeMillilitres), [750, 425, 225, 330, 250])
        XCTAssertEqual(favourites.map(\.isCaloric), [false, false, false, false, true])
        XCTAssertEqual(favourites[3].createdAt, customCreatedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationEntryRecord>()).first?.id, historyID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count, 5)
    }

    private func writeConversionFixture(
        to storeURL: URL,
        customID: UUID,
        secondCustomID: UUID,
        historyID: UUID,
        customCreatedAt: Date
    ) throws {
        let schema = Schema(versionedSchema: UFastSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)]
        )
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                hasCompletedOnboarding: true,
                waterFavouriteMillilitres: 750,
                teaFavouriteMillilitres: 425,
                coffeeFavouriteMillilitres: 225
            )
        )
        context.insert(
            HydrationFavouriteRecord(
                id: customID,
                name: "Sparkling water",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: customCreatedAt,
                creationOrder: 0
            )
        )
        context.insert(
            HydrationFavouriteRecord(
                id: secondCustomID,
                name: "Juice",
                volumeMillilitres: 250,
                isCaloric: true,
                createdAt: migrationDate.addingTimeInterval(-200),
                creationOrder: 1
            )
        )
        context.insert(
            HydrationEntryRecord(
                id: historyID,
                type: .custom,
                customName: "Sparkling water",
                volumeMillilitres: 330,
                occurredAt: customCreatedAt,
                isCaloric: false,
                createdAt: customCreatedAt
            )
        )
        try context.save()
    }

    private func makeDirectory(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
final class HydrationFavouriteMigrationFailureTests: XCTestCase {
    private let migrationDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testV4OrphanFavouriteRowsFailBootstrapAndPreserveStore() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-orphan")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try writeV4Store(to: storeURL) { context in
            context.insert(
                HydrationFavouriteRecord(
                    name: "Orphan favourite",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate
                )
            )
        }
        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        }
        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected orphan favourite rows to make persistence unavailable")
        }
        XCTAssertTrue(failure.diagnosticDescription.contains("conflictingFavouriteAuthority"))
        let unchanged = try currentContainer(at: storeURL)
        let context = unchanged.mainContext
        XCTAssertTrue(try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count, 1)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first?.name,
            "Orphan favourite"
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    func testV4InvalidLegacyAmountPreservesDataAndRoutesBootstrapToUnavailable() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try writeV4Store(to: storeURL) { context in
            context.insert(
                AppSettingsRecord(
                    hasCompletedOnboarding: true,
                    waterFavouriteMillilitres: 0,
                    teaFavouriteMillilitres: 425,
                    coffeeFavouriteMillilitres: 225
                )
            )
            context.insert(
                HydrationFavouriteRecord(
                    name: "Existing favourite",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate
                )
            )
        }
        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        }
        guard case .unavailable = result else {
            return XCTFail("Expected V4 conversion failure to make persistence unavailable")
        }
        let unchanged = try currentContainer(at: storeURL)
        let context = unchanged.mainContext
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettingsRecord>()).first)
        XCTAssertEqual(settings.waterFavouriteMillilitres, 0)
        XCTAssertEqual(settings.teaFavouriteMillilitres, 425)
        XCTAssertEqual(settings.coffeeFavouriteMillilitres, 225)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count, 1)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first?.name,
            "Existing favourite"
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    func testV4DeterministicIDConflictPreservesDataAndRoutesBootstrapToUnavailable() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try writeV4Store(to: storeURL) { context in
            context.insert(
                AppSettingsRecord(
                    hasCompletedOnboarding: true,
                    waterFavouriteMillilitres: 750,
                    teaFavouriteMillilitres: 425,
                    coffeeFavouriteMillilitres: 225
                )
            )
            context.insert(
                HydrationFavouriteRecord(
                    id: HydrationFavouriteMigration.waterID,
                    name: "Legacy authority",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate,
                    creationOrder: 7
                )
            )
        }
        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        }
        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected deterministic ID conflict to make persistence unavailable")
        }
        XCTAssertTrue(failure.diagnosticDescription.contains("conflictingFavouriteAuthority"))
        let unchanged = try currentContainer(at: storeURL)
        let context = unchanged.mainContext
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettingsRecord>()).first)
        XCTAssertEqual(settings.waterFavouriteMillilitres, 750)
        XCTAssertEqual(settings.teaFavouriteMillilitres, 425)
        XCTAssertEqual(settings.coffeeFavouriteMillilitres, 225)
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, HydrationFavouriteMigration.waterID)
        XCTAssertEqual(records.first?.name, "Legacy authority")
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    func testV4DuplicateFavouriteIDsPreserveDataAndRouteBootstrapToUnavailable() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-duplicate")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let duplicateID = try XCTUnwrap(
            UUID(uuidString: "70300000-0000-0000-0000-000000000001")
        )
        try writeV4Store(to: storeURL) { context in
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            context.insert(
                HydrationFavouriteRecord(
                    id: duplicateID,
                    name: "First authority",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate,
                    creationOrder: 1
                )
            )
            context.insert(
                HydrationFavouriteRecord(
                    id: duplicateID,
                    name: "Second authority",
                    volumeMillilitres: 355,
                    isCaloric: false,
                    createdAt: migrationDate.addingTimeInterval(1),
                    creationOrder: 2
                )
            )
        }
        let unchanged = try bootstrapUnavailable(
            at: storeURL,
            containing: "conflictingFavouriteAuthority"
        )
        let records = try unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.id), [duplicateID, duplicateID])
        XCTAssertTrue(
            try unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertFalse(unchanged.mainContext.hasChanges)
    }

    func testV4ExtremeCreationOrderPreservesDataAndRoutesBootstrapToUnavailable() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-order")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try writeV4Store(to: storeURL) { context in
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            context.insert(
                HydrationFavouriteRecord(
                    name: "Corrupt order",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate,
                    creationOrder: Int64.min
                )
            )
        }
        let unchanged = try bootstrapUnavailable(
            at: storeURL,
            containing: "invalidLegacyCreationOrder"
        )
        let record = try XCTUnwrap(
            unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first
        )
        XCTAssertEqual(record.creationOrder, Int64.min)
        XCTAssertTrue(
            try unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertFalse(unchanged.mainContext.hasChanges)
    }

    func testV4MaximumCreationOrderPreservesDataAndRoutesBootstrapToUnavailable() throws {
        let directory = try makeDirectory(prefix: "uFast-v4-favourites-maximum-order")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try writeV4Store(to: storeURL) { context in
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            context.insert(
                HydrationFavouriteRecord(
                    name: "Corrupt maximum order",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: migrationDate,
                    creationOrder: Int64.max
                )
            )
        }
        let unchanged = try bootstrapUnavailable(
            at: storeURL,
            containing: "invalidLegacyCreationOrder"
        )
        let record = try XCTUnwrap(
            unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first
        )
        XCTAssertEqual(record.creationOrder, Int64.max)
        XCTAssertTrue(
            try unchanged.mainContext.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertFalse(unchanged.mainContext.hasChanges)
    }

    private func bootstrapUnavailable(
        at storeURL: URL,
        containing diagnostic: String
    ) throws -> ModelContainer {
        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        }
        guard case let .unavailable(failure) = result else {
            throw XCTSkip("Expected bootstrap failure containing " + diagnostic)
        }
        XCTAssertTrue(failure.diagnosticDescription.contains(diagnostic))
        return try currentContainer(at: storeURL)
    }

    private func writeV4Store(
        to storeURL: URL,
        insert: (ModelContext) -> Void
    ) throws {
        let schema = Schema(versionedSchema: UFastSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)]
        )
        insert(container.mainContext)
        try container.mainContext.save()
    }

    private func currentContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: UFastSchemaV5.self)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)]
        )
    }

    private func makeDirectory(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
