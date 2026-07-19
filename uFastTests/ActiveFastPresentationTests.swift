import Foundation
import SwiftData
@testable import uFast
import XCTest

final class ActiveFastPresentationTests: XCTestCase {
    private let startDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testDerivesElapsedTargetAndProgressFromInjectedNow() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 12))
        let now = startDate.addingTimeInterval(6 * 60 * 60)

        let presentation = ActiveFastPresentation(
            startDate: startDate,
            targetDate: targetDate(for: goal),
            now: now
        )

        XCTAssertEqual(presentation.elapsedText, "06:00:00")
        XCTAssertEqual(
            presentation.elapsedAccessibilityText,
            "6 hours 0 minutes 0 seconds"
        )
        XCTAssertEqual(presentation.targetDate, startDate.addingTimeInterval(12 * 60 * 60))
        XCTAssertEqual(presentation.progress, 0.5)
        XCTAssertEqual(presentation.progressPercentage, 50)
        XCTAssertEqual(
            presentation.progressAccessibilityValue(goal: goal),
            "50 percent of 12-hour goal"
        )
        XCTAssertFalse(presentation.hasReachedGoal)
    }

    func testUnderOneMinuteUsesExactDurationForProgress() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 8))
        let presentation = ActiveFastPresentation(
            startDate: startDate,
            targetDate: targetDate(for: goal),
            now: startDate.addingTimeInterval(59)
        )

        XCTAssertEqual(presentation.elapsedText, "00:00:59")
        XCTAssertEqual(presentation.elapsedAccessibilityText, "59 seconds")
        XCTAssertEqual(presentation.progress, 59 / TimeInterval(8 * 60 * 60), accuracy: 0.000_001)
        XCTAssertEqual(presentation.progressPercentage, 0)
    }

    func testElapsedFormatterTruncatesToCompletedWholeMinutes() {
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 60), "1 minute")
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 3659), "1 hour")
        XCTAssertEqual(
            ElapsedTimeFormatter.string(from: 26 * 60 * 60 + 3 * 60 + 59),
            "1 day 2 hours 3 minutes"
        )
        XCTAssertEqual(ElapsedTimeFormatter.string(from: 48 * 60 * 60), "2 days")
    }

    func testActiveElapsedFormatterShowsCompletedSeconds() {
        XCTAssertEqual(ActiveElapsedTimeFormatter.string(from: 0.9), "00:00:00")
        XCTAssertEqual(ActiveElapsedTimeFormatter.string(from: 59.9), "00:00:59")
        XCTAssertEqual(ActiveElapsedTimeFormatter.string(from: 3661.9), "01:01:01")
        XCTAssertEqual(ActiveElapsedTimeFormatter.string(from: 97200), "1d 03:00:00")
        XCTAssertEqual(
            ActiveElapsedTimeFormatter.accessibilityString(from: 97200),
            "1 day 3 hours 0 minutes 0 seconds"
        )
    }

    func testExactAndOverTargetClampVisualProgressAndKeepFullElapsed() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 12))
        let exact = ActiveFastPresentation(
            startDate: startDate,
            targetDate: targetDate(for: goal),
            now: startDate.addingTimeInterval(12 * 60 * 60)
        )
        let over = ActiveFastPresentation(
            startDate: startDate,
            targetDate: targetDate(for: goal),
            now: startDate.addingTimeInterval(27 * 60 * 60 + 15 * 60)
        )

        XCTAssertEqual(exact.progress, 1)
        XCTAssertEqual(exact.progressPercentage, 100)
        XCTAssertTrue(exact.hasReachedGoal)
        XCTAssertEqual(over.progress, 1)
        XCTAssertEqual(over.progressPercentage, 100)
        XCTAssertEqual(over.elapsedText, "1d 03:15:00")
        XCTAssertTrue(over.hasReachedGoal)
    }

    func testFutureStartDoesNotFabricateElapsedTime() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 12))
        let presentation = ActiveFastPresentation(
            startDate: startDate,
            targetDate: targetDate(for: goal),
            now: startDate.addingTimeInterval(-1)
        )

        XCTAssertNil(presentation.elapsedText)
        XCTAssertNil(presentation.elapsedAccessibilityText)
        XCTAssertEqual(presentation.progress, 0)
        XCTAssertEqual(presentation.progressPercentage, 0)
        XCTAssertFalse(presentation.hasReachedGoal)
    }

    func testAbsoluteDurationAndTargetRemainStableAcrossDaylightSavingChange() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 8))
        let start = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-03-29T00:30:00Z")
        )
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-03-29T08:30:00Z")
        )

        let presentation = ActiveFastPresentation(
            startDate: start,
            targetDate: start.addingTimeInterval(TimeInterval(goal.hours * 60 * 60)),
            now: now
        )

        XCTAssertEqual(presentation.elapsedText, "08:00:00")
        XCTAssertEqual(presentation.targetDate, now)
        XCTAssertEqual(presentation.progress, 1)
        XCTAssertTrue(presentation.hasReachedGoal)
    }

    @MainActor
    func testPresentationDerivationDoesNotWriteToPersistence() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let fast = FastRecord(
            startDate: startDate,
            goalAtStart: .default
        )
        context.insert(fast)
        try context.save()

        _ = ActiveFastPresentation(
            startDate: fast.startDate,
            targetDate: fast.targetDate(currentGoal: .default),
            now: startDate.addingTimeInterval(5 * 60 * 60)
        )

        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(fast.startDate, startDate)
        XCTAssertNil(fast.endDate)
    }

    private func targetDate(for goal: FastingGoal) -> Date {
        startDate.addingTimeInterval(TimeInterval(goal.hours * 60 * 60))
    }
}
