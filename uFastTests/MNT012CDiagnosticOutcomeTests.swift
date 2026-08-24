import Foundation
import SwiftData
@testable import uFast
import XCTest

@MainActor
final class MNT012CDiagnosticOutcomeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testHistoryInitialFailureEmitsOnceAndRetryIsMarkedWithoutChangingState() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let sink = RecordingDiagnosticEventSink()
        let gate = HistoryDiagnosticChunkGate(outcomes: [.failure, .failure])
        let model = makeHistoryModel(
            container: container,
            sink: sink,
            gate: gate
        )

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        await gate.completeRequest(at: 0)
        await waitUntil { !model.motionInitialLoading }

        XCTAssertEqual(sink.events.count, 1)
        XCTAssertEqual(sink.events[0].subsystem, .history)
        XCTAssertEqual(sink.events[0].outcome, .initialLoadFailed)
        XCTAssertEqual(sink.events[0].severity, .error)
        XCTAssertEqual(sink.events[0].isRetry, false)
        XCTAssertNil(sink.events[0].countBucket)
        XCTAssertNil(sink.events[0].isForeground)
        XCTAssertNil(model.motionSnapshot)

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(2)
        await gate.completeRequest(at: 1)
        await waitUntil { !model.motionInitialLoading }

        XCTAssertEqual(sink.events.count, 2)
        XCTAssertEqual(sink.events[1].outcome, .initialLoadFailed)
        XCTAssertEqual(sink.events[1].isRetry, true)
        XCTAssertNil(model.motionSnapshot)
    }

    func testHistoryExtensionFailureEmitsOncePerAttemptAndRetryIsMarked() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let sink = RecordingDiagnosticEventSink()
        let gate = HistoryDiagnosticChunkGate(outcomes: [.failure, .failure])
        let model = makeHistoryModel(container: container, sink: sink, gate: gate)
        let coverage = seedMotion(on: model)

        model.requestMotionExtension(.preceding, around: coverage.firstDay)
        await gate.waitForRequestCount(1)
        await gate.completeRequest(at: 0)
        await waitUntil { model.extensionTasks[.preceding] == nil }

        XCTAssertEqual(sink.events.count, 1)
        XCTAssertEqual(sink.events[0].outcome, .extensionLoadFailed)
        XCTAssertEqual(sink.events[0].isRetry, false)
        XCTAssertTrue(model.motionFailedEdges.contains(.preceding))

        model.requestMotionExtension(.preceding, around: coverage.firstDay)
        await gate.waitForRequestCount(2)
        await gate.completeRequest(at: 1)
        await waitUntil { model.extensionTasks[.preceding] == nil }

        XCTAssertEqual(sink.events.count, 2)
        XCTAssertEqual(sink.events[1].outcome, .extensionLoadFailed)
        XCTAssertEqual(sink.events[1].isRetry, true)
        XCTAssertTrue(model.motionFailedEdges.contains(.preceding))
    }

    func testCancelledInitialLoadAndStaleReplacementFailureEmitNothing() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let sink = RecordingDiagnosticEventSink()
        let gate = HistoryDiagnosticChunkGate(outcomes: [.failure, .failure])
        let model = makeHistoryModel(container: container, sink: sink, gate: gate)

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        model.cancelOutstandingTasks()
        await gate.completeRequest(at: 0)
        await Task.yield()
        XCTAssertTrue(sink.events.isEmpty)

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(2)
        model.cancelOutstandingTasks()
        await gate.completeRequest(at: 1)
        await Task.yield()
        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertNil(model.motionSnapshot)
    }

    func testSuccessfulAndEmptyHistoryLoadsRemainSilent() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let sink = RecordingDiagnosticEventSink()
        let gate = HistoryDiagnosticChunkGate(outcomes: [.success])
        let model = makeHistoryModel(container: container, sink: sink, gate: gate)

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        await gate.completeRequest(at: 0)
        await waitUntil { model.motionSnapshot != nil && !model.motionInitialLoading }

        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertTrue(model.motionSnapshot?.presentation.intervals.isEmpty == true)
        XCTAssertTrue(model.motionSnapshot?.presentation.events.isEmpty == true)
    }

    func testLiveActivityFailuresUseExactTypedEventsAndSuccessfulPathsStaySilent() async {
        let sourceBox = LiveActivitySourceBox(value: source())
        let unavailableSink = RecordingDiagnosticEventSink()
        let unavailable = makeCoordinator(
            sourceBox: sourceBox,
            client: DeterministicLiveActivityClient(availability: .disabled),
            sink: unavailableSink
        )

        let unavailableResult = await unavailable.show()
        XCTAssertEqual(unavailableResult, .unavailable(.disabled))
        XCTAssertEqual(unavailableSink.events.count, 1)
        XCTAssertEqual(unavailableSink.events[0].subsystem, .liveActivity)
        XCTAssertEqual(unavailableSink.events[0].outcome, .unavailable)
        XCTAssertEqual(unavailableSink.events[0].isForeground, false)
        XCTAssertNil(unavailableSink.events[0].isRetry)

        let requestSink = RecordingDiagnosticEventSink()
        let requestClient = DeterministicLiveActivityClient()
        requestClient.failRequests = true
        let requestCoordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: requestClient,
            sink: requestSink
        )
        let firstRequestResult = await requestCoordinator.show()
        XCTAssertEqual(firstRequestResult, .requestFailed)
        XCTAssertEqual(requestSink.events.map(\.outcome), [.requestFailed])
        XCTAssertEqual(requestSink.events[0].isRetry, false)
        XCTAssertEqual(requestSink.events[0].isForeground, false)

        let retryRequestResult = await requestCoordinator.show()
        XCTAssertEqual(retryRequestResult, .requestFailed)
        XCTAssertEqual(requestSink.events.map(\.outcome), [.requestFailed, .requestFailed])
        XCTAssertEqual(requestSink.events[1].isRetry, true)
        XCTAssertEqual(requestSink.events[1].isForeground, false)

        let successfulSink = RecordingDiagnosticEventSink()
        let successfulClient = DeterministicLiveActivityClient()
        let successfulCoordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: successfulClient,
            sink: successfulSink
        )
        let successfulResult = await successfulCoordinator.show()
        XCTAssertEqual(successfulResult, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertTrue(successfulSink.events.isEmpty)
    }

    func testLiveActivityAuthorityUpdateAndEndFailuresAreIsolated() async {
        await assertAuthorityConflictOutcome()
        await assertUpdateFailureOutcome()
        await assertEndFailureRetryOutcome()
    }

    func testStaleUnavailableRequestDoesNotEmitDiagnostic() async {
        let sourceBox = LiveActivitySourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.holdRequests = true
        let sink = RecordingDiagnosticEventSink()
        let coordinator = makeCoordinator(sourceBox: sourceBox, client: client, sink: sink)

        let showTask = Task { await coordinator.show() }
        await waitUntil { client.requestHasStarted }
        client.availability = .disabled

        let endResult = await coordinator.didCommitFastEndOrDeletion()
        XCTAssertEqual(endResult, .hidden)
        client.releaseHeldRequest()

        let showResult = await showTask.value
        XCTAssertEqual(showResult, .unavailable(.disabled))
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testStaleUpdateFailureDoesNotEmitDiagnostic() async {
        let sourceBox = LiveActivitySourceBox(value: source())
        let baseClient = DeterministicLiveActivityClient()
        let client = HeldUpdateLiveActivityClient(base: baseClient)
        let sink = RecordingDiagnosticEventSink()
        let coordinator = makeCoordinator(sourceBox: sourceBox, client: client, sink: sink)
        baseClient.seed(
            activityRecord(id: "activity", source: source(), generatedAt: now.addingTimeInterval(-60))
        )
        baseClient.failUpdates = true

        let reconcileTask = Task { await coordinator.reconcile() }
        await waitUntil { client.updateHasStarted }

        let endResult = await coordinator.didCommitFastEndOrDeletion()
        XCTAssertEqual(endResult, .hidden)
        client.releaseHeldUpdate()

        let reconcileResult = await reconcileTask.value
        XCTAssertEqual(reconcileResult, .reconciled)
        XCTAssertTrue(sink.events.isEmpty)
    }

    func testFailingDiagnosticSinkCannotChangeHistoryOrLiveActivityOutcomes() async throws {
        let historySink = FailingDiagnosticEventSink()
        let container = try PersistenceContainer.make(inMemory: true)
        let gate = HistoryDiagnosticChunkGate(outcomes: [.failure])
        let model = makeHistoryModel(container: container, sink: historySink, gate: gate)
        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        await gate.completeRequest(at: 0)
        await waitUntil { !model.motionInitialLoading }
        XCTAssertEqual(historySink.attempts, 1)
        XCTAssertNil(model.motionSnapshot)

        let sourceBox = LiveActivitySourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.failRequests = true
        let activity = makeCoordinator(sourceBox: sourceBox, client: client, sink: historySink)
        let activityResult = await activity.show()
        XCTAssertEqual(activityResult, .requestFailed)
        XCTAssertEqual(historySink.attempts, 2)
    }

    private func makeHistoryModel(
        container: ModelContainer,
        sink: any DiagnosticEventSink,
        gate: HistoryDiagnosticChunkGate
    ) -> HistoryPresentationModel {
        HistoryPresentationModel(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_GB"),
            timeZone: .gmt,
            diagnosticSink: sink,
            loadChunk: { coverage, calendar, _, _ in
                try await gate.load(coverage: coverage, calendar: calendar)
            }
        )
    }

    private func seedMotion(on model: HistoryPresentationModel) -> HistoryMotionCoverage {
        let firstDay = utcCalendar.date(byAdding: .day, value: -2, to: now) ?? now
        let coverage = HistoryMotionCoverage(firstDay: firstDay, lastDay: now, calendar: utcCalendar)
        let window = coverage.visualWindow(calendar: utcCalendar)
            ?? DateInterval(start: firstDay, duration: 86400)
        let presentation = HistoryMotionPresentation(window: window, intervals: [], events: [])
        let chunk = HistoryMotionChunk(coverage: coverage, presentation: presentation)
        model.motionChunks = [chunk]
        model.motionSnapshot = HistoryMotionSnapshot(
            coverage: coverage,
            calendar: utcCalendar,
            generation: 7,
            presentation: presentation
        )
        model.motionGeneration = 7
        return coverage
    }

    private func makeCoordinator(
        sourceBox: LiveActivitySourceBox,
        client: any LiveActivityClient,
        sink: any DiagnosticEventSink
    ) -> ActiveFastLiveActivityCoordinator {
        ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: InMemoryLiveActivityLifecycleStore(),
            resolveActiveFast: { sourceBox.value },
            diagnosticSink: sink
        )
    }

    private func source() -> ActiveFastActivitySource {
        let start = now.addingTimeInterval(-6 * 60 * 60)
        return ActiveFastActivitySource(
            activeRecordIdentifier: UUID(uuidString: "10500000-0000-0000-0000-000000000002") ?? UUID(),
            startDate: start,
            targetDate: start.addingTimeInterval(12 * 60 * 60),
            goalHours: 12
        )
    }

    private func activityRecord(
        id: String,
        source: ActiveFastActivitySource,
        generatedAt: Date
    ) -> LiveActivityRecord {
        LiveActivityRecord(
            id: id,
            activeRecordIdentifier: source.activeRecordIdentifier,
            state: .active,
            contentState: .init(source: source, generatedAt: generatedAt)
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
}

@MainActor
private extension MNT012CDiagnosticOutcomeTests {
    func assertAuthorityConflictOutcome() async {
        let sink = RecordingDiagnosticEventSink()
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: DeterministicLiveActivityClient(),
            lifecycleStore: InMemoryLiveActivityLifecycleStore(),
            resolveActiveFast: {
                throw ActiveFastIntegrityError.multipleActiveFasts(count: 2)
            },
            diagnosticSink: sink
        )
        let result = await coordinator.reconcile()
        XCTAssertEqual(result, .reconciled)
        XCTAssertEqual(sink.events.map(\.outcome), [.authorityConflict])
        XCTAssertEqual(sink.events[0].countBucket, .multiple)
    }

    func assertUpdateFailureOutcome() async {
        let sink = RecordingDiagnosticEventSink()
        let client = DeterministicLiveActivityClient()
        let source = source()
        client.seed(activityRecord(id: "activity", source: source, generatedAt: now.addingTimeInterval(-60)))
        client.failUpdates = true
        let coordinator = makeCoordinator(
            sourceBox: LiveActivitySourceBox(value: source),
            client: client,
            sink: sink
        )
        let result = await coordinator.reconcile()
        XCTAssertEqual(result, .reconciled)
        XCTAssertEqual(sink.events.map(\.outcome), [.updateFailed])
        XCTAssertEqual(sink.events[0].isRetry, false)
        XCTAssertEqual(sink.events[0].isForeground, false)
    }

    func assertEndFailureRetryOutcome() async {
        let sink = RecordingDiagnosticEventSink()
        let client = DeterministicLiveActivityClient()
        let source = source()
        client.seed(activityRecord(id: "activity", source: source, generatedAt: now))
        client.failEnds = true
        let coordinator = makeCoordinator(
            sourceBox: LiveActivitySourceBox(value: source),
            client: client,
            sink: sink
        )
        let firstResult = await coordinator.hide()
        XCTAssertEqual(firstResult, .hideFailed)
        XCTAssertEqual(sink.events.map(\.outcome), [.endFailed])
        XCTAssertEqual(sink.events[0].isRetry, false)
        XCTAssertEqual(sink.events[0].isForeground, false)

        let retryResult = await coordinator.hide()
        XCTAssertEqual(retryResult, .hideFailed)
        XCTAssertEqual(sink.events.map(\.outcome), [.endFailed, .endFailed])
        XCTAssertEqual(sink.events[1].isRetry, true)
        XCTAssertEqual(sink.events[1].isForeground, false)
    }
}

