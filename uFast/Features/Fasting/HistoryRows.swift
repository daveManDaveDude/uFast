import SwiftUI

// swiftlint:disable trailing_comma

@MainActor
enum HistoryRowWorkProbe {
    private(set) static var cardBodyEvaluationCount = 0
    private(set) static var durationLeafInvalidationCount = 0

    static func recordCardBodyEvaluation() {
        guard HistoryLabelWorkProbe.isEnabled else { return }
        cardBodyEvaluationCount += 1
    }

    static func recordDurationLeafInvalidation() {
        guard HistoryLabelWorkProbe.isEnabled else { return }
        durationLeafInvalidationCount += 1
    }
}

struct VisibleFastHistoryRow: View {
    let item: HistoryVisibleFastItem
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone
    let durationPulse: HistoryDurationPulse?

    var body: some View {
        // SwiftUI's result builder requires this discardable binding to keep
        // the side-effect probe out of the view expression list.
        // swiftlint:disable:next redundant_discardable_let
        let _ = HistoryRowWorkProbe.recordCardBodyEvaluation()
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Text(item.title).font(.headline).foregroundStyle(UFastTheme.primary)
            SettledHistoryDurationLeaf(
                duration: item.durationSpec,
                resolver: item.textContext.textResolver,
                pulse: durationPulse
            )
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
        .uFastCard(
            accent: item.kind == .recorded || item.kind == .active
                ? UFastTheme.sage
                : UFastTheme.sky
        )
        // Combining the static facts with the leaf keeps one semantic card
        // while allowing the leaf's current duration value to update alone.
        .accessibilityElement(children: .combine)
    }

    var historyAccessibilityLabel: String {
        guard item.kind == .active else {
            return item.accessibilityLabel
        }

        let duration = HistoryTextFormatting.activeAccessibility(
            seconds: TimeInterval(item.durationSpec.completedSeconds(at: item.endDate)),
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
        HistoryTextFormatting.compactDuration(
            item.durationSpec,
            at: item.endDate,
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

/// The settled card's only live observation boundary. The parent row keeps
/// its item, title, facts and styling static while this leaf samples the
/// shared History pulse for current duration text and accessibility.
private struct SettledHistoryDurationLeaf: View {
    let duration: HistoryDurationSpec
    let resolver: AppTextResolver
    let pulse: HistoryDurationPulse?

    private var now: Date {
        guard duration.isCurrent else { return duration.endDate }
        return pulse?.now ?? duration.endDate
    }

    private var displayText: String {
        HistoryTextFormatting.compactDuration(duration, at: now, resolver: resolver)
    }

    private var accessibilityText: String {
        if duration.isCurrent {
            return HistoryTextFormatting.activeAccessibility(
                seconds: TimeInterval(duration.completedSeconds(at: now)),
                resolver: resolver
            )
        }
        return HistoryTextFormatting.duration(
            from: duration.startDate,
            to: duration.endDate,
            resolver: resolver
        )
    }

    private func recordEvaluationForCurrentLeaf() {
        guard duration.isCurrent, pulse != nil else { return }
        HistoryRowWorkProbe.recordDurationLeafInvalidation()
    }

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = recordEvaluationForCurrentLeaf()
        return Text(displayText)
            .font(.uFastDisplay(.title2))
            .foregroundStyle(UFastTheme.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                resolver(
                    .historyFastComponent(kind: .duration, value: accessibilityText)
                )
            )
            .accessibilityValue(accessibilityText)
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
