import SwiftUI

// swiftlint:disable function_body_length opening_brace

struct TemporalRibbonView: View {
    @Environment(\.calendar) var calendar
    @Environment(\.appTextResolver) var textResolver
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
    var showsVisualContentAccessibility = true
    var showsLiveActiveDuration = false
    var activeFastNow: () -> Date = { .now }
    var windowOverride: TemporalRibbonWindow?
    var emptySemanticMessage: String?
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
                        eyebrow: textResolver(.historyCopy(.selectedDay))
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
                        .accessibilityLabel(textResolver(.historyCopy(.previousDay)))
                        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).previous-day")
                        Button {
                            onNavigateDay?(1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canNavigateForward)
                        .accessibilityLabel(textResolver(.historyCopy(.nextDay)))
                        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).next-day")
                    }
                }
            }

            if let window {
                ribbonContent(window)
            }
        }
        .accessibilityAction(named: textResolver(.historyCopy(.previousDay))) {
            onNavigateDay?(-1)
        }
        .accessibilityAction(named: textResolver(.historyCopy(.nextDay))) {
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
                    policy: policy
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
        policy: TemporalRibbonGeometry
    ) -> some View {
        let geometries = TemporalHistoryPresentation.pageGeometry(
            intervals.map { TemporalIntervalInput(id: $0.id, start: $0.start, end: $0.end) },
            in: window,
            surfaceWidth: policy.contentWidth
        )
        return ForEach(geometries) { geometry in
            if let item = intervals.first(where: { $0.id == geometry.id }) {
                let segment = geometry.segment
                let markWidth = geometry.visualWidth
                let contentLayout = segment.visualContentLayout(
                    in: window,
                    visibleWidth: markWidth,
                    minimumWidth: item.visualContentMinimumWidth
                )
                let resolvedContentLayout = contentLayout == .none
                    ? segment.visualContentFallbackLayout(
                        in: window,
                        visibleWidth: markWidth,
                        surfaceWidth: policy.contentWidth,
                        calendar: calendar,
                        minimumWidth: item.visualContentMinimumWidth
                    )
                    : contentLayout
                let showsContent = resolvedContentLayout != .none
                let usesAvailableContinuationWidth = item.compactTitle != nil
                    && segment.continuesAfter
                Button {
                    onSelectInterval?(item.id)
                } label: {
                    Color.clear
                        .frame(width: markWidth, height: max(44, policy.intervalLaneHeight))
                        .background(intervalColour(item.kind))
                        .clipShape(intervalMarkShape(for: segment, visibleWidth: markWidth))
                        .overlay {
                            intervalOutlineShape(for: segment, visibleWidth: markWidth)
                                .stroke(intervalStroke(item.kind), style: strokeStyle(item.kind))
                        }
                        .overlay(alignment: .leading) {
                            if showsContent {
                                Group {
                                    if usesAvailableContinuationWidth {
                                        intervalVisualContent(
                                            item,
                                            layout: .regular,
                                            markWidth: markWidth
                                        )
                                        .fixedSize(horizontal: true, vertical: false)
                                    } else {
                                        intervalVisualContent(
                                            item,
                                            layout: resolvedContentLayout,
                                            markWidth: markWidth
                                        )
                                        .frame(
                                            width: max(markWidth - 4, 0),
                                            alignment: .leading
                                        )
                                        .clipped()
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(intervalForeground(item.kind))
                                .padding(.horizontal, 2)
                            }
                        }
                        .padding(.leading, geometry.leadingHitPadding)
                        .padding(.trailing, geometry.trailingHitPadding)
                }
                .buttonStyle(.plain)
                .disabled(onSelectInterval == nil)
                .accessibilityIdentifier(
                    item.kind == .active
                        ? "history.active-fast.\(item.id.uuidString)"
                        : "history.interval.\(item.id.uuidString)"
                )
                .offset(
                    x: geometry.visualStartX - geometry.leadingHitPadding,
                    y: 54 + Double(geometry.lane) * (policy.intervalLaneHeight + 6)
                )
            }
        }
    }

    func intervalVisualContent(
        _ item: TemporalRibbonIntervalItem,
        layout: TemporalIntervalContentLayout,
        markWidth: Double
    ) -> some View {
        HStack(spacing: layout == .compact ? 2 : 4) {
            Image(systemName: intervalSymbol(item.kind))
                .accessibilityHidden(true)
            if item.kind == .active {
                VStack(alignment: .leading, spacing: 0) {
                    identifiedVisualContent(
                        Text(item.title).lineLimit(1),
                        for: item
                    )
                    ActiveFastRibbonDurationLabel(
                        start: item.start,
                        fallbackEnd: item.end,
                        isLive: showsLiveActiveDuration,
                        now: activeFastNow
                    )
                }
            } else if layout == .compact {
                let compactTitle = compactIntervalTitle(item)
                identifiedVisualContent(
                    Text(compactTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(item.compactTitle == nil ? 0.7 : 0.9)
                        .allowsTightening(true),
                    for: item
                )
            } else {
                identifiedVisualContent(
                    Text(intervalTitle(item, markWidth: markWidth)).lineLimit(1),
                    for: item
                )
            }
        }
    }

    @ViewBuilder
    func identifiedVisualContent<Content: View>(
        _ content: Content,
        for item: TemporalRibbonIntervalItem
    ) -> some View {
        if showsVisualContentAccessibility {
            content.accessibilityIdentifier(intervalVisualContentIdentifier(for: item))
        } else {
            content
        }
    }

    func intervalVisualContentIdentifier(for item: TemporalRibbonIntervalItem) -> String {
        let prefix = item.kind == .active
            ? "history.active-fast-content"
            : "history.interval-content"
        return "\(prefix).\(item.id.uuidString)"
    }

    func compactIntervalTitle(_ item: TemporalRibbonIntervalItem) -> String {
        switch item.kind {
        case .recorded, .automatic:
            textResolver(.historyCopy(.fast))
        case .inferred:
            item.compactTitle ?? item.title
        case .active:
            textResolver(.historyCopy(.activeFast))
        case .previouslySaved, .reconstructed, .needsReview, .unknown:
            item.title
        }
    }

    func intervalMarkShape(
        for segment: TemporalIntervalSegment,
        visibleWidth: Double
    ) -> UnevenRoundedRectangle {
        let radius = TemporalRibbonGeometry.intervalCornerRadius(
            visibleWidth: visibleWidth,
            preferredRadius: UFastTheme.Radius.control,
            hasLeadingCap: !segment.continuesBefore,
            hasTrailingCap: !segment.continuesAfter
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

    func intervalOutlineShape(
        for segment: TemporalIntervalSegment,
        visibleWidth: Double
    ) -> TemporalIntervalOutlineShape {
        TemporalIntervalOutlineShape(
            continuesBefore: segment.continuesBefore,
            continuesAfter: segment.continuesAfter,
            layoutDirection: layoutDirection,
            cornerRadius: TemporalRibbonGeometry.intervalCornerRadius(
                visibleWidth: visibleWidth,
                preferredRadius: UFastTheme.Radius.control,
                hasLeadingCap: !segment.continuesBefore,
                hasTrailingCap: !segment.continuesAfter
            )
        )
    }
}

private struct ActiveFastRibbonDurationLabel: View {
    let start: Date
    let fallbackEnd: Date
    let isLive: Bool
    let now: () -> Date

    @State private var displayedEnd: Date?

    var body: some View {
        let resolvedEnd = isLive ? displayedEnd ?? fallbackEnd : fallbackEnd

        Text(
            ActiveElapsedTimeFormatter.string(
                from: resolvedEnd.timeIntervalSince(start)
            )
        )
        .monospacedDigit()
        .lineLimit(1)
        .task(id: isLive) {
            guard isLive else { return }

            displayedEnd = now()
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                    displayedEnd = now()
                }
            } catch {
                // Cancellation pauses live updates while the carousel is moving.
            }
        }
    }
}
