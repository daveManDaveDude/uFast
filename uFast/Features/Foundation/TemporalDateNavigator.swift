import SwiftUI

// swiftlint:disable function_body_length opening_brace

struct TemporalDateNavigator: View {
    @Environment(\.calendar) var calendar
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.layoutDirection) var layoutDirection
    @Environment(\.timeZone) var timeZone

    let dates: [Date]
    @Binding var selection: Date
    var selectedRange: Range<Date>?
    var maximumDate: Date?
    var readOnlyAfterDate: Date?
    var automaticScrollEnabled = true
    var coupledPresentation: TemporalCoupledScrollPresentation?
    var presentationDay: Date?
    var onDirectScrollPhaseChange: (Bool) -> Void = { _ in }
    var onRailSettled: (Date) -> Void = { _ in }

    @State var isDirectlyScrolling = false
    @State var measuredChipStride: CGFloat = 57
    @State var selectedChipMidX: CGFloat?
    @State var navigatorWidth: CGFloat = 0
    @State var coupledAnchorX: CGFloat?
    @State var chipMidpoints: [Date: CGFloat] = [:]
    @State var hadManualRailMotion = false

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
                .contentMargins(.horizontal, navigatorEdgeMargin, for: .scrollContent)
                .scrollIndicators(.hidden)
                .opacity(coupledPreview == nil ? 1 : 0)
                .onScrollPhaseChange { _, newPhase in
                    let isUserDriven = newPhase == .tracking
                        || newPhase == .interacting
                        || newPhase == .decelerating
                    if newPhase == .tracking || newPhase == .interacting {
                        hadManualRailMotion = true
                    }
                    if isUserDriven != isDirectlyScrolling {
                        isDirectlyScrolling = isUserDriven
                        onDirectScrollPhaseChange(isUserDriven)
                    }
                    if newPhase == .idle, hadManualRailMotion {
                        settleManualRail()
                    }
                }
                .onAppear {
                    keepSelectedChipVisible(using: proxy)
                }
                .onChange(of: navigatorWidth) { _, width in
                    guard width > 0 else { return }
                    keepSelectedChipVisible(using: proxy)
                }
                .onChange(of: selection) { _, _ in
                    hadManualRailMotion = false
                    keepSelectedChipVisible(using: proxy)
                    coupledPresentation?.finishReconciliation()
                }
                .onChange(of: dates) { _, _ in
                    hadManualRailMotion = false
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
        .onPreferenceChange(TemporalDateChipMidpointsKey.self) { midpoints in
            chipMidpoints = midpoints
        }
        .onPreferenceChange(TemporalDateNavigatorWidthKey.self) { width in
            guard width > 0 else { return }
            navigatorWidth = width
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Date navigator")
        .accessibilityIdentifier("temporal.date-navigator")
    }
}

extension TemporalDateNavigator {
    var selectedChipDate: Date? {
        dates.first { calendar.isDate($0, inSameDayAs: selection) }
    }

    func dateChip(_ date: Date) -> some View {
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
            dateChipLabel(date, isSelected: isSelected, isInRange: isInRange, isReadOnly: isReadOnly)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .opacity(isSelectable ? (isReadOnly ? 0.78 : 1) : 0.45)
        .accessibilityLabel(fullDate(date))
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isReadOnly ? "Future day, history is read only." : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("temporal.date.\(date.timeIntervalSince1970)")
        .id(date)
        .scrollTransition(.identity, axis: .horizontal) { content, _ in
            content
        }
        .background {
            dateChipGeometry(for: date, isSelected: isSelected)
        }
    }