@MainActor
private final class LiveActivitySourceBox {
    var value: ActiveFastActivitySource?

    init(value: ActiveFastActivitySource?) {
        self.value = value
    }
}

private actor HistoryDiagnosticChunkGate {
    enum Outcome: Equatable, Sendable {
        case success
        case failure
    }

    private let outcomes: [Outcome]
    private var requests: [HistoryMotionCoverage] = []
    private var continuations: [CheckedContinuation<HistoryMotionChunk, Error>?] = []

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func load(coverage: HistoryMotionCoverage, calendar _: Calendar) async throws -> HistoryMotionChunk {
        let index = requests.count
        requests.append(coverage)
        continuations.append(nil)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[index] = continuation
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await Task.yield()
        }
    }

    func completeRequest(at index: Int) {
        guard index < continuations.count, let continuation = continuations[index] else { return }
        if outcomes[index] == .failure {
            continuation.resume(throwing: HistoryDiagnosticChunkError.failed)
        } else {
            let coverage = requests[index]
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            let window = coverage.visualWindow(calendar: calendar)
                ?? DateInterval(start: coverage.firstDay, duration: 86400)
            continuation.resume(returning: HistoryMotionChunk(
                coverage: coverage,
                presentation: HistoryMotionPresentation(window: window, intervals: [], events: [])
            ))
        }
        continuations[index] = nil
    }
}

private enum HistoryDiagnosticChunkError: Error, Sendable {
    case failed
}

private final class FailingDiagnosticEventSink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var attempts: Int {
        lock.withLock { count }
    }

    func record(_: DiagnosticEvent) {
        lock.withLock { count += 1 }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
