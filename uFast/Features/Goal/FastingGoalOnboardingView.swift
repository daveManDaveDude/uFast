import SwiftData
import SwiftUI

struct FastingGoalOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection = FastingGoal.default
    @State private var saveError: String?

    var body: some View {
        ScreenLayout(title: "Your goal", identifier: "onboarding") {
            List {
                Section {
                    FastingGoalPicker(selection: $selection)
                } header: {
                    Text("Choose your fasting goal")
                } footer: {
                    Text("You can change this at any time in Settings.")
                }

                if let saveError {
                    Text(saveError)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("goal.save-error")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Continue") {
                    saveSelection()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityIdentifier("goal.continue")
            }
        }
    }

    private func saveSelection() {
        let settings = AppSettingsRecord(
            fastingGoal: selection,
            hasCompletedOnboarding: true
        )
        modelContext.insert(settings)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(settings)
            saveError = "Your goal couldn’t be saved. Please try again."
        }
    }
}
