import Foundation

extension HistoryPresentationModel {
    func retryFailedMotionExtensions() {
        let failed = motionFailedEdges
        motionFailedEdges.removeAll()
        failed.forEach { requestMotionExtension($0) }
    }

    @discardableResult
    func ensureMotionRunway(around date: Date, force: Bool = false) -> Bool {
        let target = calendar.startOfDay(for: date)
        let hasTarget = motionSnapshot?.coverage.contains(target, calendar: calendar) ?? false
        if !force, hasTarget {
            requestMotionExtensionIfNeeded(around: target)
            return true
        }
        if motionInitialLoading {
            guard motionPendingTarget != target else { return false }
        }
        cancelOutstandingTasks()
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: target,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        )
        let generation = prepareInitialMotionLoad(target: target)
        let expectedCalendar = calendar
        let referenceNow = referenceNow
        initialTask = Task { [weak self] in
            do {
                guard let self else { return }
                let chunk = try await loadChunk(coverage, expectedCalendar, referenceNow)
                guard !Task.isCancelled else { return }
                applyInitial(
                    chunk,
                    coverage: coverage,
                    generation: generation,
                    expectedCalendar: expectedCalendar
                )
            } catch {
                guard !Task.isCancelled else { return }
                self?.applyInitialFailure(generation: generation)
            }
        }
        return false
    }

    func requestMotionExtension(_ edge: HistoryMotionEdge) {
        requestMotionExtension(edge, around: selectedDate)
    }

    func requestMotionExtension(_ edge: HistoryMotionEdge, around date: Date) {
        guard let request = makeMotionExtensionRequest(edge, around: date) else { return }
        extensionTasks[edge]?.cancel()
        extensionTasks[edge] = Task { [weak self] in
            do {
                guard let self else { return }
                let chunk = try await loadChunk(
                    request.chunkCoverage,
                    request.calendar,
                    request.referenceNow
                )
                guard let mergedWindow = request.coverage.visualWindow(calendar: request.calendar),
                      let merged = await mergeChunks(request.existingChunks + [chunk], mergedWindow),
                      !Task.isCancelled else { return }
                applyMotionExtension(
                    HistoryMotionExtensionApplication(
                        chunk: chunk,
                        edge: request.edge,
                        coverage: request.coverage,
                        generation: request.generation,
                        calendar: request.calendar,
                        expectedCoverage: request.expectedCoverage,
                        presentation: merged
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }
                self?.applyMotionExtensionFailure(
                    edge: request.edge,
                    generation: request.generation
                )
            }
        }
    }

    func prepareInitialMotionLoad(target: Date) -> Int {
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
        return motionGeneration
    }

    func advanceMotionGeneration() {
        motionGeneration += 1
        guard let current = motionSnapshot else { return }
        motionSnapshot = HistoryMotionSnapshot(
            coverage: current.coverage,
            calendar: calendar,
            generation: motionGeneration,
            presentation: current.presentation,
            isInitial: current.isInitial,
            precedingState: motionState(.preceding),
            followingState: motionState(.following)
        )
    }

    func makeMotionExtensionRequest(
        _ edge: HistoryMotionEdge,
        around date: Date
    ) -> HistoryMotionExtensionRequest? {
        guard let current = motionSnapshot,
              !motionLoadingEdges.contains(edge),
              current.canExtend(edge, around: date, calendar: calendar),
              let coverage = current.coverage.extended(
                  toward: edge,
                  maximumDate: historyDisplayMaximumDay,
                  calendar: calendar
              ),
              let chunkCoverage = motionChunkCoverage(
                  for: edge,
                  coverage: coverage,
                  current: current
              ) else { return nil }
        motionLoadingEdges.insert(edge)
        publishMotionLoadingState()
        return HistoryMotionExtensionRequest(
            edge: edge,
            coverage: coverage,
            chunkCoverage: chunkCoverage,
            generation: current.generation,
            calendar: calendar,
            expectedCoverage: current.coverage,
            existingChunks: motionChunks,
            referenceNow: referenceNow
        )
    }

    func motionChunkCoverage(
        for edge: HistoryMotionEdge,
        coverage: HistoryMotionCoverage,
        current: HistoryMotionSnapshot
    ) -> HistoryMotionCoverage? {
        switch edge {
        case .preceding:
            guard let end = calendar.date(
                byAdding: .day,
                value: -1,
                to: current.coverage.firstDay
            ) else { return nil }
            return HistoryMotionCoverage(
                firstDay: coverage.firstDay,
                lastDay: end,
                calendar: calendar
            )
        case .following:
            guard let start = calendar.date(
                byAdding: .day,
                value: 1,
                to: current.coverage.lastDay
            ) else { return nil }
            return HistoryMotionCoverage(
                firstDay: start,
                lastDay: coverage.lastDay,
                calendar: calendar
            )
        }
    }

    func applyInitial(
        _ chunk: HistoryMotionChunk,
        coverage: HistoryMotionCoverage,
        generation: Int,
        expectedCalendar: Calendar
    ) {
        guard motionGeneration == generation,
              calendar.identifier == expectedCalendar.identifier,
              calendar.timeZone.identifier == expectedCalendar.timeZone.identifier else { return }
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
        let pendingNeedsSelection = pending.map {
            calendar.startOfDay(for: $0) != calendar.startOfDay(for: selectedDate)
        } ?? false
        if environmentRebuild {
            exactRefreshSucceeded = reloadHistory()
        } else if pendingNeedsSelection, let pending {
            selectedDate = pending
            exactRefreshSucceeded = reloadHistory()
        }
        if !exactRefreshSucceeded {
            selectedDate = priorSelectedDate
            motionSnapshot = priorSnapshot.map {
                HistoryMotionSnapshot(
                    coverage: $0.coverage,
                    calendar: calendar,
                    generation: motionGeneration,
                    presentation: $0.presentation,
                    isInitial: $0.isInitial,
                    precedingState: $0.precedingState,
                    followingState: $0.followingState
                )
            }
            motionChunks = priorChunks
        }
    }

    func applyInitialFailure(generation: Int) {
        guard motionGeneration == generation else { return }
        motionInitialLoading = false
        motionPendingTarget = nil
        motionPendingEnvironmentRebuild = false
        motionSnapshot = motionPriorSnapshot.map {
            HistoryMotionSnapshot(
                coverage: $0.coverage,
                calendar: calendar,
                generation: motionGeneration,
                presentation: $0.presentation,
                isInitial: $0.isInitial,
                precedingState: $0.precedingState,
                followingState: $0.followingState
            )
        }
        motionChunks = motionPriorChunks
        if let priorSelectedDate = motionPriorSelectedDate {
            selectedDate = priorSelectedDate
        }
        motionPriorSnapshot = nil
        motionPriorChunks.removeAll()
        motionPriorSelectedDate = nil
    }

    func applyMotionExtension(_ application: HistoryMotionExtensionApplication) {
        guard motionSnapshot?.generation == application.generation,
              motionSnapshot?.coverage == application.expectedCoverage,
              motionSnapshot?.calendarIdentifier == application.calendar.identifier,
              motionSnapshot?.timeZoneIdentifier == application.calendar.timeZone.identifier else { return }
        motionLoadingEdges.remove(application.edge)
        installMotionChunks(
            [application.chunk],
            coverage: application.coverage,
            generation: application.generation,
            presentation: application.presentation,
            isInitial: false
        )
        motionFailedEdges.remove(application.edge)
        publishMotionLoadingState()
        extensionTasks[application.edge] = nil
    }

    func applyMotionExtensionFailure(edge: HistoryMotionEdge, generation: Int) {
        defer { extensionTasks[edge] = nil }
        guard motionSnapshot?.generation == generation else { return }
        motionLoadingEdges.remove(edge)
        motionFailedEdges.insert(edge)
        publishMotionLoadingState()
    }

    func requestMotionExtensionIfNeeded(
        around date: Date,
        requestedEdge: HistoryMotionEdge? = nil
    ) {
        guard let current = motionSnapshot else { return }
        let edges = requestedEdge.map { [$0] } ?? [HistoryMotionEdge.preceding, .following]
            .filter { current.canExtend($0, around: date, calendar: calendar) }
        edges.forEach { requestMotionExtension($0, around: date) }
    }

    func installMotionChunks(
        _ chunks: [HistoryMotionChunk],
        coverage: HistoryMotionCoverage,
        generation: Int,
        presentation: HistoryMotionPresentation,
        isInitial: Bool
    ) {
        motionChunks += chunks
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

    func refreshLoadedMotionChunks() {
        guard motionSnapshot != nil else { return }
        refreshTask?.cancel()
        refreshTask = nil
        advanceMotionGeneration()
        guard let current = motionSnapshot else { return }
        let oldChunks = motionChunks
        let revision = historyDataRevision
        let generation = current.generation
        let oldCoverage = current.coverage
        let wasInitial = current.isInitial
        let expectedCalendar = calendar
        let referenceNow = referenceNow
        refreshTask = Task { [weak self] in
            defer { self?.finishRefreshTask(generation: generation) }
            do {
                guard let self else { return }
                var refreshed: [HistoryMotionChunk] = []
                for oldChunk in oldChunks {
                    try Task.checkCancellation()
                    let chunk = try await loadChunk(
                        oldChunk.coverage,
                        expectedCalendar,
                        referenceNow
                    )
                    refreshed.append(chunk)
                }
                guard let window = oldCoverage.visualWindow(calendar: expectedCalendar),
                      let presentation = await mergeChunks(refreshed, window),
                      !Task.isCancelled else { return }
                applyRefreshedMotion(
                    HistoryMotionRefreshApplication(
                        refreshed: refreshed,
                        revision: revision,
                        generation: generation,
                        oldCoverage: oldCoverage,
                        oldChunks: oldChunks,
                        expectedCalendar: expectedCalendar,
                        presentation: presentation,
                        wasInitial: wasInitial
                    )
                )
            } catch {}
        }
    }

    func finishRefreshTask(generation: Int) {
        guard motionSnapshot?.generation == generation else { return }
        refreshTask = nil
    }

    func applyRefreshedMotion(_ application: HistoryMotionRefreshApplication) {
        guard historyDataRevision == application.revision,
              motionSnapshot?.generation == application.generation,
              motionSnapshot?.coverage == application.oldCoverage,
              motionChunks == application.oldChunks,
              calendar.identifier == application.expectedCalendar.identifier,
              calendar.timeZone.identifier == application.expectedCalendar.timeZone.identifier else { return }
        motionGeneration += 1
        motionLoadingEdges.removeAll()
        motionChunks = application.refreshed
        motionSnapshot = HistoryMotionSnapshot(
            coverage: application.oldCoverage,
            calendar: calendar,
            generation: motionGeneration,
            presentation: application.presentation,
            isInitial: application.wasInitial,
            precedingState: motionState(.preceding),
            followingState: motionState(.following)
        )
        refreshTask = nil
    }

    func motionState(_ edge: HistoryMotionEdge) -> HistoryMotionLoadPhase {
        if motionLoadingEdges.contains(edge) {
            return .loading
        }
        if motionFailedEdges.contains(edge) {
            return .failed
        }
        return .idle
    }

    func publishMotionLoadingState() {
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
