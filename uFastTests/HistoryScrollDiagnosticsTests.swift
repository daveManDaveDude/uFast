@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

final class HistoryScrollDiagnosticsTests: XCTestCase {
    private func enabledConfiguration(maxEvents: Int = 64) -> HistoryScrollDiagnosticConfiguration {
        HistoryScrollDiagnosticConfiguration(
            arguments: ["--ui-testing", HistoryScrollDiagnosticConfiguration.diagnosticArgument],
            maxEvents: maxEvents
        )
    }

    func testNormalLaunchIsDisabledAndDoesNoPeriodicWork() {
        let configuration = HistoryScrollDiagnosticConfiguration(arguments: [])
        XCTAssertFalse(configuration.isEnabled)
        XCTAssertFalse(configuration.usesPeriodicWork)
        XCTAssertFalse(configuration.keepsBF105VerboseProbesDisabled)

        var capture = HistoryScrollDiagnosticCapture(configuration: configuration)
        capture.recordNativePhase(.decelerating, at: 1)
        capture.recordGeometry(offset: 10, at: 1.1)
        let report = capture.endCapture(at: 2)

        XCTAssertEqual(report.outcome, .disabled)
        XCTAssertTrue(report.events.isEmpty)
        XCTAssertEqual(report.droppedEventCount, 0)
    }

    func testDiagnosticModeRequiresExplicitUIOnlyArgumentAndDisablesBF105Probes() {
        let uiTestingOnly = HistoryScrollDiagnosticConfiguration(arguments: ["--ui-testing"])
        XCTAssertFalse(uiTestingOnly.isEnabled)

        let configuration = enabledConfiguration()
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertTrue(configuration.keepsBF105VerboseProbesDisabled)
        XCTAssertFalse(configuration.usesPeriodicWork)
    }

    func testDiagnosticLaunchCapacityOverrideIsBoundedAndProductionGated() {
        let configured = HistoryScrollDiagnosticConfiguration(arguments: [
            "--ui-testing", HistoryScrollDiagnosticConfiguration.diagnosticArgument,
            HistoryScrollDiagnosticConfiguration.maxEventsArgument, "16384",
        ])
        XCTAssertEqual(HistoryScrollDiagnosticConfiguration.maximumEventCapacity, 16384)
        XCTAssertEqual(configured.maxEvents, HistoryScrollDiagnosticConfiguration.maximumEventCapacity)

        let clampedHigh = HistoryScrollDiagnosticConfiguration(arguments: [
            "--ui-testing", HistoryScrollDiagnosticConfiguration.diagnosticArgument,
            HistoryScrollDiagnosticConfiguration.maxEventsArgument, "99999",
        ])
        XCTAssertEqual(clampedHigh.maxEvents, HistoryScrollDiagnosticConfiguration.maximumEventCapacity)

        let clampedLow = HistoryScrollDiagnosticConfiguration(arguments: [
            "--ui-testing", HistoryScrollDiagnosticConfiguration.diagnosticArgument,
            HistoryScrollDiagnosticConfiguration.maxEventsArgument, "0",
        ])
        XCTAssertEqual(clampedLow.maxEvents, 1)

        let production = HistoryScrollDiagnosticConfiguration(arguments: [
            HistoryScrollDiagnosticConfiguration.maxEventsArgument, "8192",
        ])
        XCTAssertFalse(production.isEnabled)
        XCTAssertEqual(production.maxEvents, HistoryScrollDiagnosticConfiguration.defaultMaxEvents)
    }

    func testDiagnosticMaximumCapacityRetainsQualificationSizedCaptureWithoutDrops() {
        let configuration = HistoryScrollDiagnosticConfiguration(arguments: [
            "--ui-testing", HistoryScrollDiagnosticConfiguration.diagnosticArgument,
            HistoryScrollDiagnosticConfiguration.maxEventsArgument, "16384",
        ])
        var capture = HistoryScrollDiagnosticCapture(configuration: configuration)
        for index in 0 ..< 12038 {
            capture.recordGeometry(offset: Double(index), at: Double(index))
        }

        let report = capture.endCapture(at: 12038)
        XCTAssertEqual(report.retainedEventCount, 12038)
        XCTAssertEqual(report.droppedEventCount, 0)
    }

