import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length type_body_length

struct HistoryView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var timeZone
    @Query(filter: #Predicate<FastRecord> { $0.endDate != nil }) private var completedFasts: [FastRecord]
    @Query private var unknownPeriods: [UnknownPeriodRecord]
    @State private var editor: CompletedFastEditorPresentation?
    @State private var reconstructedDetail: ReconstructedDetailPresentation?
    @State private var unknownDetail: UnknownDetailPresentation?
    @State private var isCatchUpPresented = false

    private let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    private var historyItems: [HistoryListItem] {
        let fastItems = completedFasts.compactMap { fast -> HistoryListItem? in
            guard let endDate = fast.endDate else { return nil }
            return HistoryListItem(
                id: fast.id,
                endDate: endDate,
                kind: fast.origin == .recorded ? .recordedFast : .reconstructedFast,
                content: .fast(fast)
            )
        }
        let unknownItems = unknownPeriods.map {
            HistoryListItem(
                id: $0.id,
                endDate: $0.endDate,
                kind: .unknownPeriod,
                content: .unknown($0)
            )
        }
        let items = fastItems + unknownItems
        return HistoryOrdering.newestFirst(
            items.map {
                HistoryOrderingValue(id: $0.id, endDate: $0.endDate, kind: $0.kind)
            }
        ).compactMap { value in
            items.first { $0.id == value.id && $0.kind == value.kind }
        }
    }

    var body: some View {
        ScreenLayout(title: "History", identifier: "history") {
            VStack(spacing: UFastTheme.Spacing.standard) {
                catchUpButton
                if historyItems.isEmpty {
                    UFastIllustratedInformationCard(
                        title: "No completed fasts",
                        eyebrow: "History",
                        message: "Completed fasts will appear here."
                    ) {
                        FastingBotanicalArtwork()
                    }
                    .padding(UFastTheme.Spacing.standard)
                    .accessibilityIdentifier("history.empty")
                } else {
                    List(historyItems) { item in
                        Button { open(item) } label: {
                            historyRow(item)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(
                                top: 6,
                                leading: UFastTheme.Spacing.standard,
                                bottom: 6,
                                trailing: UFastTheme.Spacing.standard
                            )
                        )
                        .accessibilityIdentifier(historyIdentifier(item))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("history.list")
                }
            }
        }
        .sheet(isPresented: $isCatchUpPresented) { CatchUpFlowView(clock: clock) }
        .sheet(item: $editor) { presentation in
            CompletedFastEditor(
                presentation: presentation,
                validation: { startDate, endDate in
                    try? makeCompletedFastService().validationError(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                },
                onSave: { startDate, endDate in
                    _ = try makeCompletedFastService().update(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                    editor = nil
                },
                onDelete: {
                    try makeCompletedFastService().delete(id: presentation.id)
                    editor = nil
                },
                onCancel: { editor = nil }
            )
        }
        .sheet(item: $reconstructedDetail) { presentation in
            ReconstructedFastDetailView(
                fast: presentation.fast,
                clock: clock,
                repository: makeReconstructionRepository(),
                onClose: { reconstructedDetail = nil }
            )
        }
        .sheet(item: $unknownDetail) { presentation in
            UnknownPeriodDetailView(
                unknown: presentation.unknown,
                repository: makeReconstructionRepository(),
                onClose: { unknownDetail = nil }
            )
        }
    }

    private var catchUpButton: some View {
        Button { isCatchUpPresented = true } label: {
            HStack(spacing: UFastTheme.Spacing.standard) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Catch up").font(.headline)
                    Text("Add remembered food and drinks from up to 7 completed days.")
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }
        }
        .buttonStyle(UFastActionRowButtonStyle())
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .accessibilityIdentifier("history.catch-up")
    }

    @ViewBuilder
    private func historyRow(_ item: HistoryListItem) -> some View {
        switch item.content {
        case let .fast(fast):
            FastHistoryRow(
                fast: fast,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        case let .unknown(unknown):
            UnknownHistoryRow(
                unknown: unknown,
                calendar: calendar,
                locale: locale,
                timeZone: timeZone
            )
        }
    }

    private func open(_ item: HistoryListItem) {
        switch item.content {
        case let .fast(fast) where fast.origin == .recorded:
            guard let endDate = fast.endDate else { return }
            editor = CompletedFastEditorPresentation(
                id: fast.id,
                startDate: fast.startDate,
                endDate: endDate
            )
        case let .fast(fast):
            reconstructedDetail = ReconstructedDetailPresentation(fast: fast)
        case let .unknown(unknown):
            unknownDetail = UnknownDetailPresentation(unknown: unknown)
        }
    }

    private func historyIdentifier(_ item: HistoryListItem) -> String {
        switch item.content {
        case .fast: "history.fast.\(item.id.uuidString)"
        case .unknown: "history.unknown.\(item.id.uuidString)"
        }
    }

    private func makeCompletedFastService() -> CompletedFastService {
        CompletedFastService(
            repository: SwiftDataActiveFastRepository(
                modelContext: modelContext,
                simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                    "--simulate-fast-history-failure"
                )
            ),
            clock: clock
        )
    }

    private func makeReconstructionRepository() -> SwiftDataReconstructionRepository {
        SwiftDataReconstructionRepository(
            modelContext: modelContext,
            clock: clock,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-reconstruction-save-failure"
            )
        )
    }
}

private struct FastHistoryRow: View {
    let fast: FastRecord
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    private var startText: String {
        formatted(fast.startDate)
    }

    private var endText: String {
        fast.endDate.map(formatted) ?? ""
    }

    private var durationText: String {
        ElapsedTimeFormatter.string(from: fast.duration ?? 0)
    }

    private var originText: String {
        fast.origin == .recorded ? "Recorded by you" : "Reconstructed · Confirmed by you"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            if fast.reviewState == .needsReview {
                Label("Needs review", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.error)
            }
            Text(originText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(UFastTheme.action)
            if fast.wasAdjustedByUser {
                Label("Adjusted by you", systemImage: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            HStack(alignment: .top) {
                Text(durationText)
                    .font(.uFastDisplay(.title2))
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
            }
            Divider()
            HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                historyFact("Started", value: startText)
                historyFact("Ended", value: endText)
            }
            if let goal = fast.capturedHistoricalGoal {
                Label("\(goal.hours)-hour historical goal", systemImage: "scope")
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
        }
        .uFastCard(accent: fast.origin == .recorded ? UFastTheme.sage : UFastTheme.sky)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var components = fast.origin == .recorded
            ? ["Recorded fast", originText]
            : [originText]
        if fast.reviewState == .needsReview {
            components.insert("Needs review", at: 0)
        }
        if fast.wasAdjustedByUser {
            components.append("Adjusted by you")
        }
        components.append("start \(startText), end \(endText), duration \(durationText)")
        if let goal = fast.capturedHistoricalGoal {
            components.append("goal \(goal.hours) hours")
        }
        return components.joined(separator: ", ")
    }

    private func historyFact(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(UFastTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

private struct UnknownHistoryRow: View {
    let unknown: UnknownPeriodRecord
    let calendar: Calendar
    let locale: Locale
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            HStack {
                Label("Unknown period", systemImage: "questionmark.circle")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
            }
            Text("\(formatted(unknown.startDate)) → \(formatted(unknown.endDate))")
                .foregroundStyle(UFastTheme.primary)
            Text(unknown.reason.explanation)
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
        }
        .uFastCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Unknown period, start \(formatted(unknown.startDate)), end "
                + "\(formatted(unknown.endDate)), \(unknown.reason.explanation)"
        )
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

private struct HistoryListItem: Identifiable {
    enum Content {
        case fast(FastRecord)
        case unknown(UnknownPeriodRecord)
    }

    let id: UUID
    let endDate: Date
    let kind: HistoryRecordKind
    let content: Content
}

private struct ReconstructedDetailPresentation: Identifiable {
    let fast: FastRecord
    var id: UUID {
        fast.id
    }
}

private struct UnknownDetailPresentation: Identifiable {
    let unknown: UnknownPeriodRecord
    var id: UUID {
        unknown.id
    }
}

struct CompletedFastEditorPresentation: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
}

#Preview("History · Empty") {
    HistoryView().modelContainer(PreviewFixtures.modelContainer)
}

#Preview("History · Populated") {
    HistoryView().modelContainer(PreviewFixtures.completedFastModelContainer)
}
