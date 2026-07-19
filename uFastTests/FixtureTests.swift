@testable import uFast
import XCTest

final class FixtureTests: XCTestCase {
    func testHealthAuthorizationFixturesCoverExpectedStates() {
        XCTAssertEqual(HealthAuthorizationFixtureState.allCases.count, 5)
    }

    func testDateFixturesPreserveAbsoluteOrderingAcrossClockChange() {
        XCTAssertLessThan(
            PreviewFixtures.beforeLondonSpringClockChange,
            PreviewFixtures.afterLondonSpringClockChange
        )
    }
}
