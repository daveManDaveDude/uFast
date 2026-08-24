import SwiftUI

struct ActiveFastProgressView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 50
    @Environment(\.appTextResolver) private var textResolver

    let presentation: ActiveFastPresentation
    let goal: FastingGoal
    let started: String
    let target: String
    let canEndNow: Bool
    let endError: String?
    let onEnd: () -> Void
    let onEditStart: () -> Void
    let onEndAtPastTime: () -> Void
    let additionalContent: AnyView

    init(
        presentation: ActiveFastPresentation,
        goal: FastingGoal,
        started: String,
        target: String,
        canEndNow: Bool,
        endError: String?,
        onEnd: @escaping () -> Void,
        onEditStart: @escaping () -> Void,
        onEndAtPastTime: @escaping () -> Void,
        additionalContent: AnyView = AnyView(EmptyView())
    ) {
        self.presentation = presentation
        self.goal = goal
        self.started = started
        self.target = target
        self.canEndNow = canEndNow
        self.endError = endError
        self.onEnd = onEnd
        self.onEditStart = onEditStart
        self.onEndAtPastTime = onEndAtPastTime
        self.additionalContent = additionalContent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                VStack(spacing: UFastTheme.Spacing.compact) {
                    Color.clear
                        .frame(height: 1)
                        .accessibilityElement()
                        .accessibilityLabel(accessibilitySummary)
                        .accessibilityIdentifier("fast.summary")

                    Label(textResolver(.fastingCopy(.activeInProgress)), systemImage: "timer")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(UFastTheme.primary)
                        .padding(.top, UFastTheme.Spacing.compact)

                    elapsedView

                    if presentation.hasReachedGoal {
                        Label(textResolver(.fastingCopy(.goalReached)), systemImage: "checkmark.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(UFastTheme.primary)
                            .accessibilityIdentifier("fast.goal-reached")
                    }

                    ProgressView(value: presentation.progress)
                        .progressViewStyle(UFastThickProgressStyle())
                        .padding(.top, UFastTheme.Spacing.compact)
                        .accessibilityLabel(textResolver(.fastingCopy(.progress)))
                        .accessibilityValue(
                            textResolver(
                                .activeFastProgress(percent: presentation.progressPercentage, goalHours: goal.hours)
                            )
                        )
                        .accessibilityIdentifier("fast.progress")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, UFastTheme.Spacing.standard)
                .padding(.horizontal, UFastTheme.Spacing.standard)
                .background {
                    ZStack {
                        UFastTheme.sky.opacity(0.72)
                        FastingBotanicalArtwork()
                    }
                }
                .clipShape(.rect(cornerRadius: UFastTheme.Radius.hero))

                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                        fact(
                            label: textResolver(.fastingCopy(.started)),
                            value: started,
                            identifier: "fast.started",
                            symbol: "clock"
                        )
                        Divider()
                        fact(
                            label: textResolver(.fastingCopy(.goal)),
                            value: textResolver(.durationComponent(value: goal.hours, unit: .hour)),
                            identifier: "fast.goal",
                            symbol: "scope"
                        )
                    }
                    Divider()
                    fact(
                        label: textResolver(.fastingCopy(.target)),
                        value: target,
                        identifier: "fast.target",
                        symbol: "sun.horizon"
                    )

                    Button(action: onEditStart) {
                        HStack(spacing: UFastTheme.Spacing.compact) {
                            Label(textResolver(.fastingCopy(.editStart)), systemImage: "pencil")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(UFastActionRowButtonStyle())
                    .accessibilityIdentifier("fast.edit-start")
                }
                .uFastCard()

                if !canEndNow {
                    Label(
                        textResolver(.fastingCopy(.endUnavailable)),
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(UFastTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("fast.end-unavailable")
                }

                if let endError {
                    Label(endError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.end-error")
                }

                VStack(spacing: UFastTheme.Spacing.standard) {
                    Button(textResolver(.fastingCopy(.endFast)), action: onEnd)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .disabled(!canEndNow)
                        .accessibilityIdentifier("fast.end")

                    Button(textResolver(.fastingCopy(.endAtPastTime)), action: onEndAtPastTime)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("fast.end-past")
                }

                additionalContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(UFastTheme.Spacing.standard)
        }
        .accessibilityIdentifier("today.content")
    }

    @ViewBuilder
    private var elapsedView: some View {
        if let elapsedText = presentation.elapsedText {
            let accessibilityText = presentation.elapsedDuration.map {
                HistoryTextFormatting.activeAccessibility(seconds: $0, resolver: textResolver)
            } ?? elapsedText

            Text(textResolver(.fastingCopy(.elapsedTime)))
                .font(.title3.weight(.medium))
                .foregroundStyle(UFastTheme.secondaryText)
            Text(elapsedText)
                .font(.system(size: timerSize, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(UFastTheme.primary)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(textResolver(.fastingCopy(.elapsedTime)))
                .accessibilityValue(accessibilityText)
                .accessibilityIdentifier("fast.elapsed")
        } else {
            Text(textResolver(.fastingCopy(.elapsedUnavailable)))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fast.elapsed-unavailable")
        }
    }

    private func fact(
        label: String,
        value: String,
        identifier: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .top, spacing: UFastTheme.Spacing.compact) {
            Image(systemName: symbol)
                .foregroundStyle(UFastTheme.action)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(UFastTheme.secondaryText)
                Text(value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(UFastTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
        }
    }

    private var accessibilitySummary: String {
        let elapsed = presentation.elapsedDuration.map {
            HistoryTextFormatting.activeAccessibility(seconds: $0, resolver: textResolver)
        } ?? textResolver(.fastingCopy(.elapsedUnavailable))
        return textResolver(
            .activeFastSummary(
                elapsed: elapsed,
                goal: textResolver(.durationComponent(value: goal.hours, unit: .hour)),
                started: started,
                target: target,
                reachedGoal: presentation.hasReachedGoal
            )
        )
    }
}

#Preview("Active fast · In progress") {
    ActiveFastProgressPreview(elapsedHours: 6)
}

#Preview("Active fast · Goal reached") {
    ActiveFastProgressPreview(elapsedHours: 13)
        .preferredColorScheme(.dark)
}

#Preview("Active fast · Accessibility") {
    ActiveFastProgressPreview(elapsedHours: 6)
        .environment(\.dynamicTypeSize, .accessibility3)
}

private struct ActiveFastProgressPreview: View {
    let elapsedHours: Double

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    var body: some View {
        ActiveFastProgressView(
            presentation: ActiveFastPresentation(
                startDate: start,
                targetDate: start.addingTimeInterval(12 * 60 * 60),
                now: start.addingTimeInterval(elapsedHours * 60 * 60)
            ),
            goal: .default,
            started: "Jan 15, 7:00 PM",
            target: "Jan 16, 7:00 AM",
            canEndNow: true,
            endError: nil,
            onEnd: {},
            onEditStart: {},
            onEndAtPastTime: {}
        )
        .background(UFastTheme.canvas)
    }
}
