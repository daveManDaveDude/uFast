import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length opening_brace statement_position

struct SettingsView: View {
    @Environment(\.applicationCommands) private var applicationCommands
    @Environment(\.liveActivityCoordinator) private var liveActivityCoordinator
    let snapshot: SettingsFeatureSnapshot
    @State private var focusedFavouriteField: FavouriteField?
    @State private var controller = SettingsFeatureController()
    @State private var isFirstDeleteConfirmationPresented = false
    @State private var isFinalDeleteConfirmationPresented = false
    @State private var liveActivityAvailability: LiveActivityAvailability?

    private var authoritativeSettings: AppSettingsSnapshot? {
        snapshot.settings.count == 1 ? snapshot.settings[0] : nil
    }

    init(snapshot: SettingsFeatureSnapshot = .init(settings: [])) {
        self.snapshot = snapshot
    }

    var body: some View {
        @Bindable var controller = controller
        NavigationStack {
            ScreenLayout(title: "Settings", identifier: "settings") {
                ScrollView {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                        SettingsGoalSection(selection: controller.selection, goalBinding: goalBinding)
                        SettingsPrivacySection()
                        SettingsWidgetSection()
                        SettingsLiveActivitiesSection(
                            isOn: Binding(
                                get: { controller.automaticallyShowLiveActivities },
                                set: { setAutomaticLiveActivities(enabled: $0) }
                            ),
                            status: controller.liveActivityStatus,
                            availability: liveActivityAvailability
                        )
                        SettingsFavouritesSection(
                            water: $controller.waterAmount,
                            tea: $controller.teaAmount,
                            coffee: $controller.coffeeAmount,
                            focusedField: $focusedFavouriteField,
                            valuesAreValid: favouriteValues != nil
                        )
                        SettingsDeleteSection(error: controller.deleteError) {
                            controller.deleteError = nil
                            isFirstDeleteConfirmationPresented = true
                        }

                        if let saveError = controller.saveError {
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
                controller.connect(commands: applicationCommands)
                controller.load(snapshot)
                Task {
                    liveActivityAvailability = liveActivityCoordinator?.availability()
                }
            }
            .onChange(of: applicationCommands != nil) { _, _ in
                controller.connect(commands: applicationCommands)
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
                        + "from this iPhone."
                )
            }
            .alert(
                "Permanently delete everything?",
                isPresented: $isFinalDeleteConfirmationPresented
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Delete everything", role: .destructive) {
                    isFinalDeleteConfirmationPresented = false
                    deleteAllData()
                }
            } message: {
                Text("This is your final confirmation. Deleted data cannot be recovered.")
            }
        }
    }

    private var goalBinding: Binding<FastingGoal> {
        Binding(
            get: { controller.selection },
            set: { goal in
                saveGoal(goal)
            }
        )
    }

    private func saveGoal(_ goal: FastingGoal) {
        guard let settings = authoritativeSettings else {
            return
        }

        let previousGoal = settings.fastingGoal
        controller.saveGoal(goal, previousGoal: previousGoal)
    }

    private func setAutomaticLiveActivities(enabled: Bool) {
        guard let settings = authoritativeSettings else { return }
        let previousPreference = settings.automaticLiveActivityPreference
        controller.setAutomaticLiveActivities(
            enabled: enabled,
            previousPreference: previousPreference
        ) {
            liveActivityAvailability = liveActivityCoordinator?.availability()
        }
    }

    private var favouriteValues: (Int, Int, Int)? {
        guard let water = Int(controller.waterAmount), let tea = Int(controller.teaAmount),
              let coffee = Int(controller.coffeeAmount),
              HydrationEntryValidator.isValid(volumeMillilitres: water),
              HydrationEntryValidator.isValid(volumeMillilitres: tea),
              HydrationEntryValidator.isValid(volumeMillilitres: coffee)
        else { return nil }
        return (water, tea, coffee)
    }

    private func saveFavouritesIfValid() {
        guard let settings = authoritativeSettings, let values = favouriteValues else { return }
        controller.saveFavourites(
            values: HydrationFavouriteAmounts(water: values.0, tea: values.1, coffee: values.2),
            previous: HydrationFavouriteAmounts(
                water: settings.waterFavouriteMillilitres,
                tea: settings.teaFavouriteMillilitres,
                coffee: settings.coffeeFavouriteMillilitres
            )
        )
    }

    private func deleteAllData() {
        controller.deleteAllData()
    }
}

struct FavouriteAmountTextField: UIViewRepresentable {
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

#Preview("Settings") {
    SettingsFeatureHost()
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("Settings · Accessibility") {
    SettingsFeatureHost()
        .modelContainer(PreviewFixtures.modelContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
