import Foundation

// swiftlint:disable opening_brace function_body_length function_parameter_count cyclomatic_complexity trailing_comma

extension HistoryView {
    @discardableResult
    func reloadHistory(in window: DateInterval? = nil, refreshMotion: Bool = false) -> Bool {
        guard let requestedWindow = window
            ?? settledVisibleWindow?.interval
            ?? TemporalHistoryPresentation.calendarDayWindow(
                containing: selectedDate,
                calendar: calendar
            )?.interval
        else { return false }
        let provider = SwiftDataHistoryDataProvider(modelContext: modelContext)
        do {
            let data = try provider.fetch(window: requestedWindow)
            historyData = data
            historyPresentation = presentationCache.presentation(
                for: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: clock.now
            )
        } catch {
            // A failed exact refresh must not turn a previously complete
            // presentation into an empty state.  Keep the last settled truth
            // and let a later lifecycle/mutation retry replace it atomically.
            return false
        }
        historyDataRevision += 1
        if motionSnapshot == nil {
            _ = ensureMotionRunway(around: selectedDate)
        } else if refreshMotion {
            refreshLoadedMotionChunks()
        }
        return true
    }

    func reloadHistoryAfterMutation(in window: DateInterval? = nil) {
        reloadHistory(in: window, refreshMotion: true)
    }

    func rebuildHistoryPresentation() {
        guard let historyData else { return }
        presentationCache.invalidate()
        historyPresentation = presentationCache.presentation(
            for: historyData,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: clock.now
        )
        // Motion primitives intentionally carry no locale-formatted copy.
        // Reformatting is therefore settled-only and does not churn the moving
        // runway or its generation.
    }

    func rebuildHistoryForEnvironmentChange() {
        let previousSnapshot = motionSnapshot
        let previousChunks = motionChunks
        motionLoadingEdges.removeAll()
        motionFailedEdges.removeAll()
        motionInitialLoading = false
        motionGeneration += 1
        motionPriorSnapshot = previousSnapshot
        motionPriorChunks = previousChunks
        motionPriorSelectedDate = selectedDate
        motionPendingEnvironmentRebuild = true
        _ = ensureMotionRunway(around: selectedDate, force: true)
    }

