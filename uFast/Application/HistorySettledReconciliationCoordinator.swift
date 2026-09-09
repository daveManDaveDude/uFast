import Foundation
import SwiftData

/// The exact identity of a settled History window.  The interval and selected
/// local day are deliberately kept separate: a fractional window can retain
/// the same day while its visible bounds change.
struct HistorySettlementWindowIdentity: Equatable, Sendable {
    let intervalStart: Date
    let intervalEnd: Date
    let selectedLocalDay: Date

    init(window: TemporalRibbonWindow) {
        intervalStart = window.interval.start
        intervalEnd = window.interval.end
        selectedLocalDay = window.selectedDay
    }
}

extension TemporalRibbonWindow {
    var settlementIdentity: HistorySettlementWindowIdentity {
        HistorySettlementWindowIdentity(window: self)
    }
}

enum HistorySettlementReconciliationOutcome: Equatable, Sendable {
    case scheduled
    case started
    case coalesced
    case superseded
    case failed
    case staleDiscarded
    case published
}

enum HistorySettlementScheduleResult: Equatable, Sendable {
    case scheduled(generation: Int)
    case coalesced(generation: Int)
    case alreadyCompleted(generation: Int)

    var generation: Int {
        switch self {
        case let .scheduled(generation), let .coalesced(generation),
             let .alreadyCompleted(generation):
            generation
        }
    }

    var isPending: Bool {
        switch self {
        case .scheduled, .coalesced:
            true
        case .alreadyCompleted:
            false
        }
    }
}

/// Test-only observability for the settlement boundary.  Production wiring
/// uses the no-op default; no event is persisted, exported or emitted to a
/// product diagnostic sink.
struct HistorySettlementReconciliationEvent: Equatable, Sendable {
    let outcome: HistorySettlementReconciliationOutcome
    let window: HistorySettlementWindowIdentity
    let requestGeneration: Int
}

typealias HistorySettlementEventSink = @MainActor (
    HistorySettlementReconciliationEvent
) -> Void

/// Opt-in UI-test observability for the final publication boundary.  Normal
/// launches never read or mutate this probe.
@MainActor
enum HistorySettlementPublicationProbe {
    private static var publishedToken = "none"

    static var viewToken: String? {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return nil
        }
        return publishedToken
    }

    static func record(_ request: HistorySettledProjectionRequest) {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return
        }
        let identity = request.identity
        publishedToken = "generation=\(request.generation);"
            + "intervalStart=\(identity.intervalStart.timeIntervalSince1970);"
            + "intervalEnd=\(identity.intervalEnd.timeIntervalSince1970);"
            + "selectedLocalDay=\(identity.selectedLocalDay.timeIntervalSince1970)"
    }
}

@MainActor
protocol HistorySettlementScheduler {
    func schedule(_ operation: @escaping @MainActor () async -> Void)
}

/// Defers work by at least one main-actor turn.  The scheduler does not own a
/// SwiftData context and never moves projection work off the main actor.
@MainActor
struct MainActorHistorySettlementScheduler: HistorySettlementScheduler {
    func schedule(_ operation: @escaping @MainActor () async -> Void) {
        Task { @MainActor in
            await Task.yield()
            await operation()
        }
    }
}

struct HistorySettledProjectionRequest {
    let window: TemporalRibbonWindow
    let generation: Int
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
    let referenceNow: Date
    let textResolver: AppTextResolver

    var identity: HistorySettlementWindowIdentity {
        window.settlementIdentity
    }
}

struct HistorySettlementProjectionContext {
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
    let referenceNow: Date
    let textResolver: AppTextResolver
}

struct HistorySettledProjection {
    let window: TemporalRibbonWindow
    let data: HistoryDataSlice
    let presentation: HistoryPresentationSnapshot

    var identity: HistorySettlementWindowIdentity {
        window.settlementIdentity
    }
}

@MainActor
protocol HistorySettledProjectionSource {
    func fetchSettledProjection(
        for request: HistorySettledProjectionRequest
    ) async throws -> HistorySettledProjection
}

/// SwiftData remains on the existing main-actor context boundary.  The async
/// API is a scheduling boundary, not permission to perform SwiftData work on a
/// detached task or an unowned background context.
@MainActor
final class SwiftDataHistorySettledProjectionSource: HistorySettledProjectionSource {
    private let source: SwiftDataHistoryProjectionDataSource

    init(modelContext: ModelContext) {
        source = SwiftDataHistoryProjectionDataSource(modelContext: modelContext)
    }

    func fetchSettledProjection(
        for request: HistorySettledProjectionRequest
    ) async throws -> HistorySettledProjection {
        let data = try source.fetchSettled(window: request.window.interval)
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: request.locale,
            calendar: request.calendar,
            timeZone: request.timeZone,
            referenceNow: request.referenceNow,
            textResolver: request.textResolver
        )
        return HistorySettledProjection(
            window: request.window,
            data: data,
            presentation: presentation
        )
    }
}

