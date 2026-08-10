import SwiftData
@testable import uFast
import XCTest

@MainActor
final class PersistenceContainerTests: XCTestCase {
    func testCurrentVersionedSchemaAndMigrationPlanCoverEveryProductionModel() {
        XCTAssertEqual(UFastSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(UFastMigrationPlan.schemas.count, 1)
        XCTAssertTrue(UFastMigrationPlan.schemas[0] == UFastSchemaV1.self)
        XCTAssertTrue(UFastMigrationPlan.stages.isEmpty)
        XCTAssertEqual(PersistenceContainer.schema.entities.count, 5)
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
            throw PersistenceBootstrapTestError.cannotOpen
        }

        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected explicit unavailable bootstrap result")
        }
        XCTAssertTrue(failure.diagnosticDescription.contains("cannotOpen"))
        XCTAssertEqual(try Data(contentsOf: storeURL), originalBytes)
    }

    func testProductionConfigurationIsLocalOnly() {
        let configuration = PersistenceContainer.configuration()

        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
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
        try context.save()
        return container
    }
}

private enum PersistenceBootstrapTestError: Error {
    case cannotOpen
}
