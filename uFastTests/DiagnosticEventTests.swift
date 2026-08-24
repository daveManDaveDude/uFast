import Foundation
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

final class DiagnosticEventTests: XCTestCase {
    func testClosedVocabularyIsExhaustive() {
        XCTAssertEqual(
            DiagnosticSubsystem.allCases.map(\.rawValue),
            ["persistence", "command", "history", "widgetProjection", "liveActivity"]
        )
        XCTAssertEqual(
            DiagnosticOutcome.allCases.map(\.rawValue),
            [
                "storeOpenFailed",
                "migrationFailed",
                "authorityConflict",
                "commitFailed",
                "rollbackApplied",
                "postCommitProjectionFailed",
                "initialLoadFailed",
                "extensionLoadFailed",
                "containerUnavailable",
                "publishFailed",
                "clearFailed",
                "unavailable",
                "requestFailed",
                "updateFailed",
                "endFailed",
            ]
        )
        XCTAssertEqual(DiagnosticSeverity.allCases.map(\.rawValue), ["warning", "error"])
        XCTAssertEqual(DiagnosticCountBucket.allCases.map(\.rawValue), ["zero", "one", "multiple"])
    }

    func testEveryOutcomeConstructsAndRoundTripsWithItsPermittedFields() throws {
        let versions = DiagnosticVersionSource.current
        for fixture in validFixtures {
            let event = try XCTUnwrap(
                DiagnosticEvent(
                    subsystem: fixture.subsystem,
                    outcome: fixture.outcome,
                    severity: fixture.severity,
                    appVersion: versions.appVersion,
                    buildNumber: versions.buildNumber,
                    schemaVersion: versions.schemaVersion,
                    countBucket: fixture.countBucket,
                    isRetry: fixture.isRetry,
                    isForeground: fixture.isForeground
                )
            )
            let data = try JSONEncoder().encode(event)
            XCTAssertEqual(try JSONDecoder().decode(DiagnosticEvent.self, from: data), event)
        }
    }

    func testOptionalFieldMatrixRejectsUndocumentedMetadata() {
        for fixture in invalidMetadataFixtures {
            XCTAssertNil(
                DiagnosticEvent(
                    subsystem: fixture.subsystem,
                    outcome: fixture.outcome,
                    severity: .error,
                    countBucket: fixture.countBucket,
                    isRetry: fixture.isRetry,
                    isForeground: fixture.isForeground
                ),
                "Unexpected metadata accepted for \(fixture.subsystem.rawValue)/\(fixture.outcome.rawValue)"
            )
        }
    }

    func testPermittedOptionalFieldsMayBeOmitted() {
        for fixture in validFixtures {
            XCTAssertNotNil(
                DiagnosticEvent(
                    subsystem: fixture.subsystem,
                    outcome: fixture.outcome,
                    severity: fixture.severity
                ),
                "Permitted optional metadata became required for "
                    + "\(fixture.subsystem.rawValue)/\(fixture.outcome.rawValue)"
            )
        }
    }

    func testUndocumentedOutcomeAndFieldAreRejectedDuringDecoding() throws {
        let unknownOutcome = Data(
            "{\"subsystem\":\"widgetProjection\",\"outcome\":\"debug\",\"severity\":\"error\"}".utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(DiagnosticEvent.self, from: unknownOutcome))

        let unknownField = Data(
            """
            {"subsystem":"widgetProjection","outcome":"publishFailed","severity":"error","recordID":"123"}
            """.utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(DiagnosticEvent.self, from: unknownField))
    }

    func testVersionFieldsRejectFreeFormAndInvalidValues() {
        XCTAssertEqual(DiagnosticVersionSource.current.appVersion.rawValue, "1.0.0")
        XCTAssertEqual(DiagnosticVersionSource.current.buildNumber.rawValue, "10")
        XCTAssertEqual(DiagnosticVersionSource.current.schemaVersion.rawValue, "1")

        XCTAssertNil(DiagnosticAppVersion(rawValue: "2.0.0"))
        XCTAssertNil(DiagnosticBuildNumber(rawValue: "11"))
        XCTAssertNil(DiagnosticSchemaVersion(rawValue: "2"))
        XCTAssertNil(DiagnosticBuildNumber(rawValue: "1800000000"))
        XCTAssertNil(DiagnosticSchemaVersion(rawValue: "1800000000"))
    }

    func testVersionFieldsRejectTimestampLikeAndUndeclaredEncodedValues() throws {
        let timestampLike = Data(
            """
            {"subsystem":"widgetProjection","outcome":"publishFailed","severity":"error",
            "buildNumber":"1800000000"}
            """.utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(DiagnosticEvent.self, from: timestampLike))

        let undeclaredSchema = Data(
            """
            {"subsystem":"widgetProjection","outcome":"publishFailed","severity":"error",
            "schemaVersion":"2"}
            """.utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(DiagnosticEvent.self, from: undeclaredSchema))

        let event = try XCTUnwrap(
            DiagnosticEvent(
                subsystem: .widgetProjection,
                outcome: .publishFailed,
                severity: .error,
                appVersion: .current,
                buildNumber: .current,
                schemaVersion: .current
            )
        )
        XCTAssertEqual(try JSONDecoder().decode(DiagnosticEvent.self, from: JSONEncoder().encode(event)), event)
    }

