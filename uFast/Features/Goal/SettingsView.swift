import SwiftData
import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length statement_position

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRecords: [AppSettingsRecord]
    @State private var focusedFavouriteField: FavouriteField?
    @State private var selection = FastingGoal.default
    @State private var saveError: String?
    @State private var deleteError: String?
    @State private var isFirstDeleteConfirmationPresented = false
    @State private var isFinalDeleteConfirmationPresented = false
    @State private var waterAmount = "500"
    @State private var teaAmount = "300"
    @State private var coffeeAmount = "300"

    var body: some View {
        NavigationStack {
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
                            Label("Private iCloud sync", systemImage: "icloud")
                                .font(.headline)
                                .foregroundStyle(UFastTheme.primary)
                            Text(
                                "Your uFast records sync through your private iCloud account "
                                    + "and remain available after reinstalling the app."
                            )
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .uFastCard()

                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            UFastSectionHeading("Drink favourites")
                            Text("Choose the amount added by each Today shortcut.")
                                .font(.subheadline).foregroundStyle(UFastTheme.secondaryText)
                            favouriteField("Water", field: .water, text: $waterAmount, identifier: "settings.drink.water")
                            favouriteField("Tea", field: .tea, text: $teaAmount, identifier: "settings.drink.tea")
                            favouriteField("Coffee", field: .coffee, text: $coffeeAmount, identifier: "settings.drink.coffee")
                            if favouriteValues == nil {
                                Label("Enter each amount from 1 to 5,000 ml.", systemImage: "exclamationmark.circle")
                                    .foregroundStyle(UFastTheme.error)
                                    .accessibilityIdentifier("settings.drink.validation")
                            }
                            Text("Changes save automatically when you finish editing.")
                                .font(.footnote)
                                .foregroundStyle(UFastTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .uFastCard(accent: UFastTheme.sky)

                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            UFastSectionHeading("Your data")
                            Text(
                                "Delete every uFast record from this device and iCloud. "
                                    + "This cannot be undone."
                            )
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                            Button("Delete all data", role: .destructive) {
                                deleteError = nil
                                isFirstDeleteConfirmationPresented = true
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("settings.data.delete-all")

                            if let deleteError {
                                Label(deleteError, systemImage: "exclamationmark.circle")
                                    .foregroundStyle(UFastTheme.error)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("settings.data.delete-error")
                            }
                        }
                        .uFastCard(accent: UFastTheme.apricot)

                        if let saveError {
                            Label(saveError, systemImage: "exclamationmark.circle")
                                .foregroundStyle(UFastTheme.error)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("settings.goal.save-error")
                        }
                    }
                    .padding(UFastTheme.Spacing.standard)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                selection = settingsRecords.first?.fastingGoal ?? .default
                if let settings = settingsRecords.first {
                    waterAmount = String(settings.waterFavouriteMillilitres)
                    teaAmount = String(settings.teaFavouriteMillilitres)
                    coffeeAmount = String(settings.coffeeFavouriteMillilitres)
                }
            }
            .onChange(of: focusedFavouriteField) { previousField, currentField in
                if previousField != nil, previousField != currentField {
                    saveFavouritesIfValid()
                }
            }
            .alert(
                "Delete all uFast data?",
                isPresented: $isFirstDeleteConfirmationPresented
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    isFinalDeleteConfirmationPresented = true
                }
            } message: {
                Text(
                    "This will remove your fasts, food, drinks, settings and history "
                        + "from this device and iCloud."
                )
            }
            .alert(
                "Permanently delete everything?",
                isPresented: $isFinalDeleteConfirmationPresented
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This is your final confirmation. Deleted data cannot be recovered.")
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

    private func favouriteField(
        _ label: String,
        field: FavouriteField,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            FavouriteAmountTextField(
                text: text,
                label: label,
                identifier: identifier,
                isFocused: Binding(
                    get: { focusedFavouriteField == field },
                    set: { isFocused in
                        if isFocused {
                            focusedFavouriteField = field
                        } else if focusedFavouriteField == field {
                            focusedFavouriteField = nil
                        }
                    }
                )
            )
            .frame(width: 100)
            Text("ml")
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityHidden(true)
        }
    }

    private func saveFavouritesIfValid() {
        guard let settings = settingsRecords.first, let values = favouriteValues else { return }
        let old = (settings.waterFavouriteMillilitres, settings.teaFavouriteMillilitres, settings.coffeeFavouriteMillilitres)
        settings.setHydrationFavourites(water: values.0, tea: values.1, coffee: values.2)
        do { try modelContext.save(); saveError = nil }
        catch { settings.setHydrationFavourites(water: old.0, tea: old.1, coffee: old.2); saveError = "Your drink favourites couldn’t be saved. Please try again." }
    }

    private func deleteAllData() {
        do {
            try AppDataDeletionService.deleteEverything(
                in: modelContext,
                simulateFailure: ProcessInfo.processInfo.arguments.contains(
                    "--simulate-delete-all-failure"
                )
            )
            deleteError = nil
        } catch {
            deleteError = "Your data couldn’t be deleted. Please try again."
        }
    }
}

private enum FavouriteField: Hashable {
    case water
    case tea
    case coffee
}

private struct FavouriteAmountTextField: UIViewRepresentable {
    @Binding var text: String
    let label: String
    let identifier: String
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.placeholder = "Amount"
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.accessibilityLabel = "\(label) amount"
        textField.accessibilityIdentifier = identifier
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingBegan), for: .editingDidBegin)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingEnded), for: .editingDidEnd)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.tintColor = UFastTheme.keyboardActionUIColor
        let done = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )
        done.accessibilityIdentifier = "settings.keyboard.done"
        toolbar.items = [.flexibleSpace(), done]
        textField.inputAccessoryView = toolbar
        context.coordinator.textField = textField
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if textField.text != text {
            textField.text = text
        }
        if isFocused, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isFocused, textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: FavouriteAmountTextField
        weak var textField: UITextField?

        init(parent: FavouriteAmountTextField) {
            self.parent = parent
        }

        @objc func textChanged() {
            parent.text = textField?.text ?? ""
        }

        @objc func editingBegan() {
            parent.isFocused = true
        }

        @objc func editingEnded() {
            parent.isFocused = false
        }

        @objc func doneTapped() {
            parent.isFocused = false
            textField?.resignFirstResponder()
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
