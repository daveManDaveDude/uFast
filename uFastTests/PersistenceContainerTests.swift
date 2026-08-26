import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class PersistenceContainerTests: XCTestCase {
    func testCurrentVersionedSchemaAndMigrationPlanCoverEveryProductionModel() {
        assertVersionedIdentifiersAndMigrationPlan()
        assertReleaseSchema()
        assertCurrentSchema()
    }

    private func assertVersionedIdentifiersAndMigrationPlan() {
        XCTAssertEqual(UFastSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(UFastSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(UFastSchemaV3.versionIdentifier, Schema.Version(3, 0, 0))
        XCTAssertEqual(UFastSchemaV4.versionIdentifier, Schema.Version(4, 0, 0))
        XCTAssertEqual(UFastSchemaV5.versionIdentifier, Schema.Version(5, 0, 0))
        XCTAssertEqual(UFastSchemaV6.versionIdentifier, Schema.Version(6, 0, 0))
        XCTAssertEqual(UFastMigrationPlan.schemas.count, 6)
        XCTAssertTrue(UFastMigrationPlan.schemas[0] == UFastSchemaV1.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[1] == UFastSchemaV2.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[2] == UFastSchemaV3.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[3] == UFastSchemaV4.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[4] == UFastSchemaV5.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[5] == UFastSchemaV6.self)
        XCTAssertEqual(UFastMigrationPlan.stages.count, 5)
        XCTAssertEqual(PersistenceContainer.schema.entities.count, 8)
    }

    private func assertReleaseSchema() {
        let releaseSchema = Schema(versionedSchema: UFastSchemaV1.self)
        XCTAssertEqual(
            Set(releaseSchema.entities.map(\.name)),
            [
                "AppSettingsRecord",
                "FastRecord",
                "FoodEntryRecord",
                "HydrationEntryRecord",
                "UnknownPeriodRecord",
            ]
        )
        XCTAssertEqual(
            releaseSchema.entitiesByName["AppSettingsRecord"]?.storedProperties.map(\.name),
            [
                "id",
                "fastingGoalHours",
                "hasCompletedOnboarding",
                "waterFavouriteMillilitres",
                "teaFavouriteMillilitres",
                "coffeeFavouriteMillilitres",
            ]
        )
        XCTAssertNil(
            releaseSchema.entitiesByName["AppSettingsRecord"]?.storedPropertiesByName[
                "automaticLiveActivityPreferenceRawValue"
            ]
        )
        XCTAssertNil(releaseSchema.entitiesByName["HydrationFavouriteRecord"])
    }

    private func assertCurrentSchema() {
        XCTAssertEqual(
            Set(PersistenceContainer.schema.entities.map(\.name)),
            [
                "AppSettingsRecord",
                "FastRecord",
                "FoodEntryRecord",
                "HydrationEntryRecord",
                "HydrationFavouriteRecord",
                "FoodFavouriteRecord",
                "HydrationFavouriteMigrationRecord",
                "UnknownPeriodRecord",
            ]
        )
    }

    func testBootstrapReturnsReadyContainerOnSuccessfulOpen() throws {
        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(inMemory: true)
        }

        guard case let .ready(container) = result else {
            return XCTFail("Expected persistence bootstrap to succeed")
        }
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<AppSettingsRecord>()),
            0
        )
    }

    func testBootstrapFailureLeavesExistingStoreBytesUntouched() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-bootstrap-failure-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let originalBytes = Data("existing local store".utf8)
        try originalBytes.write(to: storeURL)

        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(storeURL: storeURL)
        }

        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected explicit unavailable bootstrap result")
        }
        XCTAssertFalse(failure.diagnosticDescription.isEmpty)
        XCTAssertEqual(try Data(contentsOf: storeURL), originalBytes)
    }

    func testV5StoreMigratesWithoutFabricatingFoodFavouritesAndPreservesRecords() throws {
        let directory = try makeStoreDirectory(prefix: "uFast-v5-food-favourite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let v5Schema = Schema(versionedSchema: UFastSchemaV5.self)
        let v5Container = try ModelContainer(
            for: v5Schema,
            configurations: [ModelConfiguration(schema: v5Schema, url: storeURL, cloudKitDatabase: .none)]
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        let foodID = UUID()
        let food = FoodEntryRecord(
            id: foodID,
            draft: .init(description: "V5 meal", occurredAt: now),
            createdAt: now
        )
        let hydration = HydrationEntryRecord(
            type: .water,
            volumeMillilitres: 500,
            occurredAt: now,
            isCaloric: false,
            createdAt: now
        )
        v5Container.mainContext.insert(settings)
        v5Container.mainContext.insert(food)
        v5Container.mainContext.insert(hydration)
        try v5Container.mainContext.save()

        let migrated = try PersistenceContainer.make(storeURL: storeURL, now: now)
        let context = migrated.mainContext
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodFavouriteRecord>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodEntryRecord>()).map(\.id), [foodID])
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<FoodEntryRecord>()).first?.foodDescription,
            "V5 meal"
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
    }

    func testSimulatedV5ToV6MigrationFailurePreservesStoreAndReturnsUnavailable() throws {
        let directory = try makeStoreDirectory(prefix: "uFast-v5-food-favourite-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let v5Schema = Schema(versionedSchema: UFastSchemaV5.self)
        let v5Container = try ModelContainer(
            for: v5Schema,
            configurations: [ModelConfiguration(schema: v5Schema, url: storeURL, cloudKitDatabase: .none)]
        )
        v5Container.mainContext.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try v5Container.mainContext.save()
        let before = try storeContents(in: directory)

        let result = PersistenceBootstrapResult.open {
            try PersistenceContainer.make(
                storeURL: storeURL,
                simulateMigrationFailure: true
            )
        }
        guard case .unavailable = result else {
            return XCTFail("Expected migration failure to produce unavailable persistence")
        }
        XCTAssertEqual(try storeContents(in: directory), before)
    }

    func testProductionConfigurationIsLocalOnly() {
        let configuration = PersistenceContainer.configuration()

        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
    }

    func testFreshV2HydrationFavouriteRoundTripStaysLocalOnly() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let favourite = HydrationFavouriteRecord(
            name: "Sparkling water",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: createdAt
        )
        context.insert(favourite)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, favourite.id)
        XCTAssertEqual(stored.first?.name, "Sparkling water")
        XCTAssertEqual(stored.first?.volumeMillilitres, 330)
        XCTAssertEqual(stored.first?.isCaloric, false)
        XCTAssertEqual(stored.first?.createdAt, createdAt)
        XCTAssertNil(PersistenceContainer.configuration(inMemory: true).cloudKitContainerIdentifier)
    }

    func testV2SettingsStoreMigratesWithInferredDetectionOff() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-v2-settings-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let v2Schema = Schema(versionedSchema: UFastSchemaV2.self)
        let v2Configuration = ModelConfiguration(
            schema: v2Schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let v2Container = try ModelContainer(
            for: v2Schema,
            configurations: [v2Configuration]
        )
        let v2Settings = UFastSchemaV2.AppSettingsRecord()
        v2Settings.hasCompletedOnboarding = true
        v2Container.mainContext.insert(v2Settings)
        try v2Container.mainContext.save()

        let migrated = try PersistenceContainer.make(storeURL: storeURL)
        let settings = try XCTUnwrap(
            migrated.mainContext.fetch(FetchDescriptor<AppSettingsRecord>()).first
        )
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertFalse(settings.inferredFastDetectionEnabled)
    }

    func testV3StoreMigratesReconstructedReviewEvidenceFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-v3-review-fields-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        let v3Schema = Schema(versionedSchema: UFastSchemaV3.self)
        let v3Container = try ModelContainer(
            for: v3Schema,
            configurations: [ModelConfiguration(schema: v3Schema, url: storeURL, cloudKitDatabase: .none)]
        )
        v3Container.mainContext.insert(UFastSchemaV3.FastRecord())
        try v3Container.mainContext.save()

        let migrated = try PersistenceContainer.make(storeURL: storeURL)
        let fast = try XCTUnwrap(
            migrated.mainContext.fetch(FetchDescriptor<FastRecord>()).first
        )
        XCTAssertNil(fast.retainedReviewBoundary)
    }

    func testAppSettingsRoundTripInLocalContainer() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let settings = try AppSettingsRecord(
            fastingGoal: XCTUnwrap(FastingGoal(hours: 16)),
            hasCompletedOnboarding: true
        )

        context.insert(settings)
        try context.save()

        let storedSettings = try context.fetch(FetchDescriptor<AppSettingsRecord>())

        XCTAssertEqual(storedSettings.count, 1)
        XCTAssertEqual(storedSettings.first?.fastingGoalHours, 16)
        XCTAssertEqual(storedSettings.first?.hasCompletedOnboarding, true)
        XCTAssertEqual(storedSettings.first?.inferredFastDetectionEnabled, false)
    }

    func testChangedGoalPersistsWhenSettingsAreFetchedAgain() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        context.insert(settings)
        try settings.setFastingGoal(XCTUnwrap(FastingGoal(hours: 8)))
        try context.save()

        let storedSettings = try context.fetch(FetchDescriptor<AppSettingsRecord>())

        XCTAssertEqual(storedSettings.first?.fastingGoalHours, 8)
    }

    func testCompletedFastHistoricalGoalRoundTripsWithoutFollowingSettings() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sixteenHours = try XCTUnwrap(FastingGoal(hours: 16))
        let fourteenHours = try XCTUnwrap(FastingGoal(hours: 14))
        let fast = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_057_600),
            goalAtStart: sixteenHours
        )
        let settings = AppSettingsRecord(fastingGoal: sixteenHours, hasCompletedOnboarding: true)
        context.insert(fast)
        context.insert(settings)
        try context.save()

        settings.setFastingGoal(fourteenHours)
        try context.save()

        let storedFast = try XCTUnwrap(context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertEqual(storedFast.historicalGoal, sixteenHours)
        XCTAssertEqual(storedFast.duration, 16 * 60 * 60)
    }
}

