import Foundation
import SwiftData
@testable import uFast
import XCTest

@MainActor
final class MNT012BDiagnosticOutcomeTests: XCTestCase {
    private enum FixtureError: Error {
        case requested
    }

    func testBootstrapFailureEmitsOneStoreOpenEvent() {
        let sink = RecordingDiagnosticEventSink()

        let result = PersistenceBootstrapResult.open(
            containerFactory: { throw FixtureError.requested },
            diagnosticSink: sink
        )

        guard case .unavailable = result else {
            return XCTFail("Expected unavailable bootstrap result")
        }
        XCTAssertEqual(sink.events.map(\.outcome), [.storeOpenFailed])
        XCTAssertNil(sink.events.first?.countBucket)
        XCTAssertNil(sink.events.first?.isRetry)
    }

    func testMigrationFailureEmitsOneTypedEventWithoutUnderlyingError() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-mnt012b-invalid-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "production.store")
        try Data("not a SwiftData store".utf8).write(to: storeURL)
        let sink = RecordingDiagnosticEventSink()

        let result = PersistenceBootstrapResult.open(
            containerFactory: {
                try PersistenceContainer.make(storeURL: storeURL, diagnosticSink: sink)
            },
            diagnosticSink: sink
        )

        guard case let .unavailable(failure) = result else {
            return XCTFail("Expected migration failure to remain unavailable")
        }
        XCTAssertFalse(failure.diagnosticDescription.isEmpty)
        XCTAssertEqual(sink.events.map(\.outcome), [.migrationFailed])
        let payload = try JSONEncoder().encode(sink.events[0])
        let payloadText = try XCTUnwrap(String(data: payload, encoding: .utf8))
        XCTAssertFalse(payloadText.contains("SwiftData"))
    }

    func testAuthorityConflictsEmitOneCountBucketedEventAtEachBoundary() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord())
        context.insert(AppSettingsRecord())
        context.insert(
            FastRecord(
                startDate: Date(timeIntervalSince1970: 1_800_000_000),
                goalAtStart: .default
            )
        )
        context.insert(
            FastRecord(
                startDate: Date(timeIntervalSince1970: 1_800_000_060),
                goalAtStart: .default
            )
        )
        try context.save()

        let settingsSink = RecordingDiagnosticEventSink()
        XCTAssertThrowsError(
            try SwiftDataSettingsStore(
                modelContext: context,
                diagnosticSink: settingsSink
            ).authoritativeRecord()
        )
        XCTAssertEqual(settingsSink.events.map(\.outcome), [.authorityConflict])
        XCTAssertEqual(settingsSink.events.first?.countBucket, .multiple)

        let activeSink = RecordingDiagnosticEventSink()
        XCTAssertThrowsError(
            try ActiveFastAuthority.fetch(in: context, diagnosticSink: activeSink)
        )
        XCTAssertEqual(activeSink.events.map(\.outcome), [.authorityConflict])
        XCTAssertEqual(activeSink.events.first?.countBucket, .multiple)
    }

    func testBootstrapSettingsCleanupFailureRollsBackWithoutCommandEvent() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord())
        context.insert(AppSettingsRecord())
        try context.save()
        let sink = RecordingDiagnosticEventSink()
        let store = SwiftDataSettingsStore(
            modelContext: context,
            simulateSaveFailure: true,
            diagnosticSink: sink
        )

        XCTAssertThrowsError(try store.prepareForUse())
        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 2)
        XCTAssertFalse(context.hasChanges)
    }

    func testTransactionFailureRecordsCommitThenRollbackAndDroppingSinkCannotChangeRecovery() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let recording = RecordingDiagnosticEventSink()
        let recordingRepository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true,
            diagnosticSink: recording
        )

        XCTAssertThrowsError(
            try recordingRepository.saveNewActiveFast(
                FastRecord(
                    startDate: Date(timeIntervalSince1970: 1_800_000_000),
                    goalAtStart: .default
                )
            )
        )
        XCTAssertEqual(
            recording.events.map(\.outcome),
            [.commitFailed, .rollbackApplied]
        )
        XCTAssertFalse(context.hasChanges)

        let failing = FailingDiagnosticEventSink()
        let failingRepository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true,
            diagnosticSink: failing
        )
        XCTAssertThrowsError(
            try failingRepository.saveNewActiveFast(
                FastRecord(
                    startDate: Date(timeIntervalSince1970: 1_800_000_060),
                    goalAtStart: .default
                )
            )
        )
        XCTAssertEqual(failing.attempts, 2)
        XCTAssertFalse(context.hasChanges)

        context.insert(AppSettingsRecord())
        XCTAssertNoThrow(try context.save())
    }

    func testSuccessfulAndCancelledCommandPathsRemainSilent() throws {
        let successfulContainer = try PersistenceContainer.make(inMemory: true)
        let successfulSink = RecordingDiagnosticEventSink()
        let successfulProjection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil },
            diagnosticSink: successfulSink
        )
        let successfulCommands = ApplicationCommands(
            modelContext: successfulContainer.mainContext,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: successfulProjection,
            diagnosticSink: successfulSink
        )

        XCTAssertNoThrow(try successfulCommands.startFast(goal: .default))
        XCTAssertTrue(successfulSink.events.isEmpty)

        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sink = RecordingDiagnosticEventSink()
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil },
            diagnosticSink: sink
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: projection,
            diagnosticSink: sink
        )

        let fast = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_799_996_400),
            goalAtStart: .default
        )
        context.insert(fast)
        try context.save()
        let draft = FoodEntryDraft(
            description: "Lunch",
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertThrowsError(
            try commands.saveFood(
                draft,
                replacing: nil,
                goal: .default,
                endingActiveFast: false
            )
        )
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testPostCommitProjectionFailureEmitsOnceWithoutChangingCommittedResult() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sink = RecordingDiagnosticEventSink()
        var order: [String] = []
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in
                order.append("projection")
                throw FixtureError.requested
            },
            activityEffect: { _ in
                order.append("activity")
                return nil
            },
            diagnosticSink: sink
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: projection,
            diagnosticSink: sink
        )

        let outcome = try commands.startFast(goal: .default)
        await projection.waitForPendingEffects()

        XCTAssertEqual(outcome.projectionEnqueued, true)
        XCTAssertEqual(order, ["projection", "activity"])
        XCTAssertEqual(sink.events.map(\.outcome), [.postCommitProjectionFailed])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
        XCTAssertFalse(context.hasChanges)
    }
}

private final class FailingDiagnosticEventSink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var recordCount = 0

    var attempts: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordCount
    }

    func record(_: DiagnosticEvent) {
        lock.lock()
        recordCount += 1
        lock.unlock()
    }
}
