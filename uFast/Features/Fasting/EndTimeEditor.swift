import SwiftUI

struct EndTimeEditor: View {
    let startDate: Date
    let clock: any AppClock
    let onConfirm: (Date) throws -> Void
    let onCancel: () -> Void

    @State private var selectedEndDate: Date
    @State private var saveError: String?

    init(
        startDate: Date,
        initialEndDate: Date,
        clock: any AppClock,
        onConfirm: @escaping (Date) throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.startDate = startDate
        self.clock = clock
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedEndDate = State(initialValue: initialEndDate)
    }

    private var validationMessage: String? {
        if selectedEndDate <= startDate {
            return "End time must be after the start time."
        }
        if selectedEndDate > clock.now {
            return "End time can’t be in the future."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading("When did this fast end?", eyebrow: "End time")
                        Text("The end must be after the recorded start and no later than now.")
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.surface)
                }

                Section {
                    DatePicker(
                        "Date",
                        selection: $selectedEndDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("fast.end-date")

                    DatePicker(
                        "Time",
                        selection: $selectedEndDate,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("fast.end-time")
                } footer: {
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fast.end-validation")
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fast.end-save-error")
                    }
                }
            }
            .navigationTitle("End time")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .tint(UFastTheme.action)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("fast.end-cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("End fast") {
                        confirm()
                    }
                    .disabled(validationMessage != nil)
                    .accessibilityIdentifier("fast.end-confirm")
                }
            }
        }
    }

    private func confirm() {
        guard validationMessage == nil else {
            return
        }

        do {
            try onConfirm(selectedEndDate)
            saveError = nil
        } catch {
            saveError = "Your end time couldn’t be saved. Please try again."
        }
    }
}

#Preview("End fast · Past time") {
    EndTimeEditor(
        startDate: Date(timeIntervalSince1970: 1_800_000_000 - 10800),
        initialEndDate: Date(timeIntervalSince1970: 1_800_000_000 - 3600),
        clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
        onConfirm: { _ in },
        onCancel: {}
    )
}

#Preview("End fast · Validation") {
    EndTimeEditor(
        startDate: Date(timeIntervalSince1970: 1_800_000_000),
        initialEndDate: Date(timeIntervalSince1970: 1_800_000_000),
        clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
        onConfirm: { _ in },
        onCancel: {}
    )
}
