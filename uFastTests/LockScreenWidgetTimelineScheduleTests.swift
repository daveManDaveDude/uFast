import Foundation
@testable import uFast
import XCTest

final class LockScreenWidgetTimelineScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testActiveProjectionBuildsCurrentAndFiveMinuteEntriesThroughTwoHourHorizon() {
        let projection = makeProjection(start: now.addingTimeInterval(-60 * 60), goalHours: 12)
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: .success(projection),
            now: now
        )

        XCTAssertEqual(schedule.dates.first, now)
        XCTAssertEqual(schedule.dates.count, 25)
        XCTAssertEqual(schedule.dates.last, now.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(schedule.reloadDate, now.addingTimeInterval(2 * 60 * 60))
        XCTAssertTrue(
            zip(schedule.dates, schedule.dates.dropFirst()).allSatisfy {
                $1.timeIntervalSince($0) == LockScreenWidgetTimelineSchedule.cadence
            }
        )
    }

    func testExactTargetInsideHorizonIsInsertedOnceAndDatesRemainOrdered() {
        let target = now.addingTimeInterval(17 * 60)
        let projection = makeProjection(
            start: target.addingTimeInterval(-8 * 60 * 60),
            goalHours: 8
        )
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: .success(projection),
            now: now
        )

        XCTAssertEqual(schedule.dates.filter { $0 == target }.count, 1)
        XCTAssertEqual(schedule.dates.count, 26)
        XCTAssertEqual(schedule.dates, schedule.dates.sorted())
        XCTAssertEqual(Set(schedule.dates).count, schedule.dates.count)

        let cadenceTarget = now.addingTimeInterval(20 * 60)
        let cadenceProjection = makeProjection(
            start: cadenceTarget.addingTimeInterval(-8 * 60 * 60),
            goalHours: 8
        )
        let cadenceSchedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: .success(cadenceProjection),
            now: now
        )
        XCTAssertEqual(cadenceSchedule.dates.filter { $0 == cadenceTarget }.count, 1)
        XCTAssertEqual(cadenceSchedule.dates.count, 25)
    }

    func testConsecutiveEntriesAdvanceFixedContentAndPercentageMonotonically() throws {
        let projection = makeProjection(start: now.addingTimeInterval(-60), goalHours: 16)
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: .success(projection),
            now: now
        )
        let firstDate = try XCTUnwrap(schedule.dates.first)
        let secondDate = try XCTUnwrap(schedule.dates.dropFirst().first)
        let first = try activeContent(projection: projection, date: firstDate)
        let second = try activeContent(projection: projection, date: secondDate)

        XCTAssertNotEqual(first.elapsedText, second.elapsedText)
        XCTAssertNotEqual(first.accessibilitySummary, second.accessibilitySummary)
        XCTAssertLessThanOrEqual(first.progressPercentage, second.progressPercentage)
        XCTAssertTrue(second.accessibilitySummary.contains(second.elapsedText
                .replacingOccurrences(of: " h ", with: " hours ")
                .replacingOccurrences(of: " min", with: " minutes")))
    }

    func testBeyondTargetGetsAnotherBoundedHorizonAndClampedProgress() throws {
        let projection = makeProjection(start: now.addingTimeInterval(-20 * 60 * 60), goalHours: 8)
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: .success(projection),
            now: now
        )
        let first = try activeContent(projection: projection, date: schedule.dates[0])
        let last = try activeContent(projection: projection, date: schedule.dates[24])

        XCTAssertEqual(schedule.dates.count, 25)
        XCTAssertEqual(schedule.reloadDate, now.addingTimeInterval(2 * 60 * 60))
        XCTAssertNotEqual(first.elapsedText, last.elapsedText)
        XCTAssertEqual(first.progressPercentage, 100)
        XCTAssertEqual(last.progressPercentage, 100)
        XCTAssertTrue(first.accessibilitySummary.contains("100 percent"))
    }

    func testUnavailableInvalidAndFutureProjectionKeepFiveMinuteFallback() {
        let invalid = makeProjection(start: now.addingTimeInterval(-60), goalHours: 7)
        let future = makeProjection(start: now.addingTimeInterval(60), goalHours: 8)

        assertFallback(for: .success(nil))
        assertFallback(for: .failure(ActiveFastWidgetProjectionError.unreadable))
        assertFallback(for: .success(invalid))
        assertFallback(for: .success(future))
    }

    private func activeContent(
        projection: ActiveFastWidgetProjection,
        date: Date
    ) throws -> LockScreenWidgetActiveContent {
        let content = LockScreenWidgetContent.make(
            projectionResult: .success(projection),
            now: date
        )
        guard case let .active(active) = content else {
            return try XCTUnwrap(nil)
        }
        return active
    }

    private func makeProjection(start: Date, goalHours: Int) -> ActiveFastWidgetProjection {
        ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: start,
            targetDate: start.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours,
            generatedAt: now
        )
    }

    private func assertFallback(
        for result: Result<ActiveFastWidgetProjection?, Error>
    ) {
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: result,
            now: now
        )
        XCTAssertEqual(schedule.dates, [now])
        XCTAssertEqual(
            schedule.reloadDate,
            now.addingTimeInterval(LockScreenWidgetTimelineSchedule.cadence)
        )
    }
}
