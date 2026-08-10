import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command line_length force_unwrapping switch_case_alignment trailing_comma
struct HistoryView: View {
    static let futureDisplayDayCount = 1
    static let futureRailContextDayCount = 4

    @Environment(\.calendar) var calendar
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone
    @State var historyData: HistoryDataSlice?
    @State var historyPresentation: HistoryPresentationSnapshot?
    @State var presentationCache = HistoryPresentationCache()
    @State var motionHistoryData: HistoryDataSlice?
    @State var motionHistoryPresentation: HistoryPresentationSnapshot?
    @State var motionPresentationCache = HistoryPresentationCache()
    @State var editor: CompletedFastEditorPresentation?
    @State var foodEditor: HistoryFoodEditorPresentation?
    @State var hydrationEditor: HistoryHydrationEditorPresentation?
    @State var directHistoricalEntry: DirectHistoricalEntryPresentation?
    @State var eventGroupDisclosure: TemporalEventGroup?
    @State var isCalendarPresented = false
    @State var selectedDate: Date
    @State var historyDayBuffer: TemporalDayBuffer?
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
        return (historyPresentation?.visibleFastItems(activeEndingAt: now) ?? [])
            .filter { $0.intersects(window) }
            .sorted { $0.startDate < $1.startDate }
    }
}

extension HistoryView {
    var body: some View {
        ScreenLayout(title: "History", identifier: "history") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    periodHeader
                    TemporalDateNavigator(
                        dates: dateNavigatorDates,
                        selection: selectedDateBinding(source: .dateChip),
                        maximumDate: historyDisplayMaximumDay,
                        readOnlyAfterDate: clock.now,
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
                    .allowsHitTesting(!temporalMovementPhase.suppressesAutomaticAlignment)
                    .id(historyInteractionRevision)

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        TemporalHistoryCarousel(
                            dates: historyDates,
                            selection: selectedDateBinding(source: .carousel),
                            intervals: historyPresentation?.intervals(activeEndingAt: clock.now) ?? [],
                            events: historyPresentation?.events ?? [],
                            motionIntervals: motionHistoryPresentation?.intervals(
                                activeEndingAt: clock.now
                            ) ?? historyPresentation?.intervals(activeEndingAt: clock.now) ?? [],
                            motionEvents: motionHistoryPresentation?.events
                                ?? historyPresentation?.events ?? [],
                            onSelectInterval: openInterval,
                            onSelectEvent: openEvent,
                            onSelectEventGroup: { group in
                                eventGroupDisclosure = group
                            },
                            onSelectEmpty: { instant in
                                beginHistoricalEntry(at: instant)
                            },
                            onNavigateDay: navigateDay,
                            canNavigateForward: canNavigateForward,
                            allowsRecordActivation: !isFutureSelection,
                            allowsEmptySelection: !isFutureSelection,
                            showsTimelineDetails: showsSettledHistoryDetails,
                            presentationDay: selectedDate,
                            readOnlyFromDate: clock.now,
                            onMovementPhaseChange: updateTemporalMovementPhase,
                            onCoupledPresentationChange: coupledScrollPresentation.handle,
                            onSettledVisibleWindow: { window in
                                settledVisibleWindow = window
                                reloadHistory(in: window.interval)
                            }
                        )
                        .padding(.horizontal, UFastTheme.Spacing.standard)
                        .allowsHitTesting(!isDateRailMoving)
                    }

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
            rebuildHistoryPresentation()
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
                    reloadHistory()
                    editor = nil
                },
                onDelete: {
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteCompletedFast(id: presentation.id)
                    reloadHistory()
                    editor = nil
                },
                onCancel: { editor = nil }
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
                    reloadHistory()
                    foodEditor = nil
                },
                onDelete: {
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteFood(id: presentation.record.id)
                    reloadHistory()
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
                    reloadHistory()
                    hydrationEditor = nil
                },
                onDelete: {
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteHydration(id: presentation.record.id)
                    reloadHistory()
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
                favourites: HydrationFavouriteProvider.favourites(snapshot: authoritativeSettings),
                onSaveFood: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveFood(
                        draft,
                        replacing: nil,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistory()
                },
                onSaveHydration: { draft, endingActiveFast in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.saveHydration(
                        draft,
                        replacing: nil,
                        goal: authoritativeSettings?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    reloadHistory()
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
                deleteFood: { id in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteFood(id: id)
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
                deleteHydration: { id in
                    guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
                    try applicationCommands.deleteHydration(id: id)
                },
                onMutationSucceeded: { original, mutation in
                    refreshGroupSurface(for: original, mutation: mutation)
                }
            )
        }
    }
}
