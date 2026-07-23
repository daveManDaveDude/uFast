import SwiftUI

// swiftlint:disable opening_brace

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length type_body_length

struct TemporalRibbonIntervalItem: Identifiable {
    enum Kind: Equatable {
        case recorded
        case reconstructed
        case needsReview
        case unknown
    }

    let id: UUID
    let start: Date
    let end: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let kind: Kind
}

struct TemporalRibbonEventItem: Identifiable {
    enum Kind: Equatable {
        case food
        case caloricDrink
        case nonCaloricDrink
    }

    let id: UUID
    let occurredAt: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let kind: Kind
}

struct TemporalDateNavigator: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    let dates: [Date]
    @Binding var selection: Date
    var selectedRange: Range<Date>?
    var maximumDate: Date?
    var automaticScrollEnabled = true

    @State private var isDirectlyScrolling = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 5) {
                    ForEach(dates, id: \.self) { date in
                        dateChip(date)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, newPhase in
                isDirectlyScrolling = newPhase.isScrolling
            }
            .onAppear {
                keepSelectedChipVisible(using: proxy)
            }
            .onChange(of: selection) { _, _ in
                keepSelectedChipVisible(using: proxy)
            }
            .onChange(of: dates) { _, _ in
                keepSelectedChipVisible(using: proxy)
            }
            .onChange(of: automaticScrollEnabled) { _, isEnabled in
                guard isEnabled else { return }
                keepSelectedChipVisible(using: proxy)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Date navigator")
        .accessibilityIdentifier("temporal.date-navigator")
    }

    private var selectedChipDate: Date? {
        dates.first { calendar.isDate($0, inSameDayAs: selection) }
    }

    private func dateChip(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isInRange = selectedRange?.contains(date) == true
        let isSelectable = maximumDate.map {
            calendar.startOfDay(for: date) <= calendar.startOfDay(for: $0)
        } ?? true
        let accessibilityValue = if isSelected {
            "Selected"
        } else if isInRange {
            "In selected range"
        } else if isSelectable {
            ""
        } else {
            "Future date"
        }
        return Button { selection = date } label: {
            VStack(spacing: 4) {
                Text(weekday(date))
                    .font(.caption2.weight(.semibold))
                Text(date, format: .dateTime.day())
                    .font(.headline.monospacedDigit())
                dateChipStatus(isSelected: isSelected, isInRange: isInRange)
            }
            .foregroundStyle(isSelected ? UFastTheme.onAction : UFastTheme.primary)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 82 : 52)
            .frame(minHeight: 58)
            .background(isSelected ? UFastTheme.action : UFastTheme.raisedSurface)
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .stroke(
                        isSelected ? UFastTheme.primary : UFastTheme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .opacity(isSelectable ? 1 : 0.45)
        .accessibilityLabel(fullDate(date))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("temporal.date.\(date.timeIntervalSince1970)")
        .id(date)
    }

    @ViewBuilder
    private func dateChipStatus(isSelected: Bool, isInRange: Bool) -> some View {
        if isSelected {
            Text("Selected")
                .font(.system(size: 8, weight: .bold))
                .lineLimit(1)
        } else {
            Circle()
                .fill(isInRange ? UFastTheme.action : .clear)
                .frame(width: 4, height: 4)
                .accessibilityHidden(true)
        }
    }

    private func weekday(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .omitted,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            ).weekday(.narrow)
        )
    }

    private func fullDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .complete,
                time: .omitted,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    private func keepSelectedChipVisible(using proxy: ScrollViewProxy) {
        guard automaticScrollEnabled,
              !isDirectlyScrolling,
              let selectedChipDate
        else { return }
        proxy.scrollTo(selectedChipDate, anchor: .center)
    }
}

