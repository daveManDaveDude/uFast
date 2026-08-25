import Foundation
import SwiftData
@testable import uFast
import XCTest

@MainActor
final class PersistenceTransactionTests: XCTestCase {
    private enum SeederFailure: Error {
        case requested
    }

    func testSettingsFailureRollsBackAndLaterUnrelatedSaveDoesNotCommitIt() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let failedGoal = try XCTUnwrap(FastingGoal(hours: 20))
        let settings = AppSettingsRecord(
            fastingGoal: originalGoal,
            hasCompletedOnboarding: true
        )
        context.insert(settings)
        try context.save()

        let failingStore = SwiftDataSettingsStore(
            modelContext: context,
            simulateSaveFailure: true
        )
        XCTAssertThrowsError(try failingStore.updateGoal(failedGoal))
        XCTAssertEqual(settings.fastingGoal, originalGoal)
        XCTAssertFalse(context.hasChanges)

        let fast = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            goalAtStart: originalGoal
        )
        try SwiftDataActiveFastRepository(modelContext: context).saveNewActiveFast(fast)

        XCTAssertEqual(try XCTUnwrap(failingStore.authoritativeRecord()).fastingGoal, originalGoal)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testOnboardingSeederFailureRollsBackSettingsFavouriteAndMarker() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let store = SwiftDataSettingsStore(
            modelContext: context,
            newStoreSeeder: { context, now in
                context.insert(
                    HydrationFavouriteRecord(
                        name: "Partial favourite",
                        volumeMillilitres: 330,
                        isCaloric: false,
                        createdAt: now
                    )
                )
                throw SeederFailure.requested
            }
        )

        XCTAssertThrowsError(try store.completeOnboarding(goal: .default)) { error in
            XCTAssertTrue(error is SeederFailure)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertFalse(context.hasChanges)

        context.insert(
            FastRecord(
                startDate: Date(timeIntervalSince1970: 1_800_000_000),
                goalAtStart: .default
            )
        )
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty)
    }

    func testPreparationFailureRollsBackPendingChanges() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        context.insert(settings)
        try context.save()

        let transaction = PersistenceTransaction(modelContext: context)
        XCTAssertThrowsError(
            try transaction.perform {
                context.delete(settings)
                throw SeederFailure.requested
            }
        ) { error in
            XCTAssertTrue(error is SeederFailure)
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testOnDiskCaloricFailureLeavesNoPartialRecordsOrLaterStaleCommit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-transaction-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "uFast.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        do {
            let container = try PersistenceContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let fast = FastRecord(startDate: now.addingTimeInterval(-3600), goalAtStart: .default)
            context.insert(fast)
            try context.save()
            let failingRepository = SwiftDataFoodEntryRepository(
                modelContext: context,
                simulateSaveFailure: true
            )

            XCTAssertThrowsError(
                try failingRepository.create(
                    FoodEntryDraft(description: "Lunch", occurredAt: now),
                    at: now,
                    ending: fast,
                    goal: .default
                )
            )
            XCTAssertTrue(fast.isActive)
            XCTAssertTrue(try context.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
            XCTAssertFalse(context.hasChanges)

            _ = try SwiftDataHydrationEntryRepository(modelContext: context).createFavourite(
                HydrationFavourite(type: .water, volumeMillilitres: 500),
                occurredAt: now
            )
            XCTAssertFalse(context.hasChanges)
        }

        let reopened = try PersistenceContainer.make(storeURL: storeURL)
        let context = reopened.mainContext
        XCTAssertTrue(try XCTUnwrap(ActiveFastAuthority.fetch(in: context)).isActive)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertFalse(context.hasChanges)
    }
}
