import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsRecord]
    @State private var selection = FastingGoal.default
    @State private var saveError: String?

    var body: some View {
        ScreenLayout(title: "Settings", identifier: "settings") {
            List {
                Section("Fasting goal") {
                    FastingGoalPicker(selection: goalBinding)
                }

                if let saveError {
                    Text(saveError)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("settings.goal.save-error")
                }
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
            try modelContext.save()
            saveError = nil
        } catch {
            settings.setFastingGoal(previousGoal)
            selection = previousGoal
            saveError = "Your goal couldn’t be saved. Please try again."
        }
    }
}
