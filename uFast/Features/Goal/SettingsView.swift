import SwiftData
import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length opening_brace statement_position type_body_length

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.liveActivityCoordinator) private var liveActivityCoordinator
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @State private var focusedFavouriteField: FavouriteField?
    @State private var selection = FastingGoal.default
    @State private var saveError: String?
    @State private var deleteError: String?
    @State private var isFirstDeleteConfirmationPresented = false
    @State private var isFinalDeleteConfirmationPresented = false
    @State private var automaticallyShowLiveActivities = false
    @State private var liveActivityAvailability: LiveActivityAvailability?
    @State private var liveActivityStatus: String?
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

                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            UFastSectionHeading("Data on this iPhone")
                            Text(
                                "uFast stores your fasts, food, drinks, settings and history "
                                    + "locally in this app. There is no account, cloud sync, "
                                    + "backup or restore."
                            )
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            Text(
                                "Deleting uFast or losing this iPhone may permanently remove "
                                    + "your uFast data."
                            )
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                            NavigationLink {
                                PrivacySafetyView()
                            } label: {
                                Label("Privacy and safety", systemImage: "lock.shield")
                            }
                            .buttonStyle(UFastActionRowButtonStyle())
                            .accessibilityIdentifier("settings.privacy-safety")
                        }
                        .uFastCard(accent: UFastTheme.sky)

                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            UFastSectionHeading("Lock and Home Screen widgets")
                            Text(
                                "If you add an optional uFast Lock Screen or Home Screen widget, it can show your recorded elapsed time and goal progress."
                            )
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            Text(
                                "Touch and hold the Lock Screen to customize it, or touch and hold the Home Screen and tap + to add uFast. You can remove either widget at any time."
                            )
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .uFastCard(accent: UFastTheme.sage)

                        liveActivitiesSection

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
                                "Delete every uFast record stored on this iPhone. "
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
                automaticallyShowLiveActivities = settingsRecords.first?
                    .automaticLiveActivityPreference == .enabled
                if let settings = settingsRecords.first {
                    waterAmount = String(settings.waterFavouriteMillilitres)
                    teaAmount = String(settings.teaFavouriteMillilitres)
                    coffeeAmount = String(settings.coffeeFavouriteMillilitres)
                }
                Task {
                    liveActivityAvailability = liveActivityCoordinator?.availability()
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

    private var liveActivitiesSection: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Live Activities")
            Toggle(
                "Automatically show Live Activities",
                isOn: Binding(
                    get: { automaticallyShowLiveActivities },
                    set: { setAutomaticLiveActivities(enabled: $0) }
                )
            )
            .accessibilityIdentifier("settings.live-activities.toggle")

            Text(AutomaticLiveActivityCopy.settingsSupportingCopy)
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(AutomaticLiveActivityCopy.settingsExplanation)
                .font(.footnote)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let liveActivityStatus {
                Label(liveActivityStatus, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.live-activities.status")
            } else if let liveActivityAvailability,
                      liveActivityAvailability != .enabled
            {
                let copy = liveActivityAvailability == .disabled
                    ? ActiveFastLiveActivityStatusCopy.disabled
                    : ActiveFastLiveActivityStatusCopy.unsupported
                Text(copy)
                    .font(.footnote)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.live-activities.availability")
            }
        }
        .uFastCard(accent: UFastTheme.sky)
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
            if let activeFast = activeFasts.first {
                WidgetProjectionSupport.publish(activeFast, goal: goal)
                Task { await liveActivityCoordinator?.didCommitActiveFastChange() }
            }
            saveError = nil
        } catch {
            settings.setFastingGoal(previousGoal)
            selection = previousGoal
            saveError = "Your goal couldn’t be saved. Please try again."
        }
    }

    private func setAutomaticLiveActivities(enabled: Bool) {
        guard let settings = settingsRecords.first else { return }
        let previousPreference = settings.automaticLiveActivityPreference
        let preference: AutomaticLiveActivityPreference = enabled ? .enabled : .disabled
        automaticallyShowLiveActivities = enabled
        settings.setAutomaticLiveActivityPreference(preference)

        do {
            if ProcessInfo.processInfo.arguments.contains(
                "--simulate-live-activity-settings-save-failure"
            ) {
                throw AutomaticLiveActivitySettingsError.simulatedSaveFailure
            }
            try modelContext.save()
            liveActivityStatus = nil
            guard let liveActivityCoordinator else { return }
            Task {
                let result = await liveActivityCoordinator.didCommitAutomaticPreference(
                    preference
                )
                liveActivityStatus = liveActivityStatus(for: result)
                liveActivityAvailability = liveActivityCoordinator.availability()
            }
        } catch {
            settings.setAutomaticLiveActivityPreference(previousPreference)
            automaticallyShowLiveActivities = previousPreference == .enabled
            liveActivityStatus = AutomaticLiveActivityCopy.settingsSaveFailure
        }
    }

    private func liveActivityStatus(
        for result: ActiveFastLiveActivityResult
    ) -> String? {
        switch result {
        case let .unavailable(availability):
            switch availability {
            case .unsupported: ActiveFastLiveActivityStatusCopy.unsupported
            case .disabled: ActiveFastLiveActivityStatusCopy.disabled
            case .enabled: nil
            }
        case .requestFailed:
            ActiveFastLiveActivityStatusCopy.requestFailure
        case .hideFailed:
            ActiveFastLiveActivityStatusCopy.hideFailure
        case .shown, .alreadyShown, .hidden, .updated, .reconciled,
             .noActiveFast, .coalesced:
            nil
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
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitDeleteAllData() }
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
