import SwiftData
import SwiftUI

// swiftlint:disable trailing_comma

// swiftlint:disable blanket_disable_command superfluous_disable_command line_length force_unwrapping switch_case_alignment trailing_comma
struct HistoryView: View {
    static let futureDisplayDayCount = 1
    static let futureRailContextDayCount = 4

    @Environment(\.calendar) var calendar
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.historyPresentationInvalidation) var historyPresentationInvalidation
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone
    @Query(sort: [
        SortDescriptor(\HydrationFavouriteRecord.createdAt),
        SortDescriptor(\HydrationFavouriteRecord.creationOrder),
        SortDescriptor(\HydrationFavouriteRecord.id),
    ])
    private var hydrationFavouriteRecords: [HydrationFavouriteRecord]
    @State var historyData: HistoryDataSlice?
    @State var historyPresentation: HistoryPresentationSnapshot?
    @State var presentationCache = HistoryPresentationCache()
    /// Dates and compact motion primitives are published through one immutable
    /// snapshot.  Keeping this as one state value prevents a date page from
    /// becoming visible before its complete 26-hour projection is available.
    @State var motionSnapshot: HistoryMotionSnapshot?
    @State var motionChunks: [HistoryMotionChunk] = []
    @State var motionGeneration = 0
    @State var motionInitialLoading = false
    @State var motionPendingTarget: Date?
    @State var motionPriorSnapshot: HistoryMotionSnapshot?
    @State var motionPriorChunks: [HistoryMotionChunk] = []
    @State var motionPriorSelectedDate: Date?
    @State var motionPendingEnvironmentRebuild = false
    @State var historyDataRevision = 0
    @State var motionLoadingEdges: Set<HistoryMotionEdge> = []
    @State var motionFailedEdges: Set<HistoryMotionEdge> = []
    @State var editor: CompletedFastEditorPresentation?
    @State var inferredConversion: InferredFastConversionPresentation?
    @State var foodEditor: HistoryFoodEditorPresentation?
    @State var hydrationEditor: HistoryHydrationEditorPresentation?
    @State var directHistoricalEntry: DirectHistoricalEntryPresentation?
    @State var eventGroupDisclosure: TemporalEventGroup?
    @State var isCalendarPresented = false
    @State var selectedDate: Date
    @State var temporalMovementPhase = TemporalCarouselMovementPhase.settled
    @State var coupledScrollPresentation = TemporalCoupledScrollPresentation()
    @State var historyInteractionRevision = 0
    @State var isDateRailMoving = false
    @State var settledVisibleWindow: TemporalRibbonWindow?

    let clock: any AppClock
    let isTabSelected: Bool
    let onSelectToday: () -> Void

    var completedFasts: [HistoryFastSnapshot] {
        historyData?.completedFasts ?? []
    }

    var activeFasts: [HistoryFastSnapshot] {
        historyData?.activeFast.map { [$0] } ?? []
    }

    var foodEntries: [FoodEntrySnapshot] {
        historyData?.foods ?? []
    }

    var hydrationEntries: [HydrationEntrySnapshot] {
        historyData?.drinks ?? []
    }

    var authoritativeSettings: AppSettingsSnapshot? {
        historyData?.settings
    }

    var authoritativeActiveFast: HistoryFastSnapshot? {
        historyData?.activeFast
    }

    /// TimelineView re-evaluates this value while History is foregrounded.
    /// Rebuilding the disposable inferred projection here lets it cross the
    /// eight-hour threshold and goal cap without a background timer or store
    /// write. The settled/motion caches remain authoritative for their own
    /// lifecycle boundaries.
    var liveHistoryPresentation: HistoryPresentationSnapshot? {
        guard let historyData else { return historyPresentation }
        return HistoryPresentationBuilder.build(
            data: historyData,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: clock.now
        )
    }

    init(
        clock: any AppClock = SystemAppClock(),
        isTabSelected: Bool = true,
        onSelectToday: @escaping () -> Void = {}
    ) {
        self.clock = clock
        self.isTabSelected = isTabSelected
        self.onSelectToday = onSelectToday
        _selectedDate = State(initialValue: clock.now)
    }

    func visibleFastItems(at now: Date) -> [HistoryVisibleFastItem] {
        guard let visible = settledVisibleWindow?.interval else { return [] }
        let window = visible.start ..< visible.end
        return (liveHistoryPresentation?.visibleFastItems(activeEndingAt: now) ?? [])
            .filter { $0.intersects(window) }
            .sorted { $0.startDate < $1.startDate }
    }

    var motionIntervalsAtCurrentTime: [TemporalRibbonIntervalItem] {
        let now = clock.now
        let motion = motionSnapshot?.presentation.ribbonIntervals(activeEndingAt: now)
            ?? historyPresentation?.intervals(activeEndingAt: now)
            ?? []
        guard let live = liveHistoryPresentation else { return motion }
        let inferred = live.visibleFastItems(activeEndingAt: now)
            .filter { $0.kind == .inferred }
        guard !inferred.isEmpty else { return motion }
        let inferredIDs = Set(inferred.map(\.id))
        return (motion.filter { !inferredIDs.contains($0.id) } + inferred.map(\.ribbonItem))
            .sorted { $0.start < $1.start }
    }
}