struct TemporalHistoryCarousel: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase

    let dates: [Date]
    @Binding var selection: Date
    let intervals: [TemporalRibbonIntervalItem]
    let events: [TemporalRibbonEventItem]
    let onSelectInterval: (UUID) -> Void
    let onSelectEvent: (UUID) -> Void
    let onSelectEmpty: (Date) -> Void
    let onNavigateDay: (Int) -> Void
    let canNavigateForward: Bool
    let onMovementPhaseChange: (TemporalCarouselMovementPhase) -> Void

    @State private var centeredDay: Date?
    @State private var movementPhase = TemporalCarouselMovementPhase.settled
    @State private var selectedPageHeight: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            dayHeader
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        dayPage(date)
                            .containerRelativeFrame(
                                .horizontal,
                                count: 1,
                                spacing: 12
                            )
                            .id(date)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollPosition(id: $centeredDay, anchor: .center)
            .frame(height: selectedPageHeight)
            .onPreferenceChange(TemporalSelectedPageHeightKey.self) { height in
                guard height > 0, selectedPageHeight != height else { return }
                selectedPageHeight = height
            }
            .onScrollPhaseChange { _, newPhase in
                setMovementPhase(movementPhase(for: newPhase))
            }
            .onAppear {
                centeredDay = canonicalSelection
            }
            .onChange(of: centeredDay) { _, newDay in
                if movementPhase == .programmatic,
                   newDay == canonicalSelection
                {
                    setMovementPhase(.settled)
                    return
                }
                guard movementPhase == .settled else { return }
                commitSelection(newDay)
            }
            .onChange(of: selection) { _, _ in
                alignToExternalSelection()
            }
            .onChange(of: dates) { _, newDates in
                guard newDates.contains(canonicalSelection) else { return }
                alignToExternalSelection()
            }
            .onDisappear {
                setMovementPhase(.settled)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                setMovementPhase(.settled)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("History day carousel")
            .accessibilityValue(
                movementPhase == .settled ? "Settled" : "Moving"
            )
            .accessibilityIdentifier("history.day-carousel")
        }
        .accessibilityAction(named: "Previous day") {
            onNavigateDay(-1)
        }
        .accessibilityAction(named: "Next day") {
            guard canNavigateForward else { return }
            onNavigateDay(1)
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .decrement:
                onNavigateDay(-1)
            case .increment where canNavigateForward:
                onNavigateDay(1)
            default:
                break
            }
        }
    }

    private var canonicalSelection: Date {
        calendar.startOfDay(for: selection)
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            UFastSectionHeading(
                selection.formatted(
                    .dateTime.weekday(.abbreviated).day().month(.abbreviated)
                ),
                eyebrow: "Selected day"
            )
            .accessibilityIdentifier("history.selected-date")
            .accessibilityAction(named: "Previous day") {
                onNavigateDay(-1)
            }
            .accessibilityAction(named: "Next day") {
                guard canNavigateForward else { return }
                onNavigateDay(1)
            }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .decrement:
                    onNavigateDay(-1)
                case .increment where canNavigateForward:
                    onNavigateDay(1)
                default:
                    break
                }
            }
            Spacer()
            Button {
                onNavigateDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")
            .accessibilityIdentifier("history.previous-day")
            Button {
                onNavigateDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canNavigateForward)
            .accessibilityLabel("Next day")
            .accessibilityIdentifier("history.next-day")
        }
    }

    private func dayPage(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isInteractive = isSelected && movementPhase.allowsTimelineInteraction
        return TemporalRibbonView(
            selectedDate: date,
            intervals: intervals,
            events: events,
            onSelectInterval: isInteractive ? onSelectInterval : nil,
            onSelectEvent: { id in
                guard isInteractive else { return }
                onSelectEvent(id)
            },
            onSelectEmpty: isInteractive ? onSelectEmpty : nil,
            onNavigateDay: nil,
            canNavigateForward: true,
            accessibilityIdentifierPrefix: "history",
            showsDayHeader: false,
            isInteractive: isInteractive
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TemporalSelectedPageHeightKey.self,
                    value: isSelected ? proxy.size.height : 0
                )
            }
        }
        .accessibilityHidden(!isSelected)
        .accessibilityIdentifier(
            "history.day-page.\(date.timeIntervalSince1970)"
        )
    }

    private func movementPhase(for scrollPhase: ScrollPhase) -> TemporalCarouselMovementPhase {
        switch scrollPhase {
        case .idle:
            .settled
        case .tracking, .interacting:
            .userDriven
        case .decelerating:
            .decelerating
        case .animating:
            centeredDay == canonicalSelection ? .settled : .programmatic
        }
    }

    private func setMovementPhase(_ newPhase: TemporalCarouselMovementPhase) {
        guard newPhase != movementPhase else { return }
        movementPhase = newPhase
        if newPhase == .settled {
            commitSelection(centeredDay)
        }
        onMovementPhaseChange(newPhase)
    }

    private func commitSelection(_ day: Date?) {
        let settledDay = TemporalHistoryPresentation.settledCarouselDay(
            centeredPage: day,
            currentSelection: selection,
            availableDays: dates,
            maximumDate: dates.last ?? selection,
            calendar: calendar
        )
        guard settledDay != canonicalSelection else { return }
        selection = settledDay
    }

    private func alignToExternalSelection() {
        guard dates.contains(canonicalSelection),
              centeredDay != canonicalSelection,
              !movementPhase.suppressesAutomaticAlignment
        else { return }
        centeredDay = canonicalSelection
    }
}

