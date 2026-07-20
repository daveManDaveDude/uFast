@testable import uFast
import XCTest

final class UFastProgressFillGeometryTests: XCTestCase {
    func testZeroProgressHasNoVisibleFill() {
        XCTAssertEqual(
            UFastProgressFillGeometry.visibleWidth(progress: 0, trackWidth: 320),
            0
        )
    }

    func testSecondsOldLongFastUsesOnlyHairlineMinimum() {
        let oneSecondOfSixteenHours = 1 / Double(16 * 60 * 60)

        XCTAssertEqual(
            UFastProgressFillGeometry.visibleWidth(
                progress: oneSecondOfSixteenHours,
                trackWidth: 320
            ),
            UFastProgressFillGeometry.minimumVisibleWidth
        )
    }

    func testPartialProgressRemainsProportional() {
        XCTAssertEqual(
            UFastProgressFillGeometry.visibleWidth(progress: 0.25, trackWidth: 320),
            80
        )
    }

    func testProgressClampsToTrackBounds() {
        XCTAssertEqual(
            UFastProgressFillGeometry.visibleWidth(progress: -1, trackWidth: 320),
            0
        )
        XCTAssertEqual(
            UFastProgressFillGeometry.visibleWidth(progress: 2, trackWidth: 320),
            320
        )
    }
}
