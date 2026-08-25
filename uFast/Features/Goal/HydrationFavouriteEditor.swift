import SwiftUI

struct HydrationFavouriteEditorPresentation: Identifiable {
    let id: UUID
    let favourite: HydrationFavouriteSnapshot?

    init(favourite: HydrationFavouriteSnapshot?) {
        id = favourite?.id ?? UUID()
        self.favourite = favourite
    }
}

struct HydrationFavouriteEditor: View {
    @Environment(\.appTextResolver) private var textResolver
    @FocusState private var focusedField: Field?
    @State private var name: String
    @State private var amount: String
    @State private var isCaloric: Bool
    @State private var errorMessage: String?
    @State private var isRemovalConfirmationPresented = false
    @State private var isSaving = false

    let presentation: HydrationFavouriteEditorPresentation
    let existingFavourites: [HydrationFavouriteSnapshot]
    let onSave: (String, String, Bool) throws -> Void
    let onRemove: (() throws -> Void)?
    let onCancel: () -> Void

    init(
        presentation: HydrationFavouriteEditorPresentation,
        existingFavourites: [HydrationFavouriteSnapshot] = [],
        onSave: @escaping (String, String, Bool) throws -> Void,
        onRemove: (() throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.existingFavourites = existingFavourites
        self.onSave = onSave
        self.onRemove = onRemove
        self.onCancel = onCancel
        _name = State(initialValue: presentation.favourite?.name ?? "")
        _amount = State(initialValue: presentation.favourite.map { String($0.volumeMillilitres) } ?? "")
        _isCaloric = State(initialValue: presentation.favourite?.isCaloric ?? false)
    }

    private var validationError: HydrationFavouriteValidationError? {
        HydrationFavouriteValidator.validationError(
            name: name,
            amount: amount,
            existing: existingFavourites,
            excluding: presentation.favourite?.id
        )
    }

    private var isValid: Bool {
        validationError == nil && Int(amount) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(textResolver(.favouriteNamePlaceholder), text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("settings.favourite.name")
                    TextField(textResolver(.favouriteAmountPlaceholder), text: $amount)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .amount)
                        .accessibilityIdentifier("settings.favourite.amount")
                    LabeledContent(textResolver(.favouriteUnit)) {
                        Text(textResolver(.settingsMillilitres))
                    }
                    .accessibilityIdentifier("settings.favourite.unit")
                    Toggle(textResolver(.favouriteCountsAsCaloric), isOn: $isCaloric)
                        .accessibilityIdentifier("settings.favourite.caloric")
                    Text(textResolver(.favouriteBoundaryExplanation))
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text(textResolver(.favouriteDetailsHeading))
                } footer: {
                    Text(textResolver(.favouriteDetailsFooter))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message = validationMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.favourite.validation")
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.favourite.save-error")
                }

                if onRemove != nil {
                    Section {
                        Button(textResolver(.favouriteRemove), role: .destructive) {
                            isRemovalConfirmationPresented = true
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("settings.favourite.remove")
                    }
                }
            }
            .accessibilityIdentifier("settings.favourite.editor")
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle(textResolver(.favouriteTitle(isEditing: presentation.favourite != nil)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("settings.favourite.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.favouriteSave)) { save() }
                        .disabled(!isValid || isSaving)
                        .accessibilityIdentifier("settings.favourite.save")
                }
            }
            .onChange(of: name) { _, _ in errorMessage = nil }
            .onChange(of: amount) { _, _ in errorMessage = nil }
            .onChange(of: isCaloric) { _, _ in errorMessage = nil }
            .alert(
                textResolver(
                    .favouriteRemoveConfirmation(name: presentation.favourite?.name ?? name)
                ),
                isPresented: $isRemovalConfirmationPresented
            ) {
                Button(textResolver(.cancel), role: .cancel) {}
                    .accessibilityIdentifier("settings.favourite.remove-cancel")
                Button(textResolver(.favouriteRemoveAction), role: .destructive) { remove() }
                    .accessibilityIdentifier("settings.favourite.remove-confirm")
            }
        }
    }

    private var validationMessage: String? {
        validationError.map { textResolver(.favouriteValidation($0)) }
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true
        do {
            try onSave(name, amount, isCaloric)
        } catch {
            errorMessage = message(for: error, removal: false)
            isSaving = false
        }
    }

    private func remove() {
        guard let onRemove, !isSaving else { return }
        isSaving = true
        do {
            try onRemove()
        } catch {
            errorMessage = message(for: error, removal: true)
            isSaving = false
        }
    }

    private func message(for error: Error, removal: Bool) -> String {
        if removal {
            return textResolver(.favouriteRemoveError)
        }
        switch error as? HydrationFavouriteStoreError {
        case .duplicateName:
            return textResolver(.favouriteValidation(.duplicateName))
        case .invalidName, .nameTooLong:
            return textResolver(.favouriteValidation(.nameTooLong))
        case .invalidAmount:
            return textResolver(.favouriteValidation(.invalidAmount))
        default:
            return textResolver(.favouriteSaveError)
        }
    }

    private enum Field: Hashable {
        case name
        case amount
    }
}
