import SwiftUI

struct InferredFastConversionView: View {
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
        interval.isInProgress ? "Start fast" : "Save fast"
    }

    private var title: String {
        interval.isInProgress ? "Inferred fast in progress" : "Inferred fast"
    }

    private var explanation: String {
        interval.isInProgress
            ? "This will start a real active fast from the source food time."
            : "This will save one completed fast using the interval shown above."
    }

    private var duration: String {
        ElapsedTimeFormatter.string(
            from: interval.endDate.timeIntervalSince(interval.startDate)
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

                    Section("Source food") {
                        LabeledContent("Food", value: interval.sourceDescription)
                        LabeledContent("Started", value: interval.startDate.formatted(
                            .dateTime.month(.abbreviated).day().hour().minute()
                        ))
                        LabeledContent("Ends", value: interval.endDate.formatted(
                            .dateTime.month(.abbreviated).day().hour().minute()
                        ))
                        LabeledContent("Duration") {
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
                        Button("Cancel", action: onCancel)
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
            "This inferred fast is no longer available. History was refreshed."
        case InferredFastConversionError.conflictingRecordedFast:
            "This interval conflicts with a recorded fast and was not saved."
        case InferredFastConversionError.activeFastAlreadyExists:
            "An active fast already exists, so this inferred fast was not started."
        default:
            "This fast could not be saved. Your local records were unchanged."
        }
    }
}