    func testEncodingContainsOnlyMetadataFieldsAndNoProhibitedPayload() throws {
        let event = try XCTUnwrap(
            DiagnosticEvent(
                subsystem: .liveActivity,
                outcome: .requestFailed,
                severity: .error,
                appVersion: .current,
                buildNumber: .current,
                schemaVersion: .current,
                isRetry: true,
                isForeground: true
            )
        )
        let data = try JSONEncoder().encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(
            Set(object.keys),
            [
                "subsystem",
                "outcome",
                "severity",
                "appVersion",
                "buildNumber",
                "schemaVersion",
                "isRetry",
                "isForeground",
            ]
        )
        let payload = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        for prohibited in [
            "food", "drink", "nutrition", "Health", "note", "recordID", "1800000000", "/private/", "underlying error",
        ] {
            XCTAssertFalse(payload.localizedCaseInsensitiveContains(prohibited), "Payload contains \(prohibited)")
        }
    }

    func testNoOpAndRecordingSinksAreSynchronousCountOnlyObservers() throws {
        let event = try XCTUnwrap(
            DiagnosticEvent(
                subsystem: .widgetProjection,
                outcome: .publishFailed,
                severity: .error
            )
        )
        let noOp = NoOpDiagnosticEventSink()
        noOp.record(event)

        let recording = RecordingDiagnosticEventSink()
        XCTAssertEqual(recording.count, 0)
        recording.record(event)
        recording.record(event)
        XCTAssertEqual(recording.count, 2)
        XCTAssertEqual(recording.events, [event, event])
    }

    func testRecordingSinkIsSafeForConcurrentRecordsAndSnapshots() throws {
        let event = try XCTUnwrap(
            DiagnosticEvent(
                subsystem: .widgetProjection,
                outcome: .publishFailed,
                severity: .error
            )
        )
        let recording = RecordingDiagnosticEventSink()

        DispatchQueue.concurrentPerform(iterations: 256) { _ in
            recording.record(event)
        }

        XCTAssertEqual(recording.count, 256)
        XCTAssertEqual(recording.events, Array(repeating: event, count: 256))
    }

    private struct Fixture {
        let subsystem: DiagnosticSubsystem
        let outcome: DiagnosticOutcome
        let severity: DiagnosticSeverity
        let countBucket: DiagnosticCountBucket?
        let isRetry: Bool?
        let isForeground: Bool?

        init(
            _ subsystem: DiagnosticSubsystem,
            _ outcome: DiagnosticOutcome,
            _ severity: DiagnosticSeverity,
            countBucket: DiagnosticCountBucket? = nil,
            isRetry: Bool? = nil,
            isForeground: Bool? = nil
        ) {
            self.subsystem = subsystem
            self.outcome = outcome
            self.severity = severity
            self.countBucket = countBucket
            self.isRetry = isRetry
            self.isForeground = isForeground
        }
    }

    private var validFixtures: [Fixture] {
        [
            Fixture(.persistence, .storeOpenFailed, .error),
            Fixture(.persistence, .migrationFailed, .error),
            Fixture(.persistence, .authorityConflict, .error, countBucket: .multiple),
            Fixture(.command, .commitFailed, .error, isRetry: true),
            Fixture(.command, .rollbackApplied, .warning, isRetry: false),
            Fixture(.command, .postCommitProjectionFailed, .error, isRetry: false),
            Fixture(.history, .initialLoadFailed, .error, isRetry: true),
            Fixture(.history, .extensionLoadFailed, .error, isRetry: false),
            Fixture(.widgetProjection, .containerUnavailable, .error),
            Fixture(.widgetProjection, .authorityConflict, .error, countBucket: .multiple),
            Fixture(.widgetProjection, .publishFailed, .error),
            Fixture(.widgetProjection, .clearFailed, .error),
            Fixture(.liveActivity, .unavailable, .error, isForeground: true),
            Fixture(.liveActivity, .authorityConflict, .error, countBucket: .multiple),
            Fixture(.liveActivity, .requestFailed, .error, isRetry: true, isForeground: true),
            Fixture(.liveActivity, .updateFailed, .error, isRetry: false, isForeground: true),
            Fixture(.liveActivity, .endFailed, .error, isRetry: false, isForeground: false),
        ]
    }

    private var invalidMetadataFixtures: [Fixture] {
        [
            Fixture(.persistence, .storeOpenFailed, .error, countBucket: .one),
            Fixture(.persistence, .authorityConflict, .error, isRetry: true),
            Fixture(.command, .commitFailed, .error, countBucket: .one, isRetry: true),
            Fixture(.history, .initialLoadFailed, .error, isRetry: true, isForeground: true),
            Fixture(.widgetProjection, .publishFailed, .error, countBucket: .one),
            Fixture(.liveActivity, .unavailable, .error, isRetry: true, isForeground: true),
            Fixture(.liveActivity, .requestFailed, .error, countBucket: .one, isRetry: true, isForeground: true),
        ]
    }
}
