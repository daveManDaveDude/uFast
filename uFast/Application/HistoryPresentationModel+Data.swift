import Foundation
import SwiftData

extension HistoryPresentationModel {
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
        do {
            let data = try SwiftDataHistoryDataProvider(modelContext: modelContext)
                .fetch(window: requestedWindow)
            historyData = data
            historyPresentation = presentationCache.presentation(
                for: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: referenceNow,
                textResolver: textResolver
            )
        } catch {
            // Retain the last complete projection. A later lifecycle or
            // mutation refresh can replace it atomically.
            return false
        }
        historyDataRevision += 1
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
    // swiftlint:disable:next function_body_length
    func refreshHistoryAfterCommittedMutation(in window: DateInterval? = nil) -> Bool {
        guard let requestedWindow = window ?? TemporalHistoryPresentation.calendarDayWindow(
            containing: selectedDate,
            calendar: calendar
        )?.interval else { return false }
        cancelOutstandingTasks()
        let currentMotionSnapshot = motionSnapshot
        var projectionState = HistoryProjectionState(
            data: historyData,
            presentation: historyPresentation,
            motionSnapshot: currentMotionSnapshot,
            motionChunks: motionChunks,
            generation: motionGeneration
        )
        let nextGeneration = motionGeneration
        let source = SwiftDataHistoryProjectionDataSource(modelContext: modelContext)
        let request = HistoryProjectionRefreshRequest(
            window: requestedWindow,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: referenceNow,
            nextGeneration: nextGeneration,
            textResolver: textResolver
        )
        guard HistoryProjectionRefreshBoundary.refresh(
            state: &projectionState,
            source: source,
            request: request
        ), let data = projectionState.data,
        let presentation = projectionState.presentation else {
            return false
        }
        let favouriteSnapshots: [HydrationFavouriteSnapshot]
        do {
            favouriteSnapshots = try fetchHydrationFavouriteSnapshots()
        } catch {
            return false
        }
        presentationCache.invalidate()
        historyData = data
        historyPresentation = presentation
        if favouriteSnapshots != hydrationFavouriteSnapshots {
            hydrationFavouriteSnapshots = favouriteSnapshots
        }
        historyDataRevision += 1
        motionGeneration = projectionState.generation
        motionLoadingEdges.removeAll()
        motionFailedEdges.removeAll()
        motionInitialLoading = false
        motionPendingTarget = nil
        motionPendingEnvironmentRebuild = false
        motionPriorSnapshot = nil
        motionPriorChunks.removeAll()
        motionPriorSelectedDate = nil
        motionChunks = projectionState.motionChunks
        motionSnapshot = projectionState.motionSnapshot
        if currentMotionSnapshot == nil {
            _ = ensureMotionRunway(around: selectedDate, force: true)
        }
        return true
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
