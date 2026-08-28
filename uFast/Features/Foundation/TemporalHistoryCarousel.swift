import SwiftUI

// swiftlint:disable function_body_length opening_brace file_length

private struct TemporalAppearedSegmentDatesKey: PreferenceKey {
    static let defaultValue: [Date] = []

    static func reduce(value: inout [Date], nextValue: () -> [Date]) {
        value.append(contentsOf: nextValue())
    }
}

struct TemporalHistoryCarousel: View {
    @Environment(\.calendar) var calendar
    @Environment(\.appTextResolver) var textResolver
    @Environment(\.layoutDirection) var layoutDirection
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let dates: [Date]
    @Binding var selection: Date
    let intervals: [TemporalRibbonIntervalItem]
    let events: [TemporalRibbonEventItem]
    let motionIntervals: [TemporalRibbonIntervalItem]
    let motionEvents: [TemporalRibbonEventItem]
    let onSelectInterval: (UUID) -> Void
    let onSelectEvent: (UUID) -> Void
    var onSelectEventGroup: ((TemporalEventGroup) -> Void)?
    let onSelectEmpty: (Date) -> Void
    var allowsAddAtCenter = false
    let onNavigateDay: (Int) -> Void
    let canNavigateForward: Bool
    let allowsRecordActivation: Bool
    let allowsEmptySelection: Bool
    let showsTimelineDetails: Bool
    var presentationDay: Date?
    var readOnlyFromDate: Date?
    let onMovementPhaseChange: (TemporalCarouselMovementPhase) -> Void
    var onCoupledPresentationChange: (TemporalCoupledPresentationUpdate) -> Void = { _ in }
    var onSettledVisibleWindow: (TemporalRibbonWindow) -> Void = { _ in }
    var onPrefetchIntent: (HistoryMotionEdge) -> Void = { _ in }
    var onPrefetchIntentAt: (HistoryMotionEdge, Date) -> Void = { _, _ in }

    @State var centeredDay: Date?
    @State var movementPhase = TemporalCarouselMovementPhase.settled
    @State var selectedPageHeight: CGFloat?
    @State var lowerMotionInFlight = false
    @State var settledVisibleWindow: TemporalRibbonWindow?
    @State var geometrySnapshot = TemporalCarouselGeometrySnapshot()
    @State var prefetchedEdges: Set<HistoryMotionEdge> = []
    @State var viewportWidth: Double = 0
    @State var measuredContentWidth: Double = 0
    @State var measuredDayStride: Double = 0
    @State var appearedSegmentDates: Set<Date> = []

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
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TemporalCarouselContentLayoutKey.self,
                            value: TemporalCarouselContentLayout(
                                contentWidth: proxy.size.width,
                                dayStride: dates.isEmpty
                                    ? 0
                                    : proxy.size.width / CGFloat(dates.count)
                            )
                        )
                    }
                }
                .overlay(alignment: .topLeading) { labelLayer }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $centeredDay, anchor: .center)
            .frame(height: selectedPageHeight)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TemporalCarouselViewportWidthKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .onPreferenceChange(TemporalAppearedSegmentDatesKey.self) { dates in
                let newlyAppearedDates = Set(dates).subtracting(appearedSegmentDates)
                guard !newlyAppearedDates.isEmpty else { return }
                for date in newlyAppearedDates {
                    HistoryLabelWorkProbe.recordAppearedSegment(date)
                }
                appearedSegmentDates.formUnion(newlyAppearedDates)
            }
            .onPreferenceChange(TemporalCarouselViewportWidthKey.self) { width in
                guard width > 0, viewportWidth != width else { return }
                viewportWidth = width
            }
            .onPreferenceChange(TemporalCarouselContentLayoutKey.self) { layout in
                guard layout.isValid,
                      measuredContentWidth != Double(layout.contentWidth)
                      || measuredDayStride != Double(layout.dayStride)
                else { return }
                measuredContentWidth = Double(layout.contentWidth)
                measuredDayStride = Double(layout.dayStride)
                HistoryLabelWorkProbe.recordMeasuredContentLayout(
                    contentWidth: measuredContentWidth,
                    dayStride: measuredDayStride
                )
            }
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
                    HistoryLabelWorkProbe.withScrollGeometryCallback {
                        geometrySnapshot.geometry = geometry
                        HistoryLabelWorkProbe.recordScrollGeometry(
                            geometry
                        )
                        let direction = layoutDirection == .rightToLeft
                            ? TemporalHorizontalLayoutDirection.rightToLeft
                            : .leftToRight
                        let progress = geometry.centerProgress(
                            days: dates,
                            layoutDirection: direction
                        )
                        if movementPhase != .settled,
                           let progress
                        {
                            emitPrefetchIntent(for: progress)
                            onCoupledPresentationChange(.preview(progress))
                        }
                        if movementPhase == .settled, geometrySnapshot.hasActiveMotion {
                            if let progress {
                                emitPrefetchIntent(for: progress)
                            }
                            settleVisibleGeometry(geometry)
                        }
                    }
                }
            )
            .onAppear {
                centeredDay = canonicalSelection
                settledVisibleWindow = TemporalHistoryPresentation.ribbonWindow(
                    containing: canonicalSelection,
                    calendar: calendar
                )
                if let settledVisibleWindow {
                    onSettledVisibleWindow(settledVisibleWindow)
                }
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
                prefetchedEdges.removeAll()
                alignToExternalSelection()
            }
            .onDisappear {
                setMovementPhase(.settled)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                setMovementPhase(.settled)
            }
            .accessibilityLabel(textResolver(.historyCopy(.carouselLabel)))
            .accessibilityValue(
                movementPhase == .settled
                    ? textResolver(.historyCopy(.carouselSettled))
                    : textResolver(.historyCopy(.carouselMoving))
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
                    onSelectGroup: { group in
                        onSelectEventGroup?(group)
                    },
                    onSelectEmpty: allowsEmptySelection ? onSelectEmpty : nil,
                    onNavigateDay: nil,
                    canNavigateForward: true,
                    accessibilityIdentifierPrefix: "history",
                    showsDayHeader: false,
                    // Keep the panel's layout space stable while hiding its
                    // content until the native calendar is idle.
                    isInteractive: allowsRecordActivation,
                    showsSemanticItems: showsTimelineDetails
                        && movementPhase.showsTimelineDetails,
                    showsVisualRibbon: false,
                    windowOverride: settledVisibleWindow,
                    futureReadOnlyFrom: futureReadOnlyFromDate
                )
                .allowsHitTesting(movementPhase == .settled && allowsRecordActivation)
                .accessibilityHidden(movementPhase != .settled)
            }
        }
        .accessibilityAction(named: textResolver(.historyCopy(.previousDay))) {
            onNavigateDay(-1)
        }
        .accessibilityAction(named: textResolver(.historyCopy(.nextDay))) {
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
}

