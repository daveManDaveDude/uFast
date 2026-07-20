import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsRecord]
    @State private var selection = FastingGoal.default
    @State private var saveError: String?

    var body: some View {
        ScreenLayout(title: "Settings", identifier: "settings") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                        UFastSectionHeading(
                            "Fasting goal",
                            eyebrow: "\(selection.hours) hours selected"
                        )
                        Text(
                            "This updates the target for an active fast. "
                                + "Completed records keep their historical goal."
                        )
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                        FastingGoalPicker(selection: goalBinding)
                    }
                    .uFastCard(accent: UFastTheme.sage)

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Label("Private by default", systemImage: "lock")
                            .font(.headline)
                            .foregroundStyle(UFastTheme.primary)
                        Text("Your fasting goal and records stay on this device.")
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .uFastCard()

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.goal.save-error")
                    }
                }
                .padding(UFastTheme.Spacing.standard)
            }
        }
        .onAppear {
            selection = settingsRecords.first?.fastingGoal ?? .default
        }
    }

    private var goalBinding: Binding<FastingGoal> {
        Binding(
            get: { selection },
            set: { goal in
                saveGoal(goal)
            }
        )
    }

    private func saveGoal(_ goal: FastingGoal) {
        guard let settings = settingsRecords.first else {
            return
        }

        let previousGoal = settings.fastingGoal
        selection = goal
        settings.setFastingGoal(goal)

        do {
            if ProcessInfo.processInfo.arguments.contains("--simulate-goal-save-failure") {
                throw GoalSaveFixtureError.simulated
            }
            try modelContext.save()
            saveError = nil
        } catch {
            settings.setFastingGoal(previousGoal)
            selection = previousGoal
            saveError = "Your goal couldn’t be saved. Please try again."
        }
    }
}

private enum GoalSaveFixtureError: Error {
    case simulated
}

#Preview("Settings") {
    SettingsView()
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("Settings · Accessibility") {
    SettingsView()
        .modelContainer(PreviewFixtures.modelContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
