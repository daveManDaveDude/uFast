import Foundation
@testable import uFast
import XCTest

final class HistoryTextFormattingTests: XCTestCase {
    func testActiveDisplayPreservesExactHistoryClockOutput() {
        let resolve = AppTextResolver()
        XCTAssertEqual(HistoryTextFormatting.activeDisplay(seconds: 0.9, resolver: resolve), "00:00:00")
        XCTAssertEqual(HistoryTextFormatting.activeDisplay(seconds: 59.9, resolver: resolve), "00:00:59")
        XCTAssertEqual(HistoryTextFormatting.activeDisplay(seconds: 3661.9, resolver: resolve), "01:01:01")
        XCTAssertEqual(HistoryTextFormatting.activeDisplay(seconds: 97200, resolver: resolve), "1d 03:00:00")
    }

    func testHistoryGroupTitlesUseCatalogPluralFormsAndMemberTitles() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            resolve(.historyGroupTitle(count: 1, family: .food)),
            "1 food event"
        )
        XCTAssertEqual(
            resolve(.historyGroupTitle(count: 2, family: .drink)),
            "2 drinks"
        )
        XCTAssertEqual(
            resolve(.historyGroupMemberTitle(title: "Lunch", count: 2)),
            "Lunch ×2"
        )
    }

    func testDurationUsesCatalogPluralFormsAndLessThanMinuteBoundary() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            HistoryTextFormatting.duration(seconds: 59, resolver: resolve),
            "Less than 1 minute"
        )
        XCTAssertEqual(
            HistoryTextFormatting.duration(seconds: 60, resolver: resolve),
            "1 minute"
        )
        XCTAssertEqual(
            HistoryTextFormatting.duration(seconds: 120, resolver: resolve),
            "2 minutes"
        )
        XCTAssertEqual(
            HistoryTextFormatting.duration(seconds: 90120, resolver: resolve),
            "1 day 1 hour 2 minutes"
        )
    }

    func testHistoryRowsExposeCatalogOwnedDurationCopy() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(90 * 60)
        let fast = HistoryFastSnapshot(
            FastRecord(startDate: start, endDate: end, goalAtStart: .default)
        )
        let context = HistoryTextContext(
            locale: Locale(identifier: "en_GB"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt
        )
        let item = HistoryVisibleFastItem.recorded(fast, textContext: context)
        let row = VisibleFastHistoryRow(
            item: item,
            calendar: context.calendar,
            locale: context.locale,
            timeZone: context.timeZone
        )

        XCTAssertEqual(row.durationText, "1 hour 30 minutes")
        XCTAssertTrue(row.historyAccessibilityLabel.contains("duration 1 hour 30 minutes"))
    }

    func testActiveAccessibilityDurationUsesLocalizedComponents() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            HistoryTextFormatting.activeAccessibility(seconds: 3661, resolver: resolve),
            "1 hour 1 minute 1 second"
        )
        XCTAssertEqual(
            HistoryTextFormatting.activeAccessibility(seconds: 86400, resolver: resolve),
            "1 day 0 hours 0 minutes 0 seconds"
        )
    }

    func testDatesAndTimesUseExplicitLocaleCalendarAndTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        calendar.timeZone = timeZone
        let date = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 24, hour: 10, minute: 30)
        ))

        let dateTime = HistoryTextFormatting.dateTime(
            date, calendar: calendar, locale: Locale(identifier: "en_GB"), timeZone: timeZone
        )
        XCTAssertTrue(dateTime.contains("24 Jul"), dateTime)
        XCTAssertTrue(dateTime.contains("10:30"), dateTime)
        XCTAssertEqual(
            HistoryTextFormatting.date(
                date, calendar: calendar, locale: Locale(identifier: "en_GB"), timeZone: timeZone
            ),
            "24 Jul 2026"
        )
        XCTAssertEqual(
            HistoryTextFormatting.time(
                date, calendar: calendar, locale: Locale(identifier: "en_GB"), timeZone: timeZone
            ),
            "10:30"
        )
    }
}