    /// Builds the initial 120-day runway or a direct-jump runway.  The query
    /// and projection are committed together, so no date is exposed without a
    /// complete visual tile.  This synchronous path is intentionally bounded
    /// to one chunk; extension requests are coalesced by `requestMotionExtension`.
    @discardableResult
    func ensureMotionRunway(around date: Date, force: Bool = false) -> Bool {
        let target = calendar.startOfDay(for: date)
        if !force, let motionSnapshot,
           motionSnapshot.coverage.contains(target, calendar: calendar)
        {
            requestMotionExtensionIfNeeded(around: target)
            return true
        }
        guard !motionInitialLoading else { return false }
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: target,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        )
        motionInitialLoading = true
        motionPendingTarget = target
        if motionPriorSnapshot == nil {
            motionPriorSnapshot = motionSnapshot
        }
        if motionPriorChunks.isEmpty {
            motionPriorChunks = motionChunks
        }
        if motionPriorSelectedDate == nil {
            motionPriorSelectedDate = selectedDate
        }
        motionGeneration += 1
        let generation = motionGeneration
        let expectedCalendar = calendar
        let referenceNow = clock.now
        let container = modelContext.container
        Task {
            do {
                let loader = SwiftDataHistoryMotionRangeLoader(container: container)
                let chunk = try await loader.load(
                    coverage: coverage,
                    calendar: expectedCalendar,
                    referenceNow: referenceNow
                )
                await MainActor.run {
                    guard motionGeneration == generation,
                          calendar.identifier == expectedCalendar.identifier,
                          calendar.timeZone.identifier == expectedCalendar.timeZone.identifier
                    else { return }
                    motionChunks.removeAll()
                    installMotionChunks(
                        [chunk],
                        coverage: coverage,
                        generation: generation,
                        presentation: chunk.presentation,
                        isInitial: true
                    )
                    motionFailedEdges.removeAll()
                    motionInitialLoading = false
                    let pending = motionPendingTarget
                    motionPendingTarget = nil
                    let environmentRebuild = motionPendingEnvironmentRebuild
                    motionPendingEnvironmentRebuild = false
                    let priorSnapshot = motionPriorSnapshot
                    let priorChunks = motionPriorChunks
                    let priorSelectedDate = motionPriorSelectedDate ?? selectedDate
                    motionPriorSnapshot = nil
                    motionPriorChunks.removeAll()
                    motionPriorSelectedDate = nil
                    var exactRefreshSucceeded = true
                    if environmentRebuild {
                        exactRefreshSucceeded = reloadHistory()
                    } else if let pending, calendar.startOfDay(for: pending) != calendar.startOfDay(for: selectedDate) {
                        selectedDate = pending
                        exactRefreshSucceeded = reloadHistory()
                    }
                    if !exactRefreshSucceeded {
                        selectedDate = priorSelectedDate
                        if let priorSnapshot {
                            motionSnapshot = HistoryMotionSnapshot(
                                coverage: priorSnapshot.coverage,
                                calendar: calendar,
                                generation: motionGeneration,
                                presentation: priorSnapshot.presentation,
                                isInitial: priorSnapshot.isInitial,
                                precedingState: priorSnapshot.precedingState,
                                followingState: priorSnapshot.followingState
                            )
                        } else {
                            motionSnapshot = nil
                        }
                        motionChunks = priorChunks
                    }
                }
            } catch {
                await MainActor.run {
                    guard motionGeneration == generation else { return }
                    motionInitialLoading = false
                    motionPendingTarget = nil
                    motionPendingEnvironmentRebuild = false
                    if let priorSnapshot = motionPriorSnapshot {
                        motionSnapshot = HistoryMotionSnapshot(
                            coverage: priorSnapshot.coverage,
                            calendar: calendar,
                            generation: motionGeneration,
                            presentation: priorSnapshot.presentation,
                            isInitial: priorSnapshot.isInitial,
                            precedingState: priorSnapshot.precedingState,
                            followingState: priorSnapshot.followingState
                        )
                    } else {
                        motionSnapshot = nil
                    }
                    motionChunks = motionPriorChunks
                    if let priorSelectedDate = motionPriorSelectedDate {
                        selectedDate = priorSelectedDate
                    }
                    motionPriorSnapshot = nil
                    motionPriorChunks.removeAll()
                    motionPriorSelectedDate = nil
                }
            }
        }
        return false
    }

    func requestMotionExtension(_ edge: HistoryMotionEdge) {
        requestMotionExtension(edge, around: selectedDate)
    }

    func requestMotionExtension(_ edge: HistoryMotionEdge, around date: Date) {
        guard let current = motionSnapshot,
              !motionLoadingEdges.contains(edge),
              current.canExtend(edge, around: date, calendar: calendar)
        else { return }
        guard let coverage = current.coverage.extended(
            toward: edge,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        ) else { return }
        motionLoadingEdges.insert(edge)
        publishMotionLoadingState()
        let requestGeneration = current.generation
        let chunkCoverage: HistoryMotionCoverage?
        switch edge {
        case .preceding:
            guard let end = calendar.date(byAdding: .day, value: -1, to: current.coverage.firstDay) else {
                motionLoadingEdges.remove(edge)
                return
            }
            chunkCoverage = HistoryMotionCoverage(firstDay: coverage.firstDay, lastDay: end, calendar: calendar)
        case .following:
            guard let start = calendar.date(byAdding: .day, value: 1, to: current.coverage.lastDay) else {
                motionLoadingEdges.remove(edge)
                return
            }
            chunkCoverage = HistoryMotionCoverage(firstDay: start, lastDay: coverage.lastDay, calendar: calendar)
        }
        guard let chunkCoverage else {
            motionLoadingEdges.remove(edge)
            return
        }
        let container = modelContext.container
        let expectedCalendar = calendar
        let referenceNow = clock.now
        let expectedCoverage = current.coverage
        let existingChunks = motionChunks
        Task {
            do {
                let loader = SwiftDataHistoryMotionRangeLoader(container: container)
                let chunk = try await loader.load(
                    coverage: chunkCoverage,
                    calendar: expectedCalendar,
                    referenceNow: referenceNow
                )
                guard let mergedWindow = coverage.visualWindow(calendar: expectedCalendar),
                      let merged = await loader.merge(existingChunks + [chunk], window: mergedWindow)
                else { throw HistoryMotionChunkError.invalidCoverage }
                await MainActor.run {
                    applyMotionExtension(
                        chunk,
                        edge: edge,
                        coverage: coverage,
                        generation: requestGeneration,
                        calendar: expectedCalendar,
                        expectedCoverage: expectedCoverage,
                        presentation: merged
                    )
                }
            } catch {
                await MainActor.run {
                    guard motionSnapshot?.generation == requestGeneration else { return }
                    motionLoadingEdges.remove(edge)
                    motionFailedEdges.insert(edge)
                    publishMotionLoadingState()
                }
            }
        }
    }

    private func applyMotionExtension(
        _ chunk: HistoryMotionChunk,
        edge: HistoryMotionEdge,
        coverage: HistoryMotionCoverage,
        generation: Int,
        calendar: Calendar,
        expectedCoverage: HistoryMotionCoverage,
        presentation: HistoryMotionPresentation
    ) {
        motionLoadingEdges.remove(edge)
        guard motionSnapshot?.generation == generation,
              motionSnapshot?.coverage == expectedCoverage,
              motionSnapshot?.calendarIdentifier == calendar.identifier,
              motionSnapshot?.timeZoneIdentifier == calendar.timeZone.identifier
        else { return }
        installMotionChunks(
            [chunk],
            coverage: coverage,
            generation: generation,
            presentation: presentation,
            isInitial: false
        )
        motionFailedEdges.remove(edge)
        publishMotionLoadingState()
    }

    private func requestMotionExtensionIfNeeded(
        around date: Date,
        requestedEdge: HistoryMotionEdge? = nil
    ) {
        guard let current = motionSnapshot else { return }
        let edges: [HistoryMotionEdge] = requestedEdge.map { [$0] } ?? [
            .preceding, .following,
        ].filter { current.canExtend($0, around: date, calendar: calendar) }
        for edge in edges {
            requestMotionExtension(edge, around: date)
        }
    }

    private func installMotionChunks(
        _ chunks: [HistoryMotionChunk],
        coverage: HistoryMotionCoverage,
        generation: Int,
        presentation: HistoryMotionPresentation,
        isInitial: Bool
    ) {
        let allChunks = motionChunks + chunks
        // This is the only assignment that changes the scrollable date list;
        // its projection is installed in the same value.
        motionChunks = allChunks
        motionSnapshot = HistoryMotionSnapshot(
            coverage: coverage,
            calendar: calendar,
            generation: generation,
            presentation: presentation,
            isInitial: isInitial,
            precedingState: motionState(.preceding),
            followingState: motionState(.following)
        )
    }

    /// A committed mutation can alter an automatic gap whose boundary is on
    /// either side of the changed event.  Refreshing each retained compact
    /// chunk in one replacement transaction updates both adjacent gaps while
    /// preserving every already traversed page if a query fails.
    private func refreshLoadedMotionChunks() {
        guard let current = motionSnapshot else { return }
        let oldChunks = motionChunks
        let revision = historyDataRevision
        let generation = current.generation
        let oldCoverage = current.coverage
        let wasInitial = current.isInitial
        let expectedCalendar = calendar
        let referenceNow = clock.now
        let container = modelContext.container
        Task {
            do {
                let loader = SwiftDataHistoryMotionRangeLoader(container: container)
                var refreshed: [HistoryMotionChunk] = []
                refreshed.reserveCapacity(oldChunks.count)
                for oldChunk in oldChunks {
                    try await refreshed.append(loader.load(
                        coverage: oldChunk.coverage,
                        calendar: expectedCalendar,
                        referenceNow: referenceNow
                    ))
                }
                guard let window = oldCoverage.visualWindow(calendar: expectedCalendar),
                      let presentation = await loader.merge(refreshed, window: window)
                else { throw HistoryMotionChunkError.invalidCoverage }
                await MainActor.run {
                    guard historyDataRevision == revision,
                          motionSnapshot?.generation == generation,
                          motionSnapshot?.coverage == oldCoverage,
                          motionChunks == oldChunks,
                          calendar.identifier == expectedCalendar.identifier,
                          calendar.timeZone.identifier == expectedCalendar.timeZone.identifier,
                          motionSnapshot != nil
                    else { return }
                    motionGeneration += 1
                    motionLoadingEdges.removeAll()
                    motionChunks = refreshed
                    motionSnapshot = HistoryMotionSnapshot(
                        coverage: oldCoverage,
                        calendar: calendar,
                        generation: motionGeneration,
                        presentation: presentation,
                        isInitial: wasInitial,
                        precedingState: motionState(.preceding),
                        followingState: motionState(.following)
                    )
                }
            } catch {
                // Keep oldChunks/current snapshot. Failed or cancelled
                // mutations never clear a complete motion presentation.
            }
        }
    }

    private func motionState(_ edge: HistoryMotionEdge) -> HistoryMotionLoadPhase {
        if motionLoadingEdges.contains(edge) {
            return .loading
        }
        if motionFailedEdges.contains(edge) {
            return .failed
        }
        return .idle
    }

    private func publishMotionLoadingState() {
        guard let current = motionSnapshot else { return }
        motionSnapshot = HistoryMotionSnapshot(
            coverage: current.coverage,
            calendar: calendar,
            generation: current.generation,
            presentation: current.presentation,
            isInitial: current.isInitial,
            precedingState: motionState(.preceding),
            followingState: motionState(.following)
        )
    }
}
