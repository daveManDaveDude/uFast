import SwiftData
import SwiftUI

struct TodayGoalView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeZone) private var timeZone
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @State private var activeTimelineID = UUID()
    @State private var startError: String?
    @State private var startTimeEditor: StartTimeEditorPresentation?

    private let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    var body: some View {
        ScreenLayout(title: "Today", identifier: "today") {
            Group {
                if let activeFast = activeFasts.first {
                    let goal = settingsRecords.first?.fastingGoal ?? .default

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        activeFastView(
                            activeFast,
                            goal: goal,
                            now: clock.now
                        )
                    }
                    .id(activeTimelineID)
                } else {
                    let goal = settingsRecords.first?.fastingGoal ?? .default

                    ContentUnavailableView {
                        Label("Today", systemImage: "sun.max")
                    } description: {
                        Text("Your fasting goal is \(goal.hours) hours.")
                    } actions: {
                        Button(startError == nil ? "Start fast" : "Try again") {
                            startFast(goal: goal)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("fast.start")

                        Button("Start at a past time") {
                            startTimeEditor = StartTimeEditorPresentation(
                                mode: .create,
                                initialStartDate: clock.now
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("fast.start-past")

                        if let startError {
                            Text(startError)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("fast.start-error")
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                activeTimelineID = UUID()
            }
        }
        .sheet(item: $startTimeEditor) { presentation in
            StartTimeEditor(
                mode: presentation.mode,
                initialStartDate: presentation.initialStartDate,
                clock: clock,
                onConfirm: { startDate in
                    try saveStartTime(presentation.mode, startDate: startDate)
                    startTimeEditor = nil
                },
                onCancel: {
                    startTimeEditor = nil
                }
            )
        }
    }

    private func activeFastView(
        _ activeFast: FastRecord,
        goal: FastingGoal,
        now: Date
    ) -> some View {
        let presentation = ActiveFastPresentation(
            startDate: activeFast.startDate,
            targetDate: activeFast.targetDate(currentGoal: goal),
            now: now
        )
        let target = presentation.targetDate.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )

        return ActiveFastProgressView(
            presentation: presentation,
            goal: goal,
            target: target
        ) {
            startTimeEditor = StartTimeEditorPresentation(
                mode: .correct,
                initialStartDate: activeFast.startDate
            )
        }
    }

    private func startFast(goal: FastingGoal) {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        let service = FastStartService(
            repository: repository,
            clock: clock
        )

        do {
            _ = try service.startFast(goal: goal)
            startError = nil
        } catch {
            startError = "Your fast couldn’t be started. Please try again."
        }
    }

    private func saveStartTime(
        _ mode: StartTimeEditor.Mode,
        startDate: Date
    ) throws {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        let service = FastStartService(
            repository: repository,
            clock: clock
        )
        let goal = settingsRecords.first?.fastingGoal ?? .default

        switch mode {
        case .create:
            _ = try service.startFast(at: startDate, goal: goal)
        case .correct:
            _ = try service.correctActiveFastStart(to: startDate)
        }
    }
}

private struct StartTimeEditorPresentation: Identifiable {
    let id = UUID()
    let mode: StartTimeEditor.Mode
    let initialStartDate: Date
}
