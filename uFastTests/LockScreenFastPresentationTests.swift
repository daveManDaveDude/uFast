import Foundation
@testable import uFast
import XCTest

final class LockScreenFastPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testProtectedPresentationExposesOnlyAcceptedContentAndPrecision() throws {
        let active = try activePresentation(
            projection: projection(elapsed: 12 * 60 * 60 + 34 * 60 + 56),
            privacyState: .protected
        )

        XCTAssertEqual(active.elapsedText, "12 h 34 min")
        XCTAssertEqual(active.elapsedAccessibilityValue, "12 hours 34 minutes")
        XCTAssertEqual(active.startDate, now.addingTimeInterval(-(12 * 60 * 60 + 34 * 60 + 56)))
        XCTAssertEqual(active.targetDate, active.startDate.addingTimeInterval(16 * 60 * 60))
        XCTAssertEqual(active.progressPercentage, 78)
        XCTAssertEqual(active.progressAccessibilityValue, "78 percent of 16-hour goal")
        XCTAssertEqual(
            active.accessibilitySummary,
            "uFast, elapsed 12 hours 34 minutes, 78 percent of 16-hour goal. Opens uFast."
        )
        XCTAssertNil(active.targetText)
        XCTAssertNil(active.hasReachedGoal)
    }

    func testAuthenticatedPresentationAddsSecondsTargetAndGoalState() throws {
        let active = try activePresentation(
            projection: projection(elapsed: 12 * 60 * 60 + 34 * 60 + 56),
            privacyState: .authenticated,
            locale: Locale(identifier: "en_GB"),
            timeZone: XCTUnwrap(TimeZone(identifier: "Europe/London"))
        )

        XCTAssertEqual(active.elapsedText, "12:34:56")
        XCTAssertEqual(
            active.elapsedAccessibilityValue,
            "12 hours 34 minutes 56 seconds"
        )
        XCTAssertNotNil(active.targetText)
        XCTAssertEqual(active.hasReachedGoal, false)
    }

    func testNoActiveInvalidUnreadableAndFutureStatesNeverInventDuration() {
        XCTAssertEqual(
            presentation(for: .success(nil)),
            .unavailable(reason: .noActiveFast)
        )
        XCTAssertEqual(
            presentation(for: .failure(ActiveFastWidgetProjectionError.unreadable)),
            .unavailable(reason: .unreadableProjection)
        )

        let invalid = ActiveFastWidgetProjection(
            schemaVersion: 2,
            activeRecordIdentifier: UUID(),
            startDate: now.addingTimeInterval(-60),
            targetDate: now.addingTimeInterval(8 * 60 * 60),
            goalHours: 8,
            generatedAt: now
        )
        XCTAssertEqual(
            presentation(for: .success(invalid)),
            .unavailable(reason: .invalidProjection)
        )
        XCTAssertEqual(
            presentation(for: .success(projection(elapsed: -1))),
            .unavailable(reason: .futureStart)
        )
    }

    func testProgressMatchesTodayAndClampsAtBothBounds() throws {
        let halfwayProjection = projection(elapsed: 8 * 60 * 60)
        let lockScreen = try activePresentation(
            projection: halfwayProjection,
            privacyState: .authenticated
        )
        let today = ActiveFastPresentation(
            startDate: halfwayProjection.startDate,
            targetDate: halfwayProjection.targetDate,
            now: now
        )

        XCTAssertEqual(lockScreen.progress, today.progress)
        XCTAssertEqual(lockScreen.progressPercentage, today.progressPercentage)

        let over = try activePresentation(
            projection: projection(elapsed: 20 * 60 * 60),
            privacyState: .authenticated
        )
        XCTAssertEqual(over.progress, 1)
        XCTAssertEqual(over.progressPercentage, 100)
        XCTAssertEqual(over.hasReachedGoal, true)
    }

    func testDSTAndDisplayTimeZoneChangePreserveAbsoluteDuration() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-29T00:30:00Z"))
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-29T08:30:00Z"))
        let value = ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: start,
            targetDate: instant,
            goalHours: 8,
            generatedAt: start
        )

        let london = try activePresentation(
            projection: value,
            privacyState: .authenticated,
            locale: Locale(identifier: "en_GB"),
            timeZone: XCTUnwrap(TimeZone(identifier: "Europe/London")),
            now: instant
        )
        let newYork = try activePresentation(
            projection: value,
            privacyState: .authenticated,
            locale: Locale(identifier: "en_US"),
            timeZone: XCTUnwrap(TimeZone(identifier: "America/New_York")),
            now: instant
        )

        XCTAssertEqual(london.elapsedText, "08:00:00")
        XCTAssertEqual(newYork.elapsedText, london.elapsedText)
        XCTAssertNotEqual(newYork.targetText, london.targetText)
    }

    private func presentation(
        for result: Result<ActiveFastWidgetProjection?, Error>
    ) -> LockScreenFastPresentation {
        .make(
            projectionResult: result,
            now: now,
            privacyState: .protected
        )
    }

    private func activePresentation(
        projection: ActiveFastWidgetProjection,
        privacyState: LockScreenPrivacyState,
        locale: Locale = Locale(identifier: "en_GB"),
        timeZone: TimeZone = .gmt,
        now: Date? = nil
    ) throws -> LockScreenActivePresentation {
        let presentation = LockScreenFastPresentation.make(
            projectionResult: .success(projection),
            now: now ?? self.now,
            privacyState: privacyState,
            locale: locale,
            timeZone: timeZone
        )
        guard case let .active(active) = presentation else {
            return try XCTUnwrap(nil)
        }
        return active
    }

    private func projection(elapsed: TimeInterval) -> ActiveFastWidgetProjection {
        let start = now.addingTimeInterval(-elapsed)
        return ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: start,
            targetDate: start.addingTimeInterval(16 * 60 * 60),
            goalHours: 16,
            generatedAt: now
        )
    }
}
