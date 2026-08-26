import SwiftUI

extension TodayGoalView {
    var foodFavouriteConfirmationTitle: String {
        textResolver(
            .confirmationTitle(
                foodFavouriteConfirmationContext.kind,
                noun: .food,
                count: max(1, foodFavouriteConfirmationContext.affectedPersistedFastCount)
            )
        )
    }

    var foodFavouriteConfirmationActionTitle: String {
        textResolver(.confirmationAction(.saving, kind: foodFavouriteConfirmationContext.kind, noun: .food))
    }

    var foodFavouriteConfirmationMessage: String {
        Self.savingConfirmationMessage(
            context: foodFavouriteConfirmationContext,
            noun: .food,
            time: (foodFavouritePendingOperation?.occurredAt ?? clock.now)
                .formatted(date: .omitted, time: .shortened),
            textResolver: textResolver
        )
    }

    func savePendingFoodFavourite(endingActiveFast: Bool) {
        guard let favourite = foodFavouritePending, let operation = foodFavouritePendingOperation else { return }
        foodFavouriteCommitState = .saving
        do {
            try controller.addFoodFavourite(operation, endingActiveFast: endingActiveFast)
            foodFavouriteSaveError = nil
            foodFavouriteCommitState = .success
            drinkAnnouncement = textResolver(.foodFavouriteAddedAnnouncement(name: favourite.description))
            foodFavouritePending = nil
            foodFavouritePendingOperation = nil
            isFoodFavouriteConfirmationPresented = false
        } catch let FoodFavouriteStoreError.stale {
            isFoodFavouriteConfirmationPresented = false
            foodFavouriteCommitState = .stale
            foodFavouriteSaveError = textResolver(.foodFavouriteCommitState(.stale))
        } catch let FoodFavouriteStoreError.recordNotFound {
            isFoodFavouriteConfirmationPresented = false
            foodFavouriteCommitState = .stale
            foodFavouriteSaveError = textResolver(.foodFavouriteCommitState(.stale))
        } catch {
            isFoodFavouriteConfirmationPresented = false
            foodFavouriteCommitState = .failure
            foodFavouriteSaveError = textResolver(.foodFavouriteCommitState(.failure))
        }
    }

    var caloricFavouriteConfirmationTitle: String {
        textResolver(
            .confirmationTitle(
                caloricFavouriteConfirmationContext.kind,
                noun: .drink,
                count: max(1, caloricFavouriteConfirmationContext.affectedPersistedFastCount)
            )
        )
    }

    var caloricFavouriteConfirmationActionTitle: String {
        textResolver(
            .confirmationAction(
                .saving,
                kind: caloricFavouriteConfirmationContext.kind,
                noun: .drink
            )
        )
    }

    var caloricFavouriteConfirmationMessage: String {
        Self.savingConfirmationMessage(
            context: caloricFavouriteConfirmationContext,
            noun: .drink,
            time: clock.now.formatted(date: .omitted, time: .shortened),
            textResolver: textResolver
        )
    }

    static func savingConfirmationMessage(
        context: CaloricEventConfirmationContext,
        noun: AppText.CaloricEventNoun,
        time: String,
        textResolver: AppTextResolver
    ) -> String {
        var details = textResolver(
            .confirmationMessage(
                action: .saving,
                kind: context.kind,
                noun: noun,
                count: max(1, context.affectedPersistedFastCount),
                time: time
            )
        )
        if context.includesReconstructedReview {
            details += " " + textResolver(.reconstructedReviewDetail)
        }
        if context.isCombined {
            details += " " + textResolver(.inferredIntervalDetail)
        }
        return details
    }

