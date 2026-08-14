@testable import uFast
import XCTest

@MainActor
final class HistoryPresentationCacheTests: XCTestCase {
    func testOneSecondActiveTickDoesNotRebuildStaticPresentation() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let data = historyData(
            window: DateInterval(start: start, duration: 24 * 60 * 60),
            activeStart: start.addingTimeInterval(60)
        )
        let cache = HistoryPresentationCache()

        let first = presentation(cache: cache, data: data, referenceNow: start.addingTimeInterval(120))
        let second = presentation(cache: cache, data: data, referenceNow: start.addingTimeInterval(121))

        XCTAssertEqual(first, second)
        XCTAssertEqual(cache.rebuildCount, 1)
        XCTAssertNotEqual(
            first.intervals(activeEndingAt: start.addingTimeInterval(120)),
            first.intervals(activeEndingAt: start.addingTimeInterval(121))
        )
    }

    func testActiveFastCrossingIntoWindowInvalidatesPresentationCache() {
        let windowStart = Date(timeIntervalSince1970: 2_000_000_000)
        let data = historyData(
            window: DateInterval(start: windowStart, duration: 24 * 60 * 60),
            activeStart: windowStart.addingTimeInterval(-60 * 60)
        )
        let cache = HistoryPresentationCache()

        let beforeMidnight = presentation(
            cache: cache,
            data: data,
            referenceNow: windowStart.addingTimeInterval(-60)
        )
        let afterMidnight = presentation(
            cache: cache,
            data: data,
            referenceNow: windowStart.addingTimeInterval(60)
        )

        XCTAssertTrue(beforeMidnight.fastItems.isEmpty)
        XCTAssertEqual(afterMidnight.fastItems.map(\.kind), [.active])
        XCTAssertEqual(cache.rebuildCount, 2)
    }

    private func historyData(window: DateInterval, activeStart: Date) -> HistoryDataSlice {
        HistoryDataSlice(
            window: window,
            completedFasts: [],
            activeFast: HistoryFastSnapshot(
                FastRecord(startDate: activeStart, goalAtStart: .default)
            ),
            foods: [],
            drinks: [],
            settings: nil
        )
    }

    private func presentation(
        cache: HistoryPresentationCache,
        data: HistoryDataSlice,
        referenceNow: Date
    ) -> HistoryPresentationSnapshot {
        cache.presentation(
            for: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: referenceNow
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
