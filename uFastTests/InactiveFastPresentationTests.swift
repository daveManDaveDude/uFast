import Foundation
@testable import uFast
import XCTest

final class InactiveFastPresentationTests: XCTestCase {
    func testTargetPreviewUsesInjectedInstantAndWholeHourGoal() throws {
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-03-29T00:30:00Z")
        )
        let goal = try XCTUnwrap(FastingGoal(hours: 8))

        let presentation = InactiveFastPresentation(now: now, goal: goal)

        XCTAssertEqual(presentation.goal, goal)
        XCTAssertEqual(
            presentation.targetDate,
            now.addingTimeInterval(8 * 60 * 60)
        )
    }

    func testTargetPreviewDoesNotMutatePersistenceState() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let first = InactiveFastPresentation(now: now, goal: .default)
        let second = InactiveFastPresentation(now: now, goal: .default)

        XCTAssertEqual(first, second)
    }
}
