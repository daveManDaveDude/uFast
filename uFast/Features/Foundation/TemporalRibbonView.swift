import SwiftUI

// swiftlint:disable function_body_length opening_brace

struct TemporalRibbonView: View {
    @Environment(\.calendar) var calendar
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.layoutDirection) var layoutDirection
    @Environment(\.timeZone) var timeZone
    @ScaledMetric(relativeTo: .caption2) var markerLabelWidth = 64

    let selectedDate: Date
    let intervals: [TemporalRibbonIntervalItem]
    let events: [TemporalRibbonEventItem]
    let onSelectInterval: ((UUID) -> Void)?
    let onSelectEvent: (UUID) -> Void
    var onSelectGroup: ((TemporalEventGroup) -> Void)?
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
    var hidesVisualEventAccessibility = false
    var isSelectedPage = true
    var windowOverride: TemporalRibbonWindow?
    var emptySemanticMessage = "No recorded items for this date."
    var futureReadOnlyFrom: Date?

    var window: TemporalRibbonWindow? {
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
                ribbonContent(window)
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
}

extension TemporalRibbonView {
    @ViewBuilder
    func ribbonContent(_ window: TemporalRibbonWindow) -> some View {
        let eventItems = groupedEventPresentation(in: window)
        if showsVisualRibbon {
            visualRibbon(window, eventItems: eventItems)
        }
        if includesSemanticItems {
            semanticItems(window, eventItems: eventItems)
                .opacity(showsSemanticItems ? 1 : 0)
                .allowsHitTesting(showsSemanticItems)
                .accessibilityHidden(!showsSemanticItems)
        }
    }

    func groupedEventPresentation(
        in window: TemporalRibbonWindow
    ) -> [TemporalEventPresentationItem] {
        var presentationCalendar = calendar
        presentationCalendar.timeZone = timeZone
        return TemporalEventGrouping.project(
            events.map(\.groupingInput),
            in: window.interval,
            calendar: presentationCalendar
        )
    }