extension TemporalHistoryCarousel {
    var canonicalSelection: Date {
        calendar.startOfDay(for: selection)
    }

    var dayHeader: some View {
        let dayPresentation = TemporalHistoryDayPresentation(
            settledDay: selection,
            liveDay: presentationDay,
            calendar: calendar
        )
        let settledDayText = dayPresentation.settledDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        return HStack(alignment: .firstTextBaseline) {
            UFastSectionHeading(
                dayPresentation.visualDay.formatted(
                    .dateTime.weekday(.abbreviated).day().month(.abbreviated)
                )
            )
            .accessibilityLabel(
                settledDayText
            )
            .accessibilityIdentifier("history.selected-date")
            .accessibilityAction(named: textResolver(.historyCopy(.previousDay))) {
                onNavigateDay(-1)
            }
            .accessibilityAction(named: textResolver(.historyCopy(.nextDay))) {
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
            if allowsAddAtCenter {
                Button {
                    guard let settledVisibleWindow else { return }
                    onSelectEmpty(settledVisibleWindow.centerInstant)
                } label: {
                    Label(textResolver(.historyCopy(.addAtSelectedTime)), systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!movementPhase.allowsTimelineInteraction || settledVisibleWindow == nil)
                .accessibilityHint(textResolver(.historyCopy(.addAtSelectedTimeHint)))
                .accessibilityIdentifier("history.add-at-selected-time")
            }
            Button {
                onNavigateDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(textResolver(.historyCopy(.previousDay)))
            .accessibilityIdentifier("history.previous-day")
            Button {
                onNavigateDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canNavigateForward)
            .accessibilityLabel(textResolver(.historyCopy(.nextDay)))
            .accessibilityIdentifier("history.next-day")
        }
    }

    func daySegment(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let pageIntervals = motionIntervals
        // The continuous interval layer stays motion-projected in every phase.
        // Once the selected page settles, its visual event surface needs the
        // complete snapshot so group titles, members, and details remain exact.
        let pageEvents = isSelected && movementPhase == .settled
            ? events
            : motionEvents
        let interaction = Self.timelineInteractionState(
            movementPhase: movementPhase,
            allowsRecordActivation: allowsRecordActivation,
            allowsEmptySelection: allowsEmptySelection
        )
        let selectInterval: ((UUID) -> Void)? = interaction.isVisuallyEnabled ? { id in
            guard interaction.allowsRecordActivation else { return }
            onSelectInterval(id)
        } : nil
        return TemporalRibbonView(
            selectedDate: date,
            intervals: pageIntervals,
            events: pageEvents,
            onSelectInterval: selectInterval,
            onSelectEvent: { id in
                guard interaction.allowsRecordActivation else { return }
                onSelectEvent(id)
            },
            onSelectGroup: { group in
                guard interaction.allowsRecordActivation else { return }
                onSelectEventGroup?(group)
            },
            onSelectEmpty: interaction.allowsEmptySelection ? onSelectEmpty : nil,
            onNavigateDay: nil,
            canNavigateForward: true,
            accessibilityIdentifierPrefix: "history",
            showsDayHeader: false,
            // Preserve the resting control appearance during motion. Actions
            // remain gated by the movement-aware callbacks until idle.
            isInteractive: interaction.isVisuallyEnabled,
            showsSemanticItems: false,
            usesContinuousSurface: true,
            includesSemanticItems: false,
            hidesVisualEventAccessibility: true,
            windowOverride: TemporalHistoryPresentation.calendarDayWindow(
                containing: date,
                calendar: calendar
            ),
            futureReadOnlyFrom: futureReadOnlyFromDate
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TemporalSelectedPageHeightKey.self,
                    value: isSelected ? proxy.size.height : 0
                )
            }
        }
        .background {
            Color.clear.preference(
                key: TemporalAppearedSegmentDatesKey.self,
                value: [date]
            )
        }
        .accessibilityHidden(!isSelected || movementPhase != .settled)
        .scrollTransition(.identity, axis: .horizontal) { content, _ in
            content
        }
    }

    struct TimelineInteractionState: Equatable, Sendable {
        let isVisuallyEnabled: Bool
        let allowsRecordActivation: Bool
        let allowsEmptySelection: Bool
    }

    static func timelineInteractionState(
        movementPhase: TemporalCarouselMovementPhase,
        allowsRecordActivation: Bool,
        allowsEmptySelection: Bool
    ) -> TimelineInteractionState {
        let allowsTimelineInteraction = movementPhase.allowsTimelineInteraction
        return TimelineInteractionState(
            isVisuallyEnabled: !allowsTimelineInteraction
                || allowsRecordActivation
                || allowsEmptySelection,
            allowsRecordActivation: allowsTimelineInteraction && allowsRecordActivation,
            allowsEmptySelection: allowsTimelineInteraction && allowsEmptySelection
        )
    }

    var futureReadOnlyFromDate: Date? {
        // The ribbon shade remains visible during motion. Read-only control
        // styling and action guards are handled independently by the rail and
        // timeline interaction state.
        readOnlyFromDate
    }

    func movementPhase(for scrollPhase: ScrollPhase) -> TemporalCarouselMovementPhase {
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

    func setMovementPhase(_ newPhase: TemporalCarouselMovementPhase) {
        guard movementPhase.requiresPresentationUpdate(to: newPhase) else { return }
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

    func settleVisibleGeometry(_ geometry: TemporalContinuousTimelineGeometry) {
        let direction = layoutDirection == .rightToLeft
            ? TemporalHorizontalLayoutDirection.rightToLeft
            : .leftToRight
        guard let window = geometry.visibleWindow(
            days: dates,
            calendar: calendar,
            layoutDirection: direction
        ) else { return }
        settledVisibleWindow = window
        onSettledVisibleWindow(window)
        geometrySnapshot.hasActiveMotion = false
        reconcileAndCommitSelection(window.selectedDay)
    }

    func resolvedSettledDay(_ day: Date?) -> Date {
        TemporalHistoryPresentation.settledCarouselDay(
            centeredPage: day,
            currentSelection: selection,
            availableDays: dates,
            maximumDate: dates.last ?? selection,
            calendar: calendar
        )
    }

    func reconcileAndCommitSelection(_ day: Date?) {
        let settledDay = resolvedSettledDay(day)
        guard settledDay != canonicalSelection else {
            onCoupledPresentationChange(.end)
            return
        }
        onCoupledPresentationChange(.reconcile(day: settledDay, dates: dates))
        selection = settledDay
    }

    func alignToExternalSelection() {
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

    func emitPrefetchIntent(for progress: TemporalDaySpaceProgress) {
        guard let first = dates.first, let last = dates.last else { return }
        let threshold = HistoryMotionConfiguration.product.prefetchThreshold
        let leadingDistance = calendar.dateComponents(
            [.day], from: first, to: progress.leadingDay
        ).day ?? Int.max
        let trailingDistance = calendar.dateComponents(
            [.day], from: progress.trailingDay, to: last
        ).day ?? Int.max
        if leadingDistance <= threshold, !prefetchedEdges.contains(.preceding) {
            prefetchedEdges.insert(.preceding)
            onPrefetchIntent(.preceding)
            onPrefetchIntentAt(.preceding, progress.centeredCalendarDay)
        }
        if trailingDistance <= threshold, !prefetchedEdges.contains(.following) {
            prefetchedEdges.insert(.following)
            onPrefetchIntent(.following)
            onPrefetchIntentAt(.following, progress.centeredCalendarDay)
        }
    }
}
