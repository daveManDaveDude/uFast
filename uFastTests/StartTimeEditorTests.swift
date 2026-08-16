import Foundation
@testable import uFast
import XCTest

@MainActor
final class StartTimeEditorTests: XCTestCase {
    func testValidationMessageUsesCurrentClockForStaleBoundaryAndOtherGuardFailures() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let selectedAtBoundary = now.addingTimeInterval(-FastStartService.maximumStartAge)

        XCTAssertEqual(
            StartTimeEditor.validationMessage(
                for: selectedAtBoundary,
                now: now.addingTimeInterval(1),
                hasConflict: false
            ),
            "Start time must be within the past 36 hours."
        )
        XCTAssertEqual(
            StartTimeEditor.validationMessage(
                for: now.addingTimeInterval(1),
                now: now,
                hasConflict: false
            ),
            "Start time can’t be in the future."
        )
        XCTAssertEqual(
            StartTimeEditor.validationMessage(
                for: now.addingTimeInterval(-3600),
                now: now,
                hasConflict: true
            ),
            "This fast overlaps another recorded fast."
        )
    }
}
