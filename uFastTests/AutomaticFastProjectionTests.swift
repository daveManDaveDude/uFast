@testable import UFastCore
import XCTest

// swiftlint:disable line_length
final class AutomaticFastProjectionTests: XCTestCase {
    func testStrictThresholdAndStableBoundaryIdentity() {
        let first = boundary(hour: 0)
        let exact = boundary(hour: 8)
        let qualifying = boundary(seconds: 8 * 60 * 60 + 1)
        let range = Date.distantPast ..< Date.distantFuture

        XCTAssertTrue(AutomaticFastProjector.project(boundaries: [first, exact], visibleInterval: range).isEmpty)
        let result = AutomaticFastProjector.project(boundaries: [first, qualifying], visibleInterval: range)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.identity.boundaries.start, first.reference)
        XCTAssertEqual(result.first?.identity.boundaries.end, qualifying.reference)
    }

    func testOnlyConsecutiveCaloricBoundariesQualifyAndRecordedFastWins() {
        let first = boundary(hour: 0)
        let drink = boundary(hour: 4, kind: .hydration)
        let last = boundary(hour: 12)
        let range = Date.distantPast ..< Date.distantFuture
        XCTAssertTrue(AutomaticFastProjector.project(boundaries: [first, drink, last], visibleInterval: range).isEmpty)

        let recorded = RecordedFastInterval(id: UUID(), startDate: first.occurredAt, endDate: last.occurredAt)
        XCTAssertTrue(AutomaticFastProjector.project(boundaries: [first, last], visibleInterval: range, excluding: [recorded]).isEmpty)
    }

    func testCrossingViewportIsIncludedWithoutEdgeInference() {
        let first = boundary(hour: 0)
        let last = boundary(hour: 12)
        let visible = Date(timeIntervalSince1970: 3 * 60 * 60) ..< Date(timeIntervalSince1970: 5 * 60 * 60)
        XCTAssertEqual(AutomaticFastProjector.project(boundaries: [first, last], visibleInterval: visible).count, 1)
        XCTAssertTrue(AutomaticFastProjector.project(boundaries: [first], visibleInterval: visible).isEmpty)
    }

    private func boundary(hour: Int, kind: CaloricBoundaryKind = .food) -> CaloricBoundary {
        boundary(seconds: hour * 60 * 60, kind: kind)
    }

    private func boundary(seconds: Int, kind: CaloricBoundaryKind = .food) -> CaloricBoundary {
        CaloricBoundary(reference: .init(kind: kind, id: UUID()), occurredAt: Date(timeIntervalSince1970: TimeInterval(seconds)), description: "Event")
    }
}
