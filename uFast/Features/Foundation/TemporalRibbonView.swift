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
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.timeZone) private var timeZone

    let dates: [Date]
    @Binding var selection: Date
    var selectedRange: Range<Date>?
    var maximumDate: Date?
    var readOnlyAfterDate: Date?
    var automaticScrollEnabled = true
    var coupledPresentation: TemporalCoupledScrollPresentation?
    var onDirectScrollPhaseChange: (Bool) -> Void = { _ in }

    @State private var isDirectlyScrolling = false
    @State private var measuredChipStride: CGFloat = 57
    @State private var selectedChipMidX: CGFloat?
    @State private var navigatorWidth: CGFloat = 0
    @State private var coupledAnchorX: CGFloat?

    var body: some View {
        ScrollViewReader { proxy in
            let coupledPreview = coupledPresentation?.preview
            ZStack {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 5) {
                        ForEach(dates, id: \.self) { date in
                            dateChip(date)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .opacity(coupledPreview == nil ? 1 : 0)
                .onScrollPhaseChange { _, newPhase in
                    let isUserDriven = newPhase == .tracking
                        || newPhase == .interacting
                        || newPhase == .decelerating
                    guard isUserDriven != isDirectlyScrolling else { return }
                    isDirectlyScrolling = isUserDriven
                    onDirectScrollPhaseChange(isUserDriven)
                }
                .onAppear {
                    keepSelectedChipVisible(using: proxy)
                }
                .onChange(of: selection) { _, _ in
                    keepSelectedChipVisible(using: proxy)
                    coupledPresentation?.finishReconciliation()
                }
                .onChange(of: dates) { _, _ in
                    keepSelectedChipVisible(using: proxy)
                }
                .onChange(of: automaticScrollEnabled) { _, isEnabled in
                    guard isEnabled else { return }
                    keepSelectedChipVisible(using: proxy)
                }

                if let coupledPreview {
                    coupledFollower(coupledPreview)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: navigatorHeight)
            .coordinateSpace(name: TemporalDateNavigatorCoordinateSpace.name)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TemporalDateNavigatorWidthKey.self,
                        value: geometry.size.width
                    )
                }
            }
            .onChange(of: coupledPreview != nil) { _, isCoupled in
                if isCoupled {
                    coupledAnchorX = coupledAnchorX ?? selectedChipMidX
                } else {
                    coupledAnchorX = nil
                }
            }
        }
        .onPreferenceChange(TemporalDateChipStrideKey.self) { stride in
            guard stride > 0 else { return }
            measuredChipStride = stride
        }
        .onPreferenceChange(TemporalSelectedDateChipMidXKey.self) { midX in
            guard let midX else { return }
            selectedChipMidX = midX
        }
        .onPreferenceChange(TemporalDateNavigatorWidthKey.self) { width in
            guard width > 0 else { return }
            navigatorWidth = width
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
        let isReadOnly = readOnlyAfterDate.map {
            calendar.startOfDay(for: date) > calendar.startOfDay(for: $0)
        } ?? false
        let accessibilityValue = dateChipAccessibilityValue(
            isSelected: isSelected,
            isInRange: isInRange,
            isSelectable: isSelectable,
            isReadOnly: isReadOnly
        )
        return Button { selection = date } label: {
            VStack(spacing: 4) {
                Text(weekday(date))
                    .font(.caption2.weight(.semibold))
                Text(date, format: .dateTime.day())
                    .font(.headline.monospacedDigit())
                dateChipStatus(isSelected: isSelected, isInRange: isInRange)
            }
            .foregroundStyle(isSelected ? UFastTheme.onAction : UFastTheme.primary)
            .frame(width: chipWidth)
            .frame(minHeight: chipHeight)
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
        .accessibilityHint(isReadOnly ? "Future day, history is read only." : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("temporal.date.\(date.timeIntervalSince1970)")
        .id(date)
        .background {
            dateChipGeometry(isSelected: isSelected)
        }
    }

    private func dateChipGeometry(isSelected: Bool) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: TemporalDateChipStrideKey.self,
                    value: proxy.size.width + 5
                )
                .preference(
                    key: TemporalSelectedDateChipMidXKey.self,
                    value: isSelected
                        ? proxy.frame(
                            in: .named(TemporalDateNavigatorCoordinateSpace.name)
                        ).midX
                        : nil
                )
        }
    }

    private func dateChipAccessibilityValue(
        isSelected: Bool,
        isInRange: Bool,
        isSelectable: Bool,
        isReadOnly: Bool
    ) -> String {
        if isSelected, isReadOnly {
            "Selected, Future date, Read only"
        } else if isSelected {
            "Selected"
        } else if isReadOnly {
            "Future date, Read only"
        } else if isInRange {
            "In selected range"
        } else if isSelectable {
            ""
        } else {
            "Future date"
        }
    }

    private func coupledFollower(_ preview: TemporalDaySpaceProgress) -> some View {
        GeometryReader { proxy in
            if let anchorIndex = dates.firstIndex(of: preview.leadingDay),
               dates.indices.contains(anchorIndex + 1),
               dates[anchorIndex + 1] == preview.trailingDay
            {
                let lowerBound = max(0, anchorIndex - 8)
                let upperBound = min(dates.count, anchorIndex + 10)
                let chronologicalDates = Array(dates[lowerBound ..< upperBound])
                let isRightToLeft = layoutDirection == .rightToLeft
                let visibleDates = isRightToLeft
                    ? Array(chronologicalDates.reversed())
                    : chronologicalDates
                let relativeProgress = isRightToLeft
                    ? CGFloat(upperBound - 1 - anchorIndex) - CGFloat(preview.fraction)
                    : CGFloat(anchorIndex - lowerBound) + CGFloat(preview.fraction)
                let anchorX = resolvedCoupledAnchorX(in: proxy.size.width)
                ZStack(alignment: .top) {
                    HStack(spacing: 5) {
                        ForEach(visibleDates, id: \.self) { date in
                            followerChip(date)
                        }
                    }
                    .offset(
                        x: anchorX
                            - (measuredChipStride - 5) / 2
                            - relativeProgress * measuredChipStride
                    )
                    .frame(maxHeight: .infinity)
                    Capsule()
                        .fill(UFastTheme.primary.opacity(0.35))
                        .frame(width: 20, height: 2)
                        .offset(y: 1)
                }
                .clipped()
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(height: navigatorHeight)
    }

    private func followerChip(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        return VStack(spacing: 4) {
            Text(weekday(date))
                .font(.caption2.weight(.semibold))
            Text(date, format: .dateTime.day())
                .font(.headline.monospacedDigit())
            dateChipStatus(isSelected: isSelected, isInRange: false)
        }
        .foregroundStyle(isSelected ? UFastTheme.onAction : UFastTheme.primary)
        .frame(width: measuredChipStride - 5)
        .frame(minHeight: chipHeight)
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

    private var chipWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 112 : 52
    }

    private var chipHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 140 : 58
    }

    private var navigatorHeight: CGFloat {
        chipHeight + 4
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
        proxy.scrollTo(
            selectedChipDate,
            anchor: coupledScrollAnchor ?? .center
        )
    }

    private func resolvedCoupledAnchorX(in width: CGFloat) -> CGFloat {
        guard let anchorX = coupledAnchorX ?? selectedChipMidX,
              anchorX.isFinite,
              anchorX >= 0,
              anchorX <= width
        else {
            return width / 2
        }
        return anchorX
    }

    private var coupledScrollAnchor: UnitPoint? {
        guard let coupledAnchorX,
              navigatorWidth > measuredChipStride - 5
        else { return nil }
        let measuredChipWidth = measuredChipStride - 5
        let scrollableAnchorWidth = navigatorWidth - measuredChipWidth
        let normalizedAnchor = (coupledAnchorX - measuredChipWidth / 2)
            / scrollableAnchorWidth
        return UnitPoint(
            x: min(max(normalizedAnchor, 0), 1),
            y: 0.5
        )
    }
}

