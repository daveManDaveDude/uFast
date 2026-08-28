import Foundation
@testable import UFastCore
import XCTest

// swiftlint:disable trailing_comma

final class InferredFastSuppressionTests: XCTestCase {
    func testPreEligibilityPunctuationRemovesSuppression() throws {
        let source = boundary(at: 1000, kind: .food)
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source],
            currentGoal: .default,
            enabled: true,
            now: source.occurredAt.addingTimeInterval(9 * 60 * 60)
        ).first)
        let suppression = InferredFastSuppressionDecider.make(
            candidate: candidate,
            at: candidate.endDate
        )
        let tooSoon = boundary(
            at: source.occurredAt.timeIntervalSince1970 + 7 * 60 * 60,
            kind: .hydration
        )

        XCTAssertEqual(
            InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: [source, tooSoon],
                currentGoal: .default,
                enabled: true,
                now: candidate.endDate,
                updatedAt: candidate.endDate
            ),
            .remove
        )
    }

    func testInCapProjectionUpdatesAndAfterCapUnchanged() throws {
        let source = boundary(at: 2000, kind: .food)
        let firstCandidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source],
            currentGoal: .default,
            enabled: true,
            now: source.occurredAt.addingTimeInterval(9 * 60 * 60)
        ).first)
        let createdAt = source.occurredAt
        let suppression = InferredFastSuppressionDecider.make(
            candidate: firstCandidate,
            at: createdAt
        )
        let inCapNow = source.occurredAt.addingTimeInterval(10 * 60 * 60)
        let updated = InferredFastSuppressionDecider.decide(
            suppression: suppression,
            boundaries: [source],
            currentGoal: .default,
            enabled: true,
            now: inCapNow,
            updatedAt: inCapNow
        )
        guard case let .retain(inCap) = updated else {
            return XCTFail("Expected in-cap suppression retention")
        }
        XCTAssertEqual(inCap.projectedEndDate, inCapNow)
        XCTAssertEqual(inCap.createdAt, createdAt)
        XCTAssertEqual(inCap.updatedAt, inCapNow)

        let cap = source.occurredAt.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: .default)
        )
        let atCapCandidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source],
            currentGoal: .default,
            enabled: true,
            now: cap
        ).first)
        let atCap = InferredFastSuppressionDecider.make(candidate: atCapCandidate, at: cap)
        let afterCapBoundary = boundary(
            at: cap.timeIntervalSince1970 + 60,
            kind: .hydration
        )
        let afterCap = InferredFastSuppressionDecider.decide(
            suppression: atCap,
            boundaries: [source, afterCapBoundary],
            currentGoal: .default,
            enabled: true,
            now: afterCapBoundary.occurredAt,
            updatedAt: afterCapBoundary.occurredAt
        )
        XCTAssertEqual(afterCap, InferredFastSuppressionDecision.retain(atCap))
    }

    func testRecordedOverlapDoesNotChangeSuppressionDecision() throws {
        let source = boundary(at: 3000, kind: .food)
        let now = source.occurredAt.addingTimeInterval(10 * 60 * 60)
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source], currentGoal: .default, enabled: true, now: now
        ).first)
        let suppression = InferredFastSuppressionDecider.make(candidate: candidate, at: now)
        let recorded = RecordedFastInterval(
            id: UUID(),
            startDate: source.occurredAt.addingTimeInterval(9 * 60 * 60),
            endDate: source.occurredAt.addingTimeInterval(11 * 60 * 60)
        )

        let decision = InferredFastSuppressionDecider.decide(
            suppression: suppression,
            boundaries: [source],
            recordedFasts: [recorded],
            currentGoal: .default,
            enabled: true,
            now: now,
            updatedAt: now
        )
        XCTAssertEqual(decision, .retain(suppression))
    }

    func testDetectionOffPreservesSuppressionForLaterReconciliation() throws {
        let source = boundary(at: 4000, kind: .food)
        let now = source.occurredAt.addingTimeInterval(10 * 60 * 60)
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source], currentGoal: .default, enabled: true, now: now
        ).first)
        let suppression = InferredFastSuppressionDecider.make(candidate: candidate, at: now)

        XCTAssertEqual(
            InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: [],
                currentGoal: .default,
                enabled: false,
                now: now,
                updatedAt: now.addingTimeInterval(60)
            ),
            .retain(suppression)
        )
    }

    // swiftlint:disable:next function_body_length
    func testAuthoritativeMutationReconcilesWhileDetectionIsDisabled() throws {
        let source = boundary(at: 4500, kind: .food)
        let inCapNow = source.occurredAt.addingTimeInterval(9 * 60 * 60)
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [source],
            currentGoal: .default,
            enabled: true,
            now: inCapNow
        ).first)
        let suppression = InferredFastSuppressionDecider.make(candidate: candidate, at: inCapNow)
        let authoritativeMode = InferredFastSuppressionMode.authoritativeMutation

        XCTAssertEqual(
            InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: [],
                currentGoal: .default,
                enabled: false,
                mode: authoritativeMode,
                now: inCapNow,
                updatedAt: inCapNow
            ),
            .remove
        )

        let preEligibilityBoundary = boundary(
            at: source.occurredAt.timeIntervalSince1970 + 7 * 60 * 60,
            kind: .hydration
        )
        XCTAssertEqual(
            InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: [source, preEligibilityBoundary],
                currentGoal: .default,
                enabled: false,
                mode: authoritativeMode,
                now: inCapNow,
                updatedAt: inCapNow
            ),
            .remove
        )

        let later = source.occurredAt.addingTimeInterval(10 * 60 * 60)
        guard case let .retain(updated) = InferredFastSuppressionDecider.decide(
            suppression: suppression,
            boundaries: [source],
            currentGoal: .default,
            enabled: false,
            mode: authoritativeMode,
            now: later,
            updatedAt: later
        ) else {
            return XCTFail("Expected disabled authoritative in-cap reconciliation")
        }
        XCTAssertEqual(updated.projectedEndDate, later)

        let eighteenHours = try XCTUnwrap(FastingGoal(hours: 18))
        guard case let .retain(goalUpdated) = InferredFastSuppressionDecider.decide(
            suppression: suppression,
            boundaries: [source],
            currentGoal: eighteenHours,
            enabled: false,
            mode: authoritativeMode,
            now: later,
            updatedAt: later
        ) else {
            return XCTFail("Expected disabled authoritative goal reconciliation")
        }
        XCTAssertEqual(goalUpdated.goalHoursSnapshot, eighteenHours.hours)
    }

    func testEqualTimestampCanonicalizationUsesStableSourceReference() throws {
        let sharedID = UUID()
        let laterID = UUID()
        let timestamp = Date(timeIntervalSince1970: 5000)
        let food = CaloricBoundary(
            reference: .init(kind: .food, id: sharedID),
            occurredAt: timestamp,
            description: "Food"
        )
        let drink = CaloricBoundary(
            reference: .init(kind: .hydration, id: sharedID),
            occurredAt: timestamp,
            description: "Drink"
        )
        let laterDrink = CaloricBoundary(
            reference: .init(kind: .hydration, id: laterID),
            occurredAt: timestamp.addingTimeInterval(10 * 60 * 60),
            description: "Later drink"
        )
        let candidates = InferredFastProjector.project(
            boundaries: [drink, laterDrink, food],
            currentGoal: .default,
            enabled: true,
            now: laterDrink.occurredAt.addingTimeInterval(60)
        )

        XCTAssertEqual(candidates.count, 1)
        let candidate = try XCTUnwrap(candidates.first { $0.sourceBoundaryReference == food.reference })
        XCTAssertEqual(candidate.nextBoundaryReference, laterDrink.reference)
        XCTAssertEqual(candidate.nextBoundaryDate, laterDrink.occurredAt)

        let suppression = InferredFastSuppressionDecider.make(
            candidate: candidate,
            at: laterDrink.occurredAt
        )
        XCTAssertEqual(
            InferredFastSuppressionDecider.decide(
                suppression: suppression,
                boundaries: [food, drink, laterDrink],
                currentGoal: .default,
                enabled: true,
                now: laterDrink.occurredAt.addingTimeInterval(60),
                updatedAt: laterDrink.occurredAt.addingTimeInterval(60)
            ),
            .retain(suppression)
        )
    }

    func testSuppressionRetainsNextBoundaryMetadataAcrossLondonDSTTransition() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let sourceDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 29, hour: 0
        )))
        let nextDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 29, hour: 9
        )))
        let sourceReference = CaloricBoundaryReference(kind: .food, id: UUID())
        let nextReference = CaloricBoundaryReference(kind: .hydration, id: UUID())
        let next = CaloricBoundary(
            reference: nextReference,
            occurredAt: nextDate,
            description: "Coffee"
        )
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [
                CaloricBoundary(reference: sourceReference, occurredAt: sourceDate, description: "Dinner"),
                next,
            ],
            currentGoal: .default,
            enabled: true,
            now: nextDate.addingTimeInterval(60)
        ).first)

        XCTAssertEqual(candidate.nextBoundaryReference, nextReference)
        XCTAssertEqual(candidate.nextBoundaryDate, nextDate)
        XCTAssertEqual(candidate.endDate, nextDate)
        XCTAssertEqual(candidate.endDate.timeIntervalSince(candidate.startDate), 8 * 60 * 60)

        let suppression = InferredFastSuppressionDecider.make(candidate: candidate, at: nextDate)
        guard case let .retain(updated) = InferredFastSuppressionDecider.decide(
            suppression: suppression,
            boundaries: [
                CaloricBoundary(reference: sourceReference, occurredAt: sourceDate, description: "Dinner"),
                next,
            ],
            currentGoal: .default,
            enabled: true,
            now: nextDate.addingTimeInterval(60),
            updatedAt: nextDate.addingTimeInterval(60)
        ) else {
            return XCTFail("Expected DST-spanning suppression to remain retained")
        }
        XCTAssertEqual(updated.nextBoundaryReference, nextReference)
        XCTAssertEqual(updated.nextBoundaryDate, nextDate)
        XCTAssertEqual(updated.projectedEndDate, nextDate)
    }

    private func boundary(at timestamp: TimeInterval, kind: CaloricBoundaryKind) -> CaloricBoundary {
        CaloricBoundary(
            reference: CaloricBoundaryReference(kind: kind, id: UUID()),
            occurredAt: Date(timeIntervalSince1970: timestamp),
            description: "Source"
        )
    }
}
