import SwiftData
@testable import uFast
import XCTest

@MainActor
final class FixtureTests: XCTestCase {
    func testHealthAuthorizationFixturesCoverExpectedStates() {
        XCTAssertEqual(HealthAuthorizationFixtureState.allCases.count, 5)
    }

    func testDateFixturesPreserveAbsoluteOrderingAcrossClockChange() {
        XCTAssertLessThan(
            PreviewFixtures.beforeLondonSpringClockChange,
            PreviewFixtures.afterLondonSpringClockChange
        )
    }

    func testResetAndReseedTwiceRestoresOnlyDefaultWaterFavourite() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let configuration = DevelopmentFixtureConfiguration(
            resetData: true,
            seedHistoryEventGrouping: true
        )
        let clock = FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000))

        try UITestDataReset.runIfRequested(
            in: container,
            configuration: configuration,
            now: clock.now,
            clock: clock
        )
        try assertOnlyDefaultWaterFavourite(in: container.mainContext)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodFavouriteRecord>()).isEmpty)

        try UITestDataReset.runIfRequested(
            in: container,
            configuration: configuration,
            now: clock.now,
            clock: clock
        )
        try assertOnlyDefaultWaterFavourite(in: container.mainContext)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodFavouriteRecord>()).isEmpty)
    }

    private func assertOnlyDefaultWaterFavourite(in context: ModelContext) throws {
        let favourites = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(favourites.count, 1)
        let water = try XCTUnwrap(favourites.first)
        XCTAssertEqual(water.id, HydrationFavouriteMigration.waterID)
        XCTAssertEqual(water.name, HydrationDrinkType.water.displayName)
        XCTAssertEqual(water.volumeMillilitres, 330)
        XCTAssertFalse(water.isCaloric)
        let reservedIDs = [HydrationFavouriteMigration.teaID, HydrationFavouriteMigration.coffeeID]
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
                .allSatisfy { !reservedIDs.contains($0.id) }
        )
    }
}
