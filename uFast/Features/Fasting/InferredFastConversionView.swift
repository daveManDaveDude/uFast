import SwiftUI

struct InferredFastConversionView: View {
    @Environment(\.appTextResolver) private var textResolver
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    let presentation: InferredFastConversionPresentation
    let clock: any AppClock
    let onConfirm: (InferredFastInterval) throws -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    @State private var errorMessage: String?

    private var interval: InferredFastInterval {
        presentation.interval.refreshed(at: clock.now)
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
        HistoryTextFormatting.duration(
            from: interval.startDate,
            to: interval.endDate,
            resolver: textResolver
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
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

                    if let errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "exclamationmark.circle")
                                .foregroundStyle(UFastTheme.error)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("history.inferred.conversion-error")
                        }
                    }

                    Section {
                        Button(actionTitle, action: confirm)
                            .buttonStyle(UFastPrimaryButtonStyle())
                            .accessibilityIdentifier(
                                interval.isInProgress
                                    ? "history.inferred.start"
                                    : "history.inferred.save"
                            )
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
        }
    }

    private func confirm() {
        do {
            try onConfirm(interval)
            errorMessage = nil
        } catch {
            errorMessage = errorDescription(for: error)
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
}
