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
            Text(item.kind == .active
                ? ActiveElapsedTimeFormatter.string(from: item.endDate.timeIntervalSince(item.startDate))
                : ElapsedTimeFormatter.string(from: item.endDate.timeIntervalSince(item.startDate)))
                .font(.uFastDisplay(.title2)).foregroundStyle(UFastTheme.primary)
            Divider()
            if item.kind == .active {
                fact("Started", item.startDate)
            } else {
                HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                    fact("Started", item.startDate)
                    fact("Ended", item.endDate)
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

        let duration = ActiveElapsedTimeFormatter.string(
            from: item.endDate.timeIntervalSince(item.startDate)
        )
        return [
            item.title,
            "start \(item.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
            "duration \(duration)",
            "currently active",
        ].joined(separator: ", ")
    }

    func fact(_ label: String, _ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.subheadline.weight(.semibold)).foregroundStyle(UFastTheme.primary)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