    func testLongDecelerationUsesFinalTailAndFirstPostIdleWindow() {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.recordNativePhase(.tracking, at: 0)
        capture.recordNativePhase(.decelerating, at: 1)
        capture.recordFractionalMotion(at: 1.49)
        capture.recordFractionalMotion(at: 1.5)
        capture.recordGeometry(offset: 40, at: 1.75)
        capture.recordNativePhase(.idle, at: 2)
        capture.recordWork(.settlementReconciliation, at: 2)
        capture.recordGeometry(offset: 42, at: 2.1)
        let report = capture.endCapture(at: 2.25)

        XCTAssertEqual(report.outcome, .captured)
        XCTAssertEqual(try XCTUnwrap(report.decelerationDuration), 1, accuracy: 0.000_001)
        XCTAssertEqual(report.phases.count, 3)
        XCTAssertEqual(report.phases[0].phase, .nativeDecelerationTail)
        XCTAssertEqual(report.phases[0].start, 1.5, accuracy: 0.000_001)
        XCTAssertEqual(report.phases[0].end, 2, accuracy: 0.000_001)
        XCTAssertFalse(report.phases[0].isShorterThanRequestedWindow)
        XCTAssertEqual(report.phases[1].phase, .idleBoundary)
        XCTAssertEqual(report.phases[2].phase, .postIdle)
        XCTAssertEqual(report.phases[2].end, 2.25, accuracy: 0.000_001)
        XCTAssertFalse(report.phases[2].isShorterThanRequestedWindow)

        XCTAssertEqual(report.phase(for: 1.499), .outsideWindow)
        XCTAssertEqual(report.phase(for: 1.5), .nativeDecelerationTail)
        XCTAssertEqual(report.phase(for: 2), .idleBoundary)
        XCTAssertEqual(report.phase(for: 2.001), .postIdle)
        XCTAssertEqual(report.phase(for: 2.251), .outsideWindow)
    }

    func testShortDecelerationRetainsTheCompleteObservedTail() {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.recordNativePhase(.decelerating, at: 10)
        capture.recordGeometry(offset: 10, at: 10.1)
        capture.recordNativePhase(.idle, at: 10.2)
        let report = capture.endCapture(at: 10.45)

        XCTAssertEqual(report.outcome, .captured)
        XCTAssertEqual(try XCTUnwrap(report.decelerationDuration), 0.2, accuracy: 0.000_001)
        XCTAssertEqual(report.phases[0].start, 10, accuracy: 0.000_001)
        XCTAssertEqual(report.phases[0].duration, 0.2, accuracy: 0.000_001)
        XCTAssertTrue(report.phases[0].isShorterThanRequestedWindow)
        XCTAssertEqual(report.phases[2].duration, 0.25, accuracy: 0.000_001)
        XCTAssertFalse(report.phases[2].isShorterThanRequestedWindow)
    }

    func testCountersAttributeNativeTailPostIdleAndCoarseGenerations() throws {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.recordNativePhase(.decelerating, at: 0)
        capture.recordWork(.labelProjection, at: 0.1)
        capture.recordCoarseInputGeneration(4, at: 0.2)
        capture.recordCoarseInputGeneration(4, at: 0.3)
        capture.recordNativePhase(.idle, at: 0.4)
        capture.recordWork(.exactWindowFetch, at: 0.45)
        capture.recordWork(.exactWindowProjection, at: 0.5)
        let report = capture.endCapture(at: 0.65)

        let projection = try XCTUnwrap(report.workCounts[.labelProjection])
        XCTAssertEqual(projection.total, 1)
        XCTAssertEqual(projection.byPhase[.nativeDecelerationTail], 1)
        let fetch = try XCTUnwrap(report.workCounts[.exactWindowFetch])
        XCTAssertEqual(fetch.byPhase[.postIdle], 1)
        XCTAssertEqual(report.coarseInputDeliveryCount, 2)
        XCTAssertEqual(report.distinctCoarseInputGenerationCount, 1)
        XCTAssertEqual(report.nativeIdleCount, 1)
    }

    func testBoundedCaptureReportsTruncationWithoutUnboundedRawStorage() {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration(maxEvents: 3))
        capture.recordNativePhase(.decelerating, at: 0)
        capture.recordGeometry(offset: 1, at: 0.1)
        capture.recordWork(.fractionalMotion, at: 0.2)
        capture.recordWork(.followerUpdate, at: 0.3)
        capture.recordNativePhase(.idle, at: 0.4)
        capture.recordWork(.settlementReconciliation, at: 0.5)
        let report = capture.endCapture(at: 0.65)

