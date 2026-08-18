import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class PersistenceContainerTests: XCTestCase {
    func testCurrentVersionedSchemaAndMigrationPlanCoverEveryProductionModel() {
        XCTAssertEqual(UFastSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(UFastSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(UFastSchemaV3.versionIdentifier, Schema.Version(3, 0, 0))
        XCTAssertEqual(UFastSchemaV4.versionIdentifier, Schema.Version(4, 0, 0))
        XCTAssertEqual(UFastMigrationPlan.schemas.count, 4)
        XCTAssertTrue(UFastMigrationPlan.schemas[0] == UFastSchemaV1.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[1] == UFastSchemaV2.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[2] == UFastSchemaV3.self)
        XCTAssertTrue(UFastMigrationPlan.schemas[3] == UFastSchemaV4.self)
        XCTAssertEqual(UFastMigrationPlan.stages.count, 3)
        XCTAssertEqual(PersistenceContainer.schema.entities.count, 6)

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

        XCTAssertEqual(
            Set(PersistenceContainer.schema.entities.map(\.name)),
            [
                "AppSettingsRecord",
                "FastRecord",
                "FoodEntryRecord",
                "HydrationEntryRecord",
                "HydrationFavouriteRecord",
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

    func testDeleteEverythingRemovesEveryPersistedModelType() throws {
        let container = try populatedContainer()
        let context = container.mainContext

        try AppDataDeletionService.deleteEverything(in: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FastRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty)
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
        XCTAssertFalse(context.hasChanges)
    }

    private func populatedContainer() throws -> ModelContainer {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
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
        context.insert(
            HydrationFavouriteRecord(
                name: "Sparkling water",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: now
            )
        )
        try context.save()
        return container
    }
}