    func savePendingCaloricFavourite(endingActiveFast: Bool) {
        guard let favourite = caloricFavouritePending else { return }
        do {
            try controller.addFavouriteDrink(favourite, endingActiveFast: endingActiveFast)
            caloricFavouriteSaveError = nil
            drinkAnnouncement = textResolver(
                .drinkAddedAnnouncement(
                    name: localizedFavouriteName(favourite),
                    volumeMillilitres: favourite.volumeMillilitres
                )
            )
            caloricFavouritePending = nil
            isCaloricFavouriteConfirmationPresented = false
        } catch {
            isCaloricFavouriteConfirmationPresented = false
            caloricFavouriteSaveError = textResolver(.drinkCombinedSaveError)
        }
    }

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
                UFastSectionHeading(textResolver(.liveActivityHeading))
                Text(textResolver(.liveActivityTodayDescription))
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                switch liveActivityControlState {
                case .hide:
                    Button(textResolver(.liveActivityHide), action: hideLiveActivity)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .disabled(isLiveActivityActionInFlight)
                        .accessibilityIdentifier("fast.live-activity.hide")
                case .show, .showAgain:
                    Button(
                        liveActivityControlState == .show
                            ? textResolver(.liveActivityShow)
                            : textResolver(.liveActivityShowAgain),
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
                foodFavouriteSaveError = nil
                foodFavouritePending = nil
                foodFavouriteCommitState = nil
                isFoodSheetPresented = true
            } label: {
                HStack {
                    Label(textResolver(.todayFoodAdd), systemImage: "fork.knife")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("food.add")

            if let foodFavouriteSaveError {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    Label(foodFavouriteSaveError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("food.favourite.save-error")
                    if foodFavouritePending != nil, foodFavouritePendingOperation != nil {
                        Button(textResolver(.foodFavouriteRetry)) {
                            savePendingFoodFavourite(endingActiveFast: true)
                        }
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("food.favourite.retry")
                    }
                }
                .uFastCard(accent: UFastTheme.apricot)
            }
            if let foodFavouriteCommitState {
                Text(textResolver(.foodFavouriteCommitState(foodFavouriteCommitState)))
                    .foregroundStyle(
                        foodFavouriteCommitState == .failure || foodFavouriteCommitState == .stale
                            ? UFastTheme.error
                            : UFastTheme.secondaryText
                    )
                    .accessibilityIdentifier("food.favourite.commit-state")
                if foodFavouriteCommitState == .success {
                    Text(textResolver(.foodFavouriteCommitState(.success)))
                        .accessibilityIdentifier("food.favourite.success")
                } else if foodFavouriteCommitState == .stale {
                    Text(textResolver(.foodFavouriteCommitState(.stale)))
                        .accessibilityIdentifier("food.favourite.stale")
                }
            }

            Button {
                caloricFavouriteSaveError = nil
                caloricFavouritePending = nil
                isDrinkSheetPresented = true
            } label: {
                HStack {
                    Label(textResolver(.todayDrinkAdd), systemImage: "drop")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("drink.add")

            if let caloricFavouriteSaveError {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    Label(caloricFavouriteSaveError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("drink.caloric-favourite.save-error")

                    Button(textResolver(.todayDrinkRetry)) {
                        savePendingCaloricFavourite(endingActiveFast: true)
                    }
                    .buttonStyle(UFastSecondaryButtonStyle())
                    .accessibilityIdentifier("drink.caloric-favourite.retry")
                }
                .uFastCard(accent: UFastTheme.apricot)
            }

            HStack {
                Text(textResolver(.todayFluids))
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Text(textResolver(.todayFluidTotal(TodayTimeline.fluidTotal(timelineEntries))))
                    .foregroundStyle(UFastTheme.primary)
                    .accessibilityIdentifier("drink.total")
            }
            .uFastCard()

            if let timelineFailureMessage {
                Label(timelineFailureMessage, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.error")
            } else if timelineEntries.isEmpty {
                Text(textResolver(.todayTimelineEmpty))
                    .foregroundStyle(UFastTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.empty")
            } else {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                    UFastSectionHeading(textResolver(.todayTimelineHeading))
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
                            textResolver(
                                .todayTimelineAccessibilityValue(
                                    detail: timelineDetail(entry),
                                    time: entry.occurredAt.formatted(date: .omitted, time: .shortened)
                                )
                            )
                        )
                        .accessibilityHint(textResolver(.todayTimelineEditHint))
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
