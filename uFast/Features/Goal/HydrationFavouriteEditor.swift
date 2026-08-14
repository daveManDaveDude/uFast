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
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .accessibilityIdentifier("settings.favourite.name")
                    TextField("Amount", text: $amount)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .amount)
                        .accessibilityIdentifier("settings.favourite.amount")
                    LabeledContent("Unit") { Text("ml") }
                        .accessibilityIdentifier("settings.favourite.unit")
                    Toggle("Counts as caloric", isOn: $isCaloric)
                        .accessibilityIdentifier("settings.favourite.caloric")
                    Text("A caloric drink counts as a fasting boundary.")
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Drink details")
                } footer: {
                    Text("Names are unique and can be up to 80 characters.")
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
                        Button("Remove favourite", role: .destructive) {
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
            .navigationTitle(presentation.favourite == nil ? "Add favourite" : "Edit favourite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("settings.favourite.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || isSaving)
                        .accessibilityIdentifier("settings.favourite.save")
                }
            }
            .onChange(of: name) { _, _ in errorMessage = nil }
            .onChange(of: amount) { _, _ in errorMessage = nil }
            .onChange(of: isCaloric) { _, _ in errorMessage = nil }
            .alert(
                "Remove “\(presentation.favourite?.name ?? name)” from favourites?",
                isPresented: $isRemovalConfirmationPresented
            ) {
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("settings.favourite.remove-cancel")
                Button("Remove", role: .destructive) { remove() }
                    .accessibilityIdentifier("settings.favourite.remove-confirm")
            }
        }
    }

    private var validationMessage: String? {
        switch validationError {
        case .blankName, .nameTooLong: "Enter a name up to 80 characters."
        case .duplicateName, .reservedName: "Choose a name that isn’t already in your favourites."
        case .invalidAmount: "Enter an amount from 1 to 5,000 ml."
        case nil: nil
        }
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
            return "Your favourite couldn’t be removed. Please try again."
        }
        switch error as? HydrationFavouriteStoreError {
        case .duplicateName, .reservedName:
            return "Choose a name that isn’t already in your favourites."
        case .invalidName, .nameTooLong:
            return "Enter a name up to 80 characters."
        case .invalidAmount:
            return "Enter an amount from 1 to 5,000 ml."
        default:
            return "Your favourite couldn’t be saved. Please try again."
        }
    }

    private enum Field: Hashable {
        case name
        case amount
    }
}
