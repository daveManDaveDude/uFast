import SwiftData
@testable import uFast
import XCTest

@MainActor
final class BF106BusyHistoryFixtureTests: XCTestCase {
    func testBusyFixtureHasFrozenCountsAndPopulatedSelectedDayWindow() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 27, hour: 10)
        ))
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext

        try UITestSeedFixtures.seedBF106BusyHistory(
            in: context,
            clock: FixedAppClock(now: now)
        )
        try context.save()

        try assertFrozenCounts(in: context)
        let allEventDates = try eventDates(in: context)

        let selectedDay = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 26)
        ))
        let selectedDayInterval = try XCTUnwrap(calendar.dateInterval(of: .day, for: selectedDay))
        let selectedDayEvents = allEventDates.filter { selectedDayInterval.contains($0) }
        XCTAssertEqual(selectedDayEvents.count, 14)

        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: selectedDay))
        let followingDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: selectedDay))
        let lowerWindowStart = try XCTUnwrap(calendar.date(
            bySettingHour: 23,
            minute: 0,
            second: 0,
            of: previousDay
        ))
        let lowerWindowEnd = try XCTUnwrap(calendar.date(
            bySettingHour: 1,
            minute: 0,
            second: 0,
            of: followingDay
        ))
        let lowerWindowEvents = allEventDates.filter { $0 >= lowerWindowStart && $0 < lowerWindowEnd }
        XCTAssertEqual(lowerWindowEvents.count, 15)

        try assertStableFixtureIDs(in: context)
    }

    private func assertFrozenCounts(in context: ModelContext) throws {
        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        let foods = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        let hydrations = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        XCTAssertEqual(fasts.count, 6)
        XCTAssertEqual(fasts.filter(\.isActive).count, 1)
        XCTAssertEqual(foods.count, 16)
        XCTAssertEqual(hydrations.count, 73)
        XCTAssertEqual(foods.count + hydrations.count, 89)
    }

    private func eventDates(in context: ModelContext) throws -> [Date] {
        let foods = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        let hydrations = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        return foods.map(\.occurredAt) + hydrations.map(\.occurredAt)
    }

    private func assertStableFixtureIDs(in context: ModelContext) throws {
        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        let hydrations = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        XCTAssertNotNil(fasts.first {
            $0.id == UUID(uuidString: "10400000-0000-0000-0000-000000000001")
        })
        XCTAssertNotNil(fasts.first {
            $0.id == UUID(uuidString: "10400000-0000-0000-0000-000000000002")
        })
        XCTAssertNotNil(hydrations.first {
            $0.id == UUID(uuidString: "10600000-0000-0003-0000-000000000061")
        })
    }

    func testExistingFastLabelFixtureRemainsSmall() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let clock = FixedAppClock(now: Date(timeIntervalSince1970: 1_787_821_200))

        try UITestSeedFixtures.seedHistoryFastLabelLayout(in: context, clock: clock)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
    }

    private func londonCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        return calendar
    }
}