struct TemporalHistoryCarousel: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.layoutDirection) private var layoutDirection
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
    let allowsRecordActivation: Bool
    let allowsEmptySelection: Bool
    let showsTimelineDetails: Bool
    let onMovementPhaseChange: (TemporalCarouselMovementPhase) -> Void
    let onCoupledPresentationChange: (TemporalCoupledPresentationUpdate) -> Void

    @State private var centeredDay: Date?
    @State private var movementPhase = TemporalCarouselMovementPhase.settled
    @State private var selectedPageHeight: CGFloat?
    @State private var lowerMotionInFlight = false
    @State private var settledVisibleWindow: TemporalRibbonWindow?
    @State private var geometrySnapshot = TemporalCarouselGeometrySnapshot()

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            dayHeader
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(dates, id: \.self) { date in
                        daySegment(date)
                            .containerRelativeFrame(
                                .horizontal,
                                count: 26,
                                span: 24,
                                spacing: 0
                            )
                            .id(date)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $centeredDay, anchor: .center)
            .frame(height: selectedPageHeight)
            .onPreferenceChange(TemporalSelectedPageHeightKey.self) { height in
                guard height > 0, selectedPageHeight != height else { return }
                selectedPageHeight = height
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .tracking || newPhase == .interacting || newPhase == .decelerating {
                    lowerMotionInFlight = true
                }
                if newPhase != .idle {
                    geometrySnapshot.hasActiveMotion = true
                }
                setMovementPhase(movementPhase(for: newPhase))
                if newPhase == .idle {
                    lowerMotionInFlight = false
                }
            }
            .onScrollGeometryChange(
                for: TemporalContinuousTimelineGeometry.self,
                of: { geometry in
                    TemporalContinuousTimelineGeometry(
                        contentOffset: geometry.contentOffset.x,
                        contentWidth: geometry.contentSize.width,
                        containerWidth: geometry.containerSize.width
                    )
                },
                action: { _, geometry in
                    geometrySnapshot.geometry = geometry
                    let direction = layoutDirection == .rightToLeft
                        ? TemporalHorizontalLayoutDirection.rightToLeft
                        : .leftToRight
                    if movementPhase != .settled,
                       let preview = geometry.centerProgress(
                           days: dates,
                           layoutDirection: direction
                       )
                    {
                        onCoupledPresentationChange(.preview(preview))
                    } else if movementPhase == .settled,
                              geometrySnapshot.hasActiveMotion
                    {
                        settleVisibleGeometry(geometry)
                    }
                }
            )
            .onAppear {
                centeredDay = canonicalSelection
                settledVisibleWindow = TemporalHistoryPresentation.ribbonWindow(
                    containing: canonicalSelection,
                    calendar: calendar
                )
            }
            .onChange(of: centeredDay) { _, newDay in
                if movementPhase == .programmatic,
                   newDay == canonicalSelection
                {
                    setMovementPhase(.settled)
                    return
                }
                guard movementPhase == .settled else { return }
                reconcileAndCommitSelection(newDay)
            }
            .onChange(of: selection) { _, _ in
                if movementPhase == .programmatic {
                    onCoupledPresentationChange(.end)
                }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("History day carousel")
            .accessibilityValue(
                movementPhase == .settled ? "Settled" : "Moving"
            )
            .accessibilityIdentifier("history.day-carousel")

            if let settledVisibleWindow {
                TemporalRibbonView(
                    selectedDate: settledVisibleWindow.selectedDay,
                    intervals: intervals,
                    events: events,
                    onSelectInterval: allowsRecordActivation ? onSelectInterval : nil,
                    onSelectEvent: { id in
                        guard allowsRecordActivation else { return }
                        onSelectEvent(id)
                    },
                    onSelectEmpty: allowsEmptySelection ? onSelectEmpty : nil,
                    onNavigateDay: nil,
                    canNavigateForward: true,
                    accessibilityIdentifierPrefix: "history",
                    showsDayHeader: false,
                    isInteractive: movementPhase.allowsTimelineInteraction
                        && allowsRecordActivation,
                    showsSemanticItems: showsTimelineDetails
                        && movementPhase.showsTimelineDetails,
                    showsVisualRibbon: false,
                    windowOverride: settledVisibleWindow,
                    emptySemanticMessage: "No recorded items in this time window."
                )
            }
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

    private func daySegment(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let canActivateRecord = movementPhase.allowsTimelineInteraction
            && allowsRecordActivation
        let canSelectEmpty = movementPhase.allowsTimelineInteraction
            && allowsEmptySelection
        return TemporalRibbonView(
            selectedDate: date,
            intervals: intervals,
            events: events,
            onSelectInterval: canActivateRecord ? onSelectInterval : nil,
            onSelectEvent: { id in
                guard canActivateRecord else { return }
                onSelectEvent(id)
            },
            onSelectEmpty: canSelectEmpty ? onSelectEmpty : nil,
            onNavigateDay: nil,
            canNavigateForward: true,
            accessibilityIdentifierPrefix: "history",
            showsDayHeader: false,
            isInteractive: canActivateRecord || canSelectEmpty,
            showsSemanticItems: false,
            usesContinuousSurface: true,
            includesSemanticItems: false,
            windowOverride: TemporalHistoryPresentation.calendarDayWindow(
                containing: date,
                calendar: calendar
            )
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
            lowerMotionInFlight ? .aligning : .programmatic
        }
    }

    private func setMovementPhase(_ newPhase: TemporalCarouselMovementPhase) {
        guard newPhase != movementPhase else { return }
        movementPhase = newPhase
        if newPhase == .settled {
            if let geometry = geometrySnapshot.geometry {
                settleVisibleGeometry(geometry)
            } else {
                reconcileAndCommitSelection(centeredDay)
            }
        } else if newPhase == .programmatic {
            onCoupledPresentationChange(.end)
        }
        onMovementPhaseChange(newPhase)
    }

    private func settleVisibleGeometry(_ geometry: TemporalContinuousTimelineGeometry) {
        let direction = layoutDirection == .rightToLeft
            ? TemporalHorizontalLayoutDirection.rightToLeft
            : .leftToRight
        guard let window = geometry.visibleWindow(
            days: dates,
            calendar: calendar,
            layoutDirection: direction
        ) else { return }
        settledVisibleWindow = window
        geometrySnapshot.hasActiveMotion = false
        reconcileAndCommitSelection(window.selectedDay)
    }

    private func resolvedSettledDay(_ day: Date?) -> Date {
        TemporalHistoryPresentation.settledCarouselDay(
            centeredPage: day,
            currentSelection: selection,
            availableDays: dates,
            maximumDate: dates.last ?? selection,
            calendar: calendar
        )
    }

    private func reconcileAndCommitSelection(_ day: Date?) {
        let settledDay = resolvedSettledDay(day)
        guard settledDay != canonicalSelection else {
            onCoupledPresentationChange(.end)
            return
        }
        onCoupledPresentationChange(
            .reconcile(day: settledDay, dates: dates)
        )
        selection = settledDay
    }

    private func alignToExternalSelection() {
        guard dates.contains(canonicalSelection),
              centeredDay != canonicalSelection,
              !movementPhase.suppressesAutomaticAlignment
        else { return }
        settledVisibleWindow = TemporalHistoryPresentation.ribbonWindow(
            containing: canonicalSelection,
            calendar: calendar
        )
        centeredDay = canonicalSelection
    }
}

