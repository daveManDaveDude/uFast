import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

@MainActor
final class HydrationEntryTests: XCTestCase {
    func testFavouriteDefaultsAndConfiguredAmountsMapIndependently() {
        XCTAssertEqual(
            HydrationFavouriteProvider.favourites(settings: nil),
            [
                HydrationFavourite(type: .water, volumeMillilitres: 500),
                HydrationFavourite(type: .tea, volumeMillilitres: 300),
                HydrationFavourite(type: .coffee, volumeMillilitres: 300),
            ]
        )
        let settings = AppSettingsRecord(
            waterFavouriteMillilitres: 750,
            teaFavouriteMillilitres: 250,
            coffeeFavouriteMillilitres: 125
        )
        XCTAssertEqual(
            HydrationFavouriteProvider.favourites(settings: settings).map(\.volumeMillilitres),
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
    }
}
