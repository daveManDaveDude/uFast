import SwiftUI

struct StartTimeEditor: View {
    enum Mode {
        case create
        case correct

        var confirmationTitle: String {
            switch self {
            case .create:
                "Start fast"
            case .correct:
                "Save"
            }
        }
    }

    let mode: Mode
    let clock: any AppClock
    let hasConflict: (Date) -> Bool
    let onConfirm: (Date) throws -> Void
    let onCancel: () -> Void

    @State private var selectedStartDate: Date
    @State private var saveError: String?

    init(
        mode: Mode,
        initialStartDate: Date,
        clock: any AppClock,
        hasConflict: @escaping (Date) -> Bool = { _ in false },
        onConfirm: @escaping (Date) throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.clock = clock
        self.hasConflict = hasConflict
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedStartDate = State(initialValue: initialStartDate)
    }

    private var isFutureStart: Bool {
        selectedStartDate > clock.now
    }

    private var isBeyondCorrectionLimit: Bool {
        switch mode {
        case .create:
            false
        case .correct:
            selectedStartDate <
                clock.now.addingTimeInterval(-FastStartService.maximumCorrectionAge)
        }
    }

    private var isInvalidStart: Bool {
        isFutureStart || isBeyondCorrectionLimit || hasConflict(selectedStartDate)
    }

    private var allowedStartRange: ClosedRange<Date> {
        let earliestDate = switch mode {
        case .create:
            Date.distantPast
        case .correct:
            clock.now.addingTimeInterval(-FastStartService.maximumCorrectionAge)
        }

        return earliestDate ... clock.now
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Date",
                        selection: $selectedStartDate,
                        in: allowedStartRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("fast.start-date")

                    DatePicker(
                        "Time",
                        selection: $selectedStartDate,
                        in: allowedStartRange,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("fast.start-time")
                } footer: {
                    if isFutureStart {
                        Text("Start time can’t be in the future.")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("fast.start-validation")
                    } else if isBeyondCorrectionLimit {
                        Text("Start time must be within the past 24 hours.")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("fast.start-validation")
                    } else if hasConflict(selectedStartDate) {
                        Text("This fast overlaps another recorded fast.")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("fast.start-validation")
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("fast.start-save-error")
                    }
                }
            }
            .navigationTitle("Start time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("fast.start-cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.confirmationTitle) {
                        confirm()
                    }
                    .disabled(isInvalidStart)
                    .accessibilityIdentifier("fast.start-confirm")
                }
            }
        }
    }

    private func confirm() {
        guard !isInvalidStart else {
            return
        }

        do {
            try onConfirm(selectedStartDate)
            saveError = nil
        } catch {
            saveError = "Your start time couldn’t be saved. Please try again."
        }
    }
}
