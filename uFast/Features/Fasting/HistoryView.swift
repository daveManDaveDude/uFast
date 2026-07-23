import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length type_body_length

struct HistoryView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var timeZone
    @Query(filter: #Predicate<FastRecord> { $0.endDate != nil }) private var completedFasts: [FastRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @Query private var foodEntries: [FoodEntryRecord]
    @Query private var hydrationEntries: [HydrationEntryRecord]
    @Query private var settings: [AppSettingsRecord]
    @Query private var unknownPeriods: [UnknownPeriodRecord]
    @State private var editor: CompletedFastEditorPresentation?
    @State private var reconstructedDetail: ReconstructedDetailPresentation?
    @State private var unknownDetail: UnknownDetailPresentation?
    @State private var foodEditor: HistoryFoodEditorPresentation?
    @State private var hydrationEditor: HistoryHydrationEditorPresentation?
    @State private var directHistoricalEntry: DirectHistoricalEntryPresentation?
    @State private var contextualReview: ContextualReviewPresentation?
    @State private var contextualReviewError: String?
    @State private var isCalendarPresented = false
    @State private var selectedDate: Date
    @State private var historyDayBuffer: TemporalDayBuffer?
    @State private var temporalMovementPhase = TemporalCarouselMovementPhase.settled

    private let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
        _selectedDate = State(initialValue: clock.now)
    }

    private var historyItems: [HistoryListItem] {
        let fastItems = completedFasts.compactMap { fast -> HistoryListItem? in
            guard let endDate = fast.endDate else { return nil }
            return HistoryListItem(
                id: fast.id,
                endDate: endDate,
                kind: fast.origin == .recorded ? .recordedFast : .reconstructedFast,
                content: .fast(fast)
            )
        }
        let unknownItems = unknownPeriods.map {
            HistoryListItem(
                id: $0.id,
                endDate: $0.endDate,
                kind: .unknownPeriod,
                content: .unknown($0)
            )
        }
        let items = fastItems + unknownItems
        return HistoryOrdering.newestFirst(
            items.map {
                HistoryOrderingValue(id: $0.id, endDate: $0.endDate, kind: $0.kind)
            }
        ).compactMap { value in
            items.first { $0.id == value.id && $0.kind == value.kind }
        }
    }

    var body: some View {
        ScreenLayout(title: "History", identifier: "history") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    periodHeader
                    TemporalDateNavigator(
                        dates: historyDates,
                        selection: selectedDateBinding(source: .dateChip),
                        maximumDate: clock.now,
                        automaticScrollEnabled: !temporalMovementPhase
                            .suppressesAutomaticAlignment
                    )
                    .padding(.horizontal, UFastTheme.Spacing.standard)

                    TemporalHistoryCarousel(
                        dates: historyDates,
                        selection: selectedDateBinding(source: .carousel),
                        intervals: ribbonIntervals,
                        events: ribbonEvents,
                        onSelectInterval: openInterval,
                        onSelectEvent: openEvent,
                        onSelectEmpty: beginHistoricalEntry,
                        onNavigateDay: navigateDay,
                        canNavigateForward: canNavigateForward,
                        onMovementPhaseChange: updateTemporalMovementPhase
                    )
                    .padding(.horizontal, UFastTheme.Spacing.standard)

                    if isCompletedSelection {
                        directAddAlternative
                        if hasCaloricEvidence {
                            contextualReviewButton
                        }
                        if let contextualReviewError {
                            Label(contextualReviewError, systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(UFastTheme.error)
                                .padding(.horizontal, UFastTheme.Spacing.standard)
                                .accessibilityIdentifier("history.review-suggestions-error")
                        }
                    }

                    if historyItems.isEmpty {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                                Text("HISTORY")
                                    .font(.caption.weight(.semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(UFastTheme.secondaryText)
                                Text("No completed fasts")
                                    .font(.headline)
                                    .foregroundStyle(UFastTheme.primary)
                                Text("Completed fasts will appear here.")
                                    .font(.body)
                                    .foregroundStyle(UFastTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .uFastCard()
                            .padding(UFastTheme.Spacing.standard)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("history.empty")
                        } else {
                            UFastIllustratedInformationCard(
                                title: "No completed fasts",
                                eyebrow: "History",
                                message: "Completed fasts will appear here."
                            ) {
                                FastingBotanicalArtwork()
                            }
                            .padding(UFastTheme.Spacing.standard)
                            .accessibilityIdentifier("history.empty")
                        }
                    } else {
                        UFastSectionHeading("Recent records", eyebrow: "Details")
                            .padding(.horizontal, UFastTheme.Spacing.standard)
                        LazyVStack(spacing: 12) {
                            ForEach(historyItems) { item in
                                Button { open(item) } label: {
                                    historyRow(item)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(historyIdentifier(item))
                            }
                        }
                        .padding(.horizontal, UFastTheme.Spacing.standard)
                        .accessibilityIdentifier("history.list")
                    }
                }
                .padding(.vertical, UFastTheme.Spacing.standard)
            }
        }
        .onAppear {
            ensureHistoryDayCoverage(around: selectedDate)
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
                    try? makeCompletedFastService().validationError(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                },
                onSave: { startDate, endDate in
                    _ = try makeCompletedFastService().update(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                    editor = nil
                },
                onDelete: {
                    try makeCompletedFastService().delete(id: presentation.id)
                    editor = nil
                },
                onCancel: { editor = nil }
            )
        }
        .sheet(item: $reconstructedDetail) { presentation in
            ReconstructedFastDetailView(
                fast: presentation.fast,
                clock: clock,
                repository: makeReconstructionRepository(),
                onClose: { reconstructedDetail = nil }
            )
        }
        .sheet(item: $unknownDetail) { presentation in
            UnknownPeriodDetailView(
                unknown: presentation.unknown,
                repository: makeReconstructionRepository(),
                onClose: { unknownDetail = nil }
            )
        }
        .sheet(item: $foodEditor) { presentation in
            FoodEntryEditor(
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                initialOccurredAt: presentation.record.occurredAt,
                allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
                onSave: { draft, endingActiveFast in
                    try FoodEntryService(repository: makeFoodRepository(), clock: clock).save(
                        draft,
                        replacing: presentation.record,
                        goal: settings.first?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    foodEditor = nil
                },
                onDelete: {
                    try makeFoodRepository().delete(presentation.record)
                    foodEditor = nil
                },
                onCancel: { foodEditor = nil }
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                initialDraft: nil,
                allowedRange: historicalDayRange(containing: presentation.record.occurredAt),
                onSave: { draft, endingActiveFast in
                    try HydrationEntryService(repository: makeHydrationRepository(), clock: clock).save(
                        draft,
                        replacing: presentation.record,
                        goal: settings.first?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                    hydrationEditor = nil
                },
                onDelete: {
                    try makeHydrationRepository().delete(presentation.record)
                    hydrationEditor = nil
                },
                onCancel: { hydrationEditor = nil }
            )
        }
        .sheet(item: $directHistoricalEntry) { presentation in
            DirectHistoricalEntryView(
                presentation: presentation,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                favourites: HydrationFavouriteProvider.favourites(settings: settings.first),
                onSaveFood: { draft, endingActiveFast in
                    try FoodEntryService(repository: makeFoodRepository(), clock: clock).save(
                        draft,
                        replacing: nil,
                        goal: settings.first?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                },
                onSaveHydration: { draft, endingActiveFast in
                    try HydrationEntryService(repository: makeHydrationRepository(), clock: clock).save(
                        draft,
                        replacing: nil,
                        goal: settings.first?.fastingGoal ?? .default,
                        endingActiveFast: endingActiveFast
                    )
                },
                onClose: { directHistoricalEntry = nil }
            )
        }
        .sheet(item: $contextualReview) { presentation in
            NavigationStack {
                ReviewReconstructionView(
                    generation: presentation.generation,
                    onSave: { reviewed in
                        try makeReconstructionRepository().commit(
                            reviewed: reviewed,
                            expectedGeneration: presentation.generation,
                            range: presentation.range.interval
                        )
                        contextualReview = nil
                    },
                    onRefresh: {
                        refreshContextualReview(presentation)
                    },
                    eyebrow: "Selected day"
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            contextualReview = nil
                        }
                        .accessibilityIdentifier("history.review-suggestions-cancel")
                    }
                }
            }
        }
    }

    private var periodHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("HISTORY")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(UFastTheme.secondaryText)
                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.uFastDisplay(.title))
                    .foregroundStyle(UFastTheme.primary)
                    .accessibilityIdentifier("history.month-heading")
            }
            Spacer()
            Button { isCalendarPresented = true } label: {
                Label("Choose date", systemImage: "calendar")
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Choose a date")
            .accessibilityIdentifier("history.choose-date")
        }
        .padding(.horizontal, UFastTheme.Spacing.standard)
    }

    private var canNavigateForward: Bool {
        calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: clock.now)
    }

    private var isCompletedSelection: Bool {
        calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: clock.now)
    }

    private var historyDates: [Date] {
        historyDayBuffer?.days ?? [calendar.startOfDay(for: selectedDate)]
    }

    private var hasCaloricEvidence: Bool {
        foodEntries.filter(\.isCaloric).count
            + hydrationEntries.filter(\.isCaloric).count >= 2
    }

    private var directAddAlternative: some View {
        Button {
            beginHistoricalEntry(at: defaultHistoricalInstant)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Label("Add at selected time", systemImage: "plus.circle")
                            .fixedSize(horizontal: false, vertical: true)
                        Text(defaultHistoricalInstant, format: .dateTime.hour().minute())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                } else {
                    HStack {
                        Label("Add at selected time", systemImage: "plus.circle")
                        Spacer()
                        Text(defaultHistoricalInstant, format: .dateTime.hour().minute())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(UFastSecondaryButtonStyle())
        .disabled(!temporalMovementPhase.allowsTimelineInteraction)
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .accessibilityHint("Opens native date and time controls before choosing food or drink.")
        .accessibilityIdentifier("history.add-at-selected-time")
    }

    private var contextualReviewButton: some View {
        Button {
            openContextualReview()
        } label: {
            HStack {
                Label("Review suggested fasting periods", systemImage: "sparkles")
                Spacer()
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(UFastActionRowButtonStyle())
        .disabled(!temporalMovementPhase.allowsTimelineInteraction)
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .accessibilityHint("Generates unsaved suggestions from confirmed caloric entries.")
        .accessibilityIdentifier("history.review-suggestions")
    }

    private var defaultHistoricalInstant: Date {
        CatchUpRangeResolver.prefilledInstant(
            on: selectedDate,
            now: clock.now,
            calendar: calendar
        )
    }

    private func historicalDayRange(containing instant: Date) -> Range<Date>? {
        calendar.dateInterval(of: .day, for: instant).map {
            $0.start ..< $0.end
        }
    }

    private func selectedDateBinding(source: TemporalDaySelectionSource) -> Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { selectDay($0, source: source) }
        )
    }

    private func selectDay(_ date: Date, source: TemporalDaySelectionSource) {
        var coordinator = TemporalDaySelectionCoordinator(
            selectedDate: selectedDate,
            calendar: calendar
        )
        guard let change = coordinator.select(date, source: source, calendar: calendar),
              change.day <= calendar.startOfDay(for: clock.now)
        else { return }
        selectedDate = change.day
        if source != .carousel || temporalMovementPhase == .settled {
            ensureHistoryDayCoverage(around: change.day)
        }
    }

    private func navigateDay(_ direction: Int) {
        guard let adjacent = TemporalHistoryPresentation.adjacentDay(
            to: selectedDate,
            direction: direction,
            calendar: calendar
        ) else { return }
        selectDay(adjacent, source: .pager)
    }

    private func updateTemporalMovementPhase(_ phase: TemporalCarouselMovementPhase) {
        temporalMovementPhase = phase
        if phase == .settled {
            ensureHistoryDayCoverage(around: selectedDate)
        }
    }

    private func ensureHistoryDayCoverage(around date: Date) {
        var buffer = historyDayBuffer ?? TemporalDayBuffer(
            centeredOn: date,
            maximumDate: clock.now,
            calendar: calendar
        )
        buffer.ensureCoverage(
            around: date,
            maximumDate: clock.now,
            calendar: calendar
        )
        historyDayBuffer = buffer
    }

    private func beginHistoricalEntry(at instant: Date) {
        let targetDay = calendar.startOfDay(for: instant)
        let today = calendar.startOfDay(for: clock.now)
        guard targetDay < today,
              let end = calendar.date(byAdding: .day, value: 1, to: targetDay)
        else { return }
        selectDay(targetDay, source: .timeline)
        directHistoricalEntry = DirectHistoricalEntryPresentation(
            initialInstant: instant,
            allowedRange: targetDay ..< end
        )
    }

    private func openContextualReview() {
        do {
            let range = try CatchUpRangeResolver.resolve(
                from: selectedDate,
                to: selectedDate,
                now: clock.now,
                calendar: calendar
            )
            let generation = try makeReconstructionRepository().generation(
                range: range.interval
            )
            contextualReviewError = nil
            contextualReview = ContextualReviewPresentation(
                range: range,
                generation: generation
            )
        } catch {
            contextualReviewError = "Suggested periods couldn’t be prepared. Please try again."
        }
    }

    private func refreshContextualReview(_ presentation: ContextualReviewPresentation) {
        guard let generation = try? makeReconstructionRepository().generation(
            range: presentation.range.interval
        ) else { return }
        contextualReview = ContextualReviewPresentation(
            id: presentation.id,
            range: presentation.range,
            generation: generation
        )
    }

    private var ribbonIntervals: [TemporalRibbonIntervalItem] {
        let fasts = completedFasts.compactMap { fast -> TemporalRibbonIntervalItem? in
            guard let end = fast.endDate else { return nil }
            let provenance = provenance(for: fast)
            return TemporalRibbonIntervalItem(
                id: fast.id,
                start: fast.startDate,
                end: end,
                title: provenance.title,
                detail: "\(formatted(fast.startDate)) → \(formatted(end))",
                accessibilityLabel: (fast.origin == .recorded ? "Recorded fast, " : "")
                    + TemporalHistoryPresentation.intervalSummary(
                        provenance: provenance,
                        start: fast.startDate,
                        end: end,
                        context: formattingContext
                    ),
                kind: fast.reviewState == .needsReview
                    ? .needsReview : (fast.origin == .recorded ? .recorded : .reconstructed)
            )
        }
        let unknowns = unknownPeriods.map { unknown in
            TemporalRibbonIntervalItem(
                id: unknown.id,
                start: unknown.startDate,
                end: unknown.endDate,
                title: "Unknown period",
                detail: unknown.reason.explanation,
                accessibilityLabel: TemporalHistoryPresentation.intervalSummary(
                    provenance: .unknown,
                    start: unknown.startDate,
                    end: unknown.endDate,
                    context: formattingContext
                ) + ", \(unknown.reason.explanation)",
                kind: .unknown
            )
        }
        return fasts + unknowns
    }

    private var ribbonEvents: [TemporalRibbonEventItem] {
        let foods = foodEntries.map { food in
            TemporalRibbonEventItem(
                id: food.id,
                occurredAt: food.occurredAt,
                title: food.foodDescription,
                detail: eventDetail(category: "Food", caloric: food.isCaloric, date: food.occurredAt),
                accessibilityLabel: eventAccessibilityLabel(
                    name: food.foodDescription,
                    category: "food",
                    caloric: food.isCaloric,
                    date: food.occurredAt
                ),
                kind: .food
            )
        }
        let drinks = hydrationEntries.map { drink in
            TemporalRibbonEventItem(
                id: drink.id,
                occurredAt: drink.occurredAt,
                title: drink.displayName,
                detail: "\(drink.volumeMillilitres) ml · "
                    + "\(drink.isCaloric ? "Caloric drink" : "Non-caloric drink") · "
                    + formatted(drink.occurredAt),
                accessibilityLabel: "\(drink.displayName), "
                    + "\(drink.volumeMillilitres) millilitres, "
                    + "\(drink.isCaloric ? "caloric drink" : "non-caloric drink"), "
                    + formatted(drink.occurredAt),
                kind: drink.isCaloric ? .caloricDrink : .nonCaloricDrink
            )
        }
        return foods + drinks
    }

    private var formattingContext: TemporalFormattingContext {
        TemporalFormattingContext(locale: locale, calendar: calendar, timeZone: timeZone)
    }

    private func eventDetail(category: String, caloric: Bool, date: Date) -> String {
        "\(category) · \(caloric ? "Caloric" : "Non-caloric") · \(formatted(date))"
    }

    private func eventAccessibilityLabel(
        name: String,
        category: String,
        caloric: Bool,
        date: Date
    ) -> String {
        "\(name), \(category), \(caloric ? "caloric" : "non-caloric"), \(formatted(date))"
    }

    private func provenance(for fast: FastRecord) -> TemporalProvenancePresentation {
        if fast.origin == .recorded {
            return .recorded
        }
        return .reconstructed(
            adjusted: fast.wasAdjustedByUser,
            needsReview: fast.reviewState == .needsReview
        )
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    private func openInterval(_ id: UUID) {
        if let fast = completedFasts.first(where: { $0.id == id }), let end = fast.endDate {
            if fast.origin == .recorded {
                editor = CompletedFastEditorPresentation(id: fast.id, startDate: fast.startDate, endDate: end)
            } else {
                reconstructedDetail = ReconstructedDetailPresentation(fast: fast)
            }
        } else if let unknown = unknownPeriods.first(where: { $0.id == id }) {
            unknownDetail = UnknownDetailPresentation(unknown: unknown)
        }
    }

    private func openEvent(_ id: UUID) {
        if let food = foodEntries.first(where: { $0.id == id }) {
            foodEditor = HistoryFoodEditorPresentation(record: food)
        } else if let drink = hydrationEntries.first(where: { $0.id == id }) {
            hydrationEditor = HistoryHydrationEditorPresentation(record: drink)
        }
    }

    @ViewBuilder
    private func historyRow(_ item: HistoryListItem) -> some View {
        switch item.content {
        case let .fast(fast):
            FastHistoryRow(
                fast: fast,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        case let .unknown(unknown):
            UnknownHistoryRow(
                unknown: unknown,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        }
    }

    private func open(_ item: HistoryListItem) {
        switch item.content {
        case let .fast(fast) where fast.origin == .recorded:
            guard let endDate = fast.endDate else { return }
            editor = CompletedFastEditorPresentation(
                id: fast.id,
                startDate: fast.startDate,
                endDate: endDate
            )
        case let .fast(fast):
            reconstructedDetail = ReconstructedDetailPresentation(fast: fast)
        case let .unknown(unknown):
            unknownDetail = UnknownDetailPresentation(unknown: unknown)
        }
    }

    private func historyIdentifier(_ item: HistoryListItem) -> String {
        switch item.content {
        case .fast: "history.fast.\(item.id.uuidString)"
        case .unknown: "history.unknown.\(item.id.uuidString)"
        }
    }

    private func makeCompletedFastService() -> CompletedFastService {
        CompletedFastService(
            repository: SwiftDataActiveFastRepository(
                modelContext: modelContext,
                simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                    "--simulate-fast-history-failure"
                )
            ),
            clock: clock
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
}

private struct FastHistoryRow: View {
    let fast: FastRecord
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    private var startText: String {
        formatted(fast.startDate)
    }

    private var endText: String {
        fast.endDate.map(formatted) ?? ""
    }

    private var durationText: String {
        ElapsedTimeFormatter.string(from: fast.duration ?? 0)
    }

    private var originText: String {
        fast.origin == .recorded ? "Recorded by you" : "Reconstructed · Confirmed by you"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            if fast.reviewState == .needsReview {
                Label("Needs review", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.error)
            }
            Text(originText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(UFastTheme.action)
            if fast.wasAdjustedByUser {
                Label("Adjusted by you", systemImage: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            HStack(alignment: .top) {
                Text(durationText)
                    .font(.uFastDisplay(.title2))
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
            }
            Divider()
            HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                historyFact("Started", value: startText)
                historyFact("Ended", value: endText)
            }
            if let goal = fast.capturedHistoricalGoal {
                Label("\(goal.hours)-hour historical goal", systemImage: "scope")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
        }
        .uFastCard(accent: fast.origin == .recorded ? UFastTheme.sage : UFastTheme.sky)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var components = fast.origin == .recorded
            ? ["Recorded fast", originText]
            : [originText]
        if fast.reviewState == .needsReview {
            components.insert("Needs review", at: 0)
        }
        if fast.wasAdjustedByUser {
            components.append("Adjusted by you")
        }
        components.append("start \(startText), end \(endText), duration \(durationText)")
        if let goal = fast.capturedHistoricalGoal {
            components.append("goal \(goal.hours) hours")
        }
        return components.joined(separator: ", ")
    }

    private func historyFact(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(UFastTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

private struct UnknownHistoryRow: View {
    let unknown: UnknownPeriodRecord
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            HStack {
                Label("Unknown period", systemImage: "questionmark.circle")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
            }
            Text("\(formatted(unknown.startDate)) → \(formatted(unknown.endDate))")
                .foregroundStyle(UFastTheme.primary)
            Text(unknown.reason.explanation)
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
        }
        .uFastCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Unknown period, start \(formatted(unknown.startDate)), end "
                + "\(formatted(unknown.endDate)), \(unknown.reason.explanation)"
        )
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

private struct HistoryListItem: Identifiable {
    enum Content {
        case fast(FastRecord)
        case unknown(UnknownPeriodRecord)
    }

    let id: UUID
    let endDate: Date
    let kind: HistoryRecordKind
    let content: Content
}

private struct ReconstructedDetailPresentation: Identifiable {
    let fast: FastRecord
    var id: UUID {
        fast.id
    }
}

private struct UnknownDetailPresentation: Identifiable {
    let unknown: UnknownPeriodRecord
    var id: UUID {
        unknown.id
    }
}

private struct HistoryFoodEditorPresentation: Identifiable {
    let record: FoodEntryRecord
    var id: UUID {
        record.id
    }
}

private struct HistoryHydrationEditorPresentation: Identifiable {
    let record: HydrationEntryRecord
    var id: UUID {
        record.id
    }
}

private struct ContextualReviewPresentation: Identifiable {
    let id: UUID
    let range: CatchUpRange
    let generation: ReconstructionGeneration

    init(
        id: UUID = UUID(),
        range: CatchUpRange,
        generation: ReconstructionGeneration
    ) {
        self.id = id
        self.range = range
        self.generation = generation
    }
}

struct CompletedFastEditorPresentation: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
}

#Preview("History · Empty") {
    HistoryView().modelContainer(PreviewFixtures.modelContainer)
}

#Preview("History · Populated") {
    HistoryView().modelContainer(PreviewFixtures.completedFastModelContainer)
}