/// Main-actor boundary for exact settled-window reconciliation.  Only one
/// request identity can be current.  Queued and in-flight work remains safe
/// when its source is non-cooperative because every completion rechecks both
/// generation and exact window identity before publication.
@MainActor
final class HistorySettledReconciliationCoordinator {
    private struct Request {
        let window: TemporalRibbonWindow
        let generation: Int
        let locale: Locale
        let calendar: Calendar
        let timeZone: TimeZone
        let referenceNow: Date
        let textResolver: AppTextResolver

        var identity: HistorySettlementWindowIdentity {
            window.settlementIdentity
        }

        var sourceRequest: HistorySettledProjectionRequest {
            HistorySettledProjectionRequest(
                window: window,
                generation: generation,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: referenceNow,
                textResolver: textResolver
            )
        }
    }

    private enum RequestState: Equatable {
        case scheduled
        case started
        case completed
    }

    private let scheduler: any HistorySettlementScheduler
    private let source: any HistorySettledProjectionSource
    private let eventSink: HistorySettlementEventSink
    private(set) var generation = 0
    private var currentRequest: Request?
    private var currentState: RequestState?

    var onPublished: @MainActor (HistorySettledProjection, HistorySettledProjectionRequest) -> Void = { _, _ in }
    var onFailed: @MainActor (HistorySettledProjectionRequest) -> Void = { _ in }

    init(
        scheduler: any HistorySettlementScheduler = MainActorHistorySettlementScheduler(),
        source: any HistorySettledProjectionSource,
        eventSink: @escaping HistorySettlementEventSink = { _ in }
    ) {
        self.scheduler = scheduler
        self.source = source
        self.eventSink = eventSink
    }

    /// Enqueues a settlement unless the exact window is already current.  A
    /// duplicate therefore keeps the same request generation and performs no
    /// second fetch/projection.
    @discardableResult
    func schedule(
        window: TemporalRibbonWindow,
        context: HistorySettlementProjectionContext
    ) -> HistorySettlementScheduleResult {
        if let currentRequest, currentRequest.identity == window.settlementIdentity {
            if currentState == .completed {
                return .alreadyCompleted(generation: currentRequest.generation)
            }
            record(.coalesced, for: currentRequest)
            return .coalesced(generation: currentRequest.generation)
        }

        supersedeCurrentIfNeeded()
        generation += 1
        let requestGeneration = enqueue(
            window: window,
            context: context
        )
        return .scheduled(generation: requestGeneration)
    }

    /// A committed mutation or environment invalidation must advance the
    /// generation even when the visible window is unchanged, then enqueue a
    /// fresh request for that exact identity.
    @discardableResult
    func invalidateAndSchedule(
        window: TemporalRibbonWindow,
        context: HistorySettlementProjectionContext
    ) -> HistorySettlementScheduleResult {
        invalidate()
        let requestGeneration = enqueue(
            window: window,
            context: context
        )
        return .scheduled(generation: requestGeneration)
    }

    /// Invalidates queued or in-flight work without creating a replacement.
    /// The old scheduler operation may still execute; its generation check
    /// will report stale discard and prevent publication.
    func invalidate() {
        supersedeCurrentIfNeeded()
        generation += 1
        currentRequest = nil
        currentState = nil
    }

    private func enqueue(
        window: TemporalRibbonWindow,
        context: HistorySettlementProjectionContext
    ) -> Int {
        let request = Request(
            window: window,
            generation: generation,
            locale: context.locale,
            calendar: context.calendar,
            timeZone: context.timeZone,
            referenceNow: context.referenceNow,
            textResolver: context.textResolver
        )
        currentRequest = request
        currentState = .scheduled
        record(.scheduled, for: request)
        scheduler.schedule { [weak self] in
            await self?.start(request)
        }
        return request.generation
    }

    private func supersedeCurrentIfNeeded() {
        guard let currentRequest,
              let currentState,
              currentState != .completed
        else { return }
        record(.superseded, for: currentRequest)
    }

    private func start(_ request: Request) async {
        guard isCurrent(request) else {
            record(.staleDiscarded, for: request)
            return
        }
        currentState = .started
        record(.started, for: request)

        do {
            let projection = try await source.fetchSettledProjection(for: request.sourceRequest)
            guard isCurrent(request), projection.identity == request.identity else {
                record(.staleDiscarded, for: request)
                return
            }
            currentState = .completed
            record(.published, for: request)
            onPublished(projection, request.sourceRequest)
        } catch {
            guard isCurrent(request) else {
                record(.staleDiscarded, for: request)
                return
            }
            currentState = .completed
            record(.failed, for: request)
            onFailed(request.sourceRequest)
        }
    }

    private func isCurrent(_ request: Request) -> Bool {
        guard let currentRequest else { return false }
        return currentRequest.generation == request.generation
            && currentRequest.identity == request.identity
    }

    private func record(_ outcome: HistorySettlementReconciliationOutcome, for request: Request) {
        eventSink(
            HistorySettlementReconciliationEvent(
                outcome: outcome,
                window: request.identity,
                requestGeneration: request.generation
            )
        )
    }
}
