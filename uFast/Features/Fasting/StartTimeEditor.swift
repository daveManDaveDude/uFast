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
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading(
                            mode == .create ? "When did this fast start?" : "Correct the recorded start",
                            eyebrow: "Start time"
                        )
                        Text(
                            mode == .create
                                ? "Choose the date and time you intend to record."
                                : "Corrections are available for the preceding 24 hours."
                        )
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.surface)
                }

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
                        validationLabel("Start time can’t be in the future.")
                            .accessibilityIdentifier("fast.start-validation")
                    } else if isBeyondCorrectionLimit {
                        validationLabel("Start time must be within the past 24 hours.")
                            .accessibilityIdentifier("fast.start-validation")
                    } else if hasConflict(selectedStartDate) {
                        validationLabel("This fast overlaps another recorded fast.")
                            .accessibilityIdentifier("fast.start-validation")
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fast.start-save-error")
                    }
                }
            }
            .navigationTitle("Start time")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .tint(UFastTheme.action)
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

    private func validationLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .foregroundStyle(UFastTheme.error)
            .fixedSize(horizontal: false, vertical: true)
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

#Preview("Start fast · Past time") {
    StartTimeEditor(
        mode: .create,
        initialStartDate: Date(timeIntervalSince1970: 1_800_000_000 - 3600),
        clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
        onConfirm: { _ in },
        onCancel: {}
    )
}

#Preview("Start fast · Accessibility") {
    StartTimeEditor(
        mode: .correct,
        initialStartDate: Date(timeIntervalSince1970: 1_800_000_000 - 3600),
        clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
        onConfirm: { _ in },
        onCancel: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
