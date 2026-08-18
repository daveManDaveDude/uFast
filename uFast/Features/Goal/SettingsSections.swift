import SwiftUI

struct SettingsGoalSection: View {
    let selection: FastingGoal
    let goalBinding: Binding<FastingGoal>

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Fasting goal", eyebrow: "\(selection.hours) hours selected")
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
    }
}

struct SettingsPrivacySection: View {
    var body: some View {
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
            Text("Deleting uFast or losing this iPhone may permanently remove your uFast data.")
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
    }
}

struct SettingsWidgetSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Lock and Home Screen widgets")
            Text(
                "If you add an optional uFast Lock Screen or Home Screen widget, "
                    + "it can show your recorded elapsed time and goal progress."
            )
            .font(.subheadline)
            .foregroundStyle(UFastTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            Text(
                "Touch and hold the Lock Screen to customize it, or touch and hold "
                    + "the Home Screen and tap + to add uFast. You can remove either "
                    + "widget at any time."
            )
            .font(.subheadline)
            .foregroundStyle(UFastTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard(accent: UFastTheme.sage)
    }
}

struct SettingsLiveActivitiesSection: View {
    let isOn: Binding<Bool>
    let status: String?
    let availability: LiveActivityAvailability?

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Live Activities")
            Toggle("Automatically show Live Activities", isOn: isOn)
                .accessibilityIdentifier("settings.live-activities.toggle")
            Text(AutomaticLiveActivityCopy.settingsSupportingCopy)
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(AutomaticLiveActivityCopy.settingsExplanation)
                .font(.footnote)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let status {
                Label(status, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.live-activities.status")
            } else if let availability, availability != .enabled {
                Text(availability == .disabled
                    ? ActiveFastLiveActivityStatusCopy.disabled
                    : ActiveFastLiveActivityStatusCopy.unsupported)
                    .font(.footnote)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.live-activities.availability")
            }
        }
        .uFastCard(accent: UFastTheme.sky)
    }
}

struct SettingsInferredFastSection: View {
    let isOn: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Inferred fasts")
            Toggle("Detect inferred fasts", isOn: isOn)
                .accessibilityIdentifier("settings.inferred-fasts.toggle")
            Text(
                "When enabled, uFast shows a clearly labelled fasting interval "
                    + "after eight hours without a caloric food or drink event. Nothing is "
                    + "saved until you choose Save fast or Start fast."
            )
            .font(.subheadline)
            .foregroundStyle(UFastTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard(accent: UFastTheme.sky)
    }
}

struct SettingsFavouritesSection: View {
    @Binding var water: String
    @Binding var tea: String
    @Binding var coffee: String
    @Binding var focusedField: FavouriteField?
    let valuesAreValid: Bool
    let userCreatedFavourites: [HydrationFavouriteSnapshot]
    let onAddFavourite: () -> Void
    let onEditFavourite: (HydrationFavouriteSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Drink favourites")
            Text("Choose the amount added by each Today shortcut.")
                .font(.subheadline).foregroundStyle(UFastTheme.secondaryText)
            field("Water", field: .water, text: $water, identifier: "settings.drink.water")
            field("Tea", field: .tea, text: $tea, identifier: "settings.drink.tea")
            field("Coffee", field: .coffee, text: $coffee, identifier: "settings.drink.coffee")
            ForEach(userCreatedFavourites) { favourite in
                Button { onEditFavourite(favourite) } label: {
                    HStack(spacing: UFastTheme.Spacing.standard) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(favourite.name).font(.headline).foregroundStyle(UFastTheme.primary)
                            Text("\(favourite.volumeMillilitres) ml · \(favourite.classification)")
                                .font(.subheadline)
                                .foregroundStyle(UFastTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(UFastTheme.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(UFastActionRowButtonStyle())
                .accessibilityLabel(favourite.name)
                .accessibilityValue("\(favourite.volumeMillilitres) millilitres, \(favourite.classification)")
                .accessibilityIdentifier("settings.favourite.\(favourite.id.uuidString)")
            }
            Button("Add favourite", action: onAddFavourite)
                .buttonStyle(UFastSecondaryButtonStyle())
                .accessibilityIdentifier("settings.favourite.add")
            if !valuesAreValid {
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
    }

    private func field(
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
                    get: { focusedField == field },
                    set: { focusedField = $0 ? field : (focusedField == field ? nil : focusedField) }
                )
            )
            .frame(width: 100)
            Text("ml").foregroundStyle(UFastTheme.secondaryText).accessibilityHidden(true)
        }
    }
}

struct SettingsDeleteSection: View {
    let error: String?
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Your data")
            Text("Delete every uFast record stored on this iPhone. This cannot be undone.")
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Delete all data", role: .destructive, action: onDelete)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings.data.delete-all")
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.data.delete-error")
            }
        }
        .uFastCard(accent: UFastTheme.apricot)
    }
}
