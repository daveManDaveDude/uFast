import SwiftUI

struct InferredFastConversionView: View {
    @Environment(\.appTextResolver) private var textResolver
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    let presentation: InferredFastConversionPresentation
    let clock: any AppClock
    let onConfirm: (InferredFastInterval) throws -> Void
    let onDelete: (InferredFastInterval) throws -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void
    let deadlineDriver: any HistoryDurationDeadlineDriver

    @State private var errorMessage: String?
    @State private var deleteFailure: DeleteFailure?
    @State private var showDeleteConfirmation = false
    @State private var now = Date.now

    init(
        presentation: InferredFastConversionPresentation,
        clock: any AppClock,
        onConfirm: @escaping (InferredFastInterval) throws -> Void,
        onDelete: @escaping (InferredFastInterval) throws -> Void,
        onCancel: @escaping () -> Void,
        onFailure: @escaping () -> Void,
        deadlineDriver: (any HistoryDurationDeadlineDriver)? = nil
    ) {
        self.presentation = presentation
        self.clock = clock
        self.onConfirm = onConfirm
        self.onDelete = onDelete
        self.onCancel = onCancel
        self.onFailure = onFailure
        self.deadlineDriver = deadlineDriver
            ?? (clock is MutableAppClock
                ? ManualHistoryDurationDeadline()
                : SystemHistoryDurationDeadline())
        _now = State(initialValue: clock.now)
    }

    private var interval: InferredFastInterval {
        presentation.interval.refreshed(at: now)
    }

