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
}
