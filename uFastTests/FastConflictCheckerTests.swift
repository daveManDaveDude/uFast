import Foundation
@testable import uFast
import XCTest

final class FastConflictCheckerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_800_000_000)

    func testDetectsEqualContainingContainedAndPartialOverlaps() {
        let existing = interval(start: 10, end: 20)

        XCTAssertTrue(hasConflict(start: 10, end: 20, among: [existing]))
        XCTAssertTrue(hasConflict(start: 5, end: 25, among: [existing]))
        XCTAssertTrue(hasConflict(start: 12, end: 18, among: [existing]))
        XCTAssertTrue(hasConflict(start: 5, end: 15, among: [existing]))
        XCTAssertTrue(hasConflict(start: 15, end: 25, among: [existing]))
    }

    func testDisjointAndTouchingIntervalsDoNotConflict() {
        let existing = interval(start: 10, end: 20)

        XCTAssertFalse(hasConflict(start: 0, end: 10, among: [existing]))
        XCTAssertFalse(hasConflict(start: 20, end: 30, among: [existing]))
        XCTAssertFalse(hasConflict(start: 0, end: 5, among: [existing]))
        XCTAssertFalse(hasConflict(start: 25, end: 30, among: [existing]))
    }

    func testActiveIntervalIsOpenEnded() {
        let active = interval(start: 10, end: nil)

        XCTAssertFalse(hasConflict(start: 0, end: 10, among: [active]))
        XCTAssertTrue(hasConflict(start: 0, end: 11, among: [active]))
        XCTAssertTrue(hasConflict(start: 20, end: 30, among: [active]))
        XCTAssertTrue(hasConflict(start: 20, end: nil, among: [active]))
    }

    func testExcludedIdentifierIsAlwaysIgnored() {
        let existing = interval(start: 10, end: 20)

        XCTAssertFalse(
            FastConflictChecker.hasConflict(
                proposedStart: date(10),
                proposedEnd: date(20),
                excluding: existing.id,
                among: [existing]
            )
        )
    }

    private func hasConflict(
        start: TimeInterval,
        end: TimeInterval?,
        among intervals: [RecordedFastInterval]
    ) -> Bool {
        FastConflictChecker.hasConflict(
            proposedStart: date(start),
            proposedEnd: end.map(date),
            among: intervals
        )
    }

    private func interval(
        start: TimeInterval,
        end: TimeInterval?
    ) -> RecordedFastInterval {
        RecordedFastInterval(
            id: UUID(),
            startDate: date(start),
            endDate: end.map(date)
        )
    }

    private func date(_ offset: TimeInterval) -> Date {
        origin.addingTimeInterval(offset)
    }
}
