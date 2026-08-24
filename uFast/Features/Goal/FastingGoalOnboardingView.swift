import SwiftUI

struct FastingGoalOnboardingView: View {
    @Environment(\.applicationCommands) private var applicationCommands
    @Environment(\.appTextResolver) private var textResolver
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
                            Text(textResolver(.onboardingTitle))
                                .font(.uFastDisplay())
                                .foregroundStyle(UFastTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("screen-title.onboarding")
                            Text(textResolver(.onboardingPromise))
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
                            textResolver(.onboardingChoiceHeading),
                            eyebrow: textResolver(.onboardingChoiceEyebrow)
                        )
                        Text(textResolver(.onboardingSelectionSummary(hours: selection.hours)))
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

                    Button(textResolver(.continueAction)) {
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
        do {
            guard let applicationCommands else { throw ApplicationCommandError.recordNotFound }
            try applicationCommands.completeOnboarding(goal: selection)
        } catch {
            saveError = textResolver(.onboardingSaveError)
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