        XCTAssertLessThanOrEqual(report.retainedEventCount, 3)
        XCTAssertEqual(report.droppedEventCount, 3)
        XCTAssertEqual(report.workCounts[.fractionalMotion]?.total, 1)
        XCTAssertEqual(report.workCounts[.followerUpdate]?.total, 1)
        XCTAssertEqual(report.workCounts[.settlementReconciliation]?.total, 1)
        XCTAssertEqual(
            report.events.map(\.sequence),
            report.events.map(\.sequence).sorted()
        )
    }

    func testMissingNativeBoundariesAreExplicitlyInconclusive() {
        var noIdle = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        noIdle.recordNativePhase(.decelerating, at: 1)
        let noIdleReport = noIdle.endCapture(at: 2)
        XCTAssertEqual(noIdleReport.outcome, .inconclusive(.nativeIdleNotObserved))

        var noDeceleration = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        noDeceleration.recordNativePhase(.tracking, at: 1)
        noDeceleration.recordNativePhase(.idle, at: 2)
        let noDecelerationReport = noDeceleration.endCapture(at: 2.3)
        XCTAssertEqual(
            noDecelerationReport.outcome,
            .inconclusive(.nativeDecelerationNotObserved)
        )
    }

    func testUnorderedAndEqualNativeBoundariesAreExplicitlyInconclusive() {
        var reversed = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        reversed.recordNativePhase(.decelerating, at: 2)
        reversed.recordNativePhase(.idle, at: 1)
        XCTAssertEqual(
            reversed.endCapture(at: 1.25).outcome,
            .inconclusive(.nativePhaseOrderInvalid)
        )

        var equal = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        equal.recordNativePhase(.decelerating, at: 2)
        equal.recordNativePhase(.idle, at: 2)
        XCTAssertEqual(
            equal.endCapture(at: 2.25).outcome,
            .inconclusive(.nativePhaseOrderInvalid)
        )
    }

    func testIncompletePostIdleAndInvalidCaptureEndNeverCapture() {
        var incomplete = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        incomplete.recordNativePhase(.decelerating, at: 1)
        incomplete.recordNativePhase(.idle, at: 2)
        XCTAssertEqual(
            incomplete.endCapture(at: 2.249).outcome,
            .inconclusive(.postIdleObservationIncomplete)
        )

        var invalidEnd = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        invalidEnd.recordNativePhase(.decelerating, at: 1)
        invalidEnd.recordNativePhase(.idle, at: 2)
        XCTAssertEqual(
            invalidEnd.endCapture(at: 1.5).outcome,
            .inconclusive(.invalidCaptureEnd)
        )
    }

    func testSyntheticGeometryReplayRetainsContinuityWithoutNativeClaim() {
        let result = HistoryScrollGeometryReplay.analyze(
            HistoryScrollSyntheticProtocolFixture.gentleRelease.samples
        )

        XCTAssertTrue(result.isSpatiallyContinuous)
        XCTAssertEqual(result.maximumStep, 18, accuracy: 0.000_001)
        XCTAssertFalse(result.representsNativeDeceleration)

        let discontinuous = HistoryScrollGeometryReplay.analyze([
            .init(timestamp: 0, offset: 0),
            .init(timestamp: 0.016, offset: 100),
        ])
        XCTAssertFalse(discontinuous.isSpatiallyContinuous)
        XCTAssertEqual(discontinuous.discontinuityCount, 1)
        XCTAssertFalse(discontinuous.representsNativeDeceleration)
    }

    func testFinishedCaptureIsStableAndDoesNotRecordLaterWork() {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.recordNativePhase(.decelerating, at: 0)
        capture.recordNativePhase(.idle, at: 1)
        let first = capture.endCapture(at: 1.25)
        capture.recordWork(.labelProjection, at: 1.3)
        let second = capture.endCapture(at: 2)

        XCTAssertEqual(first, second)
        XCTAssertTrue(capture.isFinished)
    }

    func testCircularStorageWrapsRepeatedlyAndBoundsGenerationAccounting() {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration(maxEvents: 7))
        for index in 0 ..< 10000 {
            capture.recordCoarseInputGeneration(index, at: Double(index))
        }
        let report = capture.endCapture(at: 10000)
        XCTAssertEqual(report.events.map(\.sequence), Array(9994 ... 10000))
        XCTAssertEqual(report.droppedEventCount, 9993)
        XCTAssertEqual(report.distinctCoarseInputGenerationCount, 7)
        XCTAssertEqual(report.workCounts[.coarseInputGeneration]?.total, 10000)
    }

    func testRawExportRetainsSeparateWorkBoundariesAndNativeTimestamps() throws {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.recordNativePhase(.decelerating, at: 1)
        capture.recordNativePhase(.idle, at: 2)
        capture.recordWork(.exactWindowFetch, at: 2.01)
        capture.recordWorkEnd(.exactWindowFetch, at: 2.02)
        capture.recordWork(.exactWindowProjection, at: 2.03)
        capture.recordWorkEnd(.exactWindowProjection, at: 2.04)
        XCTAssertNil(capture.report)
        let report = capture.endCapture(at: 2.25)
        let data = try XCTUnwrap(report.rawJSON.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try XCTUnwrap(object["events"] as? [[String: Any]])
        XCTAssertEqual(rows[2]["uptime"] as? Double, 2.01)
        XCTAssertEqual(rows[3]["workEnd"] as? String, "exactWindowFetch")
        XCTAssertEqual(rows[4]["workBegin"] as? String, "exactWindowProjection")
        XCTAssertEqual(report.workCounts[.exactWindowFetch]?.total, 1)
        capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        XCTAssertTrue(capture.events.isEmpty)
        XCTAssertNil(capture.report)
        XCTAssertEqual(capture.droppedEventCount, 0)
    }

    func testRawExportRetainsStructuredBoundariesAndCountersAfterTruncation() throws {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration(maxEvents: 3))
        capture.recordNativePhase(.decelerating, at: 1)
        capture.recordNativePhase(.idle, at: 2)
        capture.recordGeometry(offset: 1, at: 2.01)
        capture.recordWork(.exactWindowFetch, at: 2.02)
        capture.recordWorkEnd(.exactWindowFetch, at: 2.03)
        let report = capture.endCapture(at: 2.25)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(report.rawJSON.utf8)) as? [String: Any]
        )
        let outcome = try XCTUnwrap(object["outcome"] as? [String: Any])
        XCTAssertEqual(outcome["status"] as? String, "captured")
        let native = try XCTUnwrap(object["native"] as? [String: Any])
        XCTAssertEqual(native["decelerationStartUptime"] as? Double, 1)
        XCTAssertEqual(native["idleUptime"] as? Double, 2)
        XCTAssertEqual(native["captureEndUptime"] as? Double, 2.25)
        let phases = try XCTUnwrap(object["phases"] as? [[String: Any]])
        XCTAssertEqual(phases.map { $0["phase"] as? String }, [
            "nativeDecelerationTail", "idleBoundary", "postIdle",
        ])
        XCTAssertEqual(phases[0]["startUptime"] as? Double, 1.5)
        XCTAssertEqual(phases[2]["duration"] as? Double, 0.25)
        let counters = try XCTUnwrap(object["counters"] as? [String: Any])
        XCTAssertEqual(counters["droppedEventCount"] as? Int, 2)
        XCTAssertEqual(counters["retainedEventCount"] as? Int, 3)
        XCTAssertEqual(object["nativeDecelerationStartUptime"] as? Double, 1)
        XCTAssertEqual(object["nativeIdleUptime"] as? Double, 2)
    }

    func testRawExportContainsCaptureWallClockAnchorPairedWithBoundaryUptimes() throws {
        var capture = HistoryScrollDiagnosticCapture(configuration: enabledConfiguration())
        capture.beginCapture(at: 100, wallClockEpoch: 1_700_000_000)
        capture.recordGeometry(offset: 0, at: 100)
        capture.recordNativePhase(.decelerating, at: 100.1)
        capture.recordNativePhase(.idle, at: 100.6)
        let report = capture.endCapture(at: 100.85, wallClockEpoch: 1_700_000_000.85)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(report.rawJSON.utf8)) as? [String: Any]
        )
        let events = try XCTUnwrap(object["events"] as? [[String: Any]])
        XCTAssertEqual(events.first?["uptime"] as? Double, 100)
        XCTAssertEqual(object["captureStartUptime"] as? Double, 100)
        XCTAssertEqual(object["captureStartWallClockEpoch"] as? Double, 1_700_000_000)
        XCTAssertEqual(object["captureEndUptime"] as? Double, 100.85)
        XCTAssertEqual(object["captureEndWallClockEpoch"] as? Double, 1_700_000_000.85)
    }
}
