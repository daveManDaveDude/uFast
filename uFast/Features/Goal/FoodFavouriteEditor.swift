import SwiftUI

struct FoodFavouriteEditorPresentation: Identifiable {
    let id: UUID
    let favourite: FoodFavouriteSnapshot?

    init(favourite: FoodFavouriteSnapshot?) {
        id = favourite?.id ?? UUID()
        self.favourite = favourite
    }
}

struct FoodFavouriteEditor: View {
    @Environment(\.appTextResolver) private var textResolver
    @State private var description: String
    @State private var values: [FoodFavouriteNutritionField: String]
    @State private var showsDetails: Bool
    @State private var errorMessage: String?
    @State private var errorAccessibilityIdentifier = "settings.food-favourite.save-error"
    @State private var isRemovalConfirmationPresented = false
    @State private var isSaving = false

    let presentation: FoodFavouriteEditorPresentation
    let locale: Locale
    let existingFavourites: [FoodFavouriteSnapshot]
    let onSave: (String, FoodNutrition) throws -> Void
    let onRemove: (() throws -> Void)?
    let onCancel: () -> Void

    init(
        presentation: FoodFavouriteEditorPresentation,
        locale: Locale,
        existingFavourites: [FoodFavouriteSnapshot] = [],
        onSave: @escaping (String, FoodNutrition) throws -> Void,
        onRemove: (() throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.locale = locale
        self.existingFavourites = existingFavourites
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        _description = State(initialValue: presentation.favourite?.description ?? "")
        var initial: [FoodFavouriteNutritionField: String] = [:]
        for field in FoodFavouriteNutritionField.allCases {
            if let value = presentation.favourite?.nutrition.value(for: field) {
                initial[field] = FoodNutritionValueFormatter.string(value, locale: locale)
            } else {
                initial[field] = ""
            }
        }
        _values = State(initialValue: initial)
        _showsDetails = State(initialValue: presentation.favourite?.nutrition.values.isEmpty == false)
    }

    private var nutrition: FoodNutrition {
        FoodNutrition(
            energyKilocalories: number(.energyKilocalories),
            proteinGrams: number(.proteinGrams),
            carbohydrateGrams: number(.carbohydrateGrams),
            fatGrams: number(.fatGrams),
            fibreGrams: number(.fibreGrams),
            sugarGrams: number(.sugarGrams),
            saltGrams: number(.saltGrams)
        )
    }

    private var validationError: FoodFavouriteValidationError? {
        FoodFavouriteValidator.validationError(
            description: description,
            nutrition: nutrition,
            existing: existingFavourites,
            excluding: presentation.favourite?.id
        )
    }

    private var isValid: Bool {
        validationError == nil && invalidNumberField == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(textResolver(.settingsFoodFavouritePlaceholder), text: $description)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("settings.food-favourite.description")
                } header: {
                    Text(textResolver(.foodOptionalDetailsSection))
                } footer: {
                    if let error = validationError, isDescriptionValidationError(error) {
                        validationLabel(error, identifier: "settings.food-favourite.validation.description")
                    }
                }

                Section {
                    Button(showsDetails ? textResolver(.foodDetailsHide) : textResolver(.foodDetailsAdd)) {
                        showsDetails.toggle()
                    }
                    .accessibilityIdentifier("settings.food-favourite.details.toggle")
                }

                if showsDetails {
                    Section {
                        ForEach(FoodFavouriteNutritionField.allCases, id: \.self) { field in
                            HStack {
                                Text(textResolver(.foodNutritionField(field.appTextField)))
                                Spacer()
                                TextField(
                                    textResolver(.foodNutritionValuePlaceholder),
                                    text: binding(for: field)
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel(textResolver(.foodNutritionField(field.appTextField)))
                                .accessibilityIdentifier("settings.food-favourite.nutrition.\(field.identifier)")
                            }
                            if invalidNumberField == field || validationError == .invalidNutrition(field) {
                                validationLabel(
                                    .invalidNutrition(field),
                                    identifier: "settings.food-favourite.validation.nutrition.\(field.identifier)"
                                )
                            }
                        }
                        Text(textResolver(.foodNutritionRange))
                            .font(.footnote)
                            .foregroundStyle(UFastTheme.secondaryText)
                    } header: {
                        Text(textResolver(.foodOptionalDetailsSection))
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(errorAccessibilityIdentifier)
                }

                if onRemove != nil {
                    Section {
                        Button(textResolver(.settingsFoodFavouriteRemove), role: .destructive) {
                            isRemovalConfirmationPresented = true
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("settings.food-favourite.remove")
                    }
                }
            }
            .accessibilityIdentifier("settings.food-favourite.editor")
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle(textResolver(.settingsFoodFavouriteTitle(isEditing: presentation.favourite != nil)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("settings.food-favourite.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.settingsFoodFavouriteSave), action: save)
                        .disabled(!isValid || isSaving)
                        .accessibilityIdentifier("settings.food-favourite.save")
                }
            }
            .onChange(of: description) {
                errorMessage = nil
                errorAccessibilityIdentifier = "settings.food-favourite.save-error"
            }
            .alert(
                textResolver(
                    .settingsFoodFavouriteRemoveConfirmation(
                        name: presentation.favourite?.description ?? description
                    )
                ),
                isPresented: $isRemovalConfirmationPresented
            ) {
                Button(textResolver(.cancel), role: .cancel) {}
                    .accessibilityIdentifier("settings.food-favourite.remove-cancel")
                Button(textResolver(.settingsFoodFavouriteRemoveAction), role: .destructive, action: remove)
                    .accessibilityIdentifier("settings.food-favourite.remove-confirm")
            }
        }
    }

    private var invalidNumberField: FoodFavouriteNutritionField? {
        for field in FoodFavouriteNutritionField.allCases {
            guard let value = values[field],
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let number = FoodNutritionValueParser.value(value, locale: locale),
                  DomainValidation.isFinite(number, in: 0 ... FoodFavouriteValidator.maximumNutritionValue)
            else {
                return field
            }
        }
        return nil
    }

    private func number(_ field: FoodFavouriteNutritionField) -> Double? {
        guard let value = values[field],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return FoodNutritionValueParser.value(value, locale: locale)
    }

    private func binding(for field: FoodFavouriteNutritionField) -> Binding<String> {
        Binding(get: { values[field] ?? "" }, set: { values[field] = $0; errorMessage = nil })
    }

    private func isDescriptionValidationError(_ error: FoodFavouriteValidationError) -> Bool {
        switch error {
        case .blankDescription, .descriptionTooLong, .duplicateDescription:
            true
        case .invalidNutrition:
            false
        }
    }

    private func validationLabel(_ error: FoodFavouriteValidationError, identifier: String) -> some View {
        Label(textResolver(.settingsFoodFavouriteValidation(error)), systemImage: "exclamationmark.circle")
            .foregroundStyle(UFastTheme.error)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true
        do {
            try onSave(description, nutrition)
        } catch {
            errorMessage = message(for: error)
            errorAccessibilityIdentifier = accessibilityIdentifier(for: error)
            isSaving = false
        }
    }

    private func remove() {
        guard let onRemove, !isSaving else { return }
        isSaving = true
        do {
            try onRemove()
        } catch {
            errorMessage = removalMessage(for: error)
            errorAccessibilityIdentifier = accessibilityIdentifier(for: error)
            isSaving = false
        }
    }

    private func removalMessage(for error: Error) -> String {
        switch error as? FoodFavouriteStoreError {
        case .stale, .recordNotFound: textResolver(.settingsFoodFavouriteStale)
        default: textResolver(.settingsFoodFavouriteRemoveError)
        }
    }

    private func message(for error: Error) -> String {
        switch error as? FoodFavouriteStoreError {
        case let .invalidNutrition(field): textResolver(.settingsFoodFavouriteValidation(.invalidNutrition(field)))
        case .blankDescription: textResolver(.settingsFoodFavouriteValidation(.blankDescription))
        case .descriptionTooLong: textResolver(.settingsFoodFavouriteValidation(.descriptionTooLong))
        case .duplicateDescription: textResolver(.settingsFoodFavouriteValidation(.duplicateDescription))
        case .stale, .recordNotFound: textResolver(.settingsFoodFavouriteStale)
        default: textResolver(.settingsFoodFavouriteSaveError)
        }
    }

    private func accessibilityIdentifier(for error: Error) -> String {
        switch error as? FoodFavouriteStoreError {
        case .stale, .recordNotFound: "settings.food-favourite.stale"
        default: "settings.food-favourite.save-error"
        }
    }
}

private extension FoodFavouriteNutritionField {
    var identifier: String {
        switch self {
        case .energyKilocalories: "energy"
        case .proteinGrams: "protein"
        case .carbohydrateGrams: "carbohydrate"
        case .fatGrams: "fat"
        case .fibreGrams: "fibre"
        case .sugarGrams: "sugar"
        case .saltGrams: "salt"
        }
    }

    var appTextField: AppText.FoodNutritionField {
        switch self {
        case .energyKilocalories: .energy
        case .proteinGrams: .protein
        case .carbohydrateGrams: .carbohydrate
        case .fatGrams: .fat
        case .fibreGrams: .fibre
        case .sugarGrams: .sugar
        case .saltGrams: .salt
        }
    }
}
