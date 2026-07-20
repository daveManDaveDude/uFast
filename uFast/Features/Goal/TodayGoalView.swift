import SwiftData
import SwiftUI
import UIKit

struct TodayGoalView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeZone) private var timeZone
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @State private var activeTimelineID = UUID()
    @State private var endError: String?
    @State private var endTimeEditor: EndTimeEditorPresentation?
    @State private var fastRecorded = false
    @State private var isEndConfirmationPresented = false
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
                    let presentation = InactiveFastPresentation(
                        now: clock.now,
                        goal: goal
                    )

                    InactiveFastView(
                        goal: goal,
                        target: formatted(presentation.targetDate),
                        fastRecorded: fastRecorded,
                        startError: startError,
                        onStart: {
                            startFast(goal: goal)
                        },
                        onStartPast: {
                            startTimeEditor = StartTimeEditorPresentation(
                                mode: .create,
                                initialStartDate: clock.now
                            )
                        }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                activeTimelineID = UUID()
            }
        }
        .onChange(of: fastRecorded) { _, isRecorded in
            if isRecorded {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Fast recorded."
                )
            }
        }
        .alert("End this fast?", isPresented: $isEndConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("End fast") {
                endFastNow()
            }
        } message: {
            Text("This will record the end time as now.")
        }
        .sheet(item: $startTimeEditor) { presentation in
            StartTimeEditor(
                mode: presentation.mode,
                initialStartDate: presentation.initialStartDate,
                clock: clock,
                hasConflict: { startDate in
                    hasStartConflict(
                        startDate,
                        mode: presentation.mode
                    )
                },
                onConfirm: { startDate in
                    try saveStartTime(presentation.mode, startDate: startDate)
                    startTimeEditor = nil
                },
                onCancel: {
                    startTimeEditor = nil
                }
            )
        }
        .sheet(item: $endTimeEditor) { presentation in
            EndTimeEditor(
                startDate: presentation.startDate,
                initialEndDate: presentation.initialEndDate,
                clock: clock,
                onConfirm: { endDate in
                    try saveEndTime(endDate)
                    endTimeEditor = nil
                },
                onCancel: {
                    endTimeEditor = nil
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
        let target = formatted(presentation.targetDate)
        let started = formatted(activeFast.startDate)

        return ActiveFastProgressView(
            presentation: presentation,
            goal: goal,
            started: started,
            target: target,
            canEndNow: now > activeFast.startDate,
            endError: endError,
            onEnd: {
                isEndConfirmationPresented = true
            },
            onEditStart: {
                startTimeEditor = StartTimeEditorPresentation(
                    mode: .correct,
                    initialStartDate: activeFast.startDate
                )
            },
            onEndAtPastTime: {
                endTimeEditor = EndTimeEditorPresentation(
                    startDate: activeFast.startDate,
                    initialEndDate: clock.now
                )
            }
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
            fastRecorded = false
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
            fastRecorded = false
        case .correct:
            _ = try service.correctActiveFastStart(to: startDate)
        }
    }

    private func hasStartConflict(
        _ startDate: Date,
        mode: StartTimeEditor.Mode
    ) -> Bool {
        let repository = SwiftDataActiveFastRepository(modelContext: modelContext)
        let service = FastStartService(repository: repository, clock: clock)
        let excludedID = mode == .correct ? activeFasts.first?.id : nil
        return (try? service.hasConflict(
            startDate: startDate,
            excluding: excludedID
        )) ?? false
    }

    private func endFastNow() {
        let service = makeEndService()
        let goal = settingsRecords.first?.fastingGoal ?? .default

        do {
            _ = try service.endFast(goal: goal)
            endError = nil
            fastRecorded = true
        } catch {
            endError = "Your fast couldn’t be ended. Please try again."
        }
    }

    private func saveEndTime(_ endDate: Date) throws {
        let service = makeEndService()
        let goal = settingsRecords.first?.fastingGoal ?? .default

        _ = try service.endFast(at: endDate, goal: goal)
        endError = nil
        fastRecorded = true
    }

    private func makeEndService() -> FastEndService {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        return FastEndService(
            repository: repository,
            clock: clock
        )
    }
}

private struct InactiveFastView: View {
    let goal: FastingGoal
    let target: String
    let fastRecorded: Bool
    let startError: String?
    let onStart: () -> Void
    let onStartPast: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: UFastTheme.Spacing.generous) {
                HStack(spacing: UFastTheme.Spacing.standard) {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Text("Ready when you are")
                            .font(.uFastDisplay(.title))
                            .foregroundStyle(UFastTheme.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("No fast is running.")
                            .foregroundStyle(UFastTheme.secondaryText)
                            .accessibilityIdentifier("fast.inactive-state")
                    }
                    Spacer(minLength: 0)
                    FastingBotanicalThumbnail()
                        .frame(width: 104)
                }

                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    UFastSectionHeading("Your next target", eyebrow: "\(goal.hours)-hour goal")
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("If started now")
                                .font(.caption)
                                .foregroundStyle(UFastTheme.secondaryText)
                            Text(target)
                                .font(.uFastDisplay(.title2))
                                .foregroundStyle(UFastTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Target if started now")
                                .accessibilityValue(target)
                                .accessibilityIdentifier("fast.preview-target")
                        }
                        Spacer()
                        Image(systemName: "sun.horizon.fill")
                            .font(.title)
                            .foregroundStyle(UFastTheme.apricot)
                            .accessibilityHidden(true)
                    }
                    Text("Your fasting goal is \(goal.hours) hours.")
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .uFastCard(accent: UFastTheme.sky)

                if fastRecorded {
                    Label("Fast recorded.", systemImage: "checkmark.circle")
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .uFastCard(accent: UFastTheme.sage)
                        .accessibilityIdentifier("fast.recorded")
                }

                if let startError {
                    Label(startError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.start-error")
                }

                VStack(spacing: UFastTheme.Spacing.standard) {
                    Button(startError == nil ? "Start fast" : "Try again", action: onStart)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .accessibilityIdentifier("fast.start")

                    Button("Start at a past time", action: onStartPast)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("fast.start-past")
                }
            }
            .padding(UFastTheme.Spacing.standard)
        }
    }
}

private struct StartTimeEditorPresentation: Identifiable {
    let id = UUID()
    let mode: StartTimeEditor.Mode
    let initialStartDate: Date
}

private struct EndTimeEditorPresentation: Identifiable {
    let id = UUID()
    let startDate: Date
    let initialEndDate: Date
}
