import SwiftUI

// swiftlint:disable function_body_length opening_brace

extension TemporalRibbonView {
    func eventMarks(
        window: TemporalRibbonWindow,
        width: Double,
        eventItems: [TemporalEventPresentationItem]
    ) -> some View {
        ForEach(eventItems) { item in
            if let layout = TemporalEventGroupLayout.make(
                bucketStartFraction: window.fraction(for: item.bucket.start),
                bucketEndFraction: window.fraction(for: item.bucket.end),
                ribbonWidth: width
            ) {
                eventMarkButton(
                    item: item,
                    layout: layout,
                    width: width,
                    metrics: TemporalEventMarkerMetrics.make(
                        category: item.presentationCategory,
                        accessibilitySize: dynamicTypeSize.isAccessibilitySize
                    )
                )
            }
        }
    }

    func eventMarkButton(
        item: TemporalEventPresentationItem,
        layout: TemporalEventGroupLayout,
        width: Double,
        metrics: TemporalEventMarkerMetrics
    ) -> some View {
        let group = item.group
        let member = group?.members.first ?? {
            if case let .single(_, member) = item {
                return member
            }
            return nil
        }()
        let buttonWidth = layout.interactiveWidth
        let buttonOffsetX = min(
            max(0, layout.centerFraction * width - buttonWidth / 2),
            max(0, width - buttonWidth)
        )
        return Button {
            if let group {
                if let onSelectGroup {
                    onSelectGroup(group)
                } else if let first = group.members.first {
                    onSelectEvent(first.reference.id)
                }
            } else if let member {
                onSelectEvent(member.reference.id)
            }
        } label: {
            eventMarkerLabel(
                item: item,
                layout: layout,
                member: member,
                metrics: metrics
            )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .frame(width: buttonWidth, height: metrics.hitHeight)
        .contentShape(Rectangle())
        .offset(x: buttonOffsetX, y: metrics.rowTop)
        .zIndex(1)
        .modifier(GroupMarkerAccessibilityModifier(
            group: group,
            member: member,
            prefix: accessibilityIdentifierPrefix,
            usesVisualEventIdentifier: hidesVisualEventAccessibility
        ))
        .accessibilityHidden(group == nil && (includesSemanticItems || hidesVisualEventAccessibility))
    }

    func eventMarkerLabel(
        item: TemporalEventPresentationItem,
        layout: TemporalEventGroupLayout,
        member: TemporalEventGroupingInput?,
        metrics: TemporalEventMarkerMetrics
    ) -> some View {
        let group = item.group
        let tileSize = min(metrics.tileSize, layout.visibleContentWidth)
        let cellWidth = layout.visibleContentWidth
        return VStack(spacing: metrics.labelGap) {
            ZStack(alignment: .topTrailing) {
                eventMarkerTile(
                    category: item.presentationCategory,
                    size: tileSize
                )
                if let group {
                    Text(group.visualCountText)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(UFastTheme.onAction)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(
                            width: min(
                                group.visualCountText.count > 2 ? 22 : 16,
                                tileSize
                            ),
                            height: 16
                        )
                        .background(UFastTheme.action)
                        .clipShape(Capsule())
                        .offset(y: -10)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: tileSize, height: tileSize)
            if group == nil, let member {
                Text(member.occurredAt, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(UFastTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .frame(height: metrics.labelBandHeight)
            } else {
                Color.clear.frame(height: metrics.labelBandHeight)
            }
        }
        .frame(width: cellWidth, height: metrics.cellHeight, alignment: .top)
    }

    @ViewBuilder
    func eventMarkerTile(
        category: TemporalEventPresentationCategory,
        size: Double
    ) -> some View {
        switch category {
        case .food:
            Image(systemName: "fork.knife")
                .font(.caption.weight(.bold))
                .foregroundStyle(UFastTheme.primary)
                .frame(width: size, height: size)
                .background(UFastTheme.apricot)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        case .caloricDrink:
            Image("HistoryCaloricDrink")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .scaleEffect(4.0 / 3.0)
                .frame(width: size, height: size)
                .clipped()
                .accessibilityHidden(true)
        case .nonCaloricDrink:
            Image("HistoryNonCaloricDrink")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .scaleEffect(4.0 / 3.0)
                .frame(width: size, height: size)
                .clipped()
                .accessibilityHidden(true)
        }
    }

    func selectEmpty(
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

    func semanticItems(
        _ window: TemporalRibbonWindow,
        eventItems: [TemporalEventPresentationItem]
    ) -> some View {
        let visibleIntervals = intervals.filter { $0.end > window.interval.start && $0.start < window.interval.end }
        let orderedItems = semanticOrder(intervals: visibleIntervals, eventItems: eventItems)
        return VStack(spacing: 0) {
            if orderedItems.isEmpty {
                Text(emptySemanticMessage ?? textResolver(.historyCopy(.timelineEmpty)))
                    .foregroundStyle(UFastTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .accessibilityIdentifier("temporal.empty")
            } else {
                ForEach(orderedItems, id: \.semanticID) { item in
                    if item.isInterval, onSelectInterval == nil {
                        semanticRow(item, showsDisclosure: false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.accessibilityLabel)
                            .accessibilityIdentifier(item.identifier)
                    } else {
                        Button {
                            if let group = item.eventGroup {
                                onSelectGroup?(group)
                            } else if item.isInterval {
                                onSelectInterval?(item.id)
                            } else if let reference = item.eventReference {
                                onSelectEvent(reference.id)
                            }
                        } label: {
                            semanticRow(item, showsDisclosure: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isInteractive)
                        .accessibilityLabel(item.accessibilityLabel)
                        .accessibilityValue(
                            item.eventGroup.map { String($0.count) }
                                ?? textResolver(.historyCopy(.empty))
                        )
                        .accessibilityHint(textResolver(.historyCopy(.memberDetailHint)))
                        .accessibilityIdentifier(item.identifier)
                    }
                    if item.semanticID != orderedItems.last?.semanticID {
                        Divider()
                    }
                }
            }
        }
        .uFastCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).event-info-panel")
    }
}
