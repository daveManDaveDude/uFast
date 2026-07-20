import SwiftUI

struct CompletedFastEditor: View {
    let presentation: CompletedFastEditorPresentation
    let validation: (Date, Date) -> CompletedFastError?
    let onSave: (Date, Date) throws -> Void
    let onDelete: () throws -> Void
    let onCancel: () -> Void

    @State private var selectedStartDate: Date
    @State private var selectedEndDate: Date
    @State private var saveError: String?
    @State private var deleteError: String?
    @State private var isDeleteConfirmationPresented = false

    init(
        presentation: CompletedFastEditorPresentation,
        validation: @escaping (Date, Date) -> CompletedFastError?,
        onSave: @escaping (Date, Date) throws -> Void,
        onDelete: @escaping () throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.validation = validation
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _selectedStartDate = State(initialValue: presentation.startDate)
        _selectedEndDate = State(initialValue: presentation.endDate)
    }

    private var validationError: CompletedFastError? {
        validation(selectedStartDate, selectedEndDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading("Recorded boundaries", eyebrow: "Edit fast")
                        Text("Review both boundaries before saving. The recorded goal is unchanged.")
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.formSurface)
                }

                Section("Start") {
                    DatePicker(
                        "Start date",
                        selection: $selectedStartDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.edit.start-date")

                    DatePicker(
                        "Start time",
                        selection: $selectedStartDate,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.edit.start-time")
                }
                .listRowBackground(UFastTheme.formSurface)
                .listSectionSeparatorTint(UFastTheme.border)

                Section {
                    DatePicker(
                        "End date",
                        selection: $selectedEndDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.edit.end-date")

                    DatePicker(
                        "End time",
                        selection: $selectedEndDate,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.edit.end-time")
                } header: {
                    Text("End")
                } footer: {
                    if let message = validationMessage {
                        Text(message)
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Validation error. \(message)")
                            .accessibilityIdentifier("history.edit.validation")
                    }
                }
                .listRowBackground(UFastTheme.formSurface)
                .listSectionSeparatorTint(UFastTheme.border)

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("history.edit.save-error")
                    }
                    .listRowBackground(UFastTheme.formSurface)
                }

                if let deleteError {
                    Section {
                        Label(deleteError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("history.edit.delete-error")
                    }
                    .listRowBackground(UFastTheme.formSurface)
                }

                Section {
                    Button("Delete fast", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .buttonStyle(UFastDestructiveButtonStyle())
                    .accessibilityIdentifier("history.edit.delete")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Edit fast")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .tint(UFastTheme.action)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("history.edit.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(validationError != nil)
                        .accessibilityIdentifier("history.edit.save")
                }
            }
            .alert("Delete this fast?", isPresented: $isDeleteConfirmationPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Delete fast", role: .destructive, action: delete)
            } message: {
                Text("This removes the record from this device.")
            }
        }
    }

    private var validationMessage: String? {
        switch validationError {
        case .startTimeNotBeforeEndTime:
            "Start time must be before end time."
        case .futureStartTime:
            "Start time can’t be in the future."
        case .futureEndTime:
            "End time can’t be in the future."
        case .conflict:
            "This fast overlaps another recorded fast."
        case .noCompletedFast, nil:
            nil
        }
    }

    private func save() {
        guard validationError == nil else {
            return
        }

        do {
            try onSave(selectedStartDate, selectedEndDate)
            saveError = nil
        } catch {
            saveError = "Your changes couldn’t be saved. Please try again."
        }
    }

    private func delete() {
        do {
            try onDelete()
            deleteError = nil
        } catch {
            deleteError = "This fast couldn’t be deleted. Please try again."
        }
    }
}

#Preview("Completed fast · Edit") {
    CompletedFastEditor(
        presentation: CompletedFastEditorPresentation(
            id: UUID(),
            startDate: Date(timeIntervalSince1970: 1_800_000_000 - 46800),
            endDate: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        validation: { _, _ in nil },
        onSave: { _, _ in },
        onDelete: {},
        onCancel: {}
    )
}

#Preview("Completed fast · Validation") {
    CompletedFastEditor(
        presentation: CompletedFastEditorPresentation(
            id: UUID(),
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_000_000)
        ),
        validation: { _, _ in .startTimeNotBeforeEndTime },
        onSave: { _, _ in },
        onDelete: {},
        onCancel: {}
    )
    .environment(\.dynamicTypeSize, .accessibility2)
}
