import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length statement_position

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsRecord]
    @State private var selection = FastingGoal.default
    @State private var saveError: String?
    @State private var waterAmount = "500"
    @State private var teaAmount = "300"
    @State private var coffeeAmount = "300"

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

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                        UFastSectionHeading("Drink favourites")
                        Text("Choose the amount added by each Today shortcut.")
                            .font(.subheadline).foregroundStyle(UFastTheme.secondaryText)
                        favouriteField("Water", text: $waterAmount, identifier: "settings.drink.water")
                        favouriteField("Tea", text: $teaAmount, identifier: "settings.drink.tea")
                        favouriteField("Coffee", text: $coffeeAmount, identifier: "settings.drink.coffee")
                        if favouriteValues == nil {
                            Label("Enter each amount from 1 to 5,000 ml.", systemImage: "exclamationmark.circle")
                                .foregroundStyle(UFastTheme.error)
                                .accessibilityIdentifier("settings.drink.validation")
                        }
                        Button("Save drink favourites") { saveFavourites() }
                            .buttonStyle(UFastPrimaryButtonStyle())
                            .disabled(favouriteValues == nil)
                            .accessibilityIdentifier("settings.drink.save")
                    }
                    .uFastCard(accent: UFastTheme.sky)

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
            if let settings = settingsRecords.first {
                waterAmount = String(settings.waterFavouriteMillilitres)
                teaAmount = String(settings.teaFavouriteMillilitres)
                coffeeAmount = String(settings.coffeeFavouriteMillilitres)
            }
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

    private var favouriteValues: (Int, Int, Int)? {
        guard let water = Int(waterAmount), let tea = Int(teaAmount), let coffee = Int(coffeeAmount),
              HydrationEntryValidator.isValid(volumeMillilitres: water),
              HydrationEntryValidator.isValid(volumeMillilitres: tea),
              HydrationEntryValidator.isValid(volumeMillilitres: coffee)
        else { return nil }
        return (water, tea, coffee)
    }

    private func favouriteField(_ label: String, text: Binding<String>, identifier: String) -> some View {
        HStack { Text(label); Spacer(); TextField("ml", text: text).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 100).accessibilityIdentifier(identifier); Text("ml").foregroundStyle(UFastTheme.secondaryText).accessibilityHidden(true) }
    }

    private func saveFavourites() {
        guard let settings = settingsRecords.first, let values = favouriteValues else { return }
        let old = (settings.waterFavouriteMillilitres, settings.teaFavouriteMillilitres, settings.coffeeFavouriteMillilitres)
        settings.setHydrationFavourites(water: values.0, tea: values.1, coffee: values.2)
        do { try modelContext.save(); saveError = nil }
        catch { settings.setHydrationFavourites(water: old.0, tea: old.1, coffee: old.2); saveError = "Your drink favourites couldn’t be saved. Please try again." }
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
