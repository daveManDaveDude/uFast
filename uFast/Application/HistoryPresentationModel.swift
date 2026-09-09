import Foundation
import Observation
import SwiftData

typealias HistoryMotionChunkLoader = @Sendable (
    HistoryMotionCoverage, Calendar, Date, AppTextResolver
) async throws -> HistoryMotionChunk
typealias HistoryMotionChunkMerger = @Sendable (
    [HistoryMotionChunk], DateInterval
) async -> HistoryMotionPresentation?

/// Main-actor owner for History's bounded data and motion lifecycle.
///
/// The view owns only transient visual presentation. This object owns the
/// immutable value projections, their generation identity, and every task that
/// can publish a projection. Cancellation is explicit; generation and input
/// guards remain the second line of defence for non-cooperative work.
@MainActor
@Observable
final class HistoryPresentationModel {
    @ObservationIgnored let modelContext: ModelContext
    @ObservationIgnored let clock: any AppClock
    @ObservationIgnored let loadChunk: HistoryMotionChunkLoader
    @ObservationIgnored let mergeChunks: HistoryMotionChunkMerger
    @ObservationIgnored let motionConfiguration: HistoryMotionConfiguration
    @ObservationIgnored let diagnosticSink: any DiagnosticEventSink
    @ObservationIgnored let presentationCache = HistoryPresentationCache()
    @ObservationIgnored var initialTask: Task<Void, Never>?
    @ObservationIgnored var extensionTasks: [HistoryMotionEdge: Task<Void, Never>] = [:]
    @ObservationIgnored var refreshTask: Task<Void, Never>?
    @ObservationIgnored let settledReconciliationCoordinator: HistorySettledReconciliationCoordinator
    @ObservationIgnored var initialLoadAttempted = false
    @ObservationIgnored var initialLoadFailed = false
    @ObservationIgnored var initialLoadRetryByGeneration: [Int: Bool] = [:]
    @ObservationIgnored let textResolver: AppTextResolver

    var calendar: Calendar
    var locale: Locale
    var timeZone: TimeZone
    var referenceNow: Date
    var selectedDate: Date
    var historyData: HistoryDataSlice?
    var historyPresentation: HistoryPresentationSnapshot?
    var motionSnapshot: HistoryMotionSnapshot?
    var motionChunks: [HistoryMotionChunk] = []
    var motionGeneration = 0
    var motionInitialLoading = false
    var motionPendingTarget: Date?
    var motionPriorSnapshot: HistoryMotionSnapshot?
    var motionPriorChunks: [HistoryMotionChunk] = []
    var motionPriorSelectedDate: Date?
    var motionPendingEnvironmentRebuild = false
    var historyDataRevision = 0
    /// Keeps the prior projection's actions and accessibility hidden between
    /// geometry settlement and publication of its matching exact projection.
    var settledReconciliationPending = false
    var settledReconciliationPublishedGeneration = 0
    var settledReconciliationWindow: TemporalRibbonWindow?
    var settledProjectionIdentity: HistorySettlementWindowIdentity?
    var motionLoadingEdges: Set<HistoryMotionEdge> = []
    var motionFailedEdges: Set<HistoryMotionEdge> = []
    var hydrationFavouriteSnapshots: [HydrationFavouriteSnapshot] = []
    var foodFavouriteSnapshots: [FoodFavouriteSnapshot] = []

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        calendar: Calendar = Calendar(identifier: .gregorian),
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        textResolver: AppTextResolver = .init(),
        motionConfiguration: HistoryMotionConfiguration = .product,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        loadChunk: HistoryMotionChunkLoader? = nil,
        mergeChunks: HistoryMotionChunkMerger? = nil,
        settlementScheduler: any HistorySettlementScheduler = MainActorHistorySettlementScheduler(),
        settledProjectionSource: (any HistorySettledProjectionSource)? = nil,
        settlementEventSink: @escaping HistorySettlementEventSink = { _ in }
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
        self.timeZone = timeZone
        self.textResolver = textResolver
        self.motionConfiguration = motionConfiguration
        self.diagnosticSink = diagnosticSink
        referenceNow = clock.now
        selectedDate = clock.now
        let projectionSource = settledProjectionSource
            ?? SwiftDataHistorySettledProjectionSource(modelContext: modelContext)
        settledReconciliationCoordinator = HistorySettledReconciliationCoordinator(
            scheduler: settlementScheduler,
            source: projectionSource,
            eventSink: settlementEventSink
        )
        let container = modelContext.container
        self.loadChunk = loadChunk ?? { coverage, calendar, referenceNow, textResolver in
            try await SwiftDataHistoryMotionRangeLoader(container: container).load(
                coverage: coverage,
                calendar: calendar,
                referenceNow: referenceNow,
                textResolver: textResolver
            )
        }
        self.mergeChunks = mergeChunks ?? { chunks, window in
            SwiftDataHistoryDataProvider.mergeMotionChunks(chunks, window: window)
        }
        settledReconciliationCoordinator.onPublished = { [weak self] projection, request in
            self?.applySettledReconciliation(projection, request: request)
        }
        settledReconciliationCoordinator.onFailed = { [weak self] _ in
            self?.settledReconciliationPending = false
        }
    }

    deinit {
        initialTask?.cancel()
        refreshTask?.cancel()
        extensionTasks.values.forEach { $0.cancel() }
    }

    func updateEnvironment(calendar: Calendar, locale: Locale, timeZone: TimeZone, now: Date) {
        self.calendar = calendar
        self.locale = locale
        self.timeZone = timeZone
        referenceNow = now
    }

    func setSelectedDate(_ date: Date) {
        selectedDate = date
    }

    func invalidateSettledReconciliation() {
        settledReconciliationCoordinator.invalidate()
        settledReconciliationPending = false
    }

    var hasMatchingSettledProjection: Bool {
        guard let settledReconciliationWindow else { return true }
        return settledProjectionIdentity == settledReconciliationWindow.settlementIdentity
    }

    func cancelOutstandingTasks() {
        initialTask?.cancel()
        initialTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        extensionTasks.values.forEach { $0.cancel() }
        extensionTasks.removeAll()
        initialLoadRetryByGeneration.removeAll()
        motionInitialLoading = false
        motionPendingTarget = nil
        motionPendingEnvironmentRebuild = false
        motionLoadingEdges.removeAll()
        invalidateSettledReconciliation()
        publishMotionLoadingState()
        advanceMotionGeneration()
    }
}
