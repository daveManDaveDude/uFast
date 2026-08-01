import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command line_length force_unwrapping switch_case_alignment trailing_comma
// swiftlint:disable file_length type_body_length

struct HistoryView: View {
    private static let futureDisplayDayCount = 1
    private static let futureRailContextDayCount = 4

    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeZone) private var timeZone
    @Query(filter: #Predicate<FastRecord> { $0.endDate != nil }) private var completedFasts: [FastRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @Query private var foodEntries: [FoodEntryRecord]
    @Query private var hydrationEntries: [HydrationEntryRecord]
    @Query private var settings: [AppSettingsRecord]
    @State private var editor: CompletedFastEditorPresentation?
    @State private var foodEditor: HistoryFoodEditorPresentation?
    @State private var hydrationEditor: HistoryHydrationEditorPresentation?
    @State private var directHistoricalEntry: DirectHistoricalEntryPresentation?
    @State private var isCalendarPresented = false
    @State private var selectedDate: Date
    @State private var historyDayBuffer: TemporalDayBuffer?
    @State private var temporalMovementPhase = TemporalCarouselMovementPhase.settled
    @State private var coupledScrollPresentation = TemporalCoupledScrollPresentation()
    @State private var historyInteractionRevision = 0
    @State private var isDateRailMoving = false
    @State private var settledVisibleWindow: TemporalRibbonWindow?

    private let clock: any AppClock
    private let isTabSelected: Bool

    init(clock: any AppClock = SystemAppClock(), isTabSelected: Bool = true) {
        self.clock = clock
        self.isTabSelected = isTabSelected
        _selectedDate = State(initialValue: clock.now)
    }

    private var visibleFastItems: [VisibleFastItem] {
        guard let visible = settledVisibleWindow?.interval else { return [] }
        let window = visible.start ..< visible.end
        return timelineFastItems
            .filter { $0.intersects(window) }
            .sorted { $0.startDate < $1.startDate }
    }

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
                        coupledPresentation: coupledScrollPresentation,
                        presentationDay: presentedHistoryDay,
                        onDirectScrollPhaseChange: updateDateRailMovement,
                        onRailSettled: { day in
                            selectDay(day, source: .dateRailSettlement)
                        }
                    )
                    .padding(.horizontal, UFastTheme.Spacing.standard)
                    .allowsHitTesting(!temporalMovementPhase.suppressesAutomaticAlignment)
                    .id(historyInteractionRevision)

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
                        allowsRecordActivation: !isFutureSelection,
                        allowsEmptySelection: !isFutureSelection,
                        showsTimelineDetails: temporalMovementPhase.showsTimelineDetails
                            && !isDateRailMoving,
                        presentationDay: presentedHistoryDay,
                        readOnlyFromDate: clock.now,
                        onMovementPhaseChange: updateTemporalMovementPhase,
                        onCoupledPresentationChange: coupledScrollPresentation.handle,
                        onSettledVisibleWindow: { window in settledVisibleWindow = window }
                    )
                    .padding(.horizontal, UFastTheme.Spacing.standard)
                    .allowsHitTesting(!isDateRailMoving)

                    if isFutureSelection {
                        futureReadOnlyNotice
                    }

                    if !isFutureSelection {
                        directAddAlternative
                    }

                    if visibleFastItems.isEmpty {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                                Text("HISTORY")
                                    .font(.caption.weight(.semibold))
                                    .tracking(1.2)
                                    .foregroundStyle(UFastTheme.secondaryText)
                                Text("No fasts in this view")
                                    .font(.headline)
                                    .foregroundStyle(UFastTheme.primary)
                                Text("Fasts appear automatically between caloric events more than eight hours apart.")
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
                                title: "No fasts in this view",
                                eyebrow: "Fasts in this view",
                                message: "Fasts appear automatically between caloric events more than eight hours apart."
                            ) {
                                FastingBotanicalArtwork()
                            }
                            .padding(UFastTheme.Spacing.standard)
                            .accessibilityIdentifier("history.empty")
                        }
                    } else {
                        UFastSectionHeading("Fasts in this view", eyebrow: "Details")
                            .padding(.horizontal, UFastTheme.Spacing.standard)
                        LazyVStack(spacing: 12) {
                            ForEach(visibleFastItems) { item in
                                Button { openVisibleFast(item) } label: {
                                    VisibleFastHistoryRow(item: item, calendar: calendar, locale: locale, timeZone: timeZone)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history.fast.\(item.id.uuidString)")
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
            resetToCurrentDayIfSelected()
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
            guard phase != .active else { return }
            interruptTemporalMotion()
        }
        .onChange(of: presentedHistorySheetID) { _, sheetID in
            guard sheetID != "none" else { return }
            interruptTemporalMotion()
        }
        .onChange(of: historyContentRevision) { _, _ in
            interruptTemporalMotion()
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
    }

    private var periodHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("HISTORY")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(UFastTheme.secondaryText)
                Text(historyDayPresentation.visualDay, format: .dateTime.month(.wide).year())
                    .font(.uFastDisplay(.title))
                    .foregroundStyle(UFastTheme.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "History, \(historyDayPresentation.settledDay.formatted(.dateTime.month(.wide).year()))"
            )
            .accessibilityIdentifier("history.month-heading")
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
        calendar.startOfDay(for: selectedDate) < historyDisplayMaximumDay
    }

    /// A visual-only day during lower-carousel motion. Semantic selection stays
    /// settled until native scrolling reaches idle.
    private var presentedHistoryDay: Date {
        coupledScrollPresentation.liveCenteredDay ?? selectedDate
    }

    private var historyDayPresentation: TemporalHistoryDayPresentation {
        TemporalHistoryDayPresentation(
            settledDay: selectedDate,
            liveDay: coupledScrollPresentation.liveCenteredDay,
            calendar: calendar
        )
    }

    private var isCompletedSelection: Bool {
        calendar.startOfDay(for: selectedDate) < calendar.startOfDay(for: clock.now)
    }

    private var isFutureSelection: Bool {
        calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: clock.now)
    }

    private var historyDisplayMaximumDay: Date {
        calendar.date(
            byAdding: .day,
            value: Self.futureDisplayDayCount,
            to: calendar.startOfDay(for: clock.now)
        ) ?? calendar.startOfDay(for: clock.now)
    }

    private var historyDates: [Date] {
        historyDayBuffer?.days ?? [calendar.startOfDay(for: selectedDate)]
    }

    private var dateNavigatorDates: [Date] {
        let today = calendar.startOfDay(for: clock.now)
        guard let finalContextDay = calendar.date(
            byAdding: .day,
            value: Self.futureRailContextDayCount,
            to: today
        ),
            let lastHistoryDay = historyDates.last,
            lastHistoryDay < finalContextDay
        else { return historyDates }

        var dates = historyDates
        var nextDay = lastHistoryDay
        while nextDay < finalContextDay {
            guard let followingDay = calendar.date(byAdding: .day, value: 1, to: nextDay) else {
                break
            }
            dates.append(followingDay)
            nextDay = followingDay
        }
        return dates
    }

    private var presentedHistorySheetID: String {
        if isCalendarPresented {
            return "calendar"
        }
        if let editor {
            return "fast-\(editor.id)"
        }
        if let foodEditor {
            return "food-\(foodEditor.id)"
        }
        if let hydrationEditor {
            return "drink-\(hydrationEditor.id)"
        }
        if let directHistoricalEntry {
            return "add-\(directHistoricalEntry.id)"
        }
        return "none"
    }

    private var historyContentRevision: String {
        let fasts = (completedFasts + activeFasts).map {
            "\($0.id):\($0.startDate.timeIntervalSinceReferenceDate):"
                + "\($0.endDate?.timeIntervalSinceReferenceDate ?? 0):\($0.reviewStateRaw)"
        }
        let foods = foodEntries.map {
            "\($0.id):\($0.occurredAt.timeIntervalSinceReferenceDate)"
        }
        let drinks = hydrationEntries.map {
            "\($0.id):\($0.occurredAt.timeIntervalSinceReferenceDate):\($0.isCaloric)"
        }
        return (fasts + foods + drinks).sorted().joined(separator: "|")
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

    private var futureReadOnlyNotice: some View {
        Label(
            "Future day · History is read only",
            systemImage: "calendar.badge.clock"
        )
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(UFastTheme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .accessibilityHint("Return to a completed day to add or repair history.")
        .accessibilityIdentifier("history.future-read-only")
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
        if source != .carousel {
            if temporalMovementPhase != .settled || isDateRailMoving {
                interruptTemporalMotion()
            } else {
                coupledScrollPresentation.handle(.end)
            }
        }
        var coordinator = TemporalDaySelectionCoordinator(
            selectedDate: selectedDate,
            calendar: calendar
        )
        guard let change = coordinator.select(date, source: source, calendar: calendar),
              change.day <= historyDisplayMaximumDay
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

    private func interruptTemporalMotion() {
        guard temporalMovementPhase != .settled
            || isDateRailMoving
            || coupledScrollPresentation.preview != nil
            || coupledScrollPresentation.isReconciling
        else { return }
        coupledScrollPresentation.handle(.end)
        temporalMovementPhase = .settled
        isDateRailMoving = false
        historyInteractionRevision += 1
        ensureHistoryDayCoverage(around: selectedDate)
    }

    private func updateDateRailMovement(_ isMoving: Bool) {
        isDateRailMoving = isMoving
        if isMoving {
            coupledScrollPresentation.handle(.end)
        }
    }

    private func ensureHistoryDayCoverage(around date: Date) {
        var buffer = historyDayBuffer ?? TemporalDayBuffer(
            centeredOn: date,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        )
        buffer.ensureCoverage(
            around: date,
            maximumDate: historyDisplayMaximumDay,
            calendar: calendar
        )
        historyDayBuffer = buffer
    }

    private func resetToCurrentDayIfSelected() {
        guard isTabSelected else { return }
        selectDay(clock.now, source: .initial)
    }

    private func beginHistoricalEntry(at instant: Date) {
        let targetDay = calendar.startOfDay(for: instant)
        guard TemporalHistoryPresentation.allowsHistoricalEntry(
            at: instant,
            now: clock.now,
            calendar: calendar
        ),
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: targetDay)
        else { return }
        selectDay(targetDay, source: .timeline)
        // `allowedRange` is half-open while the editor's picker exposes its
        // upper bound inclusively. Use Calendar arithmetic so an instant equal
        // to now remains valid without offering a future time.
        let nowExclusiveEnd = calendar.date(byAdding: .second, value: 1, to: clock.now) ?? clock.now
        let end = min(dayEnd, nowExclusiveEnd)
        guard instant < end else { return }
        directHistoricalEntry = DirectHistoricalEntryPresentation(
            initialInstant: instant,
            allowedRange: targetDay ..< end
        )
    }

    private var ribbonIntervals: [TemporalRibbonIntervalItem] {
        timelineFastItems.map { fast in
            TemporalRibbonIntervalItem(
                id: fast.id, start: fast.startDate, end: fast.endDate,
                title: fast.title, detail: fast.detail(context: formattingContext),
                accessibilityLabel: fast.accessibilityLabel(context: formattingContext), kind: fast.ribbonKind
            )
        }
    }

    private var ribbonEvents: [TemporalRibbonEventItem] {
        let foods = foodEntries.map { food in
            TemporalRibbonEventItem(
                id: food.id,
                occurredAt: food.occurredAt,
                title: food.foodDescription,
                detail: foodEventDetail(food),
                accessibilityLabel: eventAccessibilityLabel(
                    name: food.foodDescription,
                    category: "food",
                    caloric: food.isCaloric,
                    date: food.occurredAt, nutrition: food.nutrition
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

    private var timelineFastItems: [VisibleFastItem] {
        let projectionWindow = timelineProjectionInterval
        let boundaries = CaloricBoundaryExtractor.boundaries(
            food: foodEntries.map { .init(id: $0.id, occurredAt: $0.occurredAt, description: $0.foodDescription, isCaloric: $0.isCaloric) },
            hydration: hydrationEntries.map { .init(id: $0.id, occurredAt: $0.occurredAt, description: $0.displayName, isCaloric: $0.isCaloric) }
        )
        let recorded = completedFasts.compactMap { fast -> VisibleFastItem? in
            guard fast.origin == .recorded, let end = fast.endDate,
                  AutomaticFastProjector.intersects(fast.startDate ..< end, projectionWindow)
            else { return nil }
            return VisibleFastItem.recorded(fast)
        }
        let active = activeFasts.compactMap { fast -> VisibleFastItem? in
            guard fast.startDate < clock.now,
                  AutomaticFastProjector.intersects(fast.startDate ..< clock.now, projectionWindow)
            else { return nil }
            return VisibleFastItem.active(fast, endingAt: clock.now)
        }
        let legacy = completedFasts.compactMap { fast -> VisibleFastItem? in
            guard fast.origin == .reconstructed, let end = fast.endDate,
                  !AutomaticFastProjector.isReproducibleLegacy(
                      startDate: fast.startDate, endDate: end, boundaries: fast.boundaryPair, caloricBoundaries: boundaries
                  ), AutomaticFastProjector.intersects(fast.startDate ..< end, projectionWindow),
                  !recorded.contains(where: { $0.intersects(fast.startDate ..< end) })
            else { return nil }
            return VisibleFastItem.previouslySaved(fast)
        }
        let automatic = AutomaticFastProjector.project(
            boundaries: boundaries, visibleInterval: projectionWindow,
            excluding: (completedFasts + activeFasts)
                .filter { $0.origin == .recorded }
                .map(\.recordedInterval)
        ).compactMap { interval -> VisibleFastItem? in
            guard !legacy.contains(where: { $0.intersects(interval.interval) }) else { return nil }
            return VisibleFastItem.automatic(interval)
        }
        return recorded + active + legacy + automatic
    }

    private var timelineProjectionInterval: Range<Date> {
        let start = historyDates.first ?? calendar.startOfDay(for: selectedDate)
        let lastDay = historyDates.last ?? start
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay)
            ?? lastDay.addingTimeInterval(24 * 60 * 60)
        return start ..< end
    }

    private func eventDetail(category: String, caloric: Bool, date: Date) -> String {
        "\(category) · \(caloric ? "Caloric" : "Non-caloric") · \(formatted(date))"
    }

    private func eventAccessibilityLabel(
        name: String,
        category: String,
        caloric: Bool,
        date: Date,
        nutrition: FoodNutrition? = nil
    ) -> String {
        let nutritionValues = nutrition.flatMap(nutritionDetail).map { [$0] } ?? []
        return (["\(name), \(category), \(caloric ? "caloric" : "non-caloric"), \(formatted(date))"]
            + nutritionValues).joined(separator: ", ")
    }

    private func foodEventDetail(_ food: FoodEntryRecord) -> String {
        let nutritionValues = nutritionDetail(food.nutrition).map { [$0] } ?? []
        return ([eventDetail(category: "Food", caloric: food.isCaloric, date: food.occurredAt)]
            + nutritionValues).joined(separator: " · ")
    }

    private func nutritionDetail(_ nutrition: FoodNutrition) -> String? {
        let values: [(String, Double?)] = [
            ("Energy", nutrition.energyKilocalories), ("Protein", nutrition.proteinGrams),
            ("Carbohydrate", nutrition.carbohydrateGrams), ("Fat", nutrition.fatGrams),
            ("Fibre", nutrition.fibreGrams), ("Sugar", nutrition.sugarGrams), ("Salt", nutrition.saltGrams),
        ]
        let parts = values.compactMap { label, value -> String? in
            guard let value else { return nil }
            let unit = label == "Energy" ? "kcal" : "g"
            return "\(label) \(value.formatted()) \(unit)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
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
            }
        }
    }

    private func openVisibleFast(_ item: VisibleFastItem) {
        guard item.kind == .recorded,
              let fast = item.fast,
              let endDate = fast.endDate
        else { return }
        editor = CompletedFastEditorPresentation(id: fast.id, startDate: fast.startDate, endDate: endDate)
    }

    private func openEvent(_ id: UUID) {
        if let food = foodEntries.first(where: { $0.id == id }) {
            foodEditor = HistoryFoodEditorPresentation(record: food)
        } else if let drink = hydrationEntries.first(where: { $0.id == id }) {
            hydrationEditor = HistoryHydrationEditorPresentation(record: drink)
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

private struct VisibleFastItem: Identifiable {
    enum Kind { case recorded, active, automatic, previouslySaved }

    let id: UUID
    let startDate: Date
    let endDate: Date
    let kind: Kind
    let fast: FastRecord?

    static func recorded(_ fast: FastRecord) -> Self {
        Self(id: fast.id, startDate: fast.startDate, endDate: fast.endDate ?? fast.startDate, kind: .recorded, fast: fast)
    }

    static func active(_ fast: FastRecord, endingAt endDate: Date) -> Self {
        Self(id: fast.id, startDate: fast.startDate, endDate: endDate, kind: .active, fast: fast)
    }

    static func previouslySaved(_ fast: FastRecord) -> Self {
        Self(id: fast.id, startDate: fast.startDate, endDate: fast.endDate ?? fast.startDate, kind: .previouslySaved, fast: fast)
    }

    static func automatic(_ interval: AutomaticFastInterval) -> Self {
        // The start boundary has exactly one consecutive successor, making this
        // a deterministic rendering key while the typed pair remains the
        // domain identity.
        Self(
            id: interval.identity.boundaries.start.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .automatic,
            fast: nil
        )
    }

    var title: String {
        switch kind {
        case .recorded, .active: "Started fast"
        case .automatic: "Fast"
        case .previouslySaved: "Previously saved fast"
        }
    }

    var ribbonKind: TemporalRibbonIntervalItem.Kind {
        switch kind {
        case .recorded, .active: .recorded
        case .automatic: .automatic
        case .previouslySaved: .previouslySaved
        }
    }

    func intersects(_ interval: Range<Date>) -> Bool {
        AutomaticFastProjector.intersects(startDate ..< endDate, interval)
    }

    func detail(context _: TemporalFormattingContext) -> String {
        "\(startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())) → \(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())) · \(ElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate)))"
    }

    func accessibilityLabel(context _: TemporalFormattingContext) -> String {
        "\(title), start \(startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())), end \(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())), duration \(ElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate)))"
    }
}

private struct VisibleFastHistoryRow: View {
    let item: VisibleFastItem
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Text(item.title).font(.headline).foregroundStyle(UFastTheme.primary)
            Text(ElapsedTimeFormatter.string(from: item.endDate.timeIntervalSince(item.startDate)))
                .font(.uFastDisplay(.title2)).foregroundStyle(UFastTheme.primary)
            Divider()
            HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                fact("Started", item.startDate)
                fact("Ended", item.endDate)
            }
        }
        .uFastCard(accent: item.kind == .recorded || item.kind == .active ? UFastTheme.sage : UFastTheme.sky)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel(context: .init(locale: locale, calendar: calendar, timeZone: timeZone)))
    }

    private func fact(_ label: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.subheadline.weight(.semibold)).foregroundStyle(UFastTheme.primary)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
