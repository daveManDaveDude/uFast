@testable import uFast
import XCTest

@MainActor
final class HistorySettledReconciliationTests: XCTestCase {
    func testSettlementIsScheduledAndPublishesExactWindowAfterSchedulerTurn() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: recorder
        )
        let window = makeWindow(offset: 0, fractionalStart: 0.125)

        let scheduleResult = coordinator.schedule(
            window: window,
            context: context
        )

        XCTAssertEqual(scheduleResult, .scheduled(generation: 1))
        XCTAssertTrue(source.requests.isEmpty)
        XCTAssertEqual(scheduler.pendingCount, 1)

        await scheduler.runNext()

        XCTAssertEqual(source.requests.map(\.identity), [window.settlementIdentity])
        XCTAssertEqual(publishedWindows, [window.settlementIdentity])
        XCTAssertEqual(
            recorder.events.map(\.outcome),
            [.scheduled, .started, .published]
        )
        XCTAssertTrue(recorder.events.allSatisfy { $0.window == window.settlementIdentity })
        XCTAssertTrue(recorder.events.allSatisfy { $0.requestGeneration == scheduleResult.generation })
    }

    func testDuplicateSettlementCoalescesForExactWindowAndGeneration() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: recorder
        )
        let window = makeWindow(offset: 0, fractionalStart: 0.25)

        let firstResult = coordinator.schedule(
            window: window,
            context: context
        )
        let duplicateResult = coordinator.schedule(
            window: window,
            context: context
        )

        XCTAssertEqual(firstResult, .scheduled(generation: 1))
        XCTAssertEqual(duplicateResult, .coalesced(generation: 1))
        XCTAssertEqual(scheduler.pendingCount, 1)
        XCTAssertEqual(recorder.events.map(\.outcome), [.scheduled, .coalesced])

        await scheduler.runNext()

        XCTAssertEqual(source.requests.count, 1)
        XCTAssertEqual(publishedWindows.count, 1)
    }

    func testNewestWindowSupersedesQueuedWindowAndStaleWorkCannotPublish() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: recorder
        )
        let first = makeWindow(offset: 0, fractionalStart: 0.1)
        let newest = makeWindow(offset: 1, fractionalStart: 0.4)

        coordinator.schedule(
            window: first,
            context: context
        )
        coordinator.schedule(
            window: newest,
            context: context
        )

        await scheduler.runNext()
        await scheduler.runNext()

        XCTAssertEqual(publishedWindows, [newest.settlementIdentity])
        XCTAssertEqual(source.requests.map(\.identity), [newest.settlementIdentity])
        XCTAssertEqual(
            recorder.events.map(\.outcome),
            [.scheduled, .superseded, .scheduled, .staleDiscarded, .started, .published]
        )
        XCTAssertEqual(recorder.events[3].window, first.settlementIdentity)
        XCTAssertEqual(recorder.events[3].requestGeneration, 1)
    }

    func testSameWindowInvalidationAdvancesGenerationAndSchedulesFreshReconciliation() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: recorder
        )
        let window = makeWindow(offset: 0, fractionalStart: 0.5)

        let firstResult = coordinator.schedule(
            window: window,
            context: context
        )
        await scheduler.runNext()

        let refreshedResult = coordinator.invalidateAndSchedule(
            window: window,
            context: context
        )
        XCTAssertEqual(firstResult, .scheduled(generation: 1))
        XCTAssertEqual(refreshedResult, .scheduled(generation: 2))
        XCTAssertEqual(scheduler.pendingCount, 1)

        await scheduler.runNext()

        XCTAssertEqual(source.requests.count, 2)
        XCTAssertEqual(publishedWindows, [window.settlementIdentity, window.settlementIdentity])
        XCTAssertEqual(recorder.events.filter { $0.outcome == .published }.count, 2)
        XCTAssertEqual(Set(recorder.events.filter { $0.outcome == .published }.map(\.requestGeneration)), [1, 2])
    }

    func testPostCompletionDuplicateIsAlreadyCompleted() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: SettlementEventRecorder()
        )
        let window = makeWindow(offset: 0, fractionalStart: 0.6)

        XCTAssertEqual(
            coordinator.schedule(window: window, context: context),
            .scheduled(generation: 1)
        )
        await scheduler.runNext()

        XCTAssertEqual(
            coordinator.schedule(window: window, context: context),
            .alreadyCompleted(generation: 1)
        )
        XCTAssertEqual(source.requests.count, 1)
        XCTAssertEqual(scheduler.pendingCount, 0)
    }

    func testInFlightSettlementIsSupersededAndCannotPublishAfterNewWindow() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = SuspendedSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        var published: [HistorySettlementWindowIdentity] = []
        let coordinator = HistorySettledReconciliationCoordinator(
            scheduler: scheduler,
            source: source,
            eventSink: { recorder.events.append($0) }
        )
        coordinator.onPublished = { projection, _ in
            published.append(projection.identity)
        }
        let oldWindow = makeWindow(offset: 0, fractionalStart: 0.15)
        let newestWindow = makeWindow(offset: 1, fractionalStart: 0.85)

        coordinator.schedule(window: oldWindow, context: context)
        let oldOperation = Task { @MainActor in
            await scheduler.runNext()
        }
        await source.waitForRequestCount(1)

        coordinator.schedule(window: newestWindow, context: context)
        source.resumeNext()
        await oldOperation.value

        let newestOperation = Task { @MainActor in
            await scheduler.runNext()
        }
        await source.waitForRequestCount(2)
        source.resumeNext()
        await newestOperation.value

        XCTAssertEqual(published, [newestWindow.settlementIdentity])
        XCTAssertEqual(
            recorder.events.map(\.outcome),
            [.scheduled, .started, .superseded, .scheduled, .staleDiscarded, .started, .published]
        )
        XCTAssertEqual(recorder.events[4].window, oldWindow.settlementIdentity)
        XCTAssertEqual(recorder.events[4].requestGeneration, 1)
    }

    func testMismatchedProjectionIdentityIsDiscarded() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        let coordinator = makeCoordinator(
            scheduler: scheduler,
            source: source,
            recorder: recorder
        )
        let requestedWindow = makeWindow(offset: 0, fractionalStart: 0.3)
        source.projectionWindow = makeWindow(offset: 1, fractionalStart: 0.3)

        coordinator.schedule(window: requestedWindow, context: context)
        await scheduler.runNext()

        XCTAssertTrue(publishedWindows.isEmpty)
        XCTAssertEqual(recorder.events.last?.outcome, .staleDiscarded)
    }

    func testFailedFetchRetainsLastCompletePublishedProjection() async {
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let recorder = SettlementEventRecorder()
        var published: [HistorySettlementWindowIdentity] = []
        let coordinator = HistorySettledReconciliationCoordinator(
            scheduler: scheduler,
            source: source,
            eventSink: { recorder.events.append($0) }
        )
        coordinator.onPublished = { projection, _ in
            published.append(projection.identity)
        }
        let first = makeWindow(offset: 0, fractionalStart: 0.2)
        let failing = makeWindow(offset: 1, fractionalStart: 0.7)

        coordinator.schedule(
            window: first,
            context: context
        )
        await scheduler.runNext()

        source.shouldFail = true
        coordinator.schedule(
            window: failing,
            context: context
        )
        await scheduler.runNext()

        XCTAssertEqual(published, [first.settlementIdentity])
        XCTAssertEqual(recorder.events.filter { $0.outcome == .failed }.map(\.window), [failing.settlementIdentity])
        XCTAssertEqual(recorder.events.filter { $0.outcome == .published }.count, 1)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "GMT") ?? .gmt
        return calendar
    }

    private var locale: Locale {
        Locale(identifier: "en_GB")
    }

    private var context: HistorySettlementProjectionContext {
        HistorySettlementProjectionContext(
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone,
            referenceNow: now,
            textResolver: .init()
        )
    }

    private var publishedWindows: [HistorySettlementWindowIdentity] = []

    private func makeCoordinator(
        scheduler: ManualHistorySettlementScheduler,
        source: RecordingSettledProjectionSource,
        recorder: SettlementEventRecorder
    ) -> HistorySettledReconciliationCoordinator {
        let coordinator = HistorySettledReconciliationCoordinator(
            scheduler: scheduler,
            source: source,
            eventSink: { recorder.events.append($0) }
        )
        coordinator.onPublished = { [weak self] projection, _ in
            self?.publishedWindows.append(projection.identity)
        }
        return coordinator
    }

    private func makeWindow(offset: Int, fractionalStart: Double) -> TemporalRibbonWindow {
        let selectedDay = calendar.startOfDay(for: now)
            .addingTimeInterval(TimeInterval(offset * 86400))
        let selectedDayInterval = DateInterval(start: selectedDay, duration: 86400)
        let intervalStart = selectedDay.addingTimeInterval(-3600)
            .addingTimeInterval(fractionalStart * 60)
        return TemporalRibbonWindow(
            selectedDay: selectedDay,
            selectedDayInterval: selectedDayInterval,
            interval: DateInterval(start: intervalStart, duration: 90000),
            midnightMarkers: [selectedDay]
        )
    }
}

