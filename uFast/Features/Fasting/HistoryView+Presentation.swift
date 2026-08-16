import SwiftUI

// swiftlint:disable file_length opening_brace

extension HistoryView {
    @ViewBuilder
    var motionUnavailableNotice: some View {
        if motionSnapshot == nil {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                Text("History temporarily unavailable")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Text("Your saved records are still safe on this iPhone. Try loading this runway again.")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
                Button("Try again") {
                    _ = ensureMotionRunway(around: selectedDate)
                }
                .buttonStyle(UFastSecondaryButtonStyle())
                .accessibilityIdentifier("history.motion-retry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .uFastCard()
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .accessibilityIdentifier("history.motion-unavailable")
        } else if !motionFailedEdges.isEmpty {
            HStack(spacing: UFastTheme.Spacing.compact) {
                Text("More history is still available to load.")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
                Spacer()
                Button("Retry") {
                    let failed = motionFailedEdges
                    motionFailedEdges.removeAll()
                    for edge in failed {
                        requestMotionExtension(edge)
                    }
                }
                .buttonStyle(UFastSecondaryButtonStyle())
                .accessibilityIdentifier("history.motion-extension-retry")
            }
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .accessibilityIdentifier("history.motion-extension-unavailable")
        }
    }

    var periodHeader: some View {
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

    var canNavigateForward: Bool {
        calendar.startOfDay(for: selectedDate) < historyDisplayMaximumDay
    }

    var historyDayPresentation: TemporalHistoryDayPresentation {
        TemporalHistoryDayPresentation(
            settledDay: selectedDate,
            liveDay: nil,
            calendar: calendar
        )
    }

    var isFutureSelection: Bool {
        calendar.startOfDay(for: selectedDate) > calendar.startOfDay(for: clock.now)
    }

    var historyDisplayMaximumDay: Date {
        calendar.date(
            byAdding: .day,
            value: Self.futureDisplayDayCount,
            to: calendar.startOfDay(for: clock.now)
        ) ?? calendar.startOfDay(for: clock.now)
    }

    var historyDates: [Date] {
        // Only dates with a complete compact projection are exposed to the
        // native carousel.  Before the initial runway is ready, an empty date
        // list is preferable to mislabelling an unloaded page as empty.
        motionSnapshot?.dates ?? []
    }

    var dateNavigatorDates: [Date] {
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

    var presentedHistorySheetID: String {
        if isCalendarPresented {
            return "calendar"
        }
        if let editor {
            return "fast-\(editor.id)"
        }
        if let inferredConversion {
            return "inferred-\(inferredConversion.id)"
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
        if let eventGroupDisclosure {
            return "group-disclosure-\(eventGroupDisclosure.id.stableValue)"
        }
        return "none"
    }

    var directAddAlternative: some View {
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

    @ViewBuilder
    func fastHistoryDetails(at now: Date) -> some View {
        let visibleFastItems = visibleFastItems(at: now)
        if visibleFastItems.isEmpty {
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
                    eyebrow: "Fasts in this view",
                    message: "Completed fasts will appear here."
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

    var showsSettledHistoryDetails: Bool {
        temporalMovementPhase.showsTimelineDetails && !isDateRailMoving
    }

    var showsFutureReadOnlyAppearance: Bool {
        temporalMovementPhase.showsFutureReadOnlyAppearance && !isDateRailMoving
    }

    var futureReadOnlyNotice: some View {
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

    var defaultHistoricalInstant: Date {
        CatchUpRangeResolver.prefilledInstant(
            on: selectedDate,
            now: clock.now,
            calendar: calendar
        )
    }

    func historicalDayRange(containing instant: Date) -> Range<Date>? {
        calendar.dateInterval(of: .day, for: instant).map {
            $0.start ..< $0.end
        }
    }

    func selectedDateBinding(source: TemporalDaySelectionSource) -> Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { selectDay($0, source: source) }
        )
    }

    func selectDay(_ date: Date, source: TemporalDaySelectionSource) {
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
        // Deliberate date-picker/rail jumps must not expose the target day
        // until its complete target runway has been fetched.  A failed jump
        // leaves the previous selection, exact presentation and motion cache
        // untouched.  Carousel settlement stays on the already loaded runway.
        if source != .carousel,
           !(motionSnapshot?.coverage.contains(change.day, calendar: calendar) ?? false),
           !ensureMotionRunway(around: change.day)
        {
            return
        }
        selectedDate = change.day
        if let window = TemporalHistoryPresentation.ribbonWindow(
            containing: change.day,
            calendar: calendar
        ) {
            settledVisibleWindow = window
            reloadHistory(in: window.interval)
        }
        if source != .carousel || temporalMovementPhase == .settled {
            ensureHistoryDayCoverage(around: change.day)
        }
    }

    func navigateDay(_ direction: Int) {
        guard let adjacent = TemporalHistoryPresentation.adjacentDay(
            to: selectedDate,
            direction: direction,
            calendar: calendar
        ) else { return }
        selectDay(adjacent, source: .pager)
    }

    func updateTemporalMovementPhase(_ phase: TemporalCarouselMovementPhase) {
        temporalMovementPhase = phase
        if phase == .settled {
            ensureHistoryDayCoverage(around: selectedDate)
        }
    }

    func interruptTemporalMotion() {
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

    func updateDateRailMovement(_ isMoving: Bool) {
        isDateRailMoving = isMoving
        if isMoving {
            coupledScrollPresentation.handle(.end)
        }
    }

    func ensureHistoryDayCoverage(around date: Date) {
        // Retained name for the existing motion coordination call sites.  The
        // HS-101 coordinator owns both the loaded dates and projection.
        ensureMotionRunway(around: date)
    }

    func resetToCurrentDayIfSelected() {
        guard isTabSelected else { return }
        selectDay(clock.now, source: .initial)
    }

    func beginHistoricalEntry(
        at instant: Date,
        allowedRangeOverride: Range<Date>? = nil
    ) {
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
        let allowedRange = allowedRangeOverride ?? targetDay ..< end
        guard allowedRange.lowerBound < allowedRange.upperBound else { return }
        let initialInstant = min(
            max(instant, allowedRange.lowerBound),
            allowedRange.upperBound.addingTimeInterval(-1)
        )
        directHistoricalEntry = DirectHistoricalEntryPresentation(
            initialInstant: initialInstant,
            allowedRange: allowedRange
        )
    }

    func beginHistoricalEntry(for group: TemporalEventGroup) {
        guard let range = allowedRange(for: group) else { return }
        let midpoint = group.bucket.start.addingTimeInterval(group.bucket.interval.duration / 2)
        beginHistoricalEntry(
            at: midpoint,
            allowedRangeOverride: range
        )
    }

    func allowedRange(for group: TemporalEventGroup) -> Range<Date>? {
        guard let dayInterval = calendar.dateInterval(of: .day, for: selectedDate) else {
            return nil
        }
        let nowExclusive = calendar.date(byAdding: .second, value: 1, to: clock.now) ?? clock.now
        let lower = max(group.bucket.start, dayInterval.start)
        let upper = min(min(group.bucket.end, dayInterval.end), nowExclusive)
        guard lower < upper else { return nil }
        return lower ..< upper
    }

    func refreshedGroup(
        for original: TemporalEventGroup,
        mutation: HistoryEventGroupMutation
    ) -> TemporalEventGroup? {
        guard let visibleInterval = settledVisibleWindow?.interval
            ?? TemporalHistoryPresentation.calendarDayWindow(
                containing: selectedDate,
                calendar: calendar
            )?.interval
        else { return nil }
        reloadHistoryAfterMutation(in: visibleInterval)
        var presentationCalendar = calendar
        presentationCalendar.timeZone = timeZone
        let groups = TemporalEventGrouping.project(
            (historyPresentation?.events ?? []).map(\.groupingInput),
            in: visibleInterval,
            calendar: presentationCalendar
        ).compactMap(\.group)
        let oldReferences = Set(original.memberReferences)
        return groups.first { refreshed in
            guard refreshed.family == original.family,
                  refreshed.presentationCategory == original.presentationCategory,
                  refreshed.bucket == original.bucket
            else {
                return false
            }
            let refreshedReferences = Set(refreshed.memberReferences)
            switch mutation {
            case let .saved(reference):
                return reference.family == original.family
                    && oldReferences.contains(reference)
                    && oldReferences.isSubset(of: refreshedReferences)
            case let .deleted(reference):
                guard reference.family == original.family else { return false }
                return oldReferences.subtracting([reference]).isSubset(of: refreshedReferences)
            }
        }
    }

    func refreshGroupSurface(
        for original: TemporalEventGroup,
        mutation: HistoryEventGroupMutation
    ) -> TemporalEventGroup? {
        guard let refreshed = refreshedGroup(for: original, mutation: mutation) else {
            eventGroupDisclosure = nil
            return nil
        }
        eventGroupDisclosure = refreshed
        return refreshed
    }

    func openInterval(_ id: UUID) {
        if activeFasts.contains(where: { $0.id == id }) {
            onSelectToday()
            return
        }
        if let inferred = liveHistoryPresentation?.fastItems.first(where: { $0.id == id }),
           inferred.kind == .inferred,
           let interval = inferred.inferredInterval
        {
            inferredConversion = InferredFastConversionPresentation(interval: interval)
            return
        }
        if let interval = motionSnapshot?.presentation.inferredInterval(for: id, at: clock.now) {
            inferredConversion = InferredFastConversionPresentation(interval: interval)
            return
        }
        if let fast = completedFasts.first(where: { $0.id == id }), let end = fast.endDate {
            if fast.origin == .recorded {
                editor = CompletedFastEditorPresentation(id: fast.id, startDate: fast.startDate, endDate: end)
            }
        }
    }

    func openVisibleFast(_ item: HistoryVisibleFastItem) {
        if item.kind == .active {
            onSelectToday()
            return
        }
        if item.kind == .inferred, let interval = item.inferredInterval {
            inferredConversion = InferredFastConversionPresentation(interval: interval)
            return
        }
        guard item.kind == .recorded,
              let fast = item.fast,
              let endDate = fast.endDate
        else { return }
        editor = CompletedFastEditorPresentation(id: fast.id, startDate: fast.startDate, endDate: endDate)
    }

    func openEvent(_ id: UUID) {
        if let food = foodEntries.first(where: { $0.id == id }) {
            foodEditor = HistoryFoodEditorPresentation(record: food)
        } else if let drink = hydrationEntries.first(where: { $0.id == id }) {
            hydrationEditor = HistoryHydrationEditorPresentation(record: drink)
        }
    }
}