@Observable
@MainActor
final class TemporalCoupledScrollPresentation {
    private(set) var preview: TemporalDaySpaceProgress?
    private(set) var isReconciling = false

    func handle(_ update: TemporalCoupledPresentationUpdate) {
        switch update {
        case let .preview(preview):
            isReconciling = false
            guard preview != self.preview else { return }
            self.preview = preview
        case let .reconcile(day, dates):
            guard let index = dates.firstIndex(of: day),
                  dates.count > 1
            else {
                finishReconciliation()
                return
            }
            let lowerStride = preview?.lowerPageStride ?? 1
            if dates.indices.contains(index + 1) {
                preview = TemporalDaySpaceProgress(
                    leadingDay: dates[index],
                    trailingDay: dates[index + 1],
                    fraction: 0,
                    lowerPageStride: lowerStride
                )
            } else {
                preview = TemporalDaySpaceProgress(
                    leadingDay: dates[index - 1],
                    trailingDay: dates[index],
                    fraction: 1,
                    lowerPageStride: lowerStride
                )
            }
            isReconciling = true
        case .end:
            finishReconciliation()
        }
    }

    func finishReconciliation() {
        isReconciling = false
        preview = nil
    }
}

enum TemporalCoupledPresentationUpdate {
    case preview(TemporalDaySpaceProgress)
    case reconcile(day: Date, dates: [Date])
    case end
}