extension HistoryView {
    var body: some View {
        ScreenLayout(title: "History", identifier: "history") {
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
            ensureHistoryDayCoverage(around: selectedDate)
            resetToCurrentDayIfSelected()
            reloadHistory()
        }
        .onChange(of: isTabSelected) { _, isSelected in
            guard isSelected else { return }
            resetToCurrentDayIfSelected()
            refreshHistoryAfterCommittedMutation()
        }
        .onChange(of: historyInvalidationRevision) { _, _ in
            refreshHistoryAfterCommittedMutation()
        }
        .onDisappear {
            interruptTemporalMotion()
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            interruptTemporalMotion()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                reloadHistory()
            } else {
                interruptTemporalMotion()
            }
        }
        .onChange(of: presentedHistorySheetID) { _, sheetID in
            guard sheetID != "none" else { return }
            interruptTemporalMotion()
        }
        .onChange(of: locale.identifier) { _, _ in
            rebuildHistoryPresentation()
        }
        .onChange(of: timeZone.identifier) { _, _ in
            rebuildHistoryForEnvironmentChange()
        }
        .onChange(of: calendar.identifier) { _, _ in
            rebuildHistoryForEnvironmentChange()
        }
        .sheet(isPresented: $isCalendarPresented) {
            NavigationStack {
                DatePicker(
                    "Choose a date",
                    selection: selectedDateBinding(source: .datePicker),
                    in: ...clock.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Choose a date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isCalendarPresented = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $editor) { presentation in
            CompletedFastEditor(
                presentation: presentation,
                validation: { startDate, endDate in
                    try? applicationCommands?.completedFastValidationError(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                },
                onSave: { startDate, endDate in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.updateCompletedFast(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                    reloadHistoryAfterMutation()
                    editor = nil
                },
                onDelete: {
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteCompletedFast(id: presentation.id)
                    reloadHistoryAfterMutation()
                    editor = nil
                },
                onCancel: { editor = nil }
            )
        }
        .sheet(item: $inferredConversion) { presentation in
            InferredFastConversionView(
                presentation: presentation,
                clock: clock,
                onConfirm: { interval in
                    guard let applicationCommands else {
                        throw ApplicationCommandError.recordNotFound
                    }
                    if interval.isInProgress {
                        _ = try applicationCommands.startInferredFast(
                            sourceBoundaryReference: interval.sourceBoundaryReference,
                            expectedStartDate: interval.startDate,
                            expectedEndDate: interval.endDate,
                            expectedSourceDescription: interval.sourceDescription,
                            expectedGoal: interval.goal
                        )
                    } else {
                        _ = try applicationCommands.saveInferredFast(
                            sourceBoundaryReference: interval.sourceBoundaryReference,
                            expectedStartDate: interval.startDate,
                            expectedEndDate: interval.endDate,
                            expectedSourceDescription: interval.sourceDescription,
                            expectedGoal: interval.goal
                        )
                    }
                    _ = reloadHistoryAfterMutation()
                    inferredConversion = nil
                },
                onCancel: { inferredConversion = nil },
                onFailure: { _ = reloadHistoryAfterMutation() }
            )
        }
        .sheet(item: $foodEditor) { presentation in
            FoodEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: authoritativeActiveFast?.startDate,
                initialOccurredAt: presentation.record.occurredAt,
                allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
                onSave: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveFood(
                        draft,
                        replacing: presentation.record.id,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistoryAfterMutation()
                    foodEditor = nil
                },
                onDelete: { confirmingInferredImpact in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteFood(
                        id: presentation.record.id,
                        confirmingInferredImpact: confirmingInferredImpact
                    )
                    reloadHistoryAfterMutation()
                    foodEditor = nil
                },
                onCancel: { foodEditor = nil }
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: authoritativeActiveFast?.startDate,
                initialDraft: nil,
                allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
                onSave: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveHydration(
                        draft,
                        replacing: presentation.record.id,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistoryAfterMutation()
                    hydrationEditor = nil
                },
                onDelete: { confirmingInferredImpact in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteHydration(
                        id: presentation.record.id,
                        confirmingInferredImpact: confirmingInferredImpact
                    )
                    reloadHistoryAfterMutation()
                    hydrationEditor = nil
                },
                onCancel: { hydrationEditor = nil }
            )
        }
        .sheet(item: $directHistoricalEntry) { presentation in
            DirectHistoricalEntryView(
                presentation: presentation,
                clock: clock,
                activeFastStart: authoritativeActiveFast?.startDate,
                favourites: HydrationFavouriteProvider.combined(
                    settings: authoritativeSettings,
                    userCreated: hydrationFavouriteRecords.map(\.snapshot)
                ),
                resolveFavouriteDraft: { favourite, occurredAt in
                    guard let applicationCommands else {
                        throw ApplicationCommandError.recordNotFound
                    }
                    return try applicationCommands.hydrationDraft(
                        for: favourite,
                        occurredAt: occurredAt
                    )
                },
                onSaveFood: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveFood(
                        draft,
                        replacing: nil,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistoryAfterMutation()
                },
                onSaveHydration: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveHydration(
                        draft,
                        replacing: nil,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistoryAfterMutation()
                },
                onClose: { directHistoricalEntry = nil }
            )
        }
        .sheet(item: $eventGroupDisclosure) { group in
            HistoryEventGroupDisclosure(
                group: group,
                canAddEvent: allowedRange(for: group) != nil,
                onAddEvent: {
                    eventGroupDisclosure = nil
                    DispatchQueue.main.async {
                        beginHistoricalEntry(for: group)
                    }
                },
                onDismiss: { eventGroupDisclosure = nil },
                clock: clock,
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
                    try applicationCommands.deleteFood(
                        id: id,
                        confirmingInferredImpact: confirmingInferredImpact
                    )
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
                    try applicationCommands.deleteHydration(
                        id: id,
                        confirmingInferredImpact: confirmingInferredImpact
                    )
                },
                onMutationSucceeded: { original, mutation in
                    refreshGroupSurface(for: original, mutation: mutation)
                }
            )
        }
    }

    var historyInvalidationRevision: Int {
        historyPresentationInvalidation?.revision ?? 0
    }

    var historyDateNavigator: some View {
        TemporalDateNavigator(
            dates: dateNavigatorDates,
            selection: selectedDateBinding(source: .dateChip),
            maximumDate: historyDisplayMaximumDay,
            readOnlyAfterDate: clock.now,
            showsReadOnlyAppearance: showsFutureReadOnlyAppearance,
            automaticScrollEnabled: !temporalMovementPhase
                .suppressesAutomaticAlignment && !isDateRailMoving,
            // Keep the date rail on the settled presentation while
            // the lower timeline is moving. The rail still follows
            // the selected day after native scrolling settles.
            coupledPresentation: nil,
            presentationDay: selectedDate,
            onDirectScrollPhaseChange: updateDateRailMovement,
            onRailSettled: { day in
                selectDay(day, source: .dateRailSettlement)
            }
        )
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .allowsHitTesting(
            !temporalMovementPhase.suppressesAutomaticAlignment && !motionInitialLoading
        )
        .id(historyInteractionRevision)
    }
}
