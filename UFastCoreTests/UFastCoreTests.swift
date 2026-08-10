import Foundation
@testable import UFastCore
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

final class UFastCoreTests: XCTestCase {
    func testAutomaticProjectionUsesStrictThresholdAndStableBoundaryIdentity() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let startReference = CaloricBoundaryReference(kind: .food, id: UUID())
        let endReference = CaloricBoundaryReference(kind: .hydration, id: UUID())
        let exact = boundaries(start: start, duration: 8 * 60 * 60, startReference, endReference)
        XCTAssertTrue(AutomaticFastProjector.project(
            boundaries: exact,
            visibleInterval: start ..< start.addingTimeInterval(9 * 60 * 60)
        ).isEmpty)

        let qualifying = boundaries(
            start: start,
            duration: 8 * 60 * 60 + 1,
            startReference,
            endReference
        )
        let projected = try XCTUnwrap(AutomaticFastProjector.project(
            boundaries: qualifying,
            visibleInterval: start ..< start.addingTimeInterval(9 * 60 * 60)
        ).first)
        XCTAssertEqual(
            projected.identity.boundaries,
            CaloricBoundaryPair(start: startReference, end: endReference)
        )
    }

    func testConflictCheckerUsesHalfOpenIntervals() {
        let start = Date(timeIntervalSince1970: 1000)
        let existing = RecordedFastInterval(
            id: UUID(),
            startDate: start,
            endDate: start.addingTimeInterval(100)
        )
        XCTAssertFalse(FastConflictChecker.hasConflict(
            proposedStart: start.addingTimeInterval(100),
            proposedEnd: start.addingTimeInterval(200),
            among: [existing]
        ))
        XCTAssertTrue(FastConflictChecker.hasConflict(
            proposedStart: start.addingTimeInterval(99),
            proposedEnd: start.addingTimeInterval(200),
            among: [existing]
        ))
    }

    func testFoundationOnlyClockGoalAndValidationValues() {
        let now = Date(timeIntervalSince1970: 42)
        XCTAssertEqual(FixedAppClock(now: now).now, now)
        XCTAssertEqual(FastingGoal(hours: 12)?.hours, 12)
        XCTAssertNil(FastingGoal(hours: 7))
        XCTAssertEqual(DomainValidation.nonEmptyTrimmed("  tea  ", maximumLength: 4), "tea")
        XCTAssertNil(DomainValidation.nonEmptyTrimmed("     ", maximumLength: 4))
    }

    private func boundaries(
        start: Date,
        duration: TimeInterval,
        _ startReference: CaloricBoundaryReference,
        _ endReference: CaloricBoundaryReference
    ) -> [CaloricBoundary] {
        [
            CaloricBoundary(reference: startReference, occurredAt: start, description: "Start"),
            CaloricBoundary(
                reference: endReference,
                occurredAt: start.addingTimeInterval(duration),
                description: "End"
            ),
        ]
    }
}
