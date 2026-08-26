import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length opening_brace statement_position trailing_comma

struct SettingsView: View {
    @Environment(\.applicationCommands) private var applicationCommands
    @Environment(\.appTextResolver) private var textResolver
    @Environment(\.liveActivityCoordinator) private var liveActivityCoordinator
    let snapshot: SettingsFeatureSnapshot
    @State private var controller = SettingsFeatureController()
    @State private var isFirstDeleteConfirmationPresented = false
    @State private var isFinalDeleteConfirmationPresented = false
    @State private var liveActivityAvailability: LiveActivityAvailability?
    @State private var favouriteEditor: HydrationFavouriteEditorPresentation?
    @State private var foodFavouriteEditor: FoodFavouriteEditorPresentation?

    private var authoritativeSettings: AppSettingsSnapshot? {
        snapshot.settings.count == 1 ? snapshot.settings[0] : nil
    }

    init(snapshot: SettingsFeatureSnapshot = .init(settings: [])) {
        self.snapshot = snapshot
    }

    var body: some View {
        @Bindable var controller = controller
        NavigationStack {
            ScreenLayout(title: textResolver(.settingsTitle), identifier: "settings") {
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
                        SettingsInferredFastSection(
                            isOn: Binding(
                                get: { controller.inferredFastDetectionEnabled },
                                set: { controller.setInferredFastDetection(enabled: $0) }
                            )
                        )
                        SettingsFavouritesSection(
                            favourites: snapshot.hydrationFavourites,
                            onAddFavourite: {
                                favouriteEditor = HydrationFavouriteEditorPresentation(favourite: nil)
                            },
                            onEditFavourite: { favourite in
                                favouriteEditor = HydrationFavouriteEditorPresentation(favourite: favourite)
                            }
                        )
                        SettingsFoodFavouritesSection(
                            favourites: snapshot.foodFavourites,
                            onAddFavourite: {
                                foodFavouriteEditor = FoodFavouriteEditorPresentation(favourite: nil)
                            },
                            onEditFavourite: { favourite in
                                foodFavouriteEditor = FoodFavouriteEditorPresentation(favourite: favourite)
                            }
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
                .accessibilityIdentifier("settings.content")
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                controller.connect(commands: applicationCommands)
                controller.setTextResolver(textResolver)
                controller.load(snapshot)
                Task {
                    liveActivityAvailability = liveActivityCoordinator?.availability()
                }
            }
            .onChange(of: applicationCommands != nil) { _, _ in
                controller.connect(commands: applicationCommands)
            }
            .alert(
                textResolver(.settingsDeleteFirstTitle),
                isPresented: $isFirstDeleteConfirmationPresented
            ) {
                Button(textResolver(.cancel), role: .cancel) {}
                Button(textResolver(.continueAction), role: .destructive) {
                    isFinalDeleteConfirmationPresented = true
                }
            } message: {
                Text(textResolver(.settingsDeleteFirstMessage))
            }
            .alert(
                textResolver(.settingsDeleteFinalTitle),
                isPresented: $isFinalDeleteConfirmationPresented
            ) {
                Button(textResolver(.cancel), role: .cancel) {}
                Button(textResolver(.settingsDeleteEverything), role: .destructive) {
                    isFinalDeleteConfirmationPresented = false
                    deleteAllData()
                }
            } message: {
                Text(textResolver(.settingsDeleteFinalMessage))
            }
        }
        .sheet(item: $favouriteEditor) { presentation in
            HydrationFavouriteEditor(
                presentation: presentation,
                existingFavourites: snapshot.hydrationFavourites,
                onSave: { name, amount, isCaloric in
                    if let favourite = presentation.favourite {
                        try controller.updateFavourite(
                            id: favourite.id,
                            name: name,
                            amount: amount,
                            isCaloric: isCaloric
                        )
                    } else {
                        try controller.createFavourite(name, amount: amount, isCaloric: isCaloric)
                    }
                    favouriteEditor = nil
                },
                onRemove: presentation.favourite.map { favourite in
                    {
                        try controller.deleteFavourite(id: favourite.id)
                        favouriteEditor = nil
                    }
                },
                onCancel: { favouriteEditor = nil }
            )
        }
        .sheet(item: $foodFavouriteEditor) { presentation in
            FoodFavouriteEditor(
                presentation: presentation,
                existingFavourites: snapshot.foodFavourites,
                onSave: { description, nutrition in
                    if let favourite = presentation.favourite {
                        try controller.updateFoodFavourite(
                            id: favourite.id,
                            expectedRevision: favourite.revision,
                            description: description,
                            nutrition: nutrition
                        )
                    } else {
                        try controller.createFoodFavourite(description: description, nutrition: nutrition)
                    }
                    foodFavouriteEditor = nil
                },
                onRemove: presentation.favourite.map { favourite in
                    {
                        try controller.deleteFoodFavourite(id: favourite.id, expectedRevision: favourite.revision)
                        foodFavouriteEditor = nil
                    }
                },
                onCancel: { foodFavouriteEditor = nil }
            )
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

    private func deleteAllData() {
        controller.deleteAllData()
    }
}

struct FavouriteAmountTextField: UIViewRepresentable {
    @Binding var text: String
    let label: String
    let identifier: String
    let textResolver: AppTextResolver
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.placeholder = textResolver(.settingsAmountPlaceholder)
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.accessibilityLabel = textResolver(.settingsAmountAccessibilityLabel(label: label))
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
    SettingsView(snapshot: SettingsViewPreviewData.snapshot)
}

#Preview("Settings · Accessibility") {
    SettingsView(snapshot: SettingsViewPreviewData.snapshot)
        .environment(\.dynamicTypeSize, .accessibility3)
}

private enum SettingsViewPreviewData {
    static let snapshot = SettingsFeatureSnapshot(
        settings: [AppSettingsSnapshot()],
        hydrationFavourites: [
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Sparkling water",
                volumeMillilitres: 500,
                isCaloric: false,
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
            ),
        ]
    )
}
