@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length

final class TodayTimelineTests: XCTestCase {
    func testMixedEntriesSortNewestFirstWithStableTieBreakAndDrinkOnlyTotal() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let same = now.addingTimeInterval(-60)
        let food = try FoodEntryRecord(id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002")), draft: FoodEntryDraft(description: "Lunch", occurredAt: same), createdAt: same)
        let drink = try HydrationEntryRecord(id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001")), type: .water, volumeMillilitres: 500, occurredAt: same, isCaloric: false, createdAt: same)
        let later = HydrationEntryRecord(type: .custom, customName: "Juice", volumeMillilitres: 200, occurredAt: now, isCaloric: true, createdAt: now)
        let entries = TodayTimeline.entries(food: [food], drinks: [drink, later], now: now, calendar: calendar)
        XCTAssertEqual(entries.map(\.id), [later.id, drink.id, food.id])
        XCTAssertEqual(TodayTimeline.fluidTotal(entries), 700)
    }

    func testEntriesOutsideLocalTodayAreExcluded() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = try HydrationEntryRecord(type: .water, volumeMillilitres: 500, occurredAt: XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now)), isCaloric: false, createdAt: now)
        XCTAssertTrue(TodayTimeline.entries(food: [], drinks: [yesterday], now: now, calendar: calendar).isEmpty)
    }
}
