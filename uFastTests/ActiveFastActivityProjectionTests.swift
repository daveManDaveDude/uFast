import Foundation
@testable import uFast
import XCTest

// swiftlint:disable function_body_length trailing_comma

final class ActiveFastActivityProjectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let recordIdentifier = UUID(
        uuidString: "10500000-0000-0000-0000-000000000001"
    ) ?? UUID()

    func testContentStateUsesOnlyTheVersionedAllowedWireFields() throws {
        let source = source(startDate: now.addingTimeInterval(-6 * 60 * 60), goalHours: 12)
        let content = ActiveFastActivityAttributes.ContentState(source: source, generatedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(content)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            Set(["schemaVersion", "startDate", "targetDate", "goalHours", "generatedAt"])
        )
        XCTAssertLessThan(data.count, ActiveFastActivityAttributes.ContentState.maximumEncodedByteCount)
        let encodedString = String(bytes: data, encoding: .utf8) ?? ""
        XCTAssertFalse(encodedString.contains(recordIdentifier.uuidString))
        XCTAssertFalse(encodedString.localizedCaseInsensitiveContains("food"))
        XCTAssertFalse(encodedString.localizedCaseInsensitiveContains("hydration"))
    }

    func testContentStateValidationRejectsInvalidSchemaGoalTargetAndFutureDates() {
        let cases = invalidContentCases()

        for (content, expectedError) in cases {
            XCTAssertThrowsError(try content.validate(now: now)) { error in
                XCTAssertEqual(error as? ActiveFastActivityContentError, expectedError)
            }
        }
    }

    private func invalidContentCases() -> [
        (ActiveFastActivityAttributes.ContentState, ActiveFastActivityContentError)
    ] {
        let validSource = source(startDate: now.addingTimeInterval(-60), goalHours: 12)
        return [
            (
                .init(
                    schemaVersion: 2,
                    startDate: validSource.startDate,
                    targetDate: validSource.targetDate,
                    goalHours: validSource.goalHours,
                    generatedAt: now
                ),
                .incompatibleSchema
            ),
            (
                .init(
                    startDate: validSource.startDate,
                    targetDate: validSource.startDate.addingTimeInterval(7 * 60 * 60),
                    goalHours: 7,
                    generatedAt: now
                ),
                .invalidGoal
            ),
            (
                .init(
                    startDate: validSource.startDate,
                    targetDate: validSource.startDate,
                    goalHours: 12,
                    generatedAt: now
                ),
                .invalidTarget
            ),
            (
                .init(
                    startDate: validSource.startDate,
                    targetDate: validSource.startDate.addingTimeInterval(13 * 60 * 60),
                    goalHours: 12,
                    generatedAt: now
                ),
                .inconsistentTarget
            ),
            (
                .init(
                    startDate: now.addingTimeInterval(1),
                    targetDate: now.addingTimeInterval(12 * 60 * 60 + 1),
                    goalHours: 12,
                    generatedAt: now
                ),
                .futureStart
            ),
            (
                .init(
                    startDate: validSource.startDate,
                    targetDate: validSource.targetDate,
                    goalHours: 12,
                    generatedAt: now.addingTimeInterval(1)
                ),
                .futureGeneration
            ),
        ]
    }

    func testPresentationClampsProgressAndRequiresARealGoalObservation() {
        let start = now.addingTimeInterval(-6 * 60 * 60)
        let source = source(startDate: start, goalHours: 12)
        let attributes = ActiveFastActivityAttributes(activeRecordIdentifier: recordIdentifier)
        let requestState = ActiveFastActivityAttributes.ContentState(
            source: source,
            generatedAt: start
        )
        let atTargetWithoutObservation = ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: requestState,
            now: source.targetDate
        )
        XCTAssertEqual(atTargetWithoutObservation.progressPercentage, 100)
        XCTAssertFalse(atTargetWithoutObservation.hasReachedGoal)

        let observedState = ActiveFastActivityAttributes.ContentState(
            source: source,
            generatedAt: source.targetDate
        )
        let reached = ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: observedState,
            now: source.targetDate.addingTimeInterval(60)
        )
        XCTAssertEqual(reached.elapsedText, "12:01:00")
        XCTAssertEqual(reached.progress, 1)
        XCTAssertEqual(reached.progressPercentage, 100)
        XCTAssertTrue(reached.hasReachedGoal)
        XCTAssertTrue(reached.accessibilitySummary.contains("Goal time reached"))
    }

    func testRedactedPresentationContainsNoProgressTargetOrElapsedTime() {
        let source = source(startDate: now.addingTimeInterval(-6 * 60 * 60), goalHours: 12)
        let presentation = ActiveFastActivityPresentation.make(
            attributes: ActiveFastActivityAttributes(activeRecordIdentifier: recordIdentifier),
            contentState: .init(source: source, generatedAt: now),
            now: now,
            privacyState: .redacted
        )

        XCTAssertNil(presentation.elapsedText)
        XCTAssertNil(presentation.progressPercentage)
        XCTAssertNil(presentation.targetText)
        XCTAssertEqual(presentation.accessibilitySummary, "uFast. Opens uFast.")
    }

    func testBackdatedFastOlderThanEightHoursRemainsValidAndUsesHistoricalElapsedTime() throws {
        let source = source(startDate: now.addingTimeInterval(-24 * 60 * 60), goalHours: 16)
        let content = ActiveFastActivityAttributes.ContentState(source: source, generatedAt: now)

        XCTAssertNoThrow(try content.validate(now: now))
        let presentation = ActiveFastActivityPresentation.make(
            attributes: ActiveFastActivityAttributes(activeRecordIdentifier: recordIdentifier),
            contentState: content,
            now: now
        )
        XCTAssertEqual(presentation.elapsedText, "1d 00:00:00")
        XCTAssertEqual(presentation.progressPercentage, 100)
        XCTAssertTrue(presentation.hasReachedGoal)
    }

    func testRouteAcceptsOnlyTheExactCurrentFastURL() throws {
        XCTAssertTrue(try ActiveFastActivityRoute.isCurrentFastURL(XCTUnwrap(URL(string: "ufast://fast/current"))))
        XCTAssertFalse(try ActiveFastActivityRoute.isCurrentFastURL(XCTUnwrap(URL(string: "ufast://fast/current?x=1"))))
        XCTAssertFalse(try ActiveFastActivityRoute.isCurrentFastURL(XCTUnwrap(URL(string: "ufast://other/current"))))
        XCTAssertFalse(try ActiveFastActivityRoute.isCurrentFastURL(XCTUnwrap(URL(string: "ufast://fast/current/"))))
        XCTAssertFalse(try ActiveFastActivityRoute.isCurrentFastURL(XCTUnwrap(URL(string: "https://fast/current"))))
    }

    private func source(startDate: Date, goalHours: Int) -> ActiveFastActivitySource {
        ActiveFastActivitySource(
            activeRecordIdentifier: recordIdentifier,
            startDate: startDate,
            targetDate: startDate.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours
        )
    }
}
