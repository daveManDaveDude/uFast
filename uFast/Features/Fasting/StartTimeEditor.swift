import SwiftUI

struct StartTimeEditor: View {
    @Environment(\.appTextResolver) private var textResolver
    enum Mode {
        case create
        case correct

        func confirmationTitle(using resolver: AppTextResolver) -> String {
            switch self {
            case .create:
                resolver(.startFast)
            case .correct:
                resolver(.fastingCopy(.save))
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
        Self.validationMessage(
            for: selectedStartDate,
            now: clock.now,
            hasConflict: hasConflict(selectedStartDate),
            existingError: validationError,
            textResolver: textResolver
        )
    }

    static func validationMessage(
        for selectedStartDate: Date,
        now: Date,
        hasConflict: Bool,
        existingError: String? = nil,
        textResolver: AppTextResolver = .init()
    ) -> String? {
        if selectedStartDate > now {
            return textResolver(.fastingCopy(.startFuture))
        }
        if selectedStartDate < now.addingTimeInterval(-FastStartService.maximumStartAge) {
            return textResolver(.fastingCopy(.startTooOld))
        }
        if hasConflict {
            return textResolver(.fastingCopy(.overlapError))
        }
        return existingError
    }

    static func isWithinCurrentStartWindow(for selectedStartDate: Date, now: Date) -> Bool {
        selectedStartDate >= now.addingTimeInterval(-FastStartService.maximumStartAge)
            && selectedStartDate <= now
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading(
                            mode == .create
                                ? textResolver(.fastingCopy(.startCreateHeading))
                                : textResolver(.fastingCopy(.startCorrectHeading)),
                            eyebrow: textResolver(.fastingCopy(.startEyebrow))
                        )
                        Text(
                            mode == .create
                                ? textResolver(.fastingCopy(.startCreateDescription))
                                : textResolver(.fastingCopy(.startCorrectDescription))
                        )
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .listRowBackground(UFastTheme.surface)
                }

                if isShowingLegacyDraft {
                    Section {
                        Button(textResolver(.fastingCopy(.useEarliestValidStart))) {
                            isShowingLegacyDraft = false
                            selectedStartDate = earliestAllowedStartDate
                            validationError = nil
                            saveError = nil
                        }
                        .accessibilityIdentifier("fast.start-use-earliest")
                    } footer: {
                        Text(textResolver(.fastingCopy(.legacyStartFooter)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    DatePicker(
                        textResolver(.date),
                        selection: $selectedStartDate,
                        in: allowedStartRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("fast.start-date")

                    DatePicker(
                        textResolver(.time),
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
            .navigationTitle(textResolver(.fastingCopy(.startTimeTitle)))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .tint(UFastTheme.action)
            .onChange(of: selectedStartDate) { _, _ in
                if Self.isWithinCurrentStartWindow(for: selectedStartDate, now: clock.now) {
                    isShowingLegacyDraft = false
                }
                validationError = nil
                saveError = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("fast.start-cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.confirmationTitle(using: textResolver)) {
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
            validationError = validationMessage
            saveError = nil
            return
        }

        do {
            try onConfirm(selectedStartDate)
            validationError = nil
            saveError = nil
        } catch let error as FastStartError {
            switch error {
            case .futureStartTime:
                validationError = textResolver(.fastingCopy(.startFuture))
                saveError = nil
            case .startTimeBeyondMaximumAge:
                validationError = textResolver(.fastingCopy(.startTooOld))
                saveError = nil
            case .conflict:
                validationError = textResolver(.fastingCopy(.overlapError))
                saveError = nil
            case let .crossesCaloricBoundary(date):
                validationError = Self.caloricBoundaryMessage(for: date, textResolver: textResolver)
                saveError = nil
            case .noActiveFast:
                saveError = textResolver(.fastingCopy(.startSaveError))
            }
        } catch {
            saveError = textResolver(.fastingCopy(.startSaveError))
        }
    }

    static func caloricBoundaryMessage(
        for date: Date,
        textResolver: AppTextResolver = .init()
    ) -> String {
        textResolver(
            .fastingValidation(
                .startBoundary,
                value: date.formatted(date: .omitted, time: .shortened)
            )
        )
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
