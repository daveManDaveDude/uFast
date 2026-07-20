import SwiftData
import SwiftUI

struct FastingGoalOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection = FastingGoal.default
    @State private var saveError: String?

    var body: some View {
        ZStack {
            UFastTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    UFastBrandMark()

                    HStack(alignment: .center, spacing: UFastTheme.Spacing.standard) {
                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                            Text("Your fasting goal")
                                .font(.uFastDisplay())
                                .foregroundStyle(UFastTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("screen-title.onboarding")
                            Text("A calm, private companion for recording your fasts.")
                                .font(.body)
                                .foregroundStyle(UFastTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("goal.promise")
                        }

                        FastingBotanicalThumbnail()
                            .frame(width: 94)
                    }

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                        UFastSectionHeading(
                            "Choose what you intend to record",
                            eyebrow: "8–24 whole hours"
                        )
                        Text(
                            "\(selection.hours) hours is selected. "
                                + "You can change this later."
                        )
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                        FastingGoalPicker(selection: $selection)
                    }
                    .uFastCard()
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: UFastTheme.Spacing.compact) {
                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("goal.save-error")
                    }

                    Button("Continue") {
                        saveSelection()
                    }
                    .buttonStyle(UFastPrimaryButtonStyle())
                    .accessibilityIdentifier("goal.continue")
                }
                .padding(.horizontal, UFastTheme.Spacing.standard)
                .padding(.bottom, UFastTheme.Spacing.compact)
                .background(UFastTheme.canvas)
            }
        }
        .tint(UFastTheme.action)
    }

    private func saveSelection() {
        if ProcessInfo.processInfo.arguments.contains("--simulate-goal-save-failure") {
            saveError = "Your goal couldn’t be saved. Please try again."
            return
        }

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

#Preview("Onboarding") {
    FastingGoalOnboardingView()
        .modelContainer(PreviewFixtures.emptyModelContainer)
}

#Preview("Onboarding · Accessibility") {
    FastingGoalOnboardingView()
        .modelContainer(PreviewFixtures.emptyModelContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
