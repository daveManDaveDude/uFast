import SwiftUI

extension HistoryView {
    var historyBody: some View {
        ScreenLayout(title: textResolver(.historyCopy(.title)), identifier: "history") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    periodHeader
                    historyDateNavigator
                    historyTimeline
                    motionUnavailableNotice
                    if isFutureSelection {
                        futureReadOnlyNotice
                    }
                    if !isFutureSelection {
                        directAddAlternative
                            .opacity(showsSettledHistoryDetails ? 1 : 0)
                            .allowsHitTesting(showsSettledHistoryDetails)
                            .accessibilityHidden(!showsSettledHistoryDetails)
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        fastHistoryDetails(at: clock.now)
                            .opacity(showsSettledHistoryDetails ? 1 : 0)
                            .allowsHitTesting(showsSettledHistoryDetails)
                            .accessibilityHidden(!showsSettledHistoryDetails)
                    }
                }
                .padding(.vertical, UFastTheme.Spacing.standard)
            }
            .accessibilityIdentifier("history.content")
        }
        .onAppear {
            model.updateEnvironment(calendar: calendar, locale: locale, timeZone: timeZone, now: clock.now)
            ensureHistoryDayCoverage(around: selectedDate)
            resetToCurrentDayIfSelected()
            _ = model.reloadHistory()
        }
        .onChange(of: isTabSelected) { _, isSelected in
            guard isSelected else { return }
            resetToCurrentDayIfSelected()
            _ = model.refreshHistoryAfterCommittedMutation()
        }
        .onChange(of: historyInvalidationRevision) { _, _ in
            _ = model.refreshHistoryAfterCommittedMutation()
        }
        .onDisappear {
            interruptTemporalMotion()
            model.cancelOutstandingTasks()
        }
        .onChange(of: dynamicTypeSize) { _, _ in interruptTemporalMotion() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                _ = model.reloadHistory()
            } else {
                interruptTemporalMotion(); model.cancelOutstandingTasks()
            }
        }
        .onChange(of: presentedHistorySheetID) { _, sheetID in
            guard sheetID != "none" else { return }
            interruptTemporalMotion()
        }
        .onChange(of: locale.identifier) { _, _ in
            model.updateEnvironment(calendar: calendar, locale: locale, timeZone: timeZone, now: clock.now)
            model.rebuildHistoryPresentation()
        }
        .onChange(of: timeZone.identifier) { _, _ in
            model.updateEnvironment(calendar: calendar, locale: locale, timeZone: timeZone, now: clock.now)
            model.rebuildHistoryForEnvironmentChange()
        }
        .onChange(of: calendar.identifier) { _, _ in
            model.updateEnvironment(calendar: calendar, locale: locale, timeZone: timeZone, now: clock.now)
            model.rebuildHistoryForEnvironmentChange()
        }
        .sheet(isPresented: $isCalendarPresented) { calendarSheet }
        .sheet(item: $editor) { completedFastSheet($0) }
        .sheet(item: $inferredConversion) { inferredSheet($0) }
        .sheet(item: $foodEditor) { foodSheet($0) }
        .sheet(item: $hydrationEditor) { hydrationSheet($0) }
        .sheet(item: $directHistoricalEntry) { directEntrySheet($0) }
        .sheet(item: $eventGroupDisclosure) { eventGroupSheet($0) }
    }

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                textResolver(.historyCopy(.chooseDateLabel)),
                selection: selectedDateBinding(source: .datePicker),
                in: ...clock.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle(textResolver(.historyCopy(.chooseDateSheetTitle)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.historyCopy(.done))) { isCalendarPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func completedFastSheet(_ presentation: CompletedFastEditorPresentation) -> some View {
        CompletedFastEditor(
            presentation: presentation,
            validation: { startDate, endDate in
                try? applicationCommands?.completedFastValidationError(
                    id: presentation.id, startDate: startDate, endDate: endDate
                )
            },
            onSave: { startDate, endDate in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.updateCompletedFast(id: presentation.id, startDate: startDate, endDate: endDate)
                _ = model.reloadHistoryAfterMutation()
                editor = nil
            },
            onDelete: {
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.deleteCompletedFast(id: presentation.id)
                _ = model.reloadHistoryAfterMutation()
                editor = nil
            },
            onCancel: { editor = nil }
        )
    }

    private func inferredSheet(_ presentation: InferredFastConversionPresentation) -> some View {
        InferredFastConversionView(
            presentation: presentation, clock: clock,
            onConfirm: { interval in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                if interval.isInProgress {
                    _ = try applicationCommands.startInferredFast(
                        sourceBoundaryReference: interval.sourceBoundaryReference,
                        expectedStartDate: interval.startDate, expectedEndDate: interval.endDate,
                        expectedSourceDescription: interval.sourceDescription, expectedGoal: interval.goal
                    )
                } else {
                    _ = try applicationCommands.saveInferredFast(
                        sourceBoundaryReference: interval.sourceBoundaryReference,
                        expectedStartDate: interval.startDate, expectedEndDate: interval.endDate,
                        expectedSourceDescription: interval.sourceDescription, expectedGoal: interval.goal
                    )
                }
                _ = model.reloadHistoryAfterMutation()
                inferredConversion = nil
            },
            onCancel: { inferredConversion = nil },
            onFailure: { _ = model.reloadHistoryAfterMutation() }
        )
    }

    private func foodSheet(_ presentation: HistoryFoodEditorPresentation) -> some View {
        FoodEntryEditor(
            snapshot: presentation.record, clock: clock,
            activeFastStart: authoritativeActiveFast?.startDate,
            initialOccurredAt: presentation.record.occurredAt,
            allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
            onSave: { draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveFood(
                    draft, replacing: presentation.record.id,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
                _ = model.reloadHistoryAfterMutation()
                foodEditor = nil
            },
            onDelete: { confirmingInferredImpact in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.deleteFood(
                    id: presentation.record.id,
                    confirmingInferredImpact: confirmingInferredImpact
                )
                _ = model.reloadHistoryAfterMutation()
                foodEditor = nil
            },
            onCancel: { foodEditor = nil }
        )
    }

    private func hydrationSheet(_ presentation: HistoryHydrationEditorPresentation) -> some View {
        HydrationEntryEditor(
            snapshot: presentation.record, clock: clock,
            activeFastStart: authoritativeActiveFast?.startDate,
            initialDraft: nil,
            allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
            onSave: { draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveHydration(
                    draft, replacing: presentation.record.id,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
                _ = model.reloadHistoryAfterMutation()
                hydrationEditor = nil
            },
            onDelete: { confirmingInferredImpact in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.deleteHydration(
                    id: presentation.record.id,
                    confirmingInferredImpact: confirmingInferredImpact
                )
                _ = model.reloadHistoryAfterMutation()
                hydrationEditor = nil
            },
            onCancel: { hydrationEditor = nil }
        )
    }

    private func directEntrySheet(_ presentation: DirectHistoricalEntryPresentation) -> some View {
        DirectHistoricalEntryView(
            presentation: presentation, clock: clock,
            activeFastStart: authoritativeActiveFast?.startDate,
            favourites: HydrationFavouriteProvider.combined(
                settings: authoritativeSettings, userCreated: model.hydrationFavouriteSnapshots
            ),
            resolveFavouriteDraft: { favourite, occurredAt in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                return try applicationCommands.hydrationDraft(for: favourite, occurredAt: occurredAt)
            },
            onSaveFood: { draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveFood(
                    draft,
                    replacing: nil,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
                _ = model.reloadHistoryAfterMutation()
            },
            onSaveHydration: { draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveHydration(
                    draft,
                    replacing: nil,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
                _ = model.reloadHistoryAfterMutation()
            },
            onClose: { directHistoricalEntry = nil }
        )
    }

    private func eventGroupSheet(_ group: TemporalEventGroup) -> some View {
        HistoryEventGroupDisclosure(
            group: group, canAddEvent: allowedRange(for: group) != nil,
            onAddEvent: {
                eventGroupDisclosure = nil
                DispatchQueue.main.async { beginHistoricalEntry(for: group) }
            },
            onDismiss: { eventGroupDisclosure = nil }, clock: clock,
            activeFastStart: authoritativeActiveFast?.startDate,
            resolveFood: { id in foodEntries.first { $0.id == id } },
            resolveHydration: { id in hydrationEntries.first { $0.id == id } },
            saveFood: { id, draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveFood(
                    draft,
                    replacing: id,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
            },
            deleteFood: { id, confirmingInferredImpact in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.deleteFood(id: id, confirmingInferredImpact: confirmingInferredImpact)
            },
            saveHydration: { id, draft, endingActiveFast in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.saveHydration(
                    draft,
                    replacing: id,
                    goal: authoritativeSettings?.fastingGoal ?? .default,
                    endingActiveFast: endingActiveFast
                )
            },
            deleteHydration: { id, confirmingInferredImpact in
                guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                try applicationCommands.deleteHydration(id: id, confirmingInferredImpact: confirmingInferredImpact)
            },
            onMutationSucceeded: { original, mutation in
                refreshGroupSurface(for: original, mutation: mutation)
            }
        )
    }
}
