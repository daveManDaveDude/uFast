@testable import uFast
import XCTest

final class FastingGoalTests: XCTestCase {
    func testChoicesIncludeEveryWholeHourFromEightThroughTwentyFour() {
        XCTAssertEqual(FastingGoal.choices.map(\.hours), Array(8 ... 24))
    }

    func testDefaultIsTwelveHours() {
        XCTAssertEqual(FastingGoal.default.hours, 12)
    }

    func testValuesOutsideMinimumAndMaximumAreRejected() {
        XCTAssertNil(FastingGoal(hours: 7))
        XCTAssertNotNil(FastingGoal(hours: 8))
        XCTAssertNotNil(FastingGoal(hours: 24))
        XCTAssertNil(FastingGoal(hours: 25))
    }
}
