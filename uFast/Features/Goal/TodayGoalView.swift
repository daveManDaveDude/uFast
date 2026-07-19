import SwiftData
import SwiftUI

struct TodayGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @State private var startError: String?

    var body: some View {
        ScreenLayout(title: "Today", identifier: "today") {
            Group {
                if let activeFast = activeFasts.first {
                    let goal = settingsRecords.first?.fastingGoal ?? .default
                    let target = activeFast.targetDate(currentGoal: goal)

                    ContentUnavailableView {
                        Label("Fast in progress", systemImage: "timer")
                    } description: {
                        Text("Goal: \(goal.hours) hours")
                        Text("Target: \(target.formatted(date: .abbreviated, time: .shortened))")
                    }
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

                        if let startError {
                            Text(startError)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("fast.start-error")
                        }
                    }
                }
            }
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
            clock: SystemAppClock()
        )

        do {
            _ = try service.startFast(goal: goal)
            startError = nil
        } catch {
            startError = "Your fast couldn’t be started. Please try again."
        }
    }
}
