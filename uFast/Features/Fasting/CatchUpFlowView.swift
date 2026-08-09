import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length function_body_length type_body_length

struct CatchUpFlowView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.liveActivityCoordinator) private var liveActivityCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var timeZone
    @Query private var settings: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate != nil }) private var completedFasts: [FastRecord]
    @Query private var foodEntries: [FoodEntryRecord]
    @Query private var hydrationEntries: [HydrationEntryRecord]
    @Query private var unknownPeriods: [UnknownPeriodRecord]

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var selectedRange: CatchUpRange?
    @State private var selectedDayIndex = 0
    @State private var reviewGeneration: ReconstructionGeneration?
    @State private var foodEditor: CatchUpFoodEditorPresentation?
    @State private var pendingFoodEditor: CatchUpFoodEditorPresentation?
    @State private var hydrationEditor: CatchUpHydrationEditorPresentation?
    @State private var pendingHydrationEditor: CatchUpHydrationEditorPresentation?
    @State private var showsEntryChoice = false
    @State private var pendingDrinkChoice = false
    @State private var showsDrinkChoice = false

    let clock: any AppClock

    init(clock: any AppClock) {
        self.clock = clock
        _fromDate = State(initialValue: clock.now)
        _toDate = State(initialValue: clock.now)
    }

    private var resolvedRange: Result<CatchUpRange, CatchUpRangeError> {
        Result {
            try CatchUpRangeResolver.resolve(
                from: fromDate,
                to: toDate,
                now: clock.now,
                calendar: calendar
            )
        }.mapError { ($0 as? CatchUpRangeError) ?? .unresolvedCalendarDay }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let selectedRange, let reviewGeneration {
                    ReviewReconstructionView(
                        generation: reviewGeneration,
                        onSave: { reviewed in
                            try makeReconstructionRepository().commit(
                                reviewed: reviewed,
                                expectedGeneration: reviewGeneration,
                                range: selectedRange.interval
                            )
                            dismiss()
                        },
                        onRefresh: {
                            self.reviewGeneration = try? makeReconstructionRepository().generation(
                                range: selectedRange.interval
                            )
                        }
                    )
                } else if let selectedRange {
                    dayView(range: selectedRange)
                } else {
                    rangeView
                }
            }
            .background(UFastTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("catch-up.cancel")
                }
            }
        }
        .onAppear(perform: setDefaultRangeIfNeeded)
        .sheet(item: $foodEditor) { presentation in
            FoodEntryEditor(
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                initialOccurredAt: presentation.initialOccurredAt,
                allowedRange: presentation.range,
                onSave: { draft, endingActiveFast in
                    try saveFood(
                        draft,
                        record: presentation.record,
                        endingActiveFast: endingActiveFast
                    )
                    foodEditor = nil
                },
                onDelete: presentation.record.map { record in
                    {
                        try makeFoodRepository().delete(record)
                        foodEditor = nil
                    }
                },
                onCancel: { foodEditor = nil }
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                initialDraft: presentation.initialDraft,
                allowedRange: presentation.range,
                onSave: { draft, endingActiveFast in
                    try saveHydration(
                        draft,
                        record: presentation.record,
                        endingActiveFast: endingActiveFast
                    )
                    hydrationEditor = nil
                },
                onDelete: presentation.record.map { record in
                    {
                        try makeHydrationRepository().delete(record)
                        hydrationEditor = nil
                    }
                },
                onCancel: { hydrationEditor = nil }
            )
        }
    }

    private var rangeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                UFastSectionHeading("Catch up", eyebrow: "History")
                Text("Choose up to 7 completed days.")
                    .foregroundStyle(UFastTheme.secondaryText)

                if case let .success(range) = resolvedRange {
                    TemporalDateNavigator(
                        dates: TemporalHistoryPresentation.week(
                            containing: toDate,
                            calendar: calendar
                        ),
                        selection: $toDate,
                        selectedRange: range.interval
                    )
                    Text("The dots show the selected date range, not progress or completion.")
                        .font(.caption)
                        .foregroundStyle(UFastTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    Label("Date range", systemImage: "calendar")
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                    DatePicker("From", selection: $fromDate, displayedComponents: .date)
                        .accessibilityIdentifier("catch-up.from")
                    Divider()
                    DatePicker("To", selection: $toDate, displayedComponents: .date)
                        .accessibilityIdentifier("catch-up.to")
                }
                .uFastCard()

                switch resolvedRange {
                case let .success(range):
                    Label(
                        "\(range.dayCount) \(range.dayCount == 1 ? "day" : "days") selected",
                        systemImage: "calendar.badge.checkmark"
                    )
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityIdentifier("catch-up.day-count")

                    Button("Review past days") {
                        selectedRange = range
                        selectedDayIndex = 0
                    }
                    .buttonStyle(UFastPrimaryButtonStyle())
                    .accessibilityIdentifier("catch-up.review-days")
                case let .failure(error):
                    Label(error.message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Validation error. \(error.message)")
                        .accessibilityIdentifier("catch-up.range-validation")

                    Button("Review past days") {}
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .disabled(true)
                        .accessibilityIdentifier("catch-up.review-days")
                }
            }
            .padding(UFastTheme.Spacing.standard)
        }
        .navigationTitle("Catch up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayView(range: CatchUpRange) -> some View {
        let day = range.days[selectedDayIndex]
        let entries = HistoricalTimeline.entries(
            food: foodEntries,
            drinks: hydrationEntries,
            day: day,
            calendar: calendar
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                    Text("Day \(selectedDayIndex + 1) of \(range.dayCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(UFastTheme.action)
                        .accessibilityIdentifier("catch-up.day-progress")
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.uFastDisplay(.title))
                        .foregroundStyle(UFastTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Add what you remember. Times can be adjusted.")
                        .foregroundStyle(UFastTheme.secondaryText)
                }

                Button {
                    showsEntryChoice = true
                } label: {
                    HStack {
                        Label("Add entry", systemImage: "plus")
                        Spacer()
                        Text("Food or drink")
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                }
                .buttonStyle(UFastSecondaryButtonStyle())
                .accessibilityIdentifier("catch-up.add-entry")

                TemporalRibbonView(
                    selectedDate: day,
                    intervals: ribbonIntervals,
                    events: ribbonEvents,
                    onSelectInterval: nil,
                    onSelectEvent: { id in
                        if let entry = entries.first(where: { $0.id == id }) {
                            open(entry)
                        }
                    },
                    accessibilityIdentifierPrefix: "catch-up"
                )

                if entries.isEmpty {
                    Text("No food or drinks recorded for this day. Add only what you remember.")
                        .foregroundStyle(UFastTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .uFastCard()
                        .accessibilityIdentifier("catch-up.day-empty")
                }
            }
            .padding(UFastTheme.Spacing.standard)
        }
        .navigationTitle("Past day")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Food or drink", isPresented: $showsEntryChoice) {
            Button("Food") { openNewFood(on: day, range: range) }
            Button("Drink") { pendingDrinkChoice = true }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: showsEntryChoice) { _, isPresented in
            guard !isPresented else { return }
            if pendingDrinkChoice {
                pendingDrinkChoice = false
                showsDrinkChoice = true
            } else if let pendingFoodEditor {
                self.pendingFoodEditor = nil
                foodEditor = pendingFoodEditor
            }
        }
        .safeAreaInset(edge: .bottom) {
            dayNavigation(range)
                .padding(.horizontal, UFastTheme.Spacing.standard)
                .padding(.vertical, UFastTheme.Spacing.compact)
                .background(UFastTheme.canvas)
        }
        .sheet(isPresented: $showsDrinkChoice, onDismiss: presentPendingHydrationEditor) {
            AddDrinkSheet(
                favourites: HydrationFavouriteProvider.favourites(settings: settings.first),
                onAdd: { favourite in
                    openNewDrink(favourite: favourite, on: day, range: range)
                    showsDrinkChoice = false
                },
                onChooseAnother: {
                    openNewDrink(favourite: nil, on: day, range: range)
                    showsDrinkChoice = false
                },
                onCancel: { showsDrinkChoice = false }
            )
        }
    }

    private func dayNavigation(_ range: CatchUpRange) -> some View {
        HStack(spacing: UFastTheme.Spacing.standard) {
            if selectedDayIndex > 0 {
                Button("Previous") { selectedDayIndex -= 1 }
                    .buttonStyle(UFastSecondaryButtonStyle())
                    .accessibilityIdentifier("catch-up.previous")
            }
            Button(selectedDayIndex + 1 == range.dayCount ? "Review fasting history" : "Next") {
                if selectedDayIndex + 1 < range.dayCount {
                    selectedDayIndex += 1
                } else {
                    startReview(range: range)
                }
            }
            .buttonStyle(UFastPrimaryButtonStyle())
            .accessibilityIdentifier("catch-up.next")
        }
    }

    private var ribbonIntervals: [TemporalRibbonIntervalItem] {
        let fasts = completedFasts.compactMap { fast -> TemporalRibbonIntervalItem? in
            guard let end = fast.endDate else { return nil }
            let provenance: TemporalProvenancePresentation = fast.origin == .recorded
                ? .recorded
                : .reconstructed(
                    adjusted: fast.wasAdjustedByUser,
                    needsReview: fast.reviewState == .needsReview
                )
            return TemporalRibbonIntervalItem(
                id: fast.id,
                start: fast.startDate,
                end: end,
                title: provenance.title,
                detail: "Existing saved fast",
                accessibilityLabel: TemporalHistoryPresentation.intervalSummary(
                    provenance: provenance,
                    start: fast.startDate,
                    end: end,
                    context: formattingContext
                ),
                kind: fast.reviewState == .needsReview
                    ? .needsReview : (fast.origin == .recorded ? .recorded : .reconstructed)
            )
        }
        let unknowns = unknownPeriods.map {
            TemporalRibbonIntervalItem(
                id: $0.id,
                start: $0.startDate,
                end: $0.endDate,
                title: "Unknown period",
                detail: $0.reason.explanation,
                accessibilityLabel: TemporalHistoryPresentation.intervalSummary(
                    provenance: .unknown,
                    start: $0.startDate,
                    end: $0.endDate,
                    context: formattingContext
                ),
                kind: .unknown
            )
        }
        return fasts + unknowns
    }

    private var ribbonEvents: [TemporalRibbonEventItem] {
        foodEntries.map {
            TemporalRibbonEventItem(
                id: $0.id,
                occurredAt: $0.occurredAt,
                title: $0.foodDescription,
                detail: "Food · \($0.isCaloric ? "Caloric" : "Non-caloric")",
                accessibilityLabel: "\($0.foodDescription), food, \($0.isCaloric ? "caloric" : "non-caloric")",
                kind: .food
            )
        } + hydrationEntries.map {
            TemporalRibbonEventItem(
                id: $0.id,
                occurredAt: $0.occurredAt,
                title: $0.displayName,
                detail: "\($0.volumeMillilitres) ml · \($0.isCaloric ? "Caloric drink" : "Non-caloric drink")",
                accessibilityLabel: "\($0.displayName), "
                    + "\($0.volumeMillilitres) millilitres, "
                    + ($0.isCaloric ? "caloric drink" : "non-caloric drink"),
                kind: $0.isCaloric ? .caloricDrink : .nonCaloricDrink
            )
        }
    }

    private var formattingContext: TemporalFormattingContext {
        TemporalFormattingContext(locale: locale, calendar: calendar, timeZone: timeZone)
    }

    private func setDefaultRangeIfNeeded() {
        guard selectedRange == nil, fromDate == clock.now, toDate == clock.now,
              let dates = try? CatchUpRangeResolver.defaultDates(now: clock.now, calendar: calendar)
        else { return }
        fromDate = dates.from
        toDate = dates.to
    }

    private func openNewFood(on day: Date, range: CatchUpRange) {
        pendingFoodEditor = CatchUpFoodEditorPresentation(
            record: nil,
            initialOccurredAt: CatchUpRangeResolver.prefilledInstant(
                on: day,
                now: clock.now,
                calendar: calendar
            ),
            range: range.interval
        )
    }

    private func openNewDrink(
        favourite: HydrationFavourite?,
        on day: Date,
        range: CatchUpRange
    ) {
        let instant = CatchUpRangeResolver.prefilledInstant(on: day, now: clock.now, calendar: calendar)
        let draft = HydrationEntryDraft(
            type: favourite?.type ?? .custom,
            customName: nil,
            volumeMillilitres: favourite?.volumeMillilitres ?? 300,
            occurredAt: instant,
            isCaloric: false
        )
        let presentation = CatchUpHydrationEditorPresentation(
            record: nil,
            initialDraft: draft,
            range: range.interval
        )
        pendingHydrationEditor = presentation
    }

    private func presentPendingHydrationEditor() {
        guard let pendingHydrationEditor else { return }
        self.pendingHydrationEditor = nil
        hydrationEditor = pendingHydrationEditor
    }

    private func open(_ entry: TodayTimelineEntry) {
        guard let range = selectedRange else { return }
        switch entry.kind {
        case let .food(id, _, _):
            foodEditor = CatchUpFoodEditorPresentation(
                record: foodEntries.first { $0.id == id },
                initialOccurredAt: entry.occurredAt,
                range: range.interval
            )
        case let .drink(id, _, _, _):
            hydrationEditor = CatchUpHydrationEditorPresentation(
                record: hydrationEntries.first { $0.id == id },
                initialDraft: nil,
                range: range.interval
            )
        }
    }

    private func saveFood(
        _ draft: FoodEntryDraft,
        record: FoodEntryRecord?,
        endingActiveFast: Bool
    ) throws {
        try FoodEntryService(repository: makeFoodRepository(), clock: clock).save(
            draft,
            replacing: record,
            goal: settings.first?.fastingGoal ?? .default,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
        }
    }

    private func saveHydration(
        _ draft: HydrationEntryDraft,
        record: HydrationEntryRecord?,
        endingActiveFast: Bool
    ) throws {
        try HydrationEntryService(repository: makeHydrationRepository(), clock: clock).save(
            draft,
            replacing: record,
            goal: settings.first?.fastingGoal ?? .default,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
        }
    }

    private func makeFoodRepository() -> SwiftDataFoodEntryRepository {
        SwiftDataFoodEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-food-save-failure"
            )
        )
    }

    private func makeHydrationRepository() -> SwiftDataHydrationEntryRepository {
        SwiftDataHydrationEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-drink-save-failure"
            )
        )
    }

    private func makeReconstructionRepository() -> SwiftDataReconstructionRepository {
        SwiftDataReconstructionRepository(
            modelContext: modelContext,
            clock: clock,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-reconstruction-save-failure"
            )
        )
    }

    private func startReview(range: CatchUpRange) {
        reviewGeneration = try? makeReconstructionRepository().generation(range: range.interval)
    }
}

private struct CatchUpFoodEditorPresentation: Identifiable {
    let id = UUID()
    let record: FoodEntryRecord?
    let initialOccurredAt: Date
    let range: Range<Date>
}

private struct CatchUpHydrationEditorPresentation: Identifiable {
    let id = UUID()
    let record: HydrationEntryRecord?
    let initialDraft: HydrationEntryDraft?
    let range: Range<Date>
}
