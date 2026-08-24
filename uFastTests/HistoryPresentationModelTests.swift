import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistoryPresentationModelTests: XCTestCase {
    func testFailedInitialLoadWaitsForExplicitRetryAfterOrdinaryReload() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let model = makeModel(
            container: container,
            clock: clock,
            calendar: utcCalendar,
            gate: gate
        )

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        await gate.failRequest(at: 0)
        await waitUntil { !model.motionInitialLoading }

        XCTAssertNil(model.motionSnapshot)
        XCTAssertTrue(model.reloadHistory())
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        let requestCountAfterReload = await gate.requestCount()
        XCTAssertEqual(requestCountAfterReload, 1)
        XCTAssertNil(model.motionSnapshot)

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(2)
        await gate.resumeRequest(at: 1)
        await waitUntil { model.motionSnapshot != nil && !model.motionInitialLoading }

        XCTAssertNotNil(model.motionSnapshot)
    }

    func testReplacingInitialLoadCancelsObsoleteTaskAndKeepsNewestGeneration() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let calendar = utcCalendar
        let model = HistoryPresentationModel(
            modelContext: container.mainContext,
            clock: clock,
            calendar: calendar,
            locale: Locale(identifier: "en_GB"),
            timeZone: .gmt,
            loadChunk: { coverage, calendar, _, _ in
                try await gate.load(coverage: coverage, calendar: calendar)
            },
            mergeChunks: { chunks, window in
                SwiftDataHistoryDataProvider.mergeMotionChunks(chunks, window: window)
            }
        )
        let first = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: now))
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: -20, to: now))

        XCTAssertFalse(model.ensureMotionRunway(around: first))
        await gate.waitForRequestCount(1)
        XCTAssertFalse(model.ensureMotionRunway(around: second))
        await gate.waitForRequestCount(2)

        await gate.resumeRequest(at: 0)
        await gate.resumeRequest(at: 1)
        await waitUntil { model.motionSnapshot != nil && !model.motionInitialLoading }

        XCTAssertEqual(model.motionSnapshot?.coverage.contains(second, calendar: calendar), true)
        XCTAssertNotEqual(model.motionSnapshot?.generation, 1)
        XCTAssertFalse(model.motionInitialLoading)
    }

    func testCancellingOutstandingTasksPreventsACompletedLoaderFromPublishing() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let calendar = utcCalendar
        let model = HistoryPresentationModel(
            modelContext: container.mainContext,
            clock: clock,
            calendar: calendar,
            timeZone: .gmt,
            loadChunk: { coverage, calendar, _, _ in
                try await gate.load(coverage: coverage, calendar: calendar)
            }
        )

        XCTAssertFalse(model.ensureMotionRunway(around: now))
        await gate.waitForRequestCount(1)
        model.cancelOutstandingTasks()
        await gate.resumeRequest(at: 0)
        await Task.yield()

        XCTAssertNil(model.motionSnapshot)
        XCTAssertFalse(model.motionInitialLoading)
    }

    func testReplacingPrefetchCancelsObsoleteExtensionAndIgnoresStaleResult() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let calendar = utcCalendar
        let model = makeModel(
            container: container, clock: clock, calendar: calendar, gate: gate
        )
        let coverage = seedMotion(on: model, now: now, calendar: calendar)

        model.requestMotionExtension(.preceding, around: coverage.firstDay)
        await gate.waitForRequestCount(1)
        model.cancelOutstandingTasks()
        XCTAssertTrue(model.extensionTasks.isEmpty)

        model.requestMotionExtension(.preceding, around: coverage.firstDay)
        await gate.waitForRequestCount(2)
        await gate.failRequest(at: 0)
        await Task.yield()

        XCTAssertTrue(model.motionFailedEdges.isEmpty)
        XCTAssertNotNil(model.extensionTasks[.preceding])

        await gate.resumeRequest(at: 1)
        await waitUntil { model.extensionTasks[.preceding] == nil }
        XCTAssertTrue(model.motionFailedEdges.isEmpty)
        XCTAssertLessThan(model.motionSnapshot?.coverage.firstDay ?? now, coverage.firstDay)
    }

    func testReplacingAndCancellingRefreshIgnoresStaleSuccessAndError() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let calendar = utcCalendar
        let model = makeModel(
            container: container, clock: clock, calendar: calendar, gate: gate
        )
        _ = seedMotion(on: model, now: now, calendar: calendar)
        let original = try XCTUnwrap(model.motionSnapshot)

        model.refreshLoadedMotionChunks()
        await gate.waitForRequestCount(1)
        model.refreshLoadedMotionChunks()
        await gate.waitForRequestCount(2)
        let replacement = try XCTUnwrap(model.motionSnapshot)
        XCTAssertNotEqual(replacement.generation, original.generation)
        XCTAssertNotNil(model.refreshTask)

        await gate.resumeRequest(at: 0)
        await Task.yield()
        XCTAssertEqual(model.motionSnapshot, replacement)
        XCTAssertNotNil(model.refreshTask)

        await gate.resumeRequest(at: 1)
        await waitUntil { model.refreshTask == nil }
        XCTAssertNotEqual(model.motionSnapshot, replacement)
        let refreshed = try XCTUnwrap(model.motionSnapshot)

        model.refreshLoadedMotionChunks()
        await gate.waitForRequestCount(3)
        model.cancelOutstandingTasks()
        XCTAssertNil(model.refreshTask)
        await gate.failRequest(at: 2)
        await Task.yield()

        XCTAssertEqual(model.motionSnapshot?.presentation, refreshed.presentation)
        XCTAssertTrue(model.motionFailedEdges.isEmpty)
    }

    func testProjectionReplacementCancelsEveryObsoleteTaskHandle() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = FixedAppClock(now: now)
        let gate = DeferredHistoryChunkGate()
        let model = makeModel(
            container: container, clock: clock, calendar: utcCalendar, gate: gate
        )
        let initialProbe = CancellationProbe()
        let extensionProbe = CancellationProbe()
        let refreshProbe = CancellationProbe()
        model.initialTask = cancellationTask(probe: initialProbe)
        model.extensionTasks[.preceding] = cancellationTask(probe: extensionProbe)
        model.refreshTask = cancellationTask(probe: refreshProbe)
        let previousGeneration = model.motionGeneration

        XCTAssertTrue(model.refreshHistoryAfterCommittedMutation())
        await gate.waitForRequestCount(1)
        await initialProbe.waitUntilCancelled()
        await extensionProbe.waitUntilCancelled()
        await refreshProbe.waitUntilCancelled()

        XCTAssertGreaterThan(model.motionGeneration, previousGeneration)
        XCTAssertTrue(model.extensionTasks.isEmpty)
        XCTAssertNil(model.refreshTask)
        XCTAssertNotNil(model.initialTask)
        model.cancelOutstandingTasks()
    }

    private func makeModel(
        container: ModelContainer,
        clock: FixedAppClock,
        calendar: Calendar,
        gate: DeferredHistoryChunkGate
    ) -> HistoryPresentationModel {
        HistoryPresentationModel(
            modelContext: container.mainContext,
            clock: clock,
            calendar: calendar,
            locale: Locale(identifier: "en_GB"),
            timeZone: .gmt,
            loadChunk: { coverage, calendar, _, _ in
                try await gate.load(coverage: coverage, calendar: calendar)
            },
            mergeChunks: { chunks, window in
                SwiftDataHistoryDataProvider.mergeMotionChunks(chunks, window: window)
            }
        )
    }

    private func seedMotion(
        on model: HistoryPresentationModel,
        now: Date,
        calendar: Calendar
    ) -> HistoryMotionCoverage {
        let firstDay = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        let coverage = HistoryMotionCoverage(firstDay: firstDay, lastDay: now, calendar: calendar)
        let window = coverage.visualWindow(calendar: calendar)
            ?? DateInterval(start: firstDay, duration: 86400)
        let presentation = HistoryMotionPresentation(window: window, intervals: [], events: [])
        let chunk = HistoryMotionChunk(coverage: coverage, presentation: presentation)
        model.referenceNow = now
        model.selectedDate = now
        model.motionChunks = [chunk]
        model.motionSnapshot = HistoryMotionSnapshot(
            coverage: coverage,
            calendar: calendar,
            generation: 7,
            presentation: presentation
        )
        model.motionGeneration = 7
        return coverage
    }

    private func cancellationTask(probe: CancellationProbe) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
            } catch {
                await probe.markCancelled()
            }
        }
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

private actor DeferredHistoryChunkGate {
    private var requests: [HistoryMotionCoverage] = []
    private var continuations: [CheckedContinuation<HistoryMotionChunk, Error>?] = []

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

    func requestCount() -> Int {
        requests.count
    }

    func resumeRequest(at index: Int) {
        guard index < continuations.count, let continuation = continuations[index] else { return }
        let coverage = requests[index]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let window = coverage.visualWindow(calendar: calendar)
            ?? DateInterval(start: coverage.firstDay, duration: 86400)
        let presentation = HistoryMotionPresentation(window: window, intervals: [], events: [])
        continuation.resume(returning: HistoryMotionChunk(
            coverage: coverage, presentation: presentation
        ))
        continuations[index] = nil
    }

    func failRequest(at index: Int) {
        guard index < continuations.count, let continuation = continuations[index] else { return }
        continuation.resume(throwing: HistoryPresentationModelTestError.failed)
        continuations[index] = nil
    }
}

private actor CancellationProbe {
    private var cancelled = false

    func markCancelled() {
        cancelled = true
    }

    func waitUntilCancelled() async {
        while !cancelled {
            await Task.yield()
        }
    }
}

private enum HistoryPresentationModelTestError: Error, Sendable {
    case failed
}
