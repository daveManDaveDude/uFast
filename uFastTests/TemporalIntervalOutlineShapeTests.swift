import CoreGraphics
@testable import uFast
import XCTest

final class TemporalIntervalOutlineShapeTests: XCTestCase {
    func testContinuationFragmentsDoNotStrokeInternalVerticalEdges() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 44)
        let owner = strokedPath(
            continuesBefore: false,
            continuesAfter: true,
            in: rect
        )
        let continuation = strokedPath(
            continuesBefore: true,
            continuesAfter: false,
            in: rect
        )
        let middle = strokedPath(
            continuesBefore: true,
            continuesAfter: true,
            in: rect
        )

        XCTAssertTrue(owner.contains(CGPoint(x: rect.minX + 0.25, y: rect.midY)))
        XCTAssertFalse(owner.contains(CGPoint(x: rect.maxX - 0.25, y: rect.midY)))
        XCTAssertFalse(continuation.contains(CGPoint(x: rect.minX + 0.25, y: rect.midY)))
        XCTAssertTrue(continuation.contains(CGPoint(x: rect.maxX - 0.25, y: rect.midY)))
        XCTAssertFalse(middle.contains(CGPoint(x: rect.minX + 0.25, y: rect.midY)))
        XCTAssertFalse(middle.contains(CGPoint(x: rect.maxX - 0.25, y: rect.midY)))

        XCTAssertTrue(owner.contains(CGPoint(x: rect.midX, y: rect.minY + 0.25)))
        XCTAssertTrue(owner.contains(CGPoint(x: rect.midX, y: rect.maxY - 0.25)))
        XCTAssertTrue(continuation.contains(CGPoint(x: rect.midX, y: rect.minY + 0.25)))
        XCTAssertTrue(continuation.contains(CGPoint(x: rect.midX, y: rect.maxY - 0.25)))
    }

    func testSingleDayIntervalStrokesBothRoundedOuterCaps() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 44)
        let outline = strokedPath(
            continuesBefore: false,
            continuesAfter: false,
            in: rect
        )

        XCTAssertTrue(outline.contains(CGPoint(x: rect.minX + 0.25, y: rect.midY)))
        XCTAssertTrue(outline.contains(CGPoint(x: rect.maxX - 0.25, y: rect.midY)))
    }

    private func strokedPath(
        continuesBefore: Bool,
        continuesAfter: Bool,
        in rect: CGRect
    ) -> CGPath {
        TemporalIntervalOutlineShape(
            continuesBefore: continuesBefore,
            continuesAfter: continuesAfter,
            cornerRadius: 12
        )
        .path(in: rect)
        .cgPath
        .copy(
            strokingWithWidth: 1,
            lineCap: .butt,
            lineJoin: .round,
            miterLimit: 10
        )
    }
}
