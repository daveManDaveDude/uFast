import SwiftData
@testable import uFast
import XCTest

@MainActor
final class PersistenceContainerTests: XCTestCase {
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
}