    func visualRibbon(
        _ window: TemporalRibbonWindow,
        eventItems: [TemporalEventPresentationItem]
    ) -> some View {
        let markers = axisMarkers(window).map { date in
            (date, midnightMarkerText(for: date))
        }
        return GeometryReader { proxy in
            let policy = TemporalRibbonGeometry.pagePolicy(
                for: proxy.size.width,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let surfaceHeight = ribbonHeight(policy)
            ZStack(alignment: .topLeading) {
                ribbonBackground(
                    window: window,
                    width: policy.contentWidth,
                    markers: markers,
                    height: surfaceHeight,
                    futureShading: futureReadOnlyFrom.flatMap {
                        TemporalHistoryPresentation.futureShadingInterval(
                            for: window,
                            now: $0,
                            calendar: calendar
                        )
                    }
                )
                .accessibilityHidden(true)
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
                intervalMarks(
                    window: window,
                    policy: policy,
                    isSelectedPage: isSelectedPage
                )
                .accessibilityHidden(true)
                eventMarks(
                    window: window,
                    width: policy.contentWidth,
                    eventItems: eventItems
                )
            }
            // Neighboring days can have different intrinsic child bounds
            // (for example, only the selected active-fast segment has a
            // label). Pin every page to the same top-leading coordinate space
            // so a continuous interval cannot jump vertically at midnight.
            .frame(
                width: policy.contentWidth,
                height: surfaceHeight,
                alignment: .topLeading
            )
            .allowsHitTesting(isInteractive)
        }
        .frame(height: TemporalEventMarkerMetrics.make(
            category: .food,
            accessibilitySize: dynamicTypeSize.isAccessibilitySize
        ).ribbonHeight)
        .modifier(
            TemporalRibbonSurfaceModifier(
                isContinuous: usesContinuousSurface
            )
        )
    }

    func ribbonBackground(
        window: TemporalRibbonWindow,
        width: Double,
        markers: [(Date, TemporalMidnightMarkerText)],
        height: Double,
        futureShading: DateInterval?
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if usesContinuousSurface {
                Rectangle()
                    .fill(UFastTheme.formSurface)
            } else {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .fill(UFastTheme.formSurface)
            }
            if let futureShading {
                Rectangle()
                    .fill(UFastTheme.secondaryText.opacity(0.10))
                    .frame(
                        width: width * futureShadingFraction(futureShading, in: window),
                        height: height
                    )
                    .offset(x: width * window.fraction(for: futureShading.start))
                    .accessibilityHidden(true)
            }
            ForEach(markers, id: \.0) { marker, text in
                let markerX = width * window.fraction(for: marker)
                let hour = calendar.component(.hour, from: marker)
                let isLabelled = hour % 6 == 0
                Rectangle()
                    .fill(hour == 0 ? UFastTheme.action.opacity(0.7) :
                        (isLabelled ? UFastTheme.border : UFastTheme.border.opacity(0.55)))
                    .frame(
                        width: hour == 0 ? 1.5 : (isLabelled ? 1 : 0.75),
                        height: TemporalRibbonSurfaceMetrics.gridRuleHeight(surfaceHeight: height)
                    )
                    .offset(x: markerX, y: TemporalRibbonSurfaceMetrics.topLabelClearance)
                if isLabelled {
                    axisMark(marker, text: text)
                        .frame(
                            width: markerLabelWidth,
                            alignment: layoutDirection == .rightToLeft ? .topTrailing : .topLeading
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .position(x: labelCenterX(for: markerX, width: width), y: markerLabelCenterY)
                }
            }
        }
    }

    func intervalMarks(
        window: TemporalRibbonWindow,
        policy: TemporalRibbonGeometry,
        isSelectedPage: Bool
    ) -> some View {
        let segments = TemporalHistoryPresentation.clip(
            intervals.map { TemporalIntervalInput(id: $0.id, start: $0.start, end: $0.end) },
            to: window
        )
        return ForEach(segments) { segment in
            if let item = intervals.first(where: { $0.id == segment.id }) {
                let startX = policy.contentWidth * segment.startFraction(in: window)
                let endX = policy.contentWidth * segment.endFraction(in: window)
                let markWidth = max(endX - startX, 1)
                let horizontalHitPadding = max((44 - markWidth) / 2, 0)
                let showsContent = TemporalHistoryPresentation.intervalContinuationShowsContent(
                    isActive: item.kind == .active,
                    continuesBefore: segment.continuesBefore,
                    continuesAfter: segment.continuesAfter,
                    isSelectedPage: isSelectedPage
                )
                let showsContinuationMarkers = TemporalHistoryPresentation
                    .intervalContinuationShowsMarkers(isActive: item.kind == .active)
                Button {
                    onSelectInterval?(item.id)
                } label: {
                    HStack(spacing: 4) {
                        if showsContinuationMarkers, segment.continuesBefore, markWidth >= 60 {
                            Image(systemName: "chevron.left.2")
                                .accessibilityHidden(true)
                        }
                        if showsContent {
                            Image(systemName: intervalSymbol(item.kind))
                                .accessibilityHidden(true)
                            if markWidth >= 84 {
                                Text(intervalTitle(item, markWidth: markWidth)).lineLimit(1)
                            }
                        }
                        if showsContinuationMarkers, segment.continuesAfter, markWidth >= 60 {
                            Image(systemName: "chevron.right.2")
                                .accessibilityHidden(true)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(intervalForeground(item.kind))
                    .padding(.horizontal, 8)
                    .frame(width: markWidth, height: max(44, policy.intervalLaneHeight), alignment: .leading)
                    .background(intervalColour(item.kind))
                    .clipShape(intervalMarkShape(for: segment, visibleWidth: markWidth))
                    .overlay {
                        intervalMarkShape(for: segment, visibleWidth: markWidth)
                            .stroke(intervalStroke(item.kind), style: strokeStyle(item.kind))
                    }
                    .overlay(alignment: .leading) {
                        if segment.continuesBefore {
                            continuationEdgeCover(for: item.kind)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if segment.continuesAfter {
                            continuationEdgeCover(for: item.kind)
                        }
                    }
                    .padding(.horizontal, horizontalHitPadding)
                }
                .buttonStyle(.plain)
                .disabled(onSelectInterval == nil)
                .accessibilityIdentifier(
                    item.kind == .active
                        ? "history.active-fast.\(item.id.uuidString)"
                        : "history.interval.\(item.id.uuidString)"
                )
                .offset(
                    x: startX - horizontalHitPadding,
                    y: 54 + Double(segment.lane) * (policy.intervalLaneHeight + 6)
                )
            }
        }
    }

    func intervalMarkShape(
        for segment: TemporalIntervalSegment,
        visibleWidth: Double
    ) -> UnevenRoundedRectangle {
        let radius = TemporalRibbonGeometry.intervalCornerRadius(
            visibleWidth: visibleWidth,
            preferredRadius: UFastTheme.Radius.control
        )
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: segment.continuesBefore ? 0 : radius,
                bottomLeading: segment.continuesBefore ? 0 : radius,
                bottomTrailing: segment.continuesAfter ? 0 : radius,
                topTrailing: segment.continuesAfter ? 0 : radius
            ),
            style: .continuous
        )
    }
}
