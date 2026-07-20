@testable import uFast
import XCTest

final class CaloricEventSavePolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoActiveFastAndNonCaloricEventsSaveNormally() {
        XCTAssertEqual(
            CaloricEventSavePolicy.decision(
                isCaloric: true,
                occurredAt: start,
                activeFastStart: nil
            ),
            .saveWithoutEndingFast
        )
        XCTAssertEqual(
            CaloricEventSavePolicy.decision(
                isCaloric: false,
                occurredAt: start.addingTimeInterval(60),
                activeFastStart: start
            ),
            .saveWithoutEndingFast
        )
    }

    func testCaloricBeforeEqualAndAfterActiveStartUseRequiredDecisions() {
        XCTAssertEqual(
            decision(at: start.addingTimeInterval(-1)),
            .saveWithoutEndingFast
        )
        XCTAssertEqual(decision(at: start), .invalidAtActiveFastStart)
        XCTAssertEqual(
            decision(at: start.addingTimeInterval(1)),
            .requiresEndingActiveFast
        )
    }

    private func decision(at date: Date) -> CaloricEventSaveDecision {
        CaloricEventSavePolicy.decision(
            isCaloric: true,
            occurredAt: date,
            activeFastStart: start
        )
    }
}
