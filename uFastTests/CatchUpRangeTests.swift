@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable identifier_name

final class CatchUpRangeTests: XCTestCase {
    func testDefaultRangeIsLatestSevenCompletedLocalDays() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 14))
        )

        let dates = try CatchUpRangeResolver.defaultDates(now: now, calendar: calendar)
        let range = try CatchUpRangeResolver.resolve(
            from: dates.from,
            to: dates.to,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(range.dayCount, 7)
        XCTAssertEqual(calendar.component(.day, from: range.firstDay), 14)
        XCTAssertEqual(calendar.component(.day, from: range.lastDay), 20)
        XCTAssertFalse(range.contains(calendar.startOfDay(for: now)))
    }

    func testOlderOneDayRangeIsAllowedWithoutLowerLimit() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 14))
        )
        let oldDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2018, month: 2, day: 4, hour: 12))
        )

        let range = try CatchUpRangeResolver.resolve(
            from: oldDay,
            to: oldDay,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(range.dayCount, 1)
        XCTAssertTrue(range.contains(oldDay))
    }

    func testInvalidRangesReturnSpecificErrors() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 14))
        )
        let today = calendar.startOfDay(for: now)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let eightDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: today))

        XCTAssertThrowsError(
            try CatchUpRangeResolver.resolve(from: today, to: yesterday, now: now, calendar: calendar)
        ) { XCTAssertEqual($0 as? CatchUpRangeError, .endBeforeStart) }
        XCTAssertThrowsError(
            try CatchUpRangeResolver.resolve(from: yesterday, to: today, now: now, calendar: calendar)
        ) { XCTAssertEqual($0 as? CatchUpRangeError, .includesTodayOrFuture) }
        XCTAssertThrowsError(
            try CatchUpRangeResolver.resolve(from: eightDaysAgo, to: yesterday, now: now, calendar: calendar)
        ) { XCTAssertEqual($0 as? CatchUpRangeError, .moreThanSevenDays) }
    }

    func testResolutionUsesCalendarDaysAcrossSpringDST() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12))
        )
        let from = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 10))
        )
        let to = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 10))
        )

        let range = try CatchUpRangeResolver.resolve(
            from: from,
            to: to,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(range.dayCount, 3)
        XCTAssertEqual(range.interval.upperBound.timeIntervalSince(range.interval.lowerBound), 71 * 60 * 60)
    }

    func testHistoricalValidatorsAcceptSelectedPastRangeAndRejectToday() throws {
        let calendar = try londonCalendar()
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 14))
        )
        let day = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: now))
        let start = calendar.startOfDay(for: day)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))

        let food = FoodEntryValidator.validated(
            description: "Remembered meal",
            occurredAt: day,
            nutrition: FoodNutrition(),
            now: now,
            calendar: calendar,
            allowedRange: start ..< end
        )
        XCTAssertNoThrow(try food.get())

        XCTAssertNotNil(
            HydrationEntryValidator.validated(
                type: .water,
                customName: "",
                volumeMillilitres: 500,
                occurredAt: day,
                isCaloric: false,
                now: now,
                calendar: calendar,
                allowedRange: start ..< end
            )
        )

        XCTAssertThrowsError(
            try FoodEntryValidator.validated(
                description: "Today",
                occurredAt: now,
                nutrition: FoodNutrition(),
                now: now,
                calendar: calendar,
                allowedRange: start ..< end
            ).get()
        ) { XCTAssertEqual($0 as? FoodEntryValidationError, .outsideSelectedRange) }
    }

    private func londonCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        return calendar
    }
}
