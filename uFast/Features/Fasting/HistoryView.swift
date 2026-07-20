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
                ContentUnavailableView {
                    Text("No completed fasts")
                } description: {
                    Text("Completed fasts will appear here.")
                }
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
                    .accessibilityIdentifier("history.fast.\(fast.id.uuidString)")
                }
                .listStyle(.plain)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Recorded fast")
                .font(.headline)
            Text("Start: \(startText)")
                .fixedSize(horizontal: false, vertical: true)
            Text("End: \(endText)")
                .fixedSize(horizontal: false, vertical: true)
            Text("Duration: \(durationText)")
                .fixedSize(horizontal: false, vertical: true)
            Text("Goal: \(fast.historicalGoal.hours) hours")
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Recorded fast, start \(startText), end \(endText), " +
                "duration \(durationText), goal \(fast.historicalGoal.hours) hours"
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

struct CompletedFastEditorPresentation: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
}
