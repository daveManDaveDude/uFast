import Foundation
@testable import uFast
import XCTest

final class FastRecordTests: XCTestCase {
    private let startDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testActiveFastUsesCurrentGoalWithoutChangingStartTime() throws {
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 14))
        let fast = FastRecord(startDate: startDate, goalAtStart: originalGoal)

        XCTAssertEqual(fast.startDate, startDate)
        XCTAssertEqual(fast.presentationGoal(currentGoal: currentGoal), currentGoal)
        XCTAssertEqual(
            fast.targetDate(currentGoal: currentGoal),
            startDate.addingTimeInterval(14 * 60 * 60)
        )
        XCTAssertEqual(fast.startDate, startDate)
    }

    func testCompletedFastRetainsHistoricalGoalAndDuration() throws {
        let historicalGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 14))
        let endDate = startDate.addingTimeInterval(15 * 60 * 60)
        let fast = FastRecord(
            startDate: startDate,
            endDate: endDate,
            goalAtStart: historicalGoal
        )

        XCTAssertEqual(fast.presentationGoal(currentGoal: currentGoal), historicalGoal)
        XCTAssertEqual(fast.targetDate(currentGoal: currentGoal), startDate.addingTimeInterval(16 * 60 * 60))
        XCTAssertEqual(fast.duration, 15 * 60 * 60)
    }

    func testCompletionMutatesActiveFastOnceAndCapturesCompletionGoal() throws {
        let completionGoal = try XCTUnwrap(FastingGoal(hours: 18))
        let repeatedGoal = try XCTUnwrap(FastingGoal(hours: 20))
        let endDate = startDate.addingTimeInterval(18 * 60 * 60)
        let fast = FastRecord(startDate: startDate, goalAtStart: .default)

        XCTAssertTrue(fast.complete(at: endDate, goal: completionGoal))
        XCTAssertFalse(
            fast.complete(
                at: endDate.addingTimeInterval(60),
                goal: repeatedGoal
            )
        )

        XCTAssertEqual(fast.endDate, endDate)
        XCTAssertEqual(fast.historicalGoal, completionGoal)
    }

    func testUnknownProvenanceAndInvalidHistoricalGoalRemainUnavailableAndRaw() {
        let fast = FastRecord(
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            goalAtStart: .default
        )
        fast.restoreProvenance(
            FastRecordProvenanceSnapshot(
                originRaw: "future-origin",
                reviewStateRaw: "future-review",
                wasAdjustedByUser: false,
                hasHistoricalGoal: true,
                startBoundaryKindRaw: nil,
                startBoundaryID: nil,
                endBoundaryKindRaw: nil,
                endBoundaryID: nil
            )
        )
        fast.restorePersistedHistoricalGoal(rawHours: 99, isCaptured: true)

        XCTAssertNil(fast.origin)
        XCTAssertNil(fast.reviewState)
        XCTAssertNil(fast.historicalGoal)
        XCTAssertNil(fast.capturedHistoricalGoal)
        XCTAssertEqual(fast.presentationIntegrity, .unavailable)
        XCTAssertEqual(fast.provenanceSnapshot.originRaw, "future-origin")
        XCTAssertEqual(fast.provenanceSnapshot.reviewStateRaw, "future-review")
        XCTAssertEqual(fast.goalHoursAtStart, 99)
    }
}