private struct TemporalDateChipStrideKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum TemporalDateNavigatorCoordinateSpace {
    static let name = "temporal-date-navigator"
}

private struct TemporalSelectedDateChipMidXKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private struct TemporalDateNavigatorWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TemporalRibbonSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    let isContinuous: Bool

    func body(content: Content) -> some View {
        if isContinuous {
            content
                .padding(.vertical, UFastTheme.Spacing.standard)
                .background(UFastTheme.surface)
                .overlay(alignment: .top) {
                    separator
                }
                .overlay(alignment: .bottom) {
                    separator
                }
        } else {
            content.uFastCard()
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(
                UFastTheme.border.opacity(
                    contrast == .increased ? 1 : 0.72
                )
            )
            .frame(height: contrast == .increased ? 2 : 1)
    }
}

@MainActor
private final class TemporalCarouselGeometrySnapshot {
    var geometry: TemporalContinuousTimelineGeometry?
    var hasActiveMotion = false
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
    var showsSemanticItems = true
    var usesContinuousSurface = false
    var showsVisualRibbon = true
    var includesSemanticItems = true
    var windowOverride: TemporalRibbonWindow?
    var emptySemanticMessage = "No recorded items for this date."

    private var window: TemporalRibbonWindow? {
        windowOverride
            ?? TemporalHistoryPresentation.ribbonWindow(
                containing: selectedDate,
                calendar: calendar
            )
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
                if showsVisualRibbon {
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
                }
                if includesSemanticItems {
                    semanticItems(window)
                        .opacity(showsSemanticItems ? 1 : 0)
                        .allowsHitTesting(showsSemanticItems)
                        .accessibilityHidden(!showsSemanticItems)
                }
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
        .modifier(
            TemporalRibbonSurfaceModifier(
                isContinuous: usesContinuousSurface
            )
        )
        .accessibilityIdentifier("temporal.ribbon")
    }

