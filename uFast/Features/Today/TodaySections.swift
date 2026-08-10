import SwiftUI

extension TodayGoalView {
    func activeFastView(
        _ activeFast: ActiveFastSnapshot,
        goal: FastingGoal,
        now: Date
    ) -> some View {
        let presentation = ActiveFastPresentation(
            startDate: activeFast.startDate,
            targetDate: activeFast.startDate.addingTimeInterval(
                TimeInterval(goal.hours * 60 * 60)
            ),
            now: now
        )
        let target = formatted(presentation.targetDate)
        let started = formatted(activeFast.startDate)

        return ActiveFastProgressView(
            presentation: presentation,
            goal: goal,
            started: started,
            target: target,
            canEndNow: now > activeFast.startDate,
            endError: controller.endError,
            onEnd: { isEndConfirmationPresented = true },
            onEditStart: {
                startTimeEditor = StartTimeEditorPresentation(
                    mode: .correct,
                    initialStartDate: activeFast.startDate
                )
            },
            onEndAtPastTime: {
                endTimeEditor = EndTimeEditorPresentation(
                    startDate: activeFast.startDate,
                    initialEndDate: clock.now
                )
            },
            additionalContent: AnyView(
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    liveActivitySection
                    foodSection
                }
            )
        )
    }

    @ViewBuilder
    var liveActivitySection: some View {
        if liveActivityCoordinator != nil {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                UFastSectionHeading("Live Activity")
                Text(
                    "Show this active interval on the Lock Screen and Dynamic Island for up to "
                        + "8 hours. Your recorded interval continues if the activity ends."
                )
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                switch liveActivityControlState {
                case .hide:
                    Button("Hide for this fast", action: hideLiveActivity)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .disabled(isLiveActivityActionInFlight)
                        .accessibilityIdentifier("fast.live-activity.hide")
                case .show, .showAgain:
                    Button(
                        liveActivityControlState == .show
                            ? "Show Live Activity"
                            : "Show Live Activity again",
                        action: { isLiveActivityDisclosurePresented = true }
                    )
                    .buttonStyle(UFastSecondaryButtonStyle())
                    .disabled(isLiveActivityActionInFlight)
                    .accessibilityIdentifier(
                        liveActivityControlState == .show
                            ? "fast.live-activity.show"
                            : "fast.live-activity.show-again"
                    )
                case .unavailable:
                    EmptyView()
                }

                if let liveActivityStatus = controller.liveActivityStatus {
                    Label(liveActivityStatus, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.live-activity.status")
                }
            }
            .uFastCard(accent: UFastTheme.sky)
        }
    }

    var foodSection: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Button {
                foodEditor = FoodEditorPresentation(record: nil)
            } label: {
                HStack {
                    Label("Log food", systemImage: "fork.knife")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("food.add")

            Button { isDrinkSheetPresented = true } label: {
                HStack {
                    Label("Add drink", systemImage: "drop")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("drink.add")

            HStack {
                Text("Fluids today")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Text("\(TodayTimeline.fluidTotal(timelineEntries)) ml")
                    .foregroundStyle(UFastTheme.primary)
                    .accessibilityIdentifier("drink.total")
            }
            .uFastCard()

            if let previewTimelineError {
                Label(previewTimelineError, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.error")
            } else if timelineEntries.isEmpty {
                Text("Food and drinks you add today will appear here.")
                    .foregroundStyle(UFastTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.empty")
            } else {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                    UFastSectionHeading("Today timeline")
                    ForEach(timelineEntries) { entry in
                        Button { openTimelineEntry(entry) } label: {
                            HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                                Image(systemName: timelineSymbol(entry))
                                    .foregroundStyle(UFastTheme.action)
                                    .frame(width: 24, height: 24)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timelineName(entry))
                                        .foregroundStyle(UFastTheme.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(entry.occurredAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(UFastTheme.secondaryText)
                                    Text(timelineDetail(entry))
                                        .font(.caption)
                                        .foregroundStyle(UFastTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(UFastTheme.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(timelineAccessibilityLabel(entry))
                        .accessibilityValue(
                            "\(timelineDetail(entry)), "
                                + entry.occurredAt.formatted(date: .omitted, time: .shortened)
                        )
                        .accessibilityHint("Opens this event for editing.")
                        .accessibilityIdentifier("timeline.entry.\(entry.id.uuidString)")

                        if entry.id != timelineEntries.last?.id {
                            Divider()
                        }
                    }
                }
                .uFastCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