private struct TemporalSelectedPageHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TemporalRibbonView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    let selectedDate: Date
    let intervals: [TemporalRibbonIntervalItem]
    let events: [TemporalRibbonEventItem]
    let onSelectInterval: ((UUID) -> Void)?
    let onSelectEvent: (UUID) -> Void
    var onSelectEmpty: ((Date) -> Void)?
    var onNavigateDay: ((Int) -> Void)?
    var canNavigateForward = true
    var accessibilityIdentifierPrefix = "history"
    var showsDayHeader = true
    var isInteractive = true

    private var window: TemporalRibbonWindow? {
        TemporalHistoryPresentation.ribbonWindow(containing: selectedDate, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            if showsDayHeader {
                HStack(alignment: .firstTextBaseline) {
                    UFastSectionHeading(
                        selectedDate.formatted(
                            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
                        ),
                        eyebrow: "Selected day"
                    )
                    .accessibilityIdentifier("\(accessibilityIdentifierPrefix).selected-date")
                    Spacer()
                    if onNavigateDay != nil {
                        Button {
                            onNavigateDay?(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Previous day")
                        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).previous-day")
                        Button {
                            onNavigateDay?(1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canNavigateForward)
                        .accessibilityLabel("Next day")
                        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).next-day")
                    }
                }
            }

            if let window {
                if dynamicTypeSize.isAccessibilitySize {
                    Text("Timeline details are listed below.")
                        .font(.body)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 72,
                            alignment: .leading
                        )
                        .uFastCard()
                        .accessibilityHidden(true)
                } else {
                    visualRibbon(window)
                        .accessibilityHidden(true)
                }
                semanticItems(window)
            }
        }
        .accessibilityAction(named: "Previous day") {
            onNavigateDay?(-1)
        }
        .accessibilityAction(named: "Next day") {
            guard canNavigateForward else { return }
            onNavigateDay?(1)
        }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .decrement:
                onNavigateDay?(-1)
            case .increment where canNavigateForward:
                onNavigateDay?(1)
            default:
                break
            }
        }
    }

    private func visualRibbon(_ window: TemporalRibbonWindow) -> some View {
        GeometryReader { proxy in
            let policy = TemporalRibbonGeometry.pagePolicy(
                for: proxy.size.width,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            ZStack(alignment: .topLeading) {
                ribbonBackground(window: window, width: policy.contentWidth)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                selectEmpty(
                                    at: value.location.x,
                                    width: policy.contentWidth,
                                    window: window
                                )
                            }
                    )
                intervalMarks(window: window, policy: policy)
                eventMarks(window: window, width: policy.contentWidth)
            }
            .frame(width: policy.contentWidth, height: ribbonHeight(policy))
            .allowsHitTesting(isInteractive)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 252 : 220)
        .uFastCard()
        .accessibilityIdentifier("temporal.ribbon")
    }

    private func ribbonBackground(window: TemporalRibbonWindow, width: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                .fill(UFastTheme.formSurface)
            ForEach(axisMarkers(window), id: \.self) { marker in
                let markerX = width * window.fraction(for: marker)
                Rectangle()
                    .fill(calendar.isDate(marker, inSameDayAs: window.selectedDay)
                        ? UFastTheme.action.opacity(0.5) : UFastTheme.border)
                    .frame(width: 1, height: 160)
                    .offset(x: markerX, y: 32)
                axisMark(marker)
                    .offset(x: max(4, markerX + 4), y: 8)
            }
        }
    }

    private func intervalMarks(
        window: TemporalRibbonWindow,
        policy: TemporalRibbonGeometry
    ) -> some View {
        let segments = TemporalHistoryPresentation.clip(
            intervals.map { TemporalIntervalInput(id: $0.id, start: $0.start, end: $0.end) },
            to: window
        )
        return ForEach(segments) { segment in
            if let item = intervals.first(where: { $0.id == segment.id }) {
                let startX = policy.contentWidth * segment.startFraction(in: window)
                let endX = policy.contentWidth * segment.endFraction(in: window)
                let markWidth = max(endX - startX, 28)
                Button {
                    onSelectInterval?(item.id)
                } label: {
                    HStack(spacing: 4) {
                        if segment.continuesBefore, markWidth >= 60 {
                            Image(systemName: "chevron.left.2")
                                .accessibilityHidden(true)
                        }
                        Image(systemName: intervalSymbol(item.kind))
                            .accessibilityHidden(true)
                        if markWidth >= 84 {
                            Text(item.title).lineLimit(1)
                        }
                        if segment.continuesAfter, markWidth >= 60 {
                            Image(systemName: "chevron.right.2")
                                .accessibilityHidden(true)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(intervalForeground(item.kind))
                    .padding(.horizontal, 8)
                    .frame(width: markWidth, height: max(44, policy.intervalLaneHeight), alignment: .leading)
                    .background(intervalColour(item.kind))
                    .clipShape(.capsule)
                    .overlay {
                        Capsule()
                            .stroke(intervalStroke(item.kind), style: strokeStyle(item.kind))
                    }
                }
                .buttonStyle(.plain)
                .disabled(onSelectInterval == nil)
                .offset(
                    x: startX,
                    y: 54 + Double(segment.lane) * (policy.intervalLaneHeight + 6)
                )
            }
        }
    }

    private func eventMarks(window: TemporalRibbonWindow, width: Double) -> some View {
        let orderedIDs = TemporalHistoryPresentation.chronological(
            events
                .filter { window.contains($0.occurredAt) }
                .map { TemporalEventOrderingValue(id: $0.id, occurredAt: $0.occurredAt) }
        ).map(\.id)
        let visible = orderedIDs.compactMap { id in events.first { $0.id == id } }
        return ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
            let markerX = width * window.fraction(for: item.occurredAt)
            Button {
                onSelectEvent(item.id)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: eventSymbol(item.kind))
                        .accessibilityHidden(true)
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(eventColour(item.kind))
                        .foregroundStyle(UFastTheme.primary)
                        .clipShape(
                            item.kind == .nonCaloricDrink
                                ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
                        )
                        .overlay {
                            if item.kind == .nonCaloricDrink {
                                Circle().stroke(UFastTheme.action, lineWidth: 1)
                            }
                        }
                    Text(item.occurredAt, format: .dateTime.hour().minute())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(UFastTheme.secondaryText)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .offset(x: min(max(0, markerX - 22), max(0, width - 44)), y: 140 + Double(index % 2) * 30)
        }
    }

    private func selectEmpty(
        at position: Double,
        width: Double,
        window: TemporalRibbonWindow
    ) {
        guard onSelectEmpty != nil,
              case let .empty(instant)? = TemporalHistoryPresentation.ribbonHitTarget(
                  at: position,
                  width: width,
                  window: window,
                  hitRegions: []
              )
        else { return }
        onSelectEmpty?(instant)
    }

    private func semanticItems(_ window: TemporalRibbonWindow) -> some View {
        let visibleIntervals = intervals.filter { $0.end > window.interval.start && $0.start < window.interval.end }
        let visibleEvents = events.filter { window.contains($0.occurredAt) }
        return VStack(spacing: 0) {
            if visibleIntervals.isEmpty, visibleEvents.isEmpty {
                Text("No recorded items for this date.")
                    .foregroundStyle(UFastTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .accessibilityIdentifier("temporal.empty")
            } else {
                ForEach(semanticOrder(intervals: visibleIntervals, events: visibleEvents), id: \.id) { item in
                    if item.isInterval, onSelectInterval == nil {
                        semanticRow(item, showsDisclosure: false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.accessibilityLabel)
                            .accessibilityIdentifier(item.identifier)
                    } else {
                        Button {
                            if item.isInterval {
                                onSelectInterval?(item.id)
                            } else {
                                onSelectEvent(item.id)
                            }
                        } label: {
                            semanticRow(item, showsDisclosure: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isInteractive)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.accessibilityLabel)
                        .accessibilityHint("Opens details and available actions.")
                        .accessibilityIdentifier(item.identifier)
                    }
                    if item.id != semanticOrder(intervals: visibleIntervals, events: visibleEvents).last?.id {
                        Divider()
                    }
                }
            }
        }
        .uFastCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("temporal.semantic-list")
    }

    private func semanticRow(_ item: SemanticItem, showsDisclosure: Bool) -> some View {
        HStack(spacing: UFastTheme.Spacing.standard) {
            Image(systemName: item.symbol)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            Spacer()
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    private func semanticOrder(
        intervals: [TemporalRibbonIntervalItem],
        events: [TemporalRibbonEventItem]
    ) -> [SemanticItem] {
        let intervalValues = intervals.map {
            SemanticItem(
                id: $0.id,
                date: $0.start,
                title: $0.title,
                detail: $0.detail,
                accessibilityLabel: $0.accessibilityLabel,
                symbol: intervalSymbol($0.kind),
                identifier: $0.kind == .unknown
                    ? "\(accessibilityIdentifierPrefix).unknown.\($0.id.uuidString)"
                    : "\(accessibilityIdentifierPrefix).fast.\($0.id.uuidString)",
                isInterval: true
            )
        }
        let eventValues = events.map {
            SemanticItem(
                id: $0.id,
                date: $0.occurredAt,
                title: $0.title,
                detail: $0.detail,
                accessibilityLabel: $0.accessibilityLabel,
                symbol: eventSymbol($0.kind),
                identifier: "\(accessibilityIdentifierPrefix).event.\($0.id.uuidString)",
                isInterval: false
            )
        }
        return (intervalValues + eventValues).sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
    }

    private func axisMarkers(_ window: TemporalRibbonWindow) -> [Date] {
        var markers: [Date] = []
        var cursor = window.interval.start
        while cursor < window.interval.end {
            markers.append(cursor)
            guard let next = calendar.date(byAdding: .hour, value: 6, to: cursor), next > cursor else { break }
            cursor = next
        }
        return Array(Set(markers + window.midnightMarkers)).sorted()
    }

    private func axisMark(_ date: Date) -> some View {
        let isMidnight = calendar.component(.hour, from: date) == 0
            && calendar.component(.minute, from: date) == 0
        return VStack(alignment: .leading, spacing: 0) {
            if isMidnight {
                Text(
                    date.formatted(
                        Date.FormatStyle(
                            date: .omitted,
                            time: .omitted,
                            locale: locale,
                            calendar: calendar,
                            timeZone: timeZone
                        ).day().month(.abbreviated)
                    )
                )
            }
            Text(
                date.formatted(
                    Date.FormatStyle(
                        date: .omitted,
                        time: .shortened,
                        locale: locale,
                        calendar: calendar,
                        timeZone: timeZone
                    )
                )
            )
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(UFastTheme.secondaryText)
    }

    private func ribbonHeight(_ policy: TemporalRibbonGeometry) -> Double {
        max(190, 126 + policy.eventLaneHeight * 2)
    }

    private func intervalSymbol(_ kind: TemporalRibbonIntervalItem.Kind) -> String {
        switch kind {
        case .recorded: "moon.stars.fill"
        case .reconstructed: "wand.and.stars"
        case .needsReview: "exclamationmark.triangle"
        case .unknown: "questionmark.circle"
        }
    }

    private func intervalColour(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        switch kind {
        case .recorded: UFastTheme.sage
        case .reconstructed: UFastTheme.sky
        case .needsReview: UFastTheme.apricot
        case .unknown: UFastTheme.raisedSurface
        }
    }

    private func intervalForeground(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        kind == .needsReview ? UFastTheme.primary : UFastTheme.primary
    }

    private func intervalStroke(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        kind == .unknown ? UFastTheme.secondaryText : UFastTheme.action.opacity(0.5)
    }

    private func strokeStyle(_ kind: TemporalRibbonIntervalItem.Kind) -> StrokeStyle {
        StrokeStyle(lineWidth: kind == .needsReview ? 2 : 1, dash: kind == .unknown ? [5, 4] : [])
    }

    private func eventSymbol(_ kind: TemporalRibbonEventItem.Kind) -> String {
        switch kind {
        case .food: "fork.knife"
        case .caloricDrink: "cup.and.saucer.fill"
        case .nonCaloricDrink: "drop"
        }
    }

    private func eventColour(_ kind: TemporalRibbonEventItem.Kind) -> Color {
        kind == .nonCaloricDrink ? UFastTheme.raisedSurface : UFastTheme.apricot
    }
}

private struct SemanticItem: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let symbol: String
    let identifier: String
    let isInterval: Bool
}

struct TemporalProposalRibbon: View {
    let start: Date
    let end: Date
    let startTitle: String
    let endTitle: String

    var body: some View {
        let accessibilitySummary = "Proposed fast from \(startTitle) at "
            + "\(start.formatted(date: .abbreviated, time: .shortened)) to \(endTitle) at "
            + end.formatted(date: .abbreviated, time: .shortened)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Image(systemName: "fork.knife")
                    .accessibilityHidden(true)
                    .frame(width: 32, height: 32)
                    .background(UFastTheme.apricot)
                    .clipShape(.rect(cornerRadius: 8))
                Rectangle()
                    .fill(UFastTheme.sky)
                    .frame(height: 10)
                    .overlay { Rectangle().stroke(UFastTheme.action.opacity(0.5), lineWidth: 1) }
                Image(systemName: "fork.knife")
                    .accessibilityHidden(true)
                    .frame(width: 32, height: 32)
                    .background(UFastTheme.apricot)
                    .clipShape(.rect(cornerRadius: 8))
            }
            HStack {
                Text(start, style: .time)
                Spacer()
                Text(end, style: .time)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(UFastTheme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}