    func dateChipLabel(
        _ date: Date,
        isSelected: Bool,
        isInRange: Bool,
        isReadOnly: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text(weekday(date)).font(.caption2.weight(.semibold))
            Text(date, format: .dateTime.day()).font(.headline.monospacedDigit())
            dateChipStatus(isSelected: isSelected, isInRange: isInRange)
        }
        .foregroundStyle(
            isSelected ? UFastTheme.onAction : (isReadOnly ? UFastTheme.secondaryText : UFastTheme.primary)
        )
        .frame(width: chipWidth)
        .frame(minHeight: chipHeight)
        .background(
            isSelected ? UFastTheme.action.opacity(isReadOnly ? 0.78 : 1) :
                (isReadOnly ? UFastTheme.formSurface : UFastTheme.raisedSurface)
        )
        .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                .stroke(isSelected ? UFastTheme.primary : UFastTheme.border, lineWidth: isSelected ? 2 : 1)
        }
    }

    func dateChipGeometry(for date: Date, isSelected: Bool) -> some View {
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
                .preference(
                    key: TemporalDateChipMidpointsKey.self,
                    value: [date: proxy.frame(in: .named(TemporalDateNavigatorCoordinateSpace.name)).midX]
                )
        }
    }

    func settleManualRail() {
        defer { hadManualRailMotion = false }
        guard !isDirectlyScrolling,
              coupledPresentation?.preview == nil,
              let day = TemporalHistoryPresentation.settledRailDay(
                  chipMidpoints: chipMidpoints.mapValues(Double.init),
                  viewportMidpoint: Double(navigatorWidth / 2),
                  availableDays: dates,
                  maximumDate: maximumDate ?? dates.last ?? selection,
                  calendar: calendar
              )
        else { return }
        onRailSettled(day)
    }

    func dateChipAccessibilityValue(
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

    func coupledFollower(_ preview: TemporalDaySpaceProgress) -> some View {
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
                ZStack(alignment: .topLeading) {
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
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
                .clipped()
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(height: navigatorHeight)
    }

    func followerChip(_ date: Date) -> some View {
        let isSelectable = maximumDate.map {
            calendar.startOfDay(for: date) <= calendar.startOfDay(for: $0)
        } ?? true
        let isSelected = isSelectable && calendar.isDate(
            date,
            inSameDayAs: presentationDay ?? selection
        )
        let isReadOnly = readOnlyAfterDate.map {
            calendar.startOfDay(for: date) > calendar.startOfDay(for: $0)
        } ?? false
        return VStack(spacing: 4) {
            Text(weekday(date))
                .font(.caption2.weight(.semibold))
            Text(date, format: .dateTime.day())
                .font(.headline.monospacedDigit())
            dateChipStatus(isSelected: isSelected, isInRange: false)
        }
        .foregroundStyle(
            isSelected ? UFastTheme.onAction : (isReadOnly ? UFastTheme.secondaryText : UFastTheme.primary)
        )
        .frame(width: measuredChipStride - 5)
        .frame(minHeight: chipHeight)
        .background(
            isSelected ? UFastTheme.action.opacity(isReadOnly ? 0.78 : 1) :
                (isReadOnly ? UFastTheme.formSurface : UFastTheme.raisedSurface)
        )
        .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                .stroke(
                    isSelected ? UFastTheme.primary : UFastTheme.border,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .opacity(isSelectable ? (isReadOnly ? 0.78 : 1) : 0.45)
    }

    var chipWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 112 : 52
    }

    var chipHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 140 : 58
    }

    var navigatorHeight: CGFloat {
        chipHeight + 4
    }

    var navigatorEdgeMargin: CGFloat {
        max((navigatorWidth - chipWidth) / 2, 0)
    }

    @ViewBuilder
    func dateChipStatus(isSelected: Bool, isInRange: Bool) -> some View {
        if !isSelected {
            Circle()
                .fill(isInRange ? UFastTheme.action : .clear)
                .frame(width: 4, height: 4)
                .accessibilityHidden(true)
        }
    }

    func weekday(_ date: Date) -> String {
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

    func fullDate(_ date: Date) -> String {
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

    func keepSelectedChipVisible(using proxy: ScrollViewProxy) {
        guard automaticScrollEnabled,
              !isDirectlyScrolling,
              let selectedChipDate
        else { return }
        proxy.scrollTo(
            selectedChipDate,
            anchor: coupledScrollAnchor ?? .center
        )
    }

    func resolvedCoupledAnchorX(in width: CGFloat) -> CGFloat {
        guard let anchorX = coupledAnchorX ?? selectedChipMidX,
              anchorX.isFinite,
              anchorX >= 0,
              anchorX <= width
        else {
            return width / 2
        }
        return anchorX
    }

    var coupledScrollAnchor: UnitPoint? {
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
