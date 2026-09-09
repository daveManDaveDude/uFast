import Foundation
import SwiftData

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

extension HistoryPresentationModel {
    @discardableResult
    func scheduleSettledReconciliation(
        for window: TemporalRibbonWindow
    ) -> HistorySettlementScheduleResult {
        settledReconciliationWindow = window
        let result = settledReconciliationCoordinator.schedule(
            window: window,
            context: settledProjectionContext()
        )
        settledReconciliationPending = result.isPending
        return result
    }

    private func scheduleFreshSettledReconciliation(for window: TemporalRibbonWindow) {
        settledReconciliationWindow = window
        settledReconciliationPending = true
        _ = settledReconciliationCoordinator.invalidateAndSchedule(
            window: window,
            context: settledProjectionContext()
        )
    }

    private func mutationReconciliationWindow(in interval: DateInterval?) -> TemporalRibbonWindow? {
        if interval == nil, let settledReconciliationWindow {
            return settledReconciliationWindow
        }
        return reconciliationWindow(in: interval)
    }

    private func settledProjectionContext() -> HistorySettlementProjectionContext {
        HistorySettlementProjectionContext(
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: referenceNow,
            textResolver: textResolver
        )
    }

    private func reconciliationWindow(in interval: DateInterval?) -> TemporalRibbonWindow? {
        guard let interval else {
            return TemporalHistoryPresentation.ribbonWindow(
                containing: selectedDate,
                calendar: calendar
            )
        }
        if settledReconciliationWindow?.interval == interval {
            return settledReconciliationWindow
        }
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay),
              interval.start < interval.end
        else { return nil }
        return TemporalRibbonWindow(
            selectedDay: selectedDay,
            selectedDayInterval: DateInterval(start: selectedDay, end: selectedDayEnd),
            interval: interval,
            midnightMarkers: [selectedDay].filter {
                $0 > interval.start && $0 < interval.end
            }
        )
    }

    func applySettledReconciliation(
        _ projection: HistorySettledProjection,
        request: HistorySettledProjectionRequest
    ) {
        guard projection.identity == request.identity else { return }
        if !calendar.isDate(selectedDate, inSameDayAs: request.window.selectedDay) {
            selectedDate = request.window.selectedDay
        }
        historyData = projection.data
        historyPresentation = projection.presentation
        historyDataRevision += 1
        settledReconciliationWindow = request.window
        settledProjectionIdentity = request.identity
        settledReconciliationPublishedGeneration = request.generation
        HistorySettlementPublicationProbe.record(request)
        settledReconciliationPending = false
    }

    /// Reclassifies an already loaded inferred candidate at its single
    /// derived cap. This is an in-memory transition; it never queries or
    /// persists and is called only at a safe settled presentation boundary.
    @discardableResult
    func reclassifyCappedInferredFast(at now: Date) -> Bool {
        var changed = false
        if let current = historyPresentation {
            let next = current.reclassifiedInferredItems(at: now)
            if next != current {
                historyPresentation = next
                changed = true
            }
        }
        if let current = motionSnapshot {
            let nextPresentation = current.presentation.reclassifiedInferredItems(at: now)
            if nextPresentation != current.presentation {
                motionSnapshot = HistoryMotionSnapshot(
                    coverage: current.coverage,
                    calendar: calendar,
                    generation: current.generation,
                    presentation: nextPresentation,
                    isInitial: current.isInitial,
                    precedingState: current.precedingState,
                    followingState: current.followingState
                )
                changed = true
            }
        }
        return changed
    }

    var historyDisplayMaximumDay: Date {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceNow)
        ) ?? calendar.startOfDay(for: referenceNow)
    }

    @discardableResult
    func reloadHistory(in window: DateInterval? = nil, refreshMotion: Bool = false) -> Bool {
        guard let requestedWindow = window ?? TemporalHistoryPresentation.calendarDayWindow(
            containing: selectedDate,
            calendar: calendar
        )?.interval else { return false }
        HistoryScrollDiagnosticProbe.recordWindow(requestedWindow)
        do {
            let data = try HistoryScrollDiagnosticProbe.withWork(.exactWindowFetch) {
                try SwiftDataHistoryDataProvider(modelContext: modelContext)
                    .fetch(window: requestedWindow)
            }
            historyData = data
            historyPresentation = HistoryScrollDiagnosticProbe.withWork(.exactWindowProjection) {
                presentationCache.presentation(
                    for: data,
                    locale: locale,
                    calendar: calendar,
                    timeZone: timeZone,
                    referenceNow: referenceNow,
                    textResolver: textResolver
                )
            }
        } catch {
            // Retain the last complete projection. A later lifecycle or
            // mutation refresh can replace it atomically.
            return false
        }
        historyDataRevision += 1
        if let settledWindow = reconciliationWindow(in: requestedWindow) {
            settledReconciliationWindow = settledWindow
            settledProjectionIdentity = settledWindow.settlementIdentity
        }
        if motionSnapshot == nil, !initialLoadFailed {
            _ = ensureMotionRunway(around: selectedDate)
        } else if refreshMotion {
            refreshLoadedMotionChunks()
        }
        return true
    }

    @discardableResult
    func reloadHydrationFavourites() -> Bool {
        do {
            let snapshots = try fetchHydrationFavouriteSnapshots()
            if snapshots != hydrationFavouriteSnapshots {
                hydrationFavouriteSnapshots = snapshots
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func reloadFoodFavourites() -> Bool {
        do {
            let snapshots = try fetchFoodFavouriteSnapshots()
            if snapshots != foodFavouriteSnapshots {
                foodFavouriteSnapshots = snapshots
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    // swiftlint:disable:next function_body_length
    func refreshHistoryAfterCommittedMutation(in window: DateInterval? = nil) -> Bool {
        guard let requestedWindow = window ?? TemporalHistoryPresentation.calendarDayWindow(
            containing: selectedDate,
            calendar: calendar
        )?.interval else { return false }
        guard let mutationWindow = mutationReconciliationWindow(in: window)
            ?? reconciliationWindow(in: requestedWindow)
        else { return false }
        cancelOutstandingTasks()
        var freshReconciliationScheduled = false
        defer {
            if !freshReconciliationScheduled {
                scheduleFreshSettledReconciliation(for: mutationWindow)
            }
        }
        let favouriteSnapshots: [HydrationFavouriteSnapshot]
        do {
            favouriteSnapshots = try fetchHydrationFavouriteSnapshots()
        } catch {
            return false
        }
        let foodFavouriteSnapshots: [FoodFavouriteSnapshot]
        do {
            foodFavouriteSnapshots = try fetchFoodFavouriteSnapshots()
        } catch {
            return false
        }
        if favouriteSnapshots != hydrationFavouriteSnapshots {
            hydrationFavouriteSnapshots = favouriteSnapshots
        }
        if foodFavouriteSnapshots != self.foodFavouriteSnapshots {
            self.foodFavouriteSnapshots = foodFavouriteSnapshots
        }
        if motionSnapshot == nil {
            _ = ensureMotionRunway(around: selectedDate, force: true)
        }
        scheduleFreshSettledReconciliation(for: mutationWindow)
        freshReconciliationScheduled = true
        return true
    }

    private func fetchFoodFavouriteSnapshots() throws -> [FoodFavouriteSnapshot] {
        try modelContext.fetch(
            FetchDescriptor<FoodFavouriteRecord>(
                sortBy: [
                    SortDescriptor(\FoodFavouriteRecord.creationOrder),
                    SortDescriptor(\FoodFavouriteRecord.createdAt),
                    SortDescriptor(\FoodFavouriteRecord.id),
                ]
            )
        ).map(\.snapshot)
    }

    @discardableResult
    func reloadHistoryAfterMutation(in window: DateInterval? = nil) -> Bool {
        refreshHistoryAfterCommittedMutation(in: window)
    }

    func rebuildHistoryPresentation() {
        guard let historyData else { return }
        presentationCache.invalidate()
        historyPresentation = presentationCache.presentation(
            for: historyData,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: referenceNow
        )
    }

    func rebuildHistoryForEnvironmentChange() {
        let previousSnapshot = motionSnapshot
        let previousChunks = motionChunks
        cancelOutstandingTasks()
        motionLoadingEdges.removeAll()
        motionFailedEdges.removeAll()
        motionInitialLoading = false
        motionPriorSnapshot = previousSnapshot
        motionPriorChunks = previousChunks
        motionPriorSelectedDate = selectedDate
        motionPendingEnvironmentRebuild = true
        _ = ensureMotionRunway(around: selectedDate, force: true)
    }

    private func fetchHydrationFavouriteSnapshots() throws -> [HydrationFavouriteSnapshot] {
        let creationOrder = SortDescriptor<HydrationFavouriteRecord>(\.creationOrder)
        let createdAt = SortDescriptor<HydrationFavouriteRecord>(\.createdAt)
        let identifier = SortDescriptor<HydrationFavouriteRecord>(\.id)
        return try modelContext.fetch(
            FetchDescriptor<HydrationFavouriteRecord>(
                sortBy: [creationOrder, createdAt, identifier]
            )
        ).map(\.snapshot)
    }
}
