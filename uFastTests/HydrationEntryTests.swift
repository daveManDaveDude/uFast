import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

@MainActor
final class HydrationEntryTests: XCTestCase {
    func testFavouriteRecordSnapshotsMapIndependently() {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshots = [
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Water",
                volumeMillilitres: 750,
                isCaloric: false,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Tea",
                volumeMillilitres: 250,
                isCaloric: false,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Juice",
                volumeMillilitres: 125,
                isCaloric: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
        ]
        XCTAssertEqual(
            HydrationFavouriteProvider.favourites(records: snapshots).map(\.volumeMillilitres),
            [750, 250, 125]
        )
    }

    func testQuickAddPersistsExplicitNonCaloricEventAndTotal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataHydrationEntryRepository(modelContext: container.mainContext)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let water = try repository.createFavourite(
            HydrationFavourite(type: .water, volumeMillilitres: 500),
            occurredAt: now
        )
        let tea = try repository.createFavourite(
            HydrationFavourite(type: .tea, volumeMillilitres: 300),
            occurredAt: now.addingTimeInterval(1)
        )

        XCTAssertEqual(water.drinkType, .water)
        XCTAssertFalse(water.isCaloric)
        XCTAssertEqual(water.createdAt, now)
        XCTAssertEqual(tea.drinkType, .tea)
        XCTAssertEqual(HydrationTimelineCalculations.fluidTotal([water, tea]), 800)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).count, 2)
    }

    func testBoundsAndSaveFailureDoNotExposeRecord() throws {
        XCTAssertFalse(HydrationEntryValidator.isValid(volumeMillilitres: 0))
        XCTAssertTrue(HydrationEntryValidator.isValid(volumeMillilitres: 1))
        XCTAssertTrue(HydrationEntryValidator.isValid(volumeMillilitres: 5000))
        XCTAssertFalse(HydrationEntryValidator.isValid(volumeMillilitres: 5001))

        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataHydrationEntryRepository(
            modelContext: container.mainContext,
            simulateSaveFailure: true
        )
        XCTAssertThrowsError(
            try repository.createFavourite(
                HydrationFavourite(type: .coffee, volumeMillilitres: 300),
                occurredAt: Date()
            )
        )
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testCustomNameRejectsInvisibleOnlyUnicode() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(
            HydrationEntryValidator.validated(
                type: .custom,
                customName: "\u{200D}",
                volumeMillilitres: 330,
                occurredAt: now,
                isCaloric: false,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            HydrationEntryValidator.validatedCustomName("  Café  "),
            "Café"
        )
    }
}
