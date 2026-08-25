import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HydrationMigrationAuthorityTests: XCTestCase {
    private let migrationDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testEquivalentDuplicateSettingsUseDeterministicCanonicalAuthority() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let lowerID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000010")
        )
        let higherID = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000020")
        )
        context.insert(settings(id: higherID, water: 600, tea: 350, coffee: 275))
        context.insert(settings(id: lowerID, water: 750, tea: 425, coffee: 225))
        try context.save()

        try HydrationFavouriteMigration.run(in: context, now: migrationDate)

        let records = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        let amountsByID = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, $0.volumeMillilitres)
        })
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.waterID], 750)
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.teaID], 425)
        XCTAssertEqual(amountsByID[HydrationFavouriteMigration.coffeeID], 225)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 2)

        let settingsStore = SwiftDataSettingsStore(modelContext: context)
        try settingsStore.prepareForUse()
        XCTAssertEqual(try settingsStore.authoritativeRecord()?.id, lowerID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
    }

    func testConflictingDuplicateSettingsStillFailBeforeConversion() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.insert(
            AppSettingsRecord(
                fastingGoal: XCTUnwrap(FastingGoal(hours: 18)),
                hasCompletedOnboarding: true
            )
        )
        try context.save()

        XCTAssertThrowsError(
            try HydrationFavouriteMigration.run(in: context, now: migrationDate)
        ) { error in
            XCTAssertEqual(
                error as? HydrationFavouriteMigrationError,
                .conflictingSettingsAuthority
            )
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteMigrationRecord>()).isEmpty
        )
        XCTAssertFalse(context.hasChanges)
    }

    func testMigrationPreservesLegacyCreatedAtOrderInCanonicalCreationOrder() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        let later = favourite(name: "Created first", createdOffset: -100, order: 0)
        let earlier = favourite(name: "Clock moved backward", createdOffset: -200, order: 1)
        context.insert(later)
        context.insert(earlier)
        try context.save()

        try HydrationFavouriteMigration.run(in: context, now: migrationDate)

        XCTAssertEqual(
            try SwiftDataHydrationFavouriteStore(modelContext: context).snapshots().map(\.name),
            ["Water", "Tea", "Coffee", "Clock moved backward", "Created first"]
        )
        XCTAssertEqual(earlier.creationOrder, 0)
        XCTAssertEqual(later.creationOrder, 1)
    }

    private func settings(
        id: UUID,
        water: Int,
        tea: Int,
        coffee: Int
    ) -> AppSettingsRecord {
        AppSettingsRecord(
            id: id,
            hasCompletedOnboarding: true,
            waterFavouriteMillilitres: water,
            teaFavouriteMillilitres: tea,
            coffeeFavouriteMillilitres: coffee
        )
    }

    private func favourite(
        name: String,
        createdOffset: TimeInterval,
        order: Int64
    ) -> HydrationFavouriteRecord {
        HydrationFavouriteRecord(
            name: name,
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: migrationDate.addingTimeInterval(createdOffset),
            creationOrder: order
        )
    }
}