extension PersistenceContainerTests {
    func testDeleteEverythingRemovesEveryPersistedModelType() throws {
        let container = try populatedContainer()
        let context = container.mainContext

        try AppDataDeletionService.deleteEverything(in: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FastRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodFavouriteRecord>()).isEmpty)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).isEmpty)
    }

    func testDeleteEverythingFailureRollsBackEveryDeletion() throws {
        let container = try populatedContainer()
        let context = container.mainContext

        XCTAssertThrowsError(
            try AppDataDeletionService.deleteEverything(
                in: context,
                simulateFailure: true
            )
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UnknownPeriodRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationFavouriteRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodFavouriteRecord>()), 1)
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<HydrationFavouriteMigrationRecord>()),
            1
        )
        XCTAssertFalse(context.hasChanges)
    }

    private func populatedContainer() throws -> ModelContainer {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        insertCoreDeleteFixtures(in: context, now: now)
        insertFavouriteDeleteFixtures(in: context, now: now)
        try context.save()
        return container
    }

    private func insertCoreDeleteFixtures(in context: ModelContext, now: Date) {
        let startBoundaryID = UUID()
        let endBoundaryID = UUID()
        let boundaries = ReconstructionBoundaryPair(
            start: .init(kind: .food, id: startBoundaryID),
            end: .init(kind: .hydration, id: endBoundaryID)
        )
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        context.insert(FastRecord(startDate: now, goalAtStart: .default))
        context.insert(
            FoodEntryRecord(
                id: startBoundaryID,
                draft: .init(description: "Dinner", occurredAt: now),
                createdAt: now
            )
        )
        context.insert(
            HydrationEntryRecord(
                id: endBoundaryID,
                type: .water,
                volumeMillilitres: 500,
                occurredAt: now,
                isCaloric: false,
                createdAt: now
            )
        )
        context.insert(
            UnknownPeriodRecord(
                startDate: now,
                endDate: now.addingTimeInterval(60),
                boundaries: boundaries,
                reason: .userChoice,
                createdAt: now
            )
        )
    }

    private func insertFavouriteDeleteFixtures(in context: ModelContext, now: Date) {
        context.insert(
            HydrationFavouriteRecord(
                name: "Sparkling water",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: now
            )
        )
        context.insert(
            HydrationFavouriteMigrationRecord(
                migrationVersion: HydrationFavouriteMigration.migrationVersion,
                completedAt: now
            )
        )
        context.insert(
            FoodFavouriteRecord(
                description: "Saved template",
                nutrition: FoodNutrition(energyKilocalories: 100),
                createdAt: now
            )
        )
    }

    private func makeStoreDirectory(prefix: String) throws -> URL {
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
            let data = try Data(contentsOf: url)
            return (url.lastPathComponent, data)
        })
    }
}