    private var capDate: Date? {
        guard presentation.interval.isInProgress else { return nil }
        return presentation.interval.sourceDate.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: presentation.interval.goal)
        )
    }

    private var isCapReached: Bool {
        guard let capDate else { return false }
        return now >= capDate
    }

    private var actionTitle: String {
        interval.isInProgress
            ? textResolver(.startFast)
            : textResolver(.fastingCopy(.save))
    }

    private var title: String {
        interval.isInProgress
            ? textResolver(.fastingCopy(.inferredInProgressTitle))
            : textResolver(.fastingCopy(.inferredTitle))
    }

    private var explanation: String {
        interval.isInProgress
            ? textResolver(.fastingCopy(.inferredStartExplanation))
            : textResolver(.fastingCopy(.inferredSaveExplanation))
    }

    private var duration: String {
        if presentation.interval.isInProgress {
            return HistoryTextFormatting.activeDisplay(
                seconds: TimeInterval(
                    max(Int(interval.endDate.timeIntervalSince(interval.startDate)), 0)
                ),
                resolver: textResolver
            )
        }
        return HistoryTextFormatting.duration(
            from: interval.startDate, to: interval.endDate, resolver: textResolver
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(UFastTheme.primary)
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("history.inferred.confirmation")
                }

                Section(textResolver(.fastingCopy(.sourceCaloricEvent))) {
                    LabeledContent(
                        interval.sourceKind == .food
                            ? textResolver(.fastingCopy(.sourceFood))
                            : textResolver(.fastingCopy(.sourceDrink)),
                        value: interval.sourceDescription
                    )
                    LabeledContent(
                        textResolver(.fastingCopy(.startedLabel)),
                        value: HistoryTextFormatting.dateTime(
                            interval.startDate,
                            calendar: calendar,
                            locale: locale,
                            timeZone: timeZone
                        )
                    )
                    LabeledContent(
                        textResolver(.fastingCopy(.endsLabel)),
                        value: HistoryTextFormatting.dateTime(
                            interval.endDate,
                            calendar: calendar,
                            locale: locale,
                            timeZone: timeZone
                        )
                    )
                    LabeledContent(textResolver(.fastingCopy(.durationLabel))) {
                        Text(duration)
                            .accessibilityIdentifier("history.inferred.duration")
                    }
                }

                if isCapReached {
                    Section {
                        Label(
                            textResolver(.fastingCopy(.inferredCapReached)),
                            systemImage: "exclamationmark.circle"
                        )
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("history.inferred.cap-reached")
                        Button(
                            textResolver(.fastingCopy(.inferredReturnToHistory)),
                            action: onCancel
                        )
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("history.inferred.return-to-history")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(
                                deleteFailure?.accessibilityIdentifier
                                    ?? "history.inferred.conversion-error"
                            )
                    }
                }

                if !isCapReached {
                    Section {
                        Button(actionTitle, action: confirm)
                            .buttonStyle(UFastPrimaryButtonStyle())
                            .accessibilityIdentifier(
                                interval.isInProgress
                                    ? "history.inferred.start"
                                    : "history.inferred.save"
                            )
                        Button(
                            textResolver(.fastingCopy(.inferredDelete)),
                            role: .destructive
                        ) {
                            showDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("history.inferred.delete")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("history.inferred.cancel")
                }
            }
        }
        .alert(
            textResolver(.fastingCopy(.inferredDeleteConfirmationTitle)),
            isPresented: $showDeleteConfirmation
        ) {
            Button(
                textResolver(.fastingCopy(.inferredDeleteConfirmationAction)),
                role: .destructive,
                action: delete
            )
            .accessibilityIdentifier("history.inferred.delete.confirm")
            Button(textResolver(.cancel), role: .cancel) {}
                .accessibilityIdentifier("history.inferred.delete.cancel")
        } message: {
            Text(textResolver(.fastingCopy(.inferredDeleteConfirmationMessage)))
                .accessibilityIdentifier("history.inferred.delete.confirmation")
        }
        .onAppear {
            now = clock.now
            armCapDeadline()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .uFastTestClockDidAdvance)
        ) { _ in
            deadlineDriver.advance(to: clock.now)
            now = clock.now
        }
        .onChange(of: capDate) { _, _ in armCapDeadline() }
        .onDisappear { deadlineDriver.cancel() }
        .overlay(alignment: .topLeading) {
            InferredFastTestClockControl(clock: clock) { now = clock.now }
        }
    }

    private func armCapDeadline() {
        deadlineDriver.cancel()
        guard let capDate, capDate > now else { return }
        deadlineDriver.schedule(at: capDate) {
            now = clock.now
        }
    }

    private func confirm() {
        guard !isCapReached else {
            errorMessage = textResolver(.fastingCopy(.inferredCapReached))
            return
        }
        do {
            try onConfirm(interval)
            errorMessage = nil
            deleteFailure = nil
        } catch {
            errorMessage = errorDescription(for: error)
            deleteFailure = nil
            onFailure()
        }
    }

    private func delete() {
        do {
            try onDelete(interval)
            errorMessage = nil
            deleteFailure = nil
        } catch {
            let failure: DeleteFailure = error is InferredFastSuppressionError
                && (error as? InferredFastSuppressionError) == .candidateUnavailable
                ? .unavailable
                : .save
            errorMessage = deleteErrorDescription(for: failure)
            deleteFailure = failure
            onFailure()
        }
    }

    private func errorDescription(for error: Error) -> String {
        switch error {
        case InferredFastConversionError.candidateUnavailable:
            textResolver(.fastingCopy(.inferredUnavailableError))
        case InferredFastConversionError.conflictingRecordedFast:
            textResolver(.fastingCopy(.inferredConflictError))
        case InferredFastConversionError.activeFastAlreadyExists:
            textResolver(.fastingCopy(.inferredActiveFastError))
        default:
            textResolver(.fastingCopy(.inferredSaveError))
        }
    }

    private func deleteErrorDescription(for failure: DeleteFailure) -> String {
        switch failure {
        case .unavailable:
            textResolver(.fastingCopy(.inferredUnavailableError))
        case .save:
            textResolver(.fastingCopy(.inferredDeleteError))
        }
    }

    private enum DeleteFailure {
        case unavailable
        case save

        var accessibilityIdentifier: String {
            switch self {
            case .unavailable: "history.inferred.delete-unavailable"
            case .save: "history.inferred.delete-error"
            }
        }
    }
}

private struct InferredFastTestClockControl: View {
    let clock: any AppClock
    let onAdvance: () -> Void
    private let advanceBy = AppLaunchConfiguration.current().historyClockAdvance

    var body: some View {
        if let clock = clock as? MutableAppClock {
            Button("Advance History clock") {
                clock.advance(by: advanceBy)
                onAdvance()
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("history.inferred.clock-advance")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History clock timestamp")
                .accessibilityValue(String(clock.now.timeIntervalSince1970))
                .accessibilityIdentifier("history.inferred.clock-probe")
        }
    }
}
