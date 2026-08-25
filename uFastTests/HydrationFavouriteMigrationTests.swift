import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class HydrationFavouriteMigrationTests: XCTestCase {
    private let migrationDate = Date(timeIntervalSince1970: 1_800_000_000)

    private struct InvalidLegacySettingsFixture {
        let container: ModelContainer
        let existingID: UUID
        let waterAmount: Int
        let teaAmount: Int
        let coffeeAmount: Int
    }

    func testNewOnboardingSeedsExactlyOneWaterAndRelaunchDoesNotDuplicate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-new-favourites-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")

        let first = try PersistenceContainer.make(storeURL: storeURL, now: migrationDate)
        let settingsStore = SwiftDataSettingsStore(modelContext: first.mainContext, now: migrationDate)
        _ = try settingsStore.completeOnboarding(goal: .default)

        let reopened = try PersistenceContainer.make(storeURL: storeURL, now: migrationDate.addingTimeInterval(1))
        let records = try reopened.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, HydrationFavouriteMigration.waterID)
        XCTAssertEqual(records.first?.name, "Water")
        XCTAssertEqual(records.first?.volumeMillilitres, 330)
        XCTAssertFalse(records.first?.isCaloric ?? true)

        let secondStore = SwiftDataSettingsStore(modelContext: reopened.mainContext, now: migrationDate)
        _ = try secondStore.completeOnboarding(goal: .default)
        XCTAssertEqual(
            try reopened.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count,
            1
        )
    }

    func testInvalidLegacyFavouriteFailsBeforeWritingConvertedRows() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        context.insert(
            HydrationFavouriteRecord(
                name: "Broken legacy favourite",
                volumeMillilitres: 0,
                isCaloric: false,
                createdAt: migrationDate
            )
        )
        try context.save()

        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(error as? HydrationFavouriteMigrationError, .invalidLegacyAmount)
        }
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count,
            1
        )
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).count,
            0
        )
        XCTAssertFalse(context.hasChanges)
    }

    func testInvisibleLegacyNameFailsAtomically() throws {
        try assertLegacyNameRejected("\u{200D}")
    }

    func testOverlongLegacyNameFailsAtomically() throws {
        try assertLegacyNameRejected(String(repeating: "A", count: 81))
    }

    func testEachInvalidLegacySettingsAmountFailsAtomically() throws {
        let invalidSettings: [(String, (AppSettingsRecord) -> Void)] = [
            ("water", { $0.waterFavouriteMillilitres = 0 }),
            ("tea", { $0.teaFavouriteMillilitres = 5001 }),
            ("coffee", { $0.coffeeFavouriteMillilitres = 0 }),
        ]

        for (name, invalidate) in invalidSettings {
            try assertInvalidLegacySettingsAmount(name: name, invalidate: invalidate)
        }
    }

    private func assertInvalidLegacySettingsAmount(
        name: String,
        invalidate: (AppSettingsRecord) -> Void
    ) throws {
        let fixture = try makeInvalidLegacySettingsContext(
            invalidate: invalidate
        )
        let context = fixture.container.mainContext
        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(
                error as? HydrationFavouriteMigrationError,
                .invalidLegacyAmount,
                "Expected invalid amount rejection for \(name)"
            )
        }
        XCTAssertFalse(context.hasChanges)
        let savedSettings = try XCTUnwrap(
            context.fetch(FetchDescriptor<AppSettingsRecord>()).first
        )
        XCTAssertEqual(savedSettings.waterFavouriteMillilitres, fixture.waterAmount)
        XCTAssertEqual(savedSettings.teaFavouriteMillilitres, fixture.teaAmount)
        XCTAssertEqual(savedSettings.coffeeFavouriteMillilitres, fixture.coffeeAmount)
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, fixture.existingID)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).count,
            0
        )
        XCTAssertTrue(
            records.allSatisfy {
                ![
                    HydrationFavouriteMigration.waterID,
                    HydrationFavouriteMigration.teaID,
                    HydrationFavouriteMigration.coffeeID,
                ].contains($0.id)
            }
        )
    }

    private func makeInvalidLegacySettingsContext(
        invalidate: (AppSettingsRecord) -> Void
    ) throws -> InvalidLegacySettingsFixture {
        let container = try PersistenceContainer.make(inMemory: true)
        let settings = AppSettingsRecord(
            hasCompletedOnboarding: true,
            waterFavouriteMillilitres: 750,
            teaFavouriteMillilitres: 425,
            coffeeFavouriteMillilitres: 225
        )
        invalidate(settings)
        container.mainContext.insert(settings)
        let existingID = try XCTUnwrap(
            UUID(uuidString: "70200000-0000-0000-0000-000000000001")
        )
        container.mainContext.insert(
            HydrationFavouriteRecord(
                id: existingID,
                name: "Sparkling water",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: migrationDate,
                creationOrder: 7
            )
        )
        try container.mainContext.save()
        return InvalidLegacySettingsFixture(
            container: container,
            existingID: existingID,
            waterAmount: settings.waterFavouriteMillilitres,
            teaAmount: settings.teaFavouriteMillilitres,
            coffeeAmount: settings.coffeeFavouriteMillilitres
        )
    }

    func testDeterministicFavouriteIDConflictFailsAtomically() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                hasCompletedOnboarding: true,
                waterFavouriteMillilitres: 750,
                teaFavouriteMillilitres: 425,
                coffeeFavouriteMillilitres: 225
            )
        )
        let conflictingRecord = HydrationFavouriteRecord(
            id: HydrationFavouriteMigration.waterID,
            name: "Legacy authority",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: migrationDate,
            creationOrder: 7
        )
        context.insert(conflictingRecord)
        try context.save()

        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(
                error as? HydrationFavouriteMigrationError,
                .conflictingFavouriteAuthority
            )
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettingsRecord>()).count, 1)
        try assertOnlyDeterministicConflictRemains(in: context)
    }

    func testDuplicateExistingFavouriteIDsFailBeforeConversion() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        let duplicateID = try XCTUnwrap(
            UUID(uuidString: "70300000-0000-0000-0000-000000000001")
        )
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
        try context.save()

        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(
                error as? HydrationFavouriteMigrationError,
                .conflictingFavouriteAuthority
            )
        }
        XCTAssertFalse(context.hasChanges)
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.id), [duplicateID, duplicateID])
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
    }

    func testExtremeExistingCreationOrderFailsBeforeConversion() throws {
        for extremeOrder in [Int64.min, Int64.max] {
            let container = try PersistenceContainer.make(inMemory: true)
            let context = container.mainContext
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            let existing = HydrationFavouriteRecord(
                name: "Corrupt order",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: migrationDate,
                creationOrder: extremeOrder
            )
            context.insert(existing)
            try context.save()

            XCTAssertThrowsError(
                try HydrationFavouriteMigration.run(in: context, now: migrationDate)
            ) { error in
                XCTAssertEqual(
                    error as? HydrationFavouriteMigrationError,
                    .invalidLegacyCreationOrder
                )
            }
            XCTAssertFalse(context.hasChanges)
            XCTAssertEqual(
                try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first?.creationOrder,
                extremeOrder
            )
            XCTAssertTrue(
                try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
            )
        }
    }

    private func assertOnlyDeterministicConflictRemains(in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, HydrationFavouriteMigration.waterID)
        XCTAssertEqual(records.first?.name, "Legacy authority")
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).count,
            0
        )
    }

    private func assertLegacyNameRejected(_ name: String) throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        let existing = HydrationFavouriteRecord(
            name: name,
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: migrationDate
        )
        context.insert(settings)
        context.insert(existing)
        try context.save()

        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(error as? HydrationFavouriteMigrationError, .invalidLegacyName)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettingsRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).count, 1)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).first?.name,
            name
        )
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
    }
}
