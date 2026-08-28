import SwiftUI

// swiftlint:disable trailing_comma

struct VisibleFastHistoryRow: View {
    let item: HistoryVisibleFastItem
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Text(item.title).font(.headline).foregroundStyle(UFastTheme.primary)
            Text(durationText)
                .font(.uFastDisplay(.title2)).foregroundStyle(UFastTheme.primary)
            Divider()
            if item.kind == .active {
                fact(item.textContext.textResolver(.fastingCopy(.started)), item.startDate)
            } else {
                HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                    fact(item.textContext.textResolver(.fastingCopy(.started)), item.startDate)
                    fact(item.textContext.textResolver(.fastingCopy(.endHeader)), item.endDate)
                }
            }
        }
        .uFastCard(accent: item.kind == .recorded || item.kind == .active ? UFastTheme.sage : UFastTheme.sky)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(historyAccessibilityLabel)
    }

    var historyAccessibilityLabel: String {
        guard item.kind == .active else {
            return item.accessibilityLabel
        }

        let duration = HistoryTextFormatting.activeAccessibility(
            seconds: item.endDate.timeIntervalSince(item.startDate),
            resolver: item.textContext.textResolver
        )
        return [
            item.title,
            item.textContext.textResolver(
                .historyFastComponent(
                    kind: .start,
                    value: HistoryTextFormatting.dateTime(
                        item.startDate,
                        calendar: item.textContext.calendar,
                        locale: item.textContext.locale,
                        timeZone: item.textContext.timeZone
                    )
                )
            ),
            item.textContext.textResolver(.historyFastComponent(kind: .duration, value: duration)),
            item.textContext.textResolver(.historyCopy(.currentlyActive)),
        ].joined(
            separator: item.textContext.textResolver(.historyCopy(.separatorComma))
                + item.textContext.textResolver(.historyCopy(.separatorSpace))
        )
    }

    var durationText: String {
        item.kind == .active
            ? HistoryTextFormatting.activeDisplay(
                seconds: item.endDate.timeIntervalSince(item.startDate),
                resolver: item.textContext.textResolver
            )
            : HistoryTextFormatting.duration(
                seconds: item.endDate.timeIntervalSince(item.startDate),
                resolver: item.textContext.textResolver
            )
    }

    func fact(_ label: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(
                HistoryTextFormatting.dateTime(
                    date,
                    calendar: item.textContext.calendar,
                    locale: item.textContext.locale,
                    timeZone: item.textContext.timeZone
                )
            )
            .font(.subheadline.weight(.semibold)).foregroundStyle(UFastTheme.primary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HiddenInferredFastRecoveryRow: View {
    let item: HistoryVisibleFastItem
    let onReenable: () -> Void

    var body: some View {
        let sourceKind = item.inferredInterval?.sourceKind.rawValue ?? "unknown"
        let sourceID = item.inferredInterval?.sourceBoundaryReference.id.uuidString ?? item.id.uuidString
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(UFastTheme.primary)
            Text(item.textContext.textResolver(.historyCopy(.hiddenInferredHint)))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(
                item.textContext.textResolver(.historyCopy(.reenableInferredFast)),
                action: onReenable
            )
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier(
                "history.inferred.reenable.\(sourceKind).\(sourceID)"
            )
            .accessibilityHint(item.textContext.textResolver(.historyCopy(.hiddenInferredHint)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .uFastCard(accent: UFastTheme.sky)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityIdentifier(
            "history.inferred.hidden.\(sourceKind).\(sourceID)"
        )
    }
}

struct HistoryFoodEditorPresentation: Identifiable {
    let record: FoodEntrySnapshot
    var id: UUID {
        record.id
    }
}

struct HistoryHydrationEditorPresentation: Identifiable {
    let record: HydrationEntrySnapshot
    var id: UUID {
        record.id
    }
}

struct CompletedFastEditorPresentation: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
}

struct InferredFastConversionPresentation: Identifiable {
    let interval: InferredFastInterval

    var id: CaloricBoundaryReference {
        interval.sourceBoundaryReference
    }
}

#Preview("History · Empty") {
    HistoryFeatureHost(clock: SystemAppClock(), isTabSelected: true, onSelectToday: {})
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("History · Populated") {
    HistoryFeatureHost(clock: SystemAppClock(), isTabSelected: true, onSelectToday: {})
        .modelContainer(PreviewFixtures.completedFastModelContainer)
}