@MainActor
private final class SettlementEventRecorder {
    var events: [HistorySettlementReconciliationEvent] = []
}

@MainActor
final class ManualHistorySettlementScheduler: HistorySettlementScheduler {
    private var operations: [@MainActor () async -> Void] = []

    var pendingCount: Int {
        operations.count
    }

    func schedule(_ operation: @escaping @MainActor () async -> Void) {
        operations.append(operation)
    }

    func runNext() async {
        let operation = operations.removeFirst()
        await operation()
    }
}

@MainActor
final class RecordingSettledProjectionSource: HistorySettledProjectionSource {
    enum SourceError: Error {
        case simulated
    }

    var requests: [HistorySettledProjectionRequest] = []
    var shouldFail = false
    var projectionWindow: TemporalRibbonWindow?

    func fetchSettledProjection(
        for request: HistorySettledProjectionRequest
    ) async throws -> HistorySettledProjection {
        requests.append(request)
        if shouldFail {
            throw SourceError.simulated
        }
        let data = HistoryDataSlice(
            window: request.window.interval,
            completedFasts: [],
            activeFast: nil,
            foods: [],
            drinks: [],
            settings: nil
        )
        return HistorySettledProjection(
            window: projectionWindow ?? request.window,
            data: data,
            presentation: HistoryPresentationSnapshot(
                window: request.window.interval,
                fastItems: [],
                events: []
            )
        )
    }
}

@MainActor
final class SuspendedSettledProjectionSource: HistorySettledProjectionSource {
    var requests: [HistorySettledProjectionRequest] = []
    private var pendingRequests: [HistorySettledProjectionRequest] = []
    private var continuations: [
        CheckedContinuation<HistorySettledProjection, Error>
    ] = []

    func fetchSettledProjection(
        for request: HistorySettledProjectionRequest
    ) async throws -> HistorySettledProjection {
        requests.append(request)
        pendingRequests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ expected: Int) async {
        for _ in 0 ..< 200 {
            if requests.count >= expected {
                return
            }
            await Task.yield()
        }
    }

    func resumeNext() {
        let continuation = continuations.removeFirst()
        let request = pendingRequests.removeFirst()
        continuation.resume(returning: HistorySettledProjection(
            window: request.window,
            data: HistoryDataSlice(
                window: request.window.interval,
                completedFasts: [],
                activeFast: nil,
                foods: [],
                drinks: [],
                settings: nil
            ),
            presentation: HistoryPresentationSnapshot(
                window: request.window.interval,
                fastItems: [],
                events: []
            )
        ))
    }
}
