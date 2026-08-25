import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class HistoryFavouriteRefreshTests: XCTestCase {
    func testReloadHydrationFavouritesUsesCanonicalOrderBeforeCreatedAt() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let customID = try XCTUnwrap(
            UUID(uuidString: "70100000-0000-0000-0000-000000000001")
        )
        let container = try PersistenceContainer.make(inMemory: true, now: now)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        favouriteRecords(now: now, customID: customID).forEach(context.insert)
        try context.save()

        let model = HistoryPresentationModel(
            modelContext: context,
            clock: FixedAppClock(now: now),
            timeZone: .gmt
        )

        XCTAssertTrue(model.reloadHydrationFavourites())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.id), [
            HydrationFavouriteMigration.waterID,
            HydrationFavouriteMigration.teaID,
            HydrationFavouriteMigration.coffeeID,
            customID,
        ])
    }

    func testCalendarReloadDoesNotFetchOrRepublishFavouriteSnapshots() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let customID = try XCTUnwrap(
            UUID(uuidString: "70100000-0000-0000-0000-000000000001")
        )
        let container = try PersistenceContainer.make(inMemory: true, now: now)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        let favourite = HydrationFavouriteRecord(
            id: customID,
            name: "Sparkling water",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: now
        )
        context.insert(favourite)
        try context.save()
        let model = HistoryPresentationModel(
            modelContext: context,
            clock: FixedAppClock(now: now),
            timeZone: .gmt
        )

        XCTAssertTrue(model.reloadHydrationFavourites())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.name), ["Sparkling water"])

        favourite.update(
            name: "Soda water",
            volumeMillilitres: 355,
            isCaloric: false,
            updatedAt: now.addingTimeInterval(1)
        )
        try context.save()

        XCTAssertTrue(model.reloadHistory())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.name), ["Sparkling water"])
        XCTAssertTrue(model.reloadHydrationFavourites())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.name), ["Soda water"])
    }

    func testCommittedFavouriteEditAndRemovalRefreshHistorySnapshots() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let container = try PersistenceContainer.make(inMemory: true, now: now)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.save()
        let invalidation = HistoryPresentationInvalidation()
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil },
            historyPresentationInvalidation: invalidation
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let model = HistoryPresentationModel(
            modelContext: context,
            clock: FixedAppClock(now: now),
            timeZone: .gmt
        )

        XCTAssertTrue(model.reloadHydrationFavourites())
        XCTAssertTrue(model.reloadHistory())
        XCTAssertTrue(model.hydrationFavouriteSnapshots.isEmpty)
        let initialRevision = invalidation.revision
        let created = try commands.createFavourite(
            name: "Sparkling water", volumeMillilitres: 330, isCaloric: false
        )
        XCTAssertEqual(invalidation.revision, initialRevision + 1)
        XCTAssertTrue(model.refreshHistoryAfterCommittedMutation())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.name), ["Sparkling water"])

        _ = try commands.updateFavourite(
            id: created.id, name: "Soda water", volumeMillilitres: 355, isCaloric: true
        )
        XCTAssertEqual(invalidation.revision, initialRevision + 2)
        XCTAssertTrue(model.refreshHistoryAfterCommittedMutation())
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.name), ["Soda water"])
        XCTAssertEqual(model.hydrationFavouriteSnapshots.map(\.volumeMillilitres), [355])

        try commands.deleteFavourite(id: created.id)
        XCTAssertEqual(invalidation.revision, initialRevision + 3)
        XCTAssertTrue(model.refreshHistoryAfterCommittedMutation())
        XCTAssertTrue(model.hydrationFavouriteSnapshots.isEmpty)
    }

    private func favouriteRecords(now: Date, customID: UUID) -> [HydrationFavouriteRecord] {
        [
            HydrationFavouriteRecord(
                id: customID, name: "Sparkling water", volumeMillilitres: 330,
                isCaloric: false, createdAt: now.addingTimeInterval(-300), creationOrder: 0
            ),
            HydrationFavouriteRecord(
                id: HydrationFavouriteMigration.waterID,
                name: HydrationDrinkType.water.displayName, volumeMillilitres: 750,
                isCaloric: false, createdAt: now, creationOrder: -3
            ),
            HydrationFavouriteRecord(
                id: HydrationFavouriteMigration.teaID,
                name: HydrationDrinkType.tea.displayName, volumeMillilitres: 425,
                isCaloric: false, createdAt: now, creationOrder: -2
            ),
            HydrationFavouriteRecord(
                id: HydrationFavouriteMigration.coffeeID,
                name: HydrationDrinkType.coffee.displayName, volumeMillilitres: 225,
                isCaloric: false, createdAt: now, creationOrder: -1
            ),
        ]
    }
}
