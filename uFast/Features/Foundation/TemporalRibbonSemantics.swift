import SwiftUI

// swiftlint:disable function_body_length opening_brace

struct SemanticItem {
    let id: UUID
    let semanticID: String
    let date: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let symbol: String
    let identifier: String
    let isInterval: Bool
    let eventReference: TemporalEventReference?
    let eventGroup: TemporalEventGroup?
}

extension TemporalRibbonView {
    func semanticRow(_ item: SemanticItem, showsDisclosure: Bool) -> some View {
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

    func semanticOrder(
        intervals: [TemporalRibbonIntervalItem],
        eventItems: [TemporalEventPresentationItem]
    ) -> [SemanticItem] {
        let intervalValues = intervals.map {
            SemanticItem(
                id: $0.id,
                semanticID: "interval-\($0.id.uuidString)",
                date: $0.start,
                title: $0.title,
                detail: $0.detail,
                accessibilityLabel: $0.accessibilityLabel,
                symbol: intervalSymbol($0.kind),
                identifier: $0.kind == .unknown
                    ? "\(accessibilityIdentifierPrefix).unknown.\($0.id.uuidString)"
                    : "\(accessibilityIdentifierPrefix).fast.\($0.id.uuidString)",
                isInterval: true,
                eventReference: nil,
                eventGroup: nil
            )
        }
        let eventValues = eventItems.map { item in
            switch item {
            case let .single(_, member):
                SemanticItem(
                    id: member.reference.id,
                    semanticID: "event-\(member.reference.stableValue)",
                    date: member.occurredAt,
                    title: member.title,
                    detail: member.detail,
                    accessibilityLabel: member.accessibilityLabel,
                    symbol: eventSymbol(category: member.presentationCategory),
                    identifier: "\(accessibilityIdentifierPrefix).event.\(member.reference.id.uuidString)",
                    isInterval: false,
                    eventReference: member.reference,
                    eventGroup: nil
                )
            case let .group(group):
                SemanticItem(
                    id: group.members.first?.reference.id ?? UUID(),
                    semanticID: "group-\(group.id.stableValue)",
                    date: group.bucket.start,
                    title: group.summaryTitle,
                    detail: groupDetail(group),
                    accessibilityLabel: groupAccessibilityLabel(group),
                    symbol: eventSymbol(category: group.presentationCategory),
                    identifier: "\(accessibilityIdentifierPrefix).event-group.row."
                        + "\(group.presentationCategory.rawValue).\(Int(group.bucket.start.timeIntervalSince1970))",
                    isInterval: false,
                    eventReference: nil,
                    eventGroup: group
                )
            }
        }
        return (intervalValues + eventValues).sorted {
            $0.date == $1.date ? $0.semanticID < $1.semanticID : $0.date < $1.date
        }
    }

    func groupDetail(_ group: TemporalEventGroup) -> String {
        "\(timeText(group.bucket.start))–\(timeText(group.bucket.end)) · \(group.classificationSummary)"
    }

    func groupAccessibilityLabel(_ group: TemporalEventGroup) -> String {
        "\(group.count) \(group.family.pluralName), \(timeText(group.bucket.start)) to "
            + "\(timeText(group.bucket.end)), \(group.classificationSummary.lowercased())"
    }

    func timeText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    func axisMarkers(_ window: TemporalRibbonWindow) -> [Date] {
        TemporalHistoryPresentation.twoHourMarkers(in: window, calendar: calendar)
    }

    func futureShadingFraction(_ interval: DateInterval, in window: TemporalRibbonWindow) -> Double {
        max(0, window.fraction(for: interval.end) - window.fraction(for: interval.start))
    }

    func labelCenterX(for markerX: Double, width: Double) -> Double {
        TemporalMidnightMarkerLayout.labelCenterX(
            markerX: markerX,
            labelWidth: markerLabelWidth,
            availableWidth: width,
            layoutDirection: layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        )
    }

    var markerLabelCenterY: Double {
        dynamicTypeSize.isAccessibilitySize ? 34 : 23
    }

    func axisMark(_ date: Date, text: TemporalMidnightMarkerText) -> some View {
        let isMidnight = calendar.component(.hour, from: date) == 0
            && calendar.component(.minute, from: date) == 0
        return VStack(
            alignment: layoutDirection == .rightToLeft ? .trailing : .leading,
            spacing: 0
        ) {
            if isMidnight {
                Text(text.localDate)
            }
            Text(text.localTime)
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(UFastTheme.secondaryText)
        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
        .lineLimit(nil)
    }

    func midnightMarkerText(for date: Date) -> TemporalMidnightMarkerText {
        TemporalMidnightMarkerText(
            date: date,
            context: TemporalFormattingContext(
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    func ribbonHeight(_ policy: TemporalRibbonGeometry) -> Double {
        _ = policy
        return TemporalEventMarkerMetrics.make(
            category: .nonCaloricDrink,
            accessibilitySize: dynamicTypeSize.isAccessibilitySize
        ).ribbonHeight
    }

    func intervalSymbol(_ kind: TemporalRibbonIntervalItem.Kind) -> String {
        switch kind {
        case .recorded: "moon.stars.fill"
        case .active: "moon.stars.fill"
        case .automatic: "moon.fill"
        case .previouslySaved: "archivebox"
        case .reconstructed: "wand.and.stars"
        case .needsReview: "exclamationmark.triangle"
        case .unknown: "questionmark.circle"
        }
    }

    func intervalColour(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        switch kind {
        case .recorded, .active: UFastTheme.sage
        case .automatic: UFastTheme.sky
        case .previouslySaved: UFastTheme.raisedSurface
        case .reconstructed: UFastTheme.sky
        case .needsReview: UFastTheme.apricot
        case .unknown: UFastTheme.raisedSurface
        }
    }

    func intervalForeground(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        kind == .needsReview ? UFastTheme.primary : UFastTheme.primary
    }

    func intervalStroke(_ kind: TemporalRibbonIntervalItem.Kind) -> Color {
        switch kind {
        case .previouslySaved, .unknown: UFastTheme.secondaryText
        default: UFastTheme.action.opacity(0.5)
        }
    }

    func strokeStyle(_ kind: TemporalRibbonIntervalItem.Kind) -> StrokeStyle {
        StrokeStyle(lineWidth: kind == .needsReview ? 2 : 1, dash: kind == .unknown ? [5, 4] : [])
    }

    func eventSymbol(category: TemporalEventPresentationCategory) -> String {
        switch category {
        case .food: "fork.knife"
        case .caloricDrink: "cup.and.saucer.fill"
        case .nonCaloricDrink: "drop"
        }
    }

    func intervalTitle(
        _ item: TemporalRibbonIntervalItem,
        markWidth: Double
    ) -> String {
        guard item.kind == .active else { return item.title }
        guard markWidth >= 180 else { return "Active Fast" }
        let elapsed = ActiveElapsedTimeFormatter.string(
            from: item.end.timeIntervalSince(item.start)
        )
        return "Active Fast \(elapsed)"
    }
}
