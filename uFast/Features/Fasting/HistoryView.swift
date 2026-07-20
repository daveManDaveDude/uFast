import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var timeZone
    @Query(filter: #Predicate<FastRecord> { $0.endDate != nil })
    private var completedFasts: [FastRecord]
    @State private var editor: CompletedFastEditorPresentation?

    private let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    private var sortedFasts: [FastRecord] {
        CompletedFastOrdering.newestEndedFirst(completedFasts)
    }

    var body: some View {
        ScreenLayout(title: "History", identifier: "history") {
            if sortedFasts.isEmpty {
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
                List(sortedFasts) { fast in
                    Button {
                        guard let endDate = fast.endDate else {
                            return
                        }
                        editor = CompletedFastEditorPresentation(
                            id: fast.id,
                            startDate: fast.startDate,
                            endDate: endDate
                        )
                    } label: {
                        FastHistoryRow(
                            fast: fast,
                            calendar: calendar,
                            locale: locale,
                            timeZone: timeZone
                        )
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
                    .accessibilityIdentifier("history.fast.\(fast.id.uuidString)")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("history.list")
            }
        }
        .sheet(item: $editor) { presentation in
            CompletedFastEditor(
                presentation: presentation,
                validation: { startDate, endDate in
                    try? makeService().validationError(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                },
                onSave: { startDate, endDate in
                    _ = try makeService().update(
                        id: presentation.id,
                        startDate: startDate,
                        endDate: endDate
                    )
                    editor = nil
                },
                onDelete: {
                    try makeService().delete(id: presentation.id)
                    editor = nil
                },
                onCancel: {
                    editor = nil
                }
            )
        }
    }

    private func makeService() -> CompletedFastService {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-history-failure"
            )
        )
        return CompletedFastService(repository: repository, clock: clock)
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

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(UFastTheme.secondaryText)
                    Text(durationText)
                        .font(.uFastDisplay(.title2))
                        .foregroundStyle(UFastTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

            Label("\(fast.historicalGoal.hours)-hour historical goal", systemImage: "scope")
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
        }
        .uFastCard(accent: UFastTheme.sage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Recorded fast, start \(startText), end \(endText), " +
                "duration \(durationText), goal \(fast.historicalGoal.hours) hours"
        )
    }

    private func historyFact(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(UFastTheme.secondaryText)
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

struct CompletedFastEditorPresentation: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
}

#Preview("History · Empty") {
    HistoryView()
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("History · Populated") {
    HistoryView()
        .modelContainer(PreviewFixtures.completedFastModelContainer)
}
