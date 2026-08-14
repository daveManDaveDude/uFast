import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistoryMotionAuthorityTests: XCTestCase {
    func testMotionProviderReturnsNoActiveFastWhenNoneAreStored() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let window = DateInterval(
            start: Date(timeIntervalSince1970: 2_000_000_000),
            duration: 24 * 60 * 60
        )

        let result = try SwiftDataHistoryMotionDataProvider(modelContext: container.mainContext)
            .fetch(window: window, calendar: utcCalendar)

        XCTAssertNil(result.activeFast)
        XCTAssertEqual(result.window, window)
        XCTAssertTrue(result.completedFasts.isEmpty)
        XCTAssertTrue(result.foods.isEmpty)
        XCTAssertTrue(result.drinks.isEmpty)
    }

    func testMotionProviderReturnsTheSingleAuthoritativeActiveFastSnapshot() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let goal = try XCTUnwrap(FastingGoal(hours: 18))
        let fast = FastRecord(startDate: start, goalAtStart: goal)
        context.insert(fast)
        try context.save()

        let result = try SwiftDataHistoryMotionDataProvider(modelContext: context).fetch(
            window: DateInterval(start: start, duration: 24 * 60 * 60),
            calendar: utcCalendar
        )
        let active = try XCTUnwrap(result.activeFast)

        XCTAssertEqual(active.id, fast.id)
        XCTAssertEqual(active.startDate, start)
        XCTAssertEqual(active.capturedHistoricalGoal, goal)
        XCTAssertEqual(active.presentationIntegrity, .available)
    }

    func testMotionProviderRejectsEveryMultipleActiveFastAndLeavesRowsUnchanged() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let firstStart = Date(timeIntervalSince1970: 2_000_000_000)
        let secondStart = firstStart.addingTimeInterval(3600)
        let first = FastRecord(startDate: firstStart, goalAtStart: .default)
        let second = FastRecord(startDate: secondStart, goalAtStart: .default)
        context.insert(first)
        context.insert(second)
        try context.save()

        XCTAssertThrowsError(
            try SwiftDataHistoryDataProvider(modelContext: context).fetch(
                window: DateInterval(start: firstStart, duration: 24 * 60 * 60)
            )
        ) { error in
            XCTAssertEqual(error as? ActiveFastIntegrityError, .multipleActiveFasts(count: 2))
        }

        XCTAssertThrowsError(
            try SwiftDataHistoryMotionDataProvider(modelContext: context).fetch(
                window: DateInterval(start: firstStart, duration: 24 * 60 * 60),
                calendar: utcCalendar
            )
        ) { error in
            XCTAssertEqual(error as? ActiveFastIntegrityError, .multipleActiveFasts(count: 2))
        }

        let stored = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(Set(stored.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0.startDate) }),
            [first.id: firstStart, second.id: secondStart]
        )
        XCTAssertTrue(stored.allSatisfy { $0.endDate == nil })
        XCTAssertFalse(context.hasChanges)
    }

    func testMotionRangeLoaderPropagatesMultipleActiveFastErrorUnchanged() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        context.insert(FastRecord(startDate: start, goalAtStart: .default))
        context.insert(FastRecord(startDate: start.addingTimeInterval(3600), goalAtStart: .default))
        try context.save()
        let coverage = HistoryMotionCoverage(firstDay: start, lastDay: start, calendar: utcCalendar)

        do {
            _ = try await SwiftDataHistoryMotionRangeLoader(container: container)
                .load(coverage: coverage, calendar: utcCalendar)
            XCTFail("Expected the motion loader to reject ambiguous active-fast authority")
        } catch let error as ActiveFastIntegrityError {
            XCTAssertEqual(error, .multipleActiveFasts(count: 2))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 2)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