    private func ribbonBackground(window: TemporalRibbonWindow, width: Double) -> some View {
        ZStack(alignment: .topLeading) {
            if usesContinuousSurface {
                Rectangle()
                    .fill(UFastTheme.formSurface)
            } else {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .fill(UFastTheme.formSurface)
            }
            ForEach(axisMarkers(window), id: \.self) { marker in
                let markerX = width * window.fraction(for: marker)
                Rectangle()
                    .fill(calendar.isDate(marker, inSameDayAs: window.selectedDay)
                        ? UFastTheme.action.opacity(0.5) : UFastTheme.border)
                    .frame(width: 1, height: 160)
                    .offset(x: markerX, y: 32)
                axisMark(marker)
                    .frame(
                        width: 64,
                        height: 30,
                        alignment: .topLeading
                    )
                    .position(
                        x: min(max(32, markerX), max(32, width - 32)),
                        y: 23
                    )
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
                Text(emptySemanticMessage)
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
        let intradayMarkers = [6, 12, 18].compactMap { hour in
            localTime(hour: hour, on: window.selectedDay)
        }
        return Array(Set(window.midnightMarkers + intradayMarkers))
            .filter { $0 > window.interval.start && $0 < window.interval.end }
            .sorted()
    }

    private func localTime(hour: Int, on date: Date) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
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
