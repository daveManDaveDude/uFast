import SwiftUI

struct SettingsGoalSection: View {
    @Environment(\.appTextResolver) private var textResolver
    let selection: FastingGoal
    let goalBinding: Binding<FastingGoal>

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(
                textResolver(.settingsGoalHeading),
                eyebrow: textResolver(.settingsGoalSelected(hours: selection.hours))
            )
            Text(textResolver(.settingsGoalDescription))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            FastingGoalPicker(selection: goalBinding)
        }
        .uFastCard(accent: UFastTheme.sage)
    }
}

struct SettingsPrivacySection: View {
    @Environment(\.appTextResolver) private var textResolver

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(textResolver(.settingsDataHeading))
            Text(textResolver(.settingsDataDescription))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(textResolver(.settingsDataLoss))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                PrivacySafetyView()
            } label: {
                Label(textResolver(.settingsPrivacyLink), systemImage: "lock.shield")
            }
            .buttonStyle(UFastActionRowButtonStyle())
            .accessibilityIdentifier("settings.privacy-safety")
        }
        .uFastCard(accent: UFastTheme.sky)
    }
}

struct SettingsWidgetSection: View {
    @Environment(\.appTextResolver) private var textResolver

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(textResolver(.settingsWidgetHeading))
            Text(textResolver(.settingsWidgetDescription))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(textResolver(.settingsWidgetInstructions))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard(accent: UFastTheme.sage)
    }
}

struct SettingsLiveActivitiesSection: View {
    @Environment(\.appTextResolver) private var textResolver
    let isOn: Binding<Bool>
    let status: String?
    let availability: LiveActivityAvailability?

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(textResolver(.settingsLiveActivityHeading))
            Toggle(textResolver(.settingsLiveActivityToggle), isOn: isOn)
                .accessibilityIdentifier("settings.live-activities.toggle")
            Text(textResolver(.settingsLiveActivitySupport))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(textResolver(.settingsLiveActivityExplanation))
                .font(.footnote)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let status {
                Label(status, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.live-activities.status")
            } else if let availability, availability != .enabled {
                Text(textResolver(.liveActivityStatus(.unavailable(availability))))
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
    @Environment(\.appTextResolver) private var textResolver
    let isOn: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(textResolver(.settingsInferredHeading))
            Toggle(textResolver(.settingsInferredToggle), isOn: isOn)
                .accessibilityIdentifier("settings.inferred-fasts.toggle")
            Text(textResolver(.settingsInferredDescription))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard(accent: UFastTheme.sky)
    }
}

struct SettingsFavouritesSection: View {
    @Environment(\.appTextResolver) private var textResolver
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
            UFastSectionHeading(textResolver(.settingsFavouritesHeading))
            Text(textResolver(.settingsFavouritesDescription))
                .font(.subheadline).foregroundStyle(UFastTheme.secondaryText)
            field(.water, text: $water, identifier: "settings.drink.water")
            field(.tea, text: $tea, identifier: "settings.drink.tea")
            field(.coffee, text: $coffee, identifier: "settings.drink.coffee")
            ForEach(userCreatedFavourites) { favourite in
                Button { onEditFavourite(favourite) } label: {
                    HStack(spacing: UFastTheme.Spacing.standard) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(favourite.name).font(.headline).foregroundStyle(UFastTheme.primary)
                            Text(
                                textResolver(
                                    .settingsFavouriteDetail(
                                        volumeMillilitres: favourite.volumeMillilitres,
                                        isCaloric: favourite.isCaloric
                                    )
                                )
                            )
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
                .accessibilityValue(
                    textResolver(
                        .settingsFavouriteAccessibilityValue(
                            volumeMillilitres: favourite.volumeMillilitres,
                            isCaloric: favourite.isCaloric
                        )
                    )
                )
                .accessibilityIdentifier("settings.favourite.\(favourite.id.uuidString)")
            }
            Button(textResolver(.settingsAddFavourite), action: onAddFavourite)
                .buttonStyle(UFastSecondaryButtonStyle())
                .accessibilityIdentifier("settings.favourite.add")
            if !valuesAreValid {
                Label(textResolver(.settingsFavouriteValidation), systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .accessibilityIdentifier("settings.drink.validation")
            }
            Text(textResolver(.settingsFavouriteAutoSave))
                .font(.footnote)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard(accent: UFastTheme.sky)
    }

    private func field(
        _ field: FavouriteField,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        let label = textResolver(.settingsFavouriteField(field))
        return HStack {
            Text(label)
            Spacer()
            FavouriteAmountTextField(
                text: text,
                label: label,
                identifier: identifier,
                textResolver: textResolver,
                isFocused: Binding(
                    get: { focusedField == field },
                    set: { focusedField = $0 ? field : (focusedField == field ? nil : focusedField) }
                )
            )
            .frame(width: 100)
            Text(textResolver(.settingsMillilitres))
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityHidden(true)
        }
    }
}

struct SettingsDeleteSection: View {
    @Environment(\.appTextResolver) private var textResolver
    let error: String?
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading(textResolver(.settingsYourDataHeading))
            Text(textResolver(.settingsDeleteDescription))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(textResolver(.settingsDeleteAll), role: .destructive, action: onDelete)
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
