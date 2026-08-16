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

    private let initialStartDate: Date
    @State private var selectedStartDate: Date
    @State private var isShowingLegacyDraft: Bool
    @State private var validationError: String?
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
        self.initialStartDate = initialStartDate
        _selectedStartDate = State(initialValue: initialStartDate)
        _isShowingLegacyDraft = State(
            initialValue: mode == .correct
                && initialStartDate < clock.now.addingTimeInterval(-FastStartService.maximumStartAge)
        )
    }

    private var isFutureStart: Bool {
        selectedStartDate > clock.now
    }

    private var earliestAllowedStartDate: Date {
        clock.now.addingTimeInterval(-FastStartService.maximumStartAge)
    }

    private var isBeyondMaximumAge: Bool {
        selectedStartDate < earliestAllowedStartDate
    }

    private var isInvalidStart: Bool {
        isFutureStart
            || isBeyondMaximumAge
            || hasConflict(selectedStartDate)
            || validationError != nil
    }

    private var allowedStartRange: ClosedRange<Date> {
        // A legacy active fast can legitimately be older than the new policy.
        // Keep that stored instant visible instead of allowing DatePicker to
        // clamp it on open. Once replacement is chosen, the picker is bounded
        // by the same inclusive policy as the service.
        let earliestDate = isShowingLegacyDraft
            ? initialStartDate
            : earliestAllowedStartDate

        return earliestDate ... clock.now
    }

    private var validationMessage: String? {
        if isFutureStart {
            return "Start time can’t be in the future."
        }
        if isBeyondMaximumAge {
            return "Start time must be within the past 36 hours."
        }
        if hasConflict(selectedStartDate) {
            return "This fast overlaps another recorded fast."
        }
        return validationError
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
                                : "Corrections are available for the preceding 36 hours."
                        )
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.surface)
                }

                if isShowingLegacyDraft {
                    Section {
                        Button("Use earliest valid start") {
                            isShowingLegacyDraft = false
                            selectedStartDate = earliestAllowedStartDate
                            validationError = nil
                            saveError = nil
                        }
                        .accessibilityIdentifier("fast.start-use-earliest")
                    } footer: {
                        Text("The stored start is older than the preceding 36 hours. Choose a new start to replace it.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                    if let validationMessage {
                        validationLabel(validationMessage)
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
            .onChange(of: selectedStartDate) { _, _ in
                validationError = nil
                saveError = nil
            }
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
            validationError = nil
            saveError = nil
        } catch let error as FastStartError {
            switch error {
            case .futureStartTime:
                validationError = "Start time can’t be in the future."
                saveError = nil
            case .startTimeBeyondMaximumAge:
                validationError = "Start time must be within the past 36 hours."
                saveError = nil
            case .conflict:
                validationError = "This fast overlaps another recorded fast."
                saveError = nil
            case .noActiveFast:
                saveError = "Your start time couldn’t be saved. Please try again."
            }
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
