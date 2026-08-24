import SwiftUI

struct CompletedFastEditor: View {
    @Environment(\.appTextResolver) private var textResolver
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
                        UFastSectionHeading(
                            textResolver(.fastingCopy(.recordedBoundaries)),
                            eyebrow: textResolver(.fastingCopy(.editFastEyebrow))
                        )
                        Text(textResolver(.fastingCopy(.reviewBoundaries)))
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.formSurface)
                }

                Section(textResolver(.fastingCopy(.startSection))) {
                    DatePicker(
                        textResolver(.fastingCopy(.startDate)),
                        selection: $selectedStartDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.edit.start-date")

                    DatePicker(
                        textResolver(.fastingCopy(.startTime)),
                        selection: $selectedStartDate,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.edit.start-time")
                }
                .listRowBackground(UFastTheme.formSurface)
                .listSectionSeparatorTint(UFastTheme.border)

                Section {
                    DatePicker(
                        textResolver(.fastingCopy(.endDate)),
                        selection: $selectedEndDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.edit.end-date")

                    DatePicker(
                        textResolver(.fastingCopy(.endTime)),
                        selection: $selectedEndDate,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.edit.end-time")
                } header: {
                    Text(textResolver(.fastingCopy(.endHeader)))
                } footer: {
                    if let message = validationMessage {
                        Text(message)
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(
                                textResolver(.fastingCopy(.validationError))
                                    + textResolver(.historyCopy(.separatorSpace))
                                    + message
                            )
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
                    Button(textResolver(.fastingCopy(.deleteFast)), role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .buttonStyle(UFastDestructiveButtonStyle())
                    .accessibilityIdentifier("history.edit.delete")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(textResolver(.fastingCopy(.editFastTitle)))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .tint(UFastTheme.action)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("history.edit.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.fastingCopy(.save)), action: save)
                        .disabled(validationError != nil)
                        .accessibilityIdentifier("history.edit.save")
                }
            }
            .alert(textResolver(.fastingCopy(.deleteConfirmationTitle)), isPresented: $isDeleteConfirmationPresented) {
                Button(textResolver(.cancel), role: .cancel) {}
                Button(textResolver(.fastingCopy(.deleteFast)), role: .destructive, action: delete)
            } message: {
                Text(textResolver(.fastingCopy(.localDeviceRemoval)))
            }
        }
    }

    private var validationMessage: String? {
        Self.validationMessage(for: validationError, textResolver: textResolver)
    }

    static func validationMessage(
        for error: CompletedFastError?,
        textResolver: AppTextResolver = .init()
    ) -> String? {
        switch error {
        case .startTimeNotBeforeEndTime:
            textResolver(.fastingCopy(.startBeforeEnd))
        case .futureStartTime:
            textResolver(.fastingCopy(.startFuture))
        case .futureEndTime:
            textResolver(.fastingCopy(.endFuture))
        case .conflict:
            textResolver(.fastingCopy(.overlapError))
        case let .crossesCaloricBoundary(date):
            textResolver(
                .fastingValidation(
                    .completedBoundary,
                    value: date.formatted(date: .omitted, time: .shortened)
                )
            )
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
            saveError = textResolver(.fastingCopy(.changesSaveError))
        }
    }

    private func delete() {
        do {
            try onDelete()
            deleteError = nil
        } catch {
            deleteError = textResolver(.fastingCopy(.fastDeleteError))
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
