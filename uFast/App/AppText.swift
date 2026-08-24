import Foundation
import SwiftUI

// swiftlint:disable file_length line_length trailing_comma type_body_length

/// The app-owned presentation vocabulary for the currently migrated surface.
///
/// Keeping the keys here, rather than using generated catalog symbols, makes
/// the source contract reviewable and keeps domain errors independent of copy.
enum AppText: Equatable {
    case cancel
    case delete
    case date
    case time
    case localRecordRemoval

    case foodDescriptionPlaceholder
    case foodTimeSection
    case foodCaloricExplanation
    case foodActiveStartValidation
    case foodDetailsHide
    case foodDetailsAdd
    case foodOptionalDetailsSection
    case foodNutritionField(FoodNutritionField)
    case foodNutritionUnit(FoodNutritionUnit)
    case foodNutritionRange
    case foodNutritionValuePlaceholder
    case foodNutritionHint(unit: String)
    case foodDeleteEvent
    case foodDeleteConfirmationTitle
    case foodTitle(isEditing: Bool)
    case foodSaveTitle(isEditing: Bool)
    case foodValidation(FoodEntryValidationError)
    case foodSaveError
    case foodDeleteError
    case foodCombinedSaveError
    case foodConflictError
    case confirmationTitle(CaloricEventConfirmationKind, noun: CaloricEventNoun, count: Int)
    case confirmationAction(
        CaloricEventConfirmationAction,
        kind: CaloricEventConfirmationKind,
        noun: CaloricEventNoun
    )
    case confirmationMessage(
        action: CaloricEventConfirmationAction,
        kind: CaloricEventConfirmationKind,
        noun: CaloricEventNoun,
        count: Int,
        time: String
    )
    case reconstructedReviewDetail
    case inferredIntervalDetail

    case drinkSection
    case drinkType
    case drinkTypeName(HydrationDrinkType)
    case drinkName
    case drinkAmount
    case drinkVolumeValidation
    case drinkNameValidation
    case drinkActiveStartValidation
    case drinkTimeSection
    case drinkFastingClassification
    case drinkNonCaloric
    case drinkCaloric
    case drinkBoundaryExplanation
    case drinkDelete
    case drinkDeleteConfirmationTitle
    case drinkTitle(isEditing: Bool)
    case drinkSaveTitle(isEditing: Bool)
    case drinkSaveError
    case drinkDeleteError
    case drinkCombinedSaveError
    case drinkConflictError
    case drinkAddedAnnouncement(name: String, volumeMillilitres: Int)
    case drinkPickerTitle
    case drinkPickerHeading
    case drinkPickerDetail(volumeMillilitres: Int, isCaloric: Bool)
    case drinkPickerAccessibilityValue(volumeMillilitres: Int)
    case drinkPickerClassification(isCaloric: Bool)
    case drinkAddAnother
    case drinkAddError

    case todayFoodAdd
    case todayDrinkAdd
    case todayDrinkRetry
    case todayFluids
    case todayFluidTotal(Int)
    case todayTimelineEmpty
    case todayTimelineHeading
    case todayTimelineLoadError
    case todayTimelineAccessibilityValue(detail: String, time: String)
    case todayTimelineEditHint

    case tabToday
    case tabHistory
    case tabSettings
    case persistenceUnavailableTitle
    case persistenceUnavailableMessage
    case localDataIntegrityTitle
    case localDataIntegrityMessage
    case localRecordsIntegrityMessage

    case goalSelectionSummary(hours: Int)
    case goalAccessibilityLabel
    case goalHours(hours: Int)
    case goalOption(hours: Int)
    case onboardingTitle
    case onboardingPromise
    case onboardingChoiceHeading
    case onboardingChoiceEyebrow
    case onboardingSelectionSummary(hours: Int)
    case onboardingSaveError
    case continueAction
    case settingsTitle
    case settingsGoalHeading
    case settingsGoalSelected(hours: Int)
    case settingsGoalDescription
    case settingsDataHeading
    case settingsDataDescription
    case settingsDataLoss
    case settingsPrivacyLink
    case settingsWidgetHeading
    case settingsWidgetDescription
    case settingsWidgetInstructions
    case settingsLiveActivityHeading
    case settingsLiveActivityToggle
    case settingsLiveActivitySupport
    case settingsLiveActivityExplanation
    case settingsInferredHeading
    case settingsInferredToggle
    case settingsInferredDescription
    case settingsFavouritesHeading
    case settingsFavouritesDescription
    case settingsFavouriteField(FavouriteField)
    case settingsFavouriteDetail(volumeMillilitres: Int, isCaloric: Bool)
    case settingsFavouriteAccessibilityValue(volumeMillilitres: Int, isCaloric: Bool)
    case settingsAddFavourite
    case settingsFavouriteValidation
    case settingsFavouriteAutoSave
    case settingsMillilitres
    case settingsYourDataHeading
    case settingsDeleteDescription
    case settingsDeleteAll
    case settingsDeleteFirstTitle
    case settingsDeleteFirstMessage
    case settingsDeleteFinalTitle
    case settingsDeleteFinalMessage
    case settingsDeleteEverything
    case settingsConflictError
    case settingsInferredSaveError
    case settingsGoalSaveError
    case settingsFavouritesSaveError
    case settingsDeleteError
    case settingsLiveActivitySaveError
    case settingsAmountPlaceholder
    case settingsAmountAccessibilityLabel(label: String)

    case privacyTitle
    case privacySection(PrivacySection)
    case privacyBody(PrivacySection)
    case privacyMoreInformation
    case privacyReadPolicy
    case privacyContactSupport
    case privacySupportNote

    case favouriteNamePlaceholder
    case favouriteAmountPlaceholder
    case favouriteUnit
    case favouriteCountsAsCaloric
    case favouriteBoundaryExplanation
    case favouriteDetailsHeading
    case favouriteDetailsFooter
    case favouriteRemove
    case favouriteTitle(isEditing: Bool)
    case favouriteSave
    case favouriteRemoveConfirmation(name: String)
    case favouriteRemoveAction
    case favouriteValidation(HydrationFavouriteValidationError)
    case favouriteSaveError
    case favouriteRemoveError

    case todayTitle
    case todayDataIntegrity
    case fastRecorded
    case endFastConfirmationTitle
    case endFastAction
    case endFastMessage
    case todayStartError
    case todayEndError
    case inactiveReady
    case inactiveNoFast
    case inactiveNextTarget
    case inactiveGoalEyebrow(hours: Int)
    case inactiveStartedNow
    case inactiveTargetLabel
    case inactiveGoal(hours: Int)
    case startFast
    case tryAgain
    case startAtPastTime
    case liveActivityHeading
    case liveActivityTodayDescription
    case liveActivityHide
    case liveActivityShow
    case liveActivityShowAgain
    case automaticOfferTitle
    case automaticOfferShow
    case automaticOfferNotNow
    case automaticOfferMessage
    case liveActivityDisclosureTitle
    case liveActivityDisclosureMessage
    case liveActivityStatus(ActiveFastLiveActivityStatus)

    case historySelectedDateAndTime
    case historyFood
    case historyDrink
    case historyNothingRecorded
    case historyAddTitle

    case fastingCopy(FastingCopy)
    case historyCopy(HistoryCopy)
    case fastingValidation(FastingValidation, value: String)
    case durationComponent(value: Int, unit: DurationUnit)
    case historyDate(value: String)
    case historyTime(value: String)
    case historyVolume(value: Int)
    case historyGroupTitle(count: Int, family: HistoryEventFamily)
    case historyGroupMemberTitle(title: String, count: Int)
    case historyGroupClassification(TemporalEventPresentationCategory)
    case historyGroupAccessibility(
        count: Int,
        family: HistoryEventFamily,
        start: String,
        end: String,
        classification: String
    )
    case historyEventDetail(kind: HistoryEventKind, date: String)
    case historyEventAccessibility(
        kind: HistoryEventKind,
        name: String,
        volumeMillilitres: Int,
        date: String
    )
    case historyFoodAccessibility(description: String, date: String)
    case historyFastTitle(kind: HistoryFastKind, needsReview: Bool)
    case historyFastComponent(kind: HistoryFastComponent, value: String)
    case historyFastSource(kind: HistoryEventFamily, description: String)
    case historyFastBoundary(kind: HistoryBoundaryKind)
    case historyMemberAccessibility(time: String, title: String, detail: String)
    case historyMotionEvent(kind: HistoryEventFamily)
    case activeFastSummary(
        elapsed: String,
        goal: String,
        started: String,
        target: String,
        reachedGoal: Bool
    )
    case activeFastProgress(percent: Int, goalHours: Int)

    enum FoodNutritionField: String, CaseIterable, Sendable {
        case energy
        case protein
        case carbohydrate
        case fat
        case fibre
        case sugar
        case salt
    }

    enum FoodNutritionUnit: String, Sendable {
        case kilocalories
        case grams
    }

    enum CaloricEventNoun: String, Sendable {
        case food
        case drink
        case event
    }

    enum CaloricEventConfirmationAction: String, Sendable {
        case saving
        case deleting
    }

    enum PrivacySection: String, CaseIterable, Sendable {
        case stored
        case location
        case collection
        case liveActivities
        case deletion
        case safety
    }

    enum FastingCopy: String, CaseIterable, Sendable {
        case activeInProgress
        case goalReached
        case progress
        case editStart
        case endUnavailable
        case endFast
        case endAtPastTime
        case elapsedTime
        case elapsedUnavailable
        case started
        case goal
        case target
        case recordedBoundaries
        case editFastEyebrow
        case reviewBoundaries
        case startSection
        case startDate
        case startTime
        case endDate
        case endTime
        case endHeader
        case startBeforeEnd
        case validationError
        case deleteFast
        case editFastTitle
        case save
        case deleteConfirmationTitle
        case localDeviceRemoval
        case changesSaveError
        case fastDeleteError
        case endHeading
        case endDescription
        case endTimeTitle
        case endBeforeStart
        case endFuture
        case endSaveError
        case startCreateHeading
        case startCorrectHeading
        case startEyebrow
        case startCreateDescription
        case startCorrectDescription
        case useEarliestValidStart
        case legacyStartFooter
        case startTimeTitle
        case startSaveError
        case startFuture
        case startTooOld
        case overlapError
        case inferredInProgressTitle
        case inferredTitle
        case inferredStartExplanation
        case inferredSaveExplanation
        case sourceCaloricEvent
        case startedLabel
        case endsLabel
        case durationLabel
        case sourceFood
        case sourceDrink
        case inferredCancel
        case inferredUnavailableError
        case inferredConflictError
        case inferredActiveFastError
        case inferredSaveError
    }

    enum HistoryCopy: Equatable, Sendable {
        case title
        case empty
        case loading
        case carouselSettled
        case carouselMoving
        case dateNavigator
        case futureDayHint
        case dateChipState(selected: Bool, future: Bool, inRange: Bool, selectable: Bool)
        case motionUnavailableTitle
        case motionUnavailableMessage
        case retry
        case motionExtensionMessage
        case extensionRetry
        case eyebrow
        case chooseDate
        case chooseDateLabel
        case addAtSelectedTime
        case addAtSelectedTimeHint
        case emptyEyebrow
        case emptyTitle
        case emptyMessage
        case detailsEyebrow
        case fastsInView
        case futureReadOnly
        case futureReadOnlyHint
        case chooseDateSheetTitle
        case done
        case groupExactTimes
        case groupHint
        case groupCancel
        case groupAddEvent
        case groupAddHint
        case groupNoEligibleTime
        case groupMemberFoodHint
        case groupMemberDrinkHint
        case memberDetailHint
        case carouselLabel
        case selectedDateLabel
        case previousDay
        case nextDay
        case selectedDay
        case timelineEmpty
        case eventFood
        case eventDrink
        case caloric
        case nonCaloric
        case food
        case drink
        case recordedFast
        case activeFast
        case fast
        case inferredFastInProgress
        case inferredFast
        case previouslySavedFast
        case previouslySavedFastNeedsReview
        case unavailableFast
        case startActionAvailable
        case saveActionAvailable
        case currentlyActive
        case boundaryEvidenceUnavailable
        case formerBoundaryUnavailable
        case sourceLabel
        case durationLessThanMinute
        case durationDayAbbreviation
        case separatorMiddleDot
        case separatorArrow
        case separatorRange
        case separatorComma
        case separatorSpace
        // swiftlint:disable:next identifier_name
        case to
    }

    enum FastingValidation: String, CaseIterable, Sendable {
        case completedBoundary
        case startBoundary
    }

    enum DurationUnit: String, CaseIterable, Sendable {
        case day
        case hour
        case minute
        case second
    }

    enum HistoryEventFamily: String, CaseIterable, Sendable {
        case food
        case drink
    }

    enum HistoryEventKind: String, CaseIterable, Sendable {
        case food
        case caloricDrink
        case nonCaloricDrink
    }

    enum HistoryFastKind: String, CaseIterable, Sendable {
        case recorded
        case active
        case automatic
        case inferred
        case previouslySaved
        case unavailable
    }

    enum HistoryFastComponent: String, CaseIterable, Sendable {
        case start
        case end
        case duration
        case goal
        case startAction
        case saveAction
    }

    enum HistoryBoundaryKind: String, CaseIterable, Sendable {
        case unavailable
        case formerFood
        case formerDrink
    }

    var resource: LocalizedStringResource {
        switch self {
        case .cancel:
            return resource("common.cancel", "Cancel", "Common cancellation action")
        case .delete:
            return resource("common.delete", "Delete", "Common destructive action")
        case .date:
            return resource("common.date", "Date", "Date picker label")
        case .time:
            return resource("common.time", "Time", "Time picker label")
        case .localRecordRemoval:
            return resource("common.local-record-removal", "This removes it from your local record.", "Local-only deletion explanation")
        case .foodDescriptionPlaceholder:
            return resource("food.description.placeholder", "What did you eat?", "Food description text field placeholder")
        case .foodTimeSection:
            return resource("food.time.section", "Time", "Food editor time section")
        case .foodCaloricExplanation:
            return resource(
                "food.caloric.explanation",
                "Food events count as caloric and are used as fasting boundaries. If this event falls during your active fast, saving it ends the fast at this time.",
                "Food caloric-boundary explanation"
            )
        case .foodActiveStartValidation:
            return resource("food.active-start.validation", "Choose a time after the fast started, or change the fast start time.", "Food active-fast start validation")
        case .foodDetailsHide:
            return resource("food.details.hide", "Hide details", "Hide optional food nutrition details")
        case .foodDetailsAdd:
            return resource("food.details.add", "Add details", "Add optional food nutrition details")
        case .foodOptionalDetailsSection:
            return resource("food.details.section", "Optional manual details", "Optional food nutrition section")
        case let .foodNutritionField(field):
            switch field {
            case .energy: return resource("food.nutrition.energy", "Energy", "Food nutrition field label")
            case .protein: return resource("food.nutrition.protein", "Protein", "Food nutrition field label")
            case .carbohydrate: return resource("food.nutrition.carbohydrate", "Carbohydrate", "Food nutrition field label")
            case .fat: return resource("food.nutrition.fat", "Fat", "Food nutrition field label")
            case .fibre: return resource("food.nutrition.fibre", "Fibre", "Food nutrition field label")
            case .sugar: return resource("food.nutrition.sugar", "Sugar", "Food nutrition field label")
            case .salt: return resource("food.nutrition.salt", "Salt", "Food nutrition field label")
            }
        case let .foodNutritionUnit(unit):
            switch unit {
            case .kilocalories: return resource("food.nutrition.unit.kcal", "kcal", "Food nutrition unit")
            case .grams: return resource("food.nutrition.unit.grams", "g", "Food nutrition unit")
            }
        case .foodNutritionRange:
            return resource("food.nutrition.range", "Each value is optional. Valid range: 0–1,000,000.", "Food nutrition validation range")
        case .foodNutritionValuePlaceholder:
            return resource("food.nutrition.value.placeholder", "Value", "Food nutrition input placeholder")
        case let .foodNutritionHint(unit):
            return resource("food.nutrition.hint", "Optional, from 0 to 1,000,000 \(unit).", "Food nutrition accessibility hint")
        case .foodDeleteEvent:
            return resource("food.delete", "Delete food event", "Delete food event action")
        case .foodDeleteConfirmationTitle:
            return resource("food.delete.confirmation.title", "Delete this food event?", "Food deletion confirmation")
        case let .foodTitle(isEditing):
            return resource(
                isEditing ? "food.title.edit" : "food.title.add",
                isEditing ? "Edit food" : "Log food",
                "Food editor navigation title"
            )
        case let .foodSaveTitle(isEditing):
            return resource(
                isEditing ? "food.save.edit" : "food.save.add",
                isEditing ? "Save changes" : "Save food",
                "Food editor save action"
            )
        case let .foodValidation(error):
            switch error {
            case .emptyDescription:
                return resource("food.validation.empty-description", "Enter what you ate.", "Food description validation")
            case .descriptionTooLong:
                return resource("food.validation.description-too-long", "Keep the description to 200 characters or fewer.", "Food description length validation")
            case .invalidNutrition:
                return resource("food.validation.invalid-nutrition", "Enter each detail as a number from 0 to 1,000,000.", "Food nutrition validation")
            case .beforeToday:
                return resource("food.validation.before-today", "Choose a time from today.", "Food date validation")
            case .futureTime:
                return resource("food.validation.future-time", "Choose a time that isn’t in the future.", "Food date validation")
            case .outsideSelectedRange:
                return resource("food.validation.outside-selected-range", "Choose a time within the selected catch-up days.", "Food History range validation")
            }
        case .foodSaveError:
            return resource("food.error.save", "Your food event couldn’t be saved. Please try again.", "Food save failure")
        case .foodDeleteError:
            return resource("food.error.delete", "Your food event couldn’t be deleted. Please try again.", "Food delete failure")
        case .foodCombinedSaveError:
            return resource("food.error.combined-save", "Your food event and fast couldn’t be saved. Please try again.", "Food and fast save failure")
        case .foodConflictError, .drinkConflictError:
            return resource("caloric.error.fast-conflict", "This fast overlaps another recorded fast. Correct the fast before saving.", "Caloric event fast conflict")
        case let .confirmationTitle(kind, noun, count):
            return confirmationTitleResource(kind: kind, noun: noun, count: count)
        case let .confirmationAction(action, kind, noun):
            return confirmationActionResource(action: action, kind: kind, noun: noun)
        case let .confirmationMessage(action, kind, noun, count, time):
            return confirmationMessageResource(action: action, kind: kind, noun: noun, count: count, time: time)
        case .reconstructedReviewDetail:
            return resource("caloric.confirmation.reconstructed-review", "At least one affected fast is reconstructed and will be marked for review.", "Reconstructed fast review consequence")
        case .inferredIntervalDetail:
            return resource("caloric.confirmation.inferred-interval", "It also refreshes the derived inferred interval.", "Inferred interval consequence")
        case .drinkSection:
            return resource("drink.section", "Drink", "Hydration editor section")
        case .drinkType:
            return resource("drink.type", "Type", "Hydration drink type picker")
        case let .drinkTypeName(type):
            switch type {
            case .water: return resource("drink.type.water", "Water", "Built-in hydration drink type name")
            case .tea: return resource("drink.type.tea", "Tea", "Built-in hydration drink type name")
            case .coffee: return resource("drink.type.coffee", "Coffee", "Built-in hydration drink type name")
            case .custom: return resource("drink.type.custom", "Custom", "Built-in hydration drink type name")
            }
        case .drinkName:
            return resource("drink.name", "Drink name", "Custom drink name field")
        case .drinkAmount:
            return resource("drink.amount", "Amount (ml)", "Hydration volume field")
        case .drinkVolumeValidation:
            return resource("drink.validation.volume", "Enter an amount from 1 to 5,000 ml.", "Hydration volume validation")
        case .drinkNameValidation:
            return resource("drink.validation.name", "Enter a drink name of 80 characters or fewer.", "Custom drink name validation")
        case .drinkActiveStartValidation:
            return resource("drink.active-start.validation", "Choose a time after the fast started, or change the fast start time.", "Drink active-fast start validation")
        case .drinkTimeSection:
            return resource("drink.time.section", "Time", "Hydration editor time section")
        case .drinkFastingClassification:
            return resource("drink.fasting-classification", "Fasting classification", "Hydration caloric classification picker")
        case .drinkNonCaloric:
            return resource("drink.classification.non-caloric", "Non-caloric", "Non-caloric hydration choice")
        case .drinkCaloric:
            return resource("drink.classification.caloric", "Caloric", "Caloric hydration choice")
        case .drinkBoundaryExplanation:
            return resource("drink.caloric.explanation", "Used as a fasting boundary. If it falls during your active fast, saving it ends the fast at this time.", "Hydration caloric-boundary explanation")
        case .drinkDelete:
            return resource("drink.delete", "Delete drink", "Delete drink action")
        case .drinkDeleteConfirmationTitle:
            return resource("drink.delete.confirmation.title", "Delete this drink?", "Drink deletion confirmation")
        case let .drinkTitle(isEditing):
            return resource(
                isEditing ? "drink.title.edit" : "drink.title.add",
                isEditing ? "Edit drink" : "Add another drink",
                "Hydration editor navigation title"
            )
        case let .drinkSaveTitle(isEditing):
            return resource(
                isEditing ? "drink.save.edit" : "drink.save.add",
                isEditing ? "Save changes" : "Save drink",
                "Hydration editor save action"
            )
        case .drinkSaveError:
            return resource("drink.error.save", "Your drink couldn’t be saved. Please try again.", "Drink save failure")
        case .drinkDeleteError:
            return resource("drink.error.delete", "Your drink couldn’t be deleted. Please try again.", "Drink delete failure")
        case .drinkCombinedSaveError:
            return resource("drink.error.combined-save", "Your drink and fast couldn’t be saved. Please try again.", "Drink and fast save failure")
        case let .drinkAddedAnnouncement(name, volumeMillilitres):
            return resource("drink.added.announcement", "\(name), \(volumeMillilitres) millilitres, added.", "Drink added VoiceOver announcement")
        case .drinkPickerTitle:
            return resource("drink.picker.title", "Add a drink", "Favourite drink picker navigation title")
        case .drinkPickerHeading:
            return resource("drink.picker.heading", "Favourites", "Favourite drink picker heading")
        case let .drinkPickerDetail(volumeMillilitres, isCaloric):
            return resource(
                isCaloric ? "drink.picker.detail.caloric" : "drink.picker.detail.non-caloric",
                isCaloric ? "\(volumeMillilitres) ml · Caloric" : "\(volumeMillilitres) ml · Non-caloric",
                "Favourite drink detail"
            )
        case let .drinkPickerAccessibilityValue(volumeMillilitres):
            return resource("drink.picker.accessibility-value", "\(volumeMillilitres) millilitres", "Favourite drink VoiceOver volume")
        case let .drinkPickerClassification(isCaloric):
            return resource(
                isCaloric ? "drink.picker.classification.caloric" : "drink.picker.classification.non-caloric",
                isCaloric ? "Caloric" : "Non-caloric",
                "Favourite drink VoiceOver classification"
            )
        case .drinkAddAnother:
            return resource("drink.picker.add-another", "Add another drink", "Open custom drink editor")
        case .drinkAddError:
            return resource("drink.error.add", "Your drink couldn’t be added. Please try again.", "Favourite drink save failure")
        case .todayFoodAdd:
            return resource("today.food.add", "Log food", "Today food entry action")
        case .todayDrinkAdd:
            return resource("today.drink.add", "Add drink", "Today drink entry action")
        case .todayDrinkRetry:
            return resource("today.drink.retry", "Try adding drink again", "Retry caloric favourite drink")
        case .todayFluids:
            return resource("today.fluids", "Fluids today", "Today fluid total heading")
        case let .todayFluidTotal(volumeMillilitres):
            return resource("today.fluids.total", "\(volumeMillilitres) ml", "Today fluid total")
        case .todayTimelineEmpty:
            return resource("today.timeline.empty", "Food and drinks you add today will appear here.", "Empty food and drink timeline")
        case .todayTimelineHeading:
            return resource("today.timeline.heading", "Today timeline", "Today food and drink timeline heading")
        case .todayTimelineLoadError:
            return resource("today.timeline.load-error", "Your timeline couldn’t be loaded. Please try again.", "Today timeline persistence failure")
        case let .todayTimelineAccessibilityValue(detail, time):
            return resource(
                "today.timeline.accessibility-value",
                "\(detail), \(time)",
                "Today food and drink timeline VoiceOver value"
            )
        case .todayTimelineEditHint:
            return resource("today.timeline.edit-hint", "Opens this event for editing.", "Today timeline VoiceOver hint")
        case .tabToday:
            return resource("tab.today", "Today", "Today tab title")
        case .tabHistory:
            return resource("tab.history", "History", "History tab title")
        case .tabSettings:
            return resource("tab.settings", "Settings", "Settings tab title")
        case .persistenceUnavailableTitle:
            return resource("persistence.unavailable.title", "Your local data couldn’t be opened", "Persistence unavailable title")
        case .persistenceUnavailableMessage:
            return resource("persistence.unavailable.message", "Nothing was deleted or replaced. Close uFast and try again.", "Persistence unavailable message")
        case .localDataIntegrityTitle:
            return resource("integrity.local.title", "Your local data needs attention", "Conflicting local settings title")
        case .localDataIntegrityMessage:
            return resource("integrity.local.message", "uFast found conflicting local settings and did not choose between them. Nothing was changed.", "Conflicting local settings message")
        case .localRecordsIntegrityMessage:
            return resource("integrity.records.message", "uFast found conflicting local records. Nothing was changed.", "Conflicting local records message")
        case let .goalSelectionSummary(hours):
            return resource("goal.selection.summary", "\(hours) hours selected", "Selected fasting goal summary")
        case .goalAccessibilityLabel:
            return resource("goal.accessibility.label", "Fasting goal", "Fasting goal VoiceOver label")
        case let .goalHours(hours):
            return resource("goal.hours", "\(hours) hours", "Fasting goal VoiceOver value")
        case let .goalOption(hours):
            return resource("goal.option", "\(hours) hr", "Fasting goal option title")
        case .onboardingTitle:
            return resource("onboarding.title", "Your fasting goal", "Onboarding title")
        case .onboardingPromise:
            return resource("onboarding.promise", "A calm, private companion for recording your fasts.", "Onboarding promise")
        case .onboardingChoiceHeading:
            return resource("onboarding.choice.heading", "Choose what you intend to record", "Onboarding goal choice heading")
        case .onboardingChoiceEyebrow:
            return resource("onboarding.choice.eyebrow", "8–24 whole hours", "Onboarding goal choice range")
        case let .onboardingSelectionSummary(hours):
            return resource("onboarding.selection.summary", "\(hours) hours is selected. You can change this later.", "Onboarding selected goal explanation")
        case .onboardingSaveError:
            return resource("onboarding.error.save", "Your goal couldn’t be saved. Please try again.", "Onboarding save failure")
        case .continueAction:
            return resource("common.continue", "Continue", "Common continuation action")
        case .settingsTitle:
            return resource("settings.title", "Settings", "Settings screen title")
        case .settingsGoalHeading:
            return resource("settings.goal.heading", "Fasting goal", "Settings fasting goal heading")
        case let .settingsGoalSelected(hours):
            return resource("settings.goal.selected", "\(hours) hours selected", "Settings selected fasting goal eyebrow")
        case .settingsGoalDescription:
            return resource("settings.goal.description", "This updates the target for an active fast. Completed records keep their historical goal.", "Settings fasting goal explanation")
        case .settingsDataHeading:
            return resource("settings.data.heading", "Data on this iPhone", "Settings local data heading")
        case .settingsDataDescription:
            return resource("settings.data.description", "uFast stores your fasts, food, drinks, settings and history locally in this app. There is no account, cloud sync, backup or restore.", "Settings local data explanation")
        case .settingsDataLoss:
            return resource("settings.data.loss", "Deleting uFast or losing this iPhone may permanently remove your uFast data.", "Settings local data loss warning")
        case .settingsPrivacyLink:
            return resource("settings.privacy.link", "Privacy and safety", "Settings privacy link")
        case .settingsWidgetHeading:
            return resource("settings.widget.heading", "Lock and Home Screen widgets", "Settings widget heading")
        case .settingsWidgetDescription:
            return resource("settings.widget.description", "If you add an optional uFast Lock Screen or Home Screen widget, it can show your recorded elapsed time and goal progress.", "Settings widget explanation")
        case .settingsWidgetInstructions:
            return resource("settings.widget.instructions", "Touch and hold the Lock Screen to customize it, or touch and hold the Home Screen and tap + to add uFast. You can remove either widget at any time.", "Settings widget instructions")
        case .settingsLiveActivityHeading:
            return resource("settings.live-activity.heading", "Live Activities", "Settings Live Activities heading")
        case .settingsLiveActivityToggle:
            return resource("settings.live-activity.toggle", "Automatically show Live Activities", "Settings automatic Live Activities toggle")
        case .settingsLiveActivitySupport:
            return resource("settings.live-activity.support", "Show elapsed time, goal progress and target on the Lock Screen and Dynamic Island when a fast starts. Each Live Activity stays active for up to 8 hours. If your fast is still active, uFast can show a new one the next time you open the app.", "Settings automatic Live Activities supporting copy")
        case .settingsLiveActivityExplanation:
            return resource("settings.live-activity.explanation", "Turn this off to hide the current Live Activity and prevent new ones. You can also choose Hide for this fast without changing the setting for future fasts.", "Settings automatic Live Activities explanation")
        case .settingsInferredHeading:
            return resource("settings.inferred.heading", "Inferred fasts", "Settings inferred fast heading")
        case .settingsInferredToggle:
            return resource("settings.inferred.toggle", "Detect inferred fasts", "Settings inferred fast toggle")
        case .settingsInferredDescription:
            return resource("settings.inferred.description", "When enabled, uFast shows a clearly labelled fasting interval after eight hours without a caloric food or drink event. Nothing is saved until you choose Save fast or Start fast.", "Settings inferred fast explanation")
        case .settingsFavouritesHeading:
            return resource("settings.favourites.heading", "Drink favourites", "Settings drink favourites heading")
        case .settingsFavouritesDescription:
            return resource("settings.favourites.description", "Choose the amount added by each Today shortcut.", "Settings drink favourites explanation")
        case let .settingsFavouriteField(field):
            switch field {
            case .water: return resource("settings.favourites.field.water", "Water", "Water favourite field")
            case .tea: return resource("settings.favourites.field.tea", "Tea", "Tea favourite field")
            case .coffee: return resource("settings.favourites.field.coffee", "Coffee", "Coffee favourite field")
            }
        case let .settingsFavouriteDetail(volumeMillilitres, isCaloric):
            return resource(
                isCaloric ? "settings.favourites.detail.caloric" : "settings.favourites.detail.non-caloric",
                isCaloric ? "\(volumeMillilitres) ml · Caloric" : "\(volumeMillilitres) ml · Non-caloric",
                "Drink favourite detail"
            )
        case let .settingsFavouriteAccessibilityValue(volumeMillilitres, isCaloric):
            return resource(
                isCaloric ? "settings.favourites.accessibility-value.caloric" : "settings.favourites.accessibility-value.non-caloric",
                isCaloric ? "\(volumeMillilitres) millilitres, Caloric" : "\(volumeMillilitres) millilitres, Non-caloric",
                "Drink favourite VoiceOver value"
            )
        case .settingsAddFavourite:
            return resource("settings.favourites.add", "Add favourite", "Add drink favourite action")
        case .settingsFavouriteValidation:
            return resource("settings.favourites.validation", "Enter each amount from 1 to 5,000 ml.", "Drink favourite amount validation")
        case .settingsFavouriteAutoSave:
            return resource("settings.favourites.auto-save", "Changes save automatically when you finish editing.", "Drink favourite automatic save explanation")
        case .settingsMillilitres:
            return resource("settings.favourites.unit", "ml", "Drink favourite volume unit")
        case .settingsYourDataHeading:
            return resource("settings.data.your-data", "Your data", "Settings deletion heading")
        case .settingsDeleteDescription:
            return resource("settings.data.delete-description", "Delete every uFast record stored on this iPhone. This cannot be undone.", "Settings deletion explanation")
        case .settingsDeleteAll:
            return resource("settings.data.delete-all", "Delete all data", "Settings delete all action")
        case .settingsDeleteFirstTitle:
            return resource("settings.data.delete-first.title", "Delete all uFast data?", "First delete confirmation title")
        case .settingsDeleteFirstMessage:
            return resource("settings.data.delete-first.message", "This will remove your fasts, food, drinks, settings and history from this iPhone.", "First delete confirmation message")
        case .settingsDeleteFinalTitle:
            return resource("settings.data.delete-final.title", "Permanently delete everything?", "Final delete confirmation title")
        case .settingsDeleteFinalMessage:
            return resource("settings.data.delete-final.message", "This is your final confirmation. Deleted data cannot be recovered.", "Final delete confirmation message")
        case .settingsDeleteEverything:
            return resource("settings.data.delete-everything", "Delete everything", "Final delete confirmation action")
        case .settingsConflictError:
            return resource("settings.error.conflict", "Your local settings conflict. Nothing was changed.", "Settings conflict error")
        case .settingsInferredSaveError:
            return resource("settings.error.inferred-save", "Your inferred fast setting couldn’t be saved. Please try again.", "Inferred fast setting save error")
        case .settingsGoalSaveError:
            return resource("settings.error.goal-save", "Your goal couldn’t be saved. Please try again.", "Settings goal save error")
        case .settingsFavouritesSaveError:
            return resource("settings.error.favourites-save", "Your drink favourites couldn’t be saved. Please try again.", "Drink favourites save error")
        case .settingsDeleteError:
            return resource("settings.error.delete", "Your data couldn’t be deleted. Please try again.", "Settings deletion error")
        case .settingsLiveActivitySaveError:
            return resource("settings.error.live-activity-save", "Your Live Activities setting couldn’t be saved. Please try again.", "Live Activities setting save error")
        case .settingsAmountPlaceholder:
            return resource("settings.amount.placeholder", "Amount", "Settings amount input placeholder")
        case let .settingsAmountAccessibilityLabel(label):
            return resource("settings.amount.accessibility-label", "\(label) amount", "Settings amount input VoiceOver label")
        case .privacyTitle:
            return resource("privacy.title", "Privacy and safety", "Privacy and safety screen title")
        case let .privacySection(section):
            switch section {
            case .stored:
                return resource("privacy.section.stored", "What uFast stores", "Privacy stored-data heading")
            case .location:
                return resource("privacy.section.location", "Where it stays", "Privacy local-storage heading")
            case .collection:
                return resource("privacy.section.collection", "No collection", "Privacy collection heading")
            case .liveActivities:
                return resource("privacy.section.live-activities", "Live Activities", "Privacy Live Activities heading")
            case .deletion:
                return resource("privacy.section.deletion", "Deletion", "Privacy deletion heading")
            case .safety:
                return resource("privacy.section.safety", "Safety", "Privacy safety heading")
            }
        case let .privacyBody(section):
            switch section {
            case .stored:
                return resource("privacy.body.stored", "uFast stores user-entered fasting intervals, food entries, hydration entries, fasting and drink settings, and legacy history required by the current local schema.", "Privacy stored-data explanation")
            case .location:
                return resource("privacy.body.location", "These records stay locally in uFast’s protected app container on this iPhone. uFast has no account, cloud sync, backup, restore or password recovery.", "Privacy local-storage explanation")
            case .collection:
                return resource("privacy.body.collection", "In this release uFast sends fasting, food, drink or settings records to neither the developer nor a third party. uFast has no analytics, advertising or tracking.", "Privacy collection explanation")
            case .liveActivities:
                return resource("privacy.body.live-activities", "Live Activities are optional. If you enable automatic Live Activities, the preference and minimal presentation lifecycle metadata stay on this iPhone. The elapsed time, goal progress and target you choose to show may be visible on the Lock Screen and Dynamic Island. No Live Activity content is sent to uFast, a server or a third party. Turn the setting off or choose Hide for this fast at any time.", "Privacy Live Activities explanation")
            case .deletion:
                return resource("privacy.body.deletion", "Delete all data in Settings to remove every uFast record from this iPhone after two confirmations. Deleting the app may also remove its local data. Deleted data cannot be recovered by uFast.", "Privacy deletion explanation")
            case .safety:
                return resource("privacy.body.safety", "uFast records information you choose to enter and displays patterns in those records. It is not medical advice and does not diagnose, treat or guarantee a health outcome.", "Privacy safety explanation")
            }
        case .privacyMoreInformation:
            return resource("privacy.more-information", "More information", "Privacy links heading")
        case .privacyReadPolicy:
            return resource("privacy.read-policy", "Read the public privacy policy", "Privacy policy link")
        case .privacyContactSupport:
            return resource("privacy.contact-support", "Contact support", "Privacy support link")
        case .privacySupportNote:
            return resource("privacy.support-note", "Only information you voluntarily include in a support request is received through that route.", "Privacy support note")
        case .favouriteNamePlaceholder:
            return resource("favourite.name.placeholder", "Name", "Drink favourite name input placeholder")
        case .favouriteAmountPlaceholder:
            return resource("favourite.amount.placeholder", "Amount", "Drink favourite amount input placeholder")
        case .favouriteUnit:
            return resource("favourite.unit", "Unit", "Drink favourite unit label")
        case .favouriteCountsAsCaloric:
            return resource("favourite.counts-as-caloric", "Counts as caloric", "Drink favourite caloric toggle")
        case .favouriteBoundaryExplanation:
            return resource("favourite.boundary-explanation", "A caloric drink counts as a fasting boundary.", "Drink favourite caloric explanation")
        case .favouriteDetailsHeading:
            return resource("favourite.details.heading", "Drink details", "Drink favourite details heading")
        case .favouriteDetailsFooter:
            return resource("favourite.details.footer", "Names are unique and can be up to 80 characters.", "Drink favourite details footer")
        case .favouriteRemove:
            return resource("favourite.remove", "Remove favourite", "Remove drink favourite action")
        case let .favouriteTitle(isEditing):
            return resource(isEditing ? "favourite.title.edit" : "favourite.title.add", isEditing ? "Edit favourite" : "Add favourite", "Drink favourite editor title")
        case .favouriteSave:
            return resource("favourite.save", "Save", "Drink favourite save action")
        case let .favouriteRemoveConfirmation(name):
            return resource("favourite.remove.confirmation", "Remove “\(name)” from favourites?", "Drink favourite removal confirmation")
        case .favouriteRemoveAction:
            return resource("favourite.remove.confirm", "Remove", "Drink favourite removal confirmation action")
        case let .favouriteValidation(error):
            switch error {
            case .blankName, .nameTooLong:
                return resource("favourite.validation.name", "Enter a name up to 80 characters.", "Drink favourite name validation")
            case .duplicateName, .reservedName:
                return resource("favourite.validation.duplicate", "Choose a name that isn’t already in your favourites.", "Drink favourite duplicate-name validation")
            case .invalidAmount:
                return resource("favourite.validation.amount", "Enter an amount from 1 to 5,000 ml.", "Drink favourite amount validation")
            }
        case .favouriteSaveError:
            return resource("favourite.error.save", "Your favourite couldn’t be saved. Please try again.", "Drink favourite save failure")
        case .favouriteRemoveError:
            return resource("favourite.error.remove", "Your favourite couldn’t be removed. Please try again.", "Drink favourite removal failure")
        case .todayTitle:
            return resource("today.title", "Today", "Today screen title")
        case .todayDataIntegrity:
            return resource("today.error.data-integrity", "uFast found conflicting local records. Nothing was changed.", "Today data integrity error")
        case .fastRecorded:
            return resource("fast.recorded", "Fast recorded.", "Fast recorded announcement")
        case .endFastConfirmationTitle:
            return resource("fast.end.confirmation.title", "End this fast?", "End-fast confirmation title")
        case .endFastAction:
            return resource("fast.end", "End fast", "End-fast action")
        case .endFastMessage:
            return resource("fast.end.confirmation.message", "This will record the end time as now.", "End-fast confirmation message")
        case .todayStartError:
            return resource("today.error.start", "Your fast couldn’t be started. Please try again.", "Today fast start error")
        case .todayEndError:
            return resource("today.error.end", "Your fast couldn’t be ended. Please try again.", "Today fast end error")
        case .inactiveReady:
            return resource("today.inactive.ready", "Ready when you are", "Inactive Today heading")
        case .inactiveNoFast:
            return resource("today.inactive.no-fast", "No fast is running.", "Inactive Today state")
        case .inactiveNextTarget:
            return resource("today.inactive.next-target", "Your next target", "Inactive Today target heading")
        case let .inactiveGoalEyebrow(hours):
            return resource("today.inactive.goal-eyebrow", "\(hours)-hour goal", "Inactive Today goal eyebrow")
        case .inactiveStartedNow:
            return resource("today.inactive.started-now", "If started now", "Inactive Today target label")
        case .inactiveTargetLabel:
            return resource("today.inactive.target-label", "Target if started now", "Inactive Today target VoiceOver label")
        case let .inactiveGoal(hours):
            return resource("today.inactive.goal", "Your fasting goal is \(hours) hours.", "Inactive Today goal explanation")
        case .startFast:
            return resource("fast.start", "Start fast", "Start-fast action")
        case .tryAgain:
            return resource("common.try-again", "Try again", "Common retry action")
        case .startAtPastTime:
            return resource("fast.start-past", "Start at a past time", "Start-fast past-time action")
        case .liveActivityHeading:
            return resource("live-activity.today.heading", "Live Activity", "Today Live Activity heading")
        case .liveActivityTodayDescription:
            return resource("live-activity.today.description", "Show this active interval on the Lock Screen and Dynamic Island for up to 8 hours. Your recorded interval continues if the activity ends.", "Today Live Activity explanation")
        case .liveActivityHide:
            return resource("live-activity.hide", "Hide for this fast", "Hide Live Activity action")
        case .liveActivityShow:
            return resource("live-activity.show", "Show Live Activity", "Show Live Activity action")
        case .liveActivityShowAgain:
            return resource("live-activity.show-again", "Show Live Activity again", "Show Live Activity again action")
        case .automaticOfferTitle:
            return resource("live-activity.automatic-offer.title", "See your fast at a glance?", "Automatic Live Activity offer title")
        case .automaticOfferShow:
            return resource("live-activity.automatic-offer.show", "Show Automatically", "Automatic Live Activity offer action")
        case .automaticOfferNotNow:
            return resource("live-activity.automatic-offer.not-now", "Not Now", "Automatic Live Activity offer cancellation")
        case .automaticOfferMessage:
            return resource("live-activity.automatic-offer.message", "uFast can automatically show elapsed time, goal progress and target on the Lock Screen and Dynamic Island when you start a fast. Each Live Activity stays active for up to 8 hours. If your fast continues, uFast can show a new one the next time you open the app. You can hide it or turn this off at any time in Settings.", "Automatic Live Activity offer explanation")
        case .liveActivityDisclosureTitle:
            return resource("live-activity.disclosure.title", "Show Live Activity?", "Live Activity disclosure title")
        case .liveActivityDisclosureMessage:
            return resource("live-activity.disclosure.message", "Shows uFast, elapsed time, goal progress and target on the Lock Screen and Dynamic Island for up to 8 hours. You can hide it at any time. Your fast continues if the activity ends.", "Live Activity disclosure explanation")
        case let .liveActivityStatus(status):
            switch status {
            case .unavailable(.unsupported):
                return resource("live-activity.status.unsupported", "Live Activities aren’t available on this iPhone.", "Live Activity unsupported status")
            case .unavailable(.disabled):
                return resource("live-activity.status.disabled", "Live Activities are turned off for uFast in iPhone Settings.", "Live Activity disabled status")
            case .unavailable(.enabled):
                return resource("live-activity.status.disabled", "Live Activities are turned off for uFast in iPhone Settings.", "Live Activity disabled status")
            case .requestFailed:
                return resource("live-activity.status.request-failed", "The Live Activity couldn’t be started. Please try again.", "Live Activity request failure")
            case .hideFailed:
                return resource("live-activity.status.hide-failed", "The Live Activity couldn’t be hidden. You can remove it from the Lock Screen.", "Live Activity hide failure")
            }
        case .historySelectedDateAndTime:
            return resource("history.entry.selected-date-time", "Selected date and time", "History food/drink entry date section")
        case .historyFood:
            return resource("history.entry.food", "Food", "History food entry action")
        case .historyDrink:
            return resource("history.entry.drink", "Drink", "History drink entry action")
        case .historyNothingRecorded:
            return resource("history.entry.nothing-recorded", "Nothing is recorded until you save the full editor.", "History entry persistence explanation")
        case .historyAddTitle:
            return resource("history.entry.title", "Add to history", "History food/drink entry title")
        case let .fastingCopy(copy):
            return fastingCopyResource(copy)
        case let .historyCopy(copy):
            return historyCopyResource(copy)
        case let .fastingValidation(kind, value):
            switch kind {
            case .completedBoundary:
                return resource(
                    "history.edit.crosses-boundary",
                    "This fast must end at or before the caloric event at \(value).",
                    "Completed History fast boundary validation"
                )
            case .startBoundary:
                return resource(
                    "fast.start.crosses-boundary",
                    "Start after the caloric event at \(value).",
                    "Active-fast start boundary validation"
                )
            }
        case let .durationComponent(value, unit):
            return durationComponentResource(value: value, unit: unit)
        case let .historyDate(value):
            return historyDateResource(value)
        case let .historyTime(value):
            return resource("history.time.value", "\(value)", "History localized time value")
        case let .historyVolume(value):
            return resource("history.volume", "\(value) ml", "History drink volume detail")
        case let .historyGroupTitle(count, family):
            return historyGroupTitleResource(count: count, family: family)
        case let .historyGroupMemberTitle(title, count):
            return resource(
                "history.group.member.title",
                "\(title) ×\(count)",
                "History repeated event group title with count"
            )
        case let .historyGroupClassification(category):
            switch category {
            case .food:
                return resource("history.group.classification.food", "Caloric food", "History food group classification")
            case .caloricDrink:
                return resource("history.group.classification.caloric-drink", "Caloric drink", "History caloric drink group classification")
            case .nonCaloricDrink:
                return resource("history.group.classification.non-caloric-drink", "Non-caloric drink", "History non-caloric drink group classification")
            }
        case let .historyGroupAccessibility(count, family, start, end, classification):
            return historyGroupAccessibilityResource(
                count: count,
                family: family,
                start: start,
                end: end,
                classification: classification
            )
        case let .historyEventDetail(kind, date):
            return historyEventDetailResource(kind: kind, date: date)
        case let .historyEventAccessibility(kind, name, volumeMillilitres, date):
            return historyEventAccessibilityResource(
                kind: kind,
                name: name,
                volumeMillilitres: volumeMillilitres,
                date: date
            )
        case let .historyFoodAccessibility(description, date):
            return resource(
                "history.event.food.accessibility",
                "\(description), food, caloric, \(date)",
                "History food event VoiceOver value"
            )
        case let .historyFastTitle(kind, needsReview):
            return historyFastTitleResource(kind: kind, needsReview: needsReview)
        case let .historyFastComponent(kind, value):
            return historyFastComponentResource(kind: kind, value: value)
        case let .historyFastSource(kind, description):
            switch kind {
            case .food:
                return resource(
                    "history.fast.source.food",
                    "source food \(description)",
                    "History inferred food-fast source VoiceOver detail"
                )
            case .drink:
                return resource(
                    "history.fast.source.drink",
                    "source drink \(description)",
                    "History inferred drink-fast source VoiceOver detail"
                )
            }
        case let .historyFastBoundary(kind):
            switch kind {
            case .unavailable:
                return resource(
                    "history.fast.boundary.unavailable",
                    "boundary evidence unavailable",
                    "History unavailable boundary detail"
                )
            case .formerFood:
                return resource(
                    "history.fast.boundary.former-food",
                    "former food boundary unavailable",
                    "History former food boundary detail"
                )
            case .formerDrink:
                return resource(
                    "history.fast.boundary.former-drink",
                    "former drink boundary unavailable",
                    "History former drink boundary detail"
                )
            }
        case let .historyMemberAccessibility(time, title, detail):
            return resource(
                "history.group.member.accessibility",
                "\(time), \(title), \(detail)",
                "History grouped event member VoiceOver value"
            )
        case let .historyMotionEvent(kind):
            return resource(
                kind == .drink ? "history.motion.event.drink" : "history.motion.event.food",
                kind == .drink ? "Drink event" : "Food event",
                "History moving event VoiceOver label"
            )
        case let .activeFastSummary(elapsed, goal, started, target, reachedGoal):
            if reachedGoal {
                return resource(
                    "fast.summary.goal-reached",
                    "Fast in progress, Elapsed \(elapsed), Goal \(goal), Started \(started), Target \(target), Goal time reached",
                    "Active-fast accessibility summary after goal"
                )
            }
            return resource(
                "fast.summary",
                "Fast in progress, Elapsed \(elapsed), Goal \(goal), Started \(started), Target \(target)",
                "Active-fast accessibility summary"
            )
        case let .activeFastProgress(percent, goalHours):
            return resource(
                "fast.progress.value",
                "\(percent) percent of \(goalHours)-hour goal",
                "Active-fast progress VoiceOver value"
            )
        }
    }

    static let catalogKeys: Set<String> = Set(catalogRepresentatives.map(\.resource.key))

    private static let catalogRepresentatives: [AppText] = [
        .cancel, .delete, .date, .time, .localRecordRemoval,
        .foodDescriptionPlaceholder, .foodTimeSection, .foodCaloricExplanation,
        .foodActiveStartValidation, .foodDetailsHide, .foodDetailsAdd,
        .foodOptionalDetailsSection, .foodNutritionField(.energy), .foodNutritionField(.protein),
        .foodNutritionField(.carbohydrate), .foodNutritionField(.fat), .foodNutritionField(.fibre),
        .foodNutritionField(.sugar), .foodNutritionField(.salt), .foodNutritionRange,
        .foodNutritionValuePlaceholder, .foodNutritionUnit(.kilocalories), .foodNutritionUnit(.grams),
        .foodNutritionHint(unit: "g"), .foodDeleteEvent,
        .foodDeleteConfirmationTitle, .foodTitle(isEditing: false), .foodTitle(isEditing: true),
        .foodSaveTitle(isEditing: false), .foodSaveTitle(isEditing: true),
        .foodValidation(.emptyDescription), .foodValidation(.descriptionTooLong),
        .foodValidation(.invalidNutrition), .foodValidation(.beforeToday),
        .foodValidation(.futureTime), .foodValidation(.outsideSelectedRange),
        .foodSaveError, .foodDeleteError, .foodCombinedSaveError, .foodConflictError,
        .confirmationTitle(.active, noun: .food, count: 1),
        .confirmationTitle(.completed, noun: .food, count: 1),
        .confirmationTitle(.completed, noun: .drink, count: 1),
        .confirmationTitle(.inferred, noun: .food, count: 1),
        .confirmationAction(.saving, kind: .active, noun: .food),
        .confirmationAction(.saving, kind: .completed, noun: .food),
        .confirmationAction(.saving, kind: .inferred, noun: .food),
        .confirmationAction(.deleting, kind: .active, noun: .food),
        .confirmationAction(.deleting, kind: .inferred, noun: .food),
        .confirmationMessage(action: .saving, kind: .active, noun: .food, count: 1, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .active, noun: .food, count: 2, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .active, noun: .drink, count: 1, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .active, noun: .drink, count: 2, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .completed, noun: .food, count: 1, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .completed, noun: .food, count: 2, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .completed, noun: .drink, count: 1, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .completed, noun: .drink, count: 2, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .inferred, noun: .food, count: 1, time: "10:30"),
        .confirmationMessage(action: .saving, kind: .inferred, noun: .drink, count: 1, time: "10:30"),
        .reconstructedReviewDetail, .inferredIntervalDetail,
        .drinkSection, .drinkType, .drinkTypeName(.water), .drinkTypeName(.tea),
        .drinkTypeName(.coffee), .drinkTypeName(.custom), .drinkName, .drinkAmount, .drinkVolumeValidation,
        .drinkNameValidation, .drinkActiveStartValidation, .drinkTimeSection, .drinkFastingClassification, .drinkNonCaloric,
        .drinkCaloric, .drinkBoundaryExplanation, .drinkDelete, .drinkDeleteConfirmationTitle,
        .drinkTitle(isEditing: false), .drinkTitle(isEditing: true), .drinkSaveTitle(isEditing: false),
        .drinkSaveTitle(isEditing: true), .drinkSaveError, .drinkDeleteError,
        .drinkCombinedSaveError, .drinkConflictError, .drinkAddedAnnouncement(name: "Drink", volumeMillilitres: 300),
        .drinkPickerTitle, .drinkPickerHeading, .drinkPickerDetail(volumeMillilitres: 300, isCaloric: false),
        .drinkPickerDetail(volumeMillilitres: 300, isCaloric: true),
        .drinkPickerAccessibilityValue(volumeMillilitres: 300), .drinkPickerClassification(isCaloric: false),
        .drinkPickerClassification(isCaloric: true), .drinkAddAnother, .drinkAddError,
        .todayFoodAdd, .todayDrinkAdd, .todayDrinkRetry, .todayFluids, .todayFluidTotal(0),
        .todayTimelineEmpty, .todayTimelineHeading, .todayTimelineLoadError,
        .todayTimelineAccessibilityValue(detail: "Caloric", time: "10:30"), .todayTimelineEditHint,
        .tabToday, .tabHistory, .tabSettings, .persistenceUnavailableTitle,
        .persistenceUnavailableMessage, .localDataIntegrityTitle, .localDataIntegrityMessage,
        .localRecordsIntegrityMessage, .goalSelectionSummary(hours: 12), .goalAccessibilityLabel,
        .goalHours(hours: 12), .goalOption(hours: 12), .onboardingTitle, .onboardingPromise,
        .onboardingChoiceHeading, .onboardingChoiceEyebrow, .onboardingSelectionSummary(hours: 12),
        .onboardingSaveError, .continueAction, .settingsTitle, .settingsGoalHeading,
        .settingsGoalSelected(hours: 12), .settingsGoalDescription, .settingsDataHeading,
        .settingsDataDescription, .settingsDataLoss, .settingsPrivacyLink, .settingsWidgetHeading,
        .settingsWidgetDescription, .settingsWidgetInstructions, .settingsLiveActivityHeading,
        .settingsLiveActivityToggle, .settingsLiveActivitySupport, .settingsLiveActivityExplanation,
        .settingsInferredHeading, .settingsInferredToggle, .settingsInferredDescription,
        .settingsFavouritesHeading, .settingsFavouritesDescription,
        .settingsFavouriteField(.water), .settingsFavouriteField(.tea), .settingsFavouriteField(.coffee),
        .settingsFavouriteDetail(volumeMillilitres: 300, isCaloric: false),
        .settingsFavouriteDetail(volumeMillilitres: 300, isCaloric: true),
        .settingsFavouriteAccessibilityValue(volumeMillilitres: 300, isCaloric: false),
        .settingsFavouriteAccessibilityValue(volumeMillilitres: 300, isCaloric: true),
        .settingsAddFavourite, .settingsFavouriteValidation, .settingsFavouriteAutoSave,
        .settingsMillilitres, .settingsYourDataHeading, .settingsDeleteDescription,
        .settingsDeleteAll, .settingsDeleteFirstTitle, .settingsDeleteFirstMessage,
        .settingsDeleteFinalTitle, .settingsDeleteFinalMessage, .settingsDeleteEverything,
        .settingsConflictError, .settingsInferredSaveError, .settingsGoalSaveError,
        .settingsFavouritesSaveError, .settingsDeleteError, .settingsLiveActivitySaveError,
        .settingsAmountPlaceholder, .settingsAmountAccessibilityLabel(label: "Water"),
        .privacyTitle, .privacySection(.stored), .privacySection(.location), .privacySection(.collection),
        .privacySection(.liveActivities), .privacySection(.deletion), .privacySection(.safety),
        .privacyBody(.stored), .privacyBody(.location), .privacyBody(.collection),
        .privacyBody(.liveActivities), .privacyBody(.deletion), .privacyBody(.safety),
        .privacyMoreInformation, .privacyReadPolicy, .privacyContactSupport, .privacySupportNote,
        .favouriteNamePlaceholder, .favouriteAmountPlaceholder, .favouriteUnit,
        .favouriteCountsAsCaloric, .favouriteBoundaryExplanation, .favouriteDetailsHeading,
        .favouriteDetailsFooter, .favouriteRemove, .favouriteTitle(isEditing: false),
        .favouriteTitle(isEditing: true), .favouriteSave, .favouriteRemoveConfirmation(name: "Drink"),
        .favouriteRemoveAction, .favouriteValidation(.blankName), .favouriteValidation(.duplicateName),
        .favouriteValidation(.invalidAmount), .favouriteSaveError, .favouriteRemoveError,
        .todayTitle, .todayDataIntegrity, .fastRecorded, .endFastConfirmationTitle,
        .endFastAction, .endFastMessage, .todayStartError, .todayEndError, .inactiveReady,
        .inactiveNoFast, .inactiveNextTarget, .inactiveGoalEyebrow(hours: 12), .inactiveStartedNow,
        .inactiveTargetLabel, .inactiveGoal(hours: 12), .startFast, .tryAgain, .startAtPastTime,
        .liveActivityHeading, .liveActivityTodayDescription, .liveActivityHide, .liveActivityShow,
        .liveActivityShowAgain, .automaticOfferTitle, .automaticOfferShow, .automaticOfferNotNow,
        .automaticOfferMessage, .liveActivityDisclosureTitle, .liveActivityDisclosureMessage,
        .liveActivityStatus(.unavailable(.unsupported)), .liveActivityStatus(.requestFailed),
        .historySelectedDateAndTime, .historyFood, .historyDrink, .historyNothingRecorded, .historyAddTitle,
        .fastingCopy(.activeInProgress), .fastingCopy(.goalReached), .fastingCopy(.progress),
        .fastingCopy(.editStart), .fastingCopy(.endUnavailable), .fastingCopy(.endFast),
        .fastingCopy(.endAtPastTime), .fastingCopy(.elapsedTime), .fastingCopy(.elapsedUnavailable),
        .fastingCopy(.started), .fastingCopy(.goal), .fastingCopy(.target),
        .fastingCopy(.recordedBoundaries), .fastingCopy(.editFastEyebrow),
        .fastingCopy(.reviewBoundaries), .fastingCopy(.startSection), .fastingCopy(.startDate),
        .fastingCopy(.startTime), .fastingCopy(.endDate), .fastingCopy(.endTime),
        .fastingCopy(.endHeader), .fastingCopy(.startBeforeEnd), .fastingCopy(.validationError), .fastingCopy(.deleteFast),
        .fastingCopy(.editFastTitle), .fastingCopy(.save), .fastingCopy(.deleteConfirmationTitle),
        .fastingCopy(.localDeviceRemoval), .fastingCopy(.changesSaveError), .fastingCopy(.fastDeleteError),
        .fastingCopy(.endHeading), .fastingCopy(.endDescription), .fastingCopy(.endTimeTitle),
        .fastingCopy(.endBeforeStart), .fastingCopy(.endFuture), .fastingCopy(.endSaveError),
        .fastingCopy(.startCreateHeading), .fastingCopy(.startCorrectHeading),
        .fastingCopy(.startEyebrow), .fastingCopy(.startCreateDescription),
        .fastingCopy(.startCorrectDescription), .fastingCopy(.useEarliestValidStart),
        .fastingCopy(.legacyStartFooter), .fastingCopy(.startTimeTitle), .fastingCopy(.startSaveError),
        .fastingCopy(.startFuture), .fastingCopy(.startTooOld), .fastingCopy(.overlapError),
        .fastingCopy(.inferredInProgressTitle), .fastingCopy(.inferredTitle),
        .fastingCopy(.inferredStartExplanation), .fastingCopy(.inferredSaveExplanation),
        .fastingCopy(.sourceCaloricEvent), .fastingCopy(.startedLabel), .fastingCopy(.endsLabel),
        .fastingCopy(.durationLabel), .fastingCopy(.sourceFood), .fastingCopy(.sourceDrink),
        .fastingCopy(.inferredCancel), .fastingCopy(.inferredUnavailableError),
        .fastingCopy(.inferredConflictError), .fastingCopy(.inferredActiveFastError),
        .fastingCopy(.inferredSaveError),
        .historyCopy(.motionUnavailableTitle), .historyCopy(.motionUnavailableMessage),
        .historyCopy(.title), .historyCopy(.empty), .historyCopy(.loading), .historyCopy(.retry),
        .historyCopy(.carouselSettled), .historyCopy(.carouselMoving),
        .historyCopy(.dateNavigator), .historyCopy(.futureDayHint),
        .historyCopy(.dateChipState(selected: true, future: true, inRange: false, selectable: false)),
        .historyCopy(.dateChipState(selected: true, future: false, inRange: false, selectable: true)),
        .historyCopy(.dateChipState(selected: false, future: true, inRange: false, selectable: false)),
        .historyCopy(.dateChipState(selected: false, future: false, inRange: true, selectable: true)),
        .historyCopy(.dateChipState(selected: false, future: false, inRange: false, selectable: true)),
        .historyCopy(.dateChipState(selected: false, future: false, inRange: false, selectable: false)),
        .historyCopy(.motionExtensionMessage), .historyCopy(.extensionRetry),
        .historyCopy(.eyebrow), .historyCopy(.chooseDate), .historyCopy(.chooseDateLabel),
        .historyCopy(.addAtSelectedTime), .historyCopy(.addAtSelectedTimeHint),
        .historyCopy(.emptyEyebrow), .historyCopy(.emptyTitle), .historyCopy(.emptyMessage),
        .historyCopy(.detailsEyebrow), .historyCopy(.fastsInView), .historyCopy(.futureReadOnly),
        .historyCopy(.futureReadOnlyHint), .historyCopy(.chooseDateSheetTitle), .historyCopy(.done),
        .historyCopy(.groupExactTimes), .historyCopy(.groupHint), .historyCopy(.groupCancel),
        .historyCopy(.groupAddEvent), .historyCopy(.groupAddHint), .historyCopy(.groupNoEligibleTime),
        .historyCopy(.groupMemberFoodHint), .historyCopy(.groupMemberDrinkHint),
        .historyCopy(.memberDetailHint), .historyCopy(.carouselLabel), .historyCopy(.selectedDateLabel),
        .historyCopy(.previousDay), .historyCopy(.nextDay), .historyCopy(.selectedDay),
        .historyCopy(.timelineEmpty), .historyCopy(.eventFood), .historyCopy(.eventDrink),
        .historyCopy(.caloric), .historyCopy(.nonCaloric), .historyCopy(.food), .historyCopy(.drink),
        .historyCopy(.recordedFast), .historyCopy(.activeFast), .historyCopy(.fast),
        .historyCopy(.inferredFastInProgress), .historyCopy(.inferredFast),
        .historyCopy(.previouslySavedFast), .historyCopy(.previouslySavedFastNeedsReview),
        .historyCopy(.unavailableFast), .historyCopy(.startActionAvailable),
        .historyCopy(.saveActionAvailable), .historyCopy(.currentlyActive),
        .historyCopy(.boundaryEvidenceUnavailable),
        .historyCopy(.formerBoundaryUnavailable), .historyCopy(.sourceLabel),
        .historyCopy(.durationLessThanMinute), .historyCopy(.durationDayAbbreviation),
        .historyCopy(.separatorMiddleDot),
        .historyCopy(.separatorArrow), .historyCopy(.separatorComma),
        .historyCopy(.separatorRange), .historyCopy(.separatorSpace), .historyCopy(.to),
        .fastingValidation(.completedBoundary, value: "10:30"),
        .fastingValidation(.startBoundary, value: "10:30"),
        .durationComponent(value: 1, unit: .day), .durationComponent(value: 1, unit: .hour),
        .durationComponent(value: 1, unit: .minute), .durationComponent(value: 1, unit: .second),
        .historyDate(value: "24 July 2026"), .historyTime(value: "10:30"),
        .historyVolume(value: 300),
        .historyGroupTitle(count: 1, family: .food), .historyGroupTitle(count: 2, family: .drink),
        .historyGroupMemberTitle(title: "Lunch", count: 2),
        .historyGroupClassification(.food), .historyGroupClassification(.caloricDrink),
        .historyGroupClassification(.nonCaloricDrink),
        .historyGroupAccessibility(
            count: 2, family: .food, start: "10:00", end: "12:00", classification: "caloric food"
        ),
        .historyEventDetail(kind: .food, date: "24 Jul, 10:30"),
        .historyEventDetail(kind: .caloricDrink, date: "24 Jul, 10:30"),
        .historyEventDetail(kind: .nonCaloricDrink, date: "24 Jul, 10:30"),
        .historyEventAccessibility(
            kind: .caloricDrink, name: "Drink", volumeMillilitres: 300, date: "24 Jul, 10:30"
        ),
        .historyFoodAccessibility(description: "Food", date: "24 Jul, 10:30"),
        .historyFastTitle(kind: .recorded, needsReview: false),
        .historyFastTitle(kind: .previouslySaved, needsReview: true),
        .historyFastComponent(kind: .start, value: "24 Jul, 10:30"),
        .historyFastComponent(kind: .end, value: "24 Jul, 12:30"),
        .historyFastComponent(kind: .duration, value: "2 hours"),
        .historyFastComponent(kind: .goal, value: "12 hours"),
        .historyFastComponent(kind: .startAction, value: ""),
        .historyFastComponent(kind: .saveAction, value: ""),
        .historyFastSource(kind: .food, description: "Food"),
        .historyFastBoundary(kind: .unavailable), .historyFastBoundary(kind: .formerFood),
        .historyFastBoundary(kind: .formerDrink),
        .historyMemberAccessibility(time: "10:30", title: "Food", detail: "Caloric"),
        .historyMotionEvent(kind: .food), .historyMotionEvent(kind: .drink),
        .activeFastSummary(
            elapsed: "1 hour", goal: "12 hours", started: "24 Jul, 10:30", target: "25 Jul, 10:30",
            reachedGoal: false
        ),
        .activeFastProgress(percent: 50, goalHours: 12),
    ]

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func fastingCopyResource(_ copy: FastingCopy) -> LocalizedStringResource {
        switch copy {
        case .activeInProgress: resource("fast.in-progress", "Fast in progress", "Active-fast heading")
        case .goalReached: resource("fast.goal-reached", "Goal time reached", "Active-fast goal state")
        case .progress: resource("fast.progress", "Progress", "Active-fast progress label")
        case .editStart: resource("fast.edit-start", "Edit start time", "Active-fast edit-start action")
        case .endUnavailable: resource("fast.end-unavailable", "This fast can’t end until after its recorded start time.", "Active-fast end validation")
        case .endFast: resource("fast.end", "End fast", "End-fast action")
        case .endAtPastTime: resource("fast.end-past", "End at a past time", "End-fast past-time action")
        case .elapsedTime: resource("fast.elapsed", "Elapsed time", "Elapsed-fast label")
        case .elapsedUnavailable: resource("fast.elapsed-unavailable", "Elapsed time isn’t available while the recorded start is in the future.", "Future-start elapsed state")
        case .started: resource("fast.started", "Started", "Fast start label")
        case .goal: resource("fast.goal", "Goal", "Fast goal label")
        case .target: resource("fast.target", "Target", "Fast target label")
        case .recordedBoundaries: resource("history.edit.recorded-boundaries", "Recorded boundaries", "Completed History fast editor heading")
        case .editFastEyebrow: resource("history.edit.eyebrow", "Edit fast", "Completed History fast editor eyebrow")
        case .reviewBoundaries: resource("history.edit.review-boundaries", "Review both boundaries before saving. The recorded goal is unchanged.", "Completed History fast editor explanation")
        case .startSection: resource("history.edit.start-section", "Start", "Completed History fast start section")
        case .startDate: resource("history.edit.start-date", "Start date", "Completed History fast start date picker")
        case .startTime: resource("history.edit.start-time", "Start time", "Completed History fast start time picker")
        case .endDate: resource("history.edit.end-date", "End date", "Completed History fast end date picker")
        case .endTime: resource("history.edit.end-time", "End time", "Completed History fast end time picker")
        case .endHeader: resource("history.edit.end-header", "End", "Completed History fast end section")
        case .startBeforeEnd: resource("history.edit.validation.start-before-end", "Start time must be before end time.", "Completed History fast validation")
        case .validationError: resource("history.edit.validation-error", "Validation error.", "Completed History fast validation VoiceOver label")
        case .deleteFast: resource("history.edit.delete", "Delete fast", "Completed History fast delete action")
        case .editFastTitle: resource("history.edit.title", "Edit fast", "Completed History fast editor title")
        case .save: resource("history.edit.save", "Save", "Completed History fast save action")
        case .deleteConfirmationTitle: resource("history.edit.delete-confirmation.title", "Delete this fast?", "Completed History fast deletion confirmation")
        case .localDeviceRemoval: resource("history.edit.local-device-removal", "This removes the record from this device.", "Completed History fast local deletion explanation")
        case .changesSaveError: resource("history.edit.save-error", "Your changes couldn’t be saved. Please try again.", "Completed History fast save failure")
        case .fastDeleteError: resource("history.edit.delete-error", "This fast couldn’t be deleted. Please try again.", "Completed History fast delete failure")
        case .endHeading: resource("fast.end.heading", "When did this fast end?", "End-fast editor heading")
        case .endDescription: resource("fast.end.description", "The end must be after the recorded start and no later than now.", "End-fast editor explanation")
        case .endTimeTitle: resource("fast.end.title", "End time", "End-fast editor title")
        case .endBeforeStart: resource("fast.end.validation.before-start", "End time must be after the start time.", "End-fast validation")
        case .endFuture: resource("fast.end.validation.future", "End time can’t be in the future.", "End-fast validation")
        case .endSaveError: resource("fast.end.save-error", "Your end time couldn’t be saved. Please try again.", "End-fast save failure")
        case .startCreateHeading: resource("fast.start.heading.create", "When did this fast start?", "Start-fast creation heading")
        case .startCorrectHeading: resource("fast.start.heading.correct", "Correct the recorded start", "Active-fast start correction heading")
        case .startEyebrow: resource("fast.start.eyebrow", "Start time", "Start-fast editor eyebrow")
        case .startCreateDescription: resource("fast.start.description.create", "Choose the date and time you intend to record.", "Start-fast creation explanation")
        case .startCorrectDescription: resource("fast.start.description.correct", "Corrections are available for the preceding 36 hours.", "Active-fast start correction explanation")
        case .useEarliestValidStart: resource("fast.start.use-earliest", "Use earliest valid start", "Legacy active-fast start replacement action")
        case .legacyStartFooter: resource("fast.start.legacy-footer", "The stored start is older than the preceding 36 hours. Choose a new start to replace it.", "Legacy active-fast start explanation")
        case .startTimeTitle: resource("fast.start.title", "Start time", "Start-fast editor title")
        case .startSaveError: resource("fast.start.save-error", "Your start time couldn’t be saved. Please try again.", "Start-fast save failure")
        case .startFuture: resource("fast.start.validation.future", "Start time can’t be in the future.", "Start-fast validation")
        case .startTooOld: resource("fast.start.validation.too-old", "Start time must be within the past 36 hours.", "Start-fast validation")
        case .overlapError: resource("fast.validation.overlap", "This fast overlaps another recorded fast.", "Fast overlap validation")
        case .inferredInProgressTitle: resource("history.inferred.title.in-progress", "Inferred fast in progress", "Inferred-fast conversion title")
        case .inferredTitle: resource("history.inferred.title", "Inferred fast", "Inferred-fast conversion title")
        case .inferredStartExplanation: resource("history.inferred.explanation.start", "This will start a real active fast from the source event time.", "Inferred-fast start explanation")
        case .inferredSaveExplanation: resource("history.inferred.explanation.save", "This will save one completed fast using the interval shown above.", "Inferred-fast save explanation")
        case .sourceCaloricEvent: resource("history.inferred.source", "Source caloric event", "Inferred-fast source section")
        case .startedLabel: resource("history.inferred.started", "Started", "Inferred-fast start label")
        case .endsLabel: resource("history.inferred.ends", "Ends", "Inferred-fast end label")
        case .durationLabel: resource("history.inferred.duration", "Duration", "Inferred-fast duration label")
        case .sourceFood: resource("history.inferred.source.food", "Food", "Inferred-fast food source label")
        case .sourceDrink: resource("history.inferred.source.drink", "Drink", "Inferred-fast drink source label")
        case .inferredCancel: resource("history.inferred.cancel", "Cancel", "Inferred-fast cancellation action")
        case .inferredUnavailableError: resource("history.inferred.error.unavailable", "This inferred fast is no longer available. History was refreshed.", "Inferred-fast unavailable error")
        case .inferredConflictError: resource("history.inferred.error.conflict", "This interval conflicts with a recorded fast and was not saved.", "Inferred-fast conflict error")
        case .inferredActiveFastError: resource("history.inferred.error.active-fast", "An active fast already exists, so this inferred fast was not started.", "Inferred-fast active-fast error")
        case .inferredSaveError: resource("history.inferred.error.save", "This fast could not be saved. Your local records were unchanged.", "Inferred-fast save error")
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func historyCopyResource(_ copy: HistoryCopy) -> LocalizedStringResource {
        switch copy {
        case .title: resource("history.title", "History", "History screen title")
        case .empty: resource("history.empty.value", "", "History empty accessibility value")
        case .loading: resource("history.loading", "Loading History", "History loading progress label")
        case .carouselSettled: resource("history.carousel.settled", "Settled", "History carousel settled accessibility state")
        case .carouselMoving: resource("history.carousel.moving", "Moving", "History carousel moving accessibility state")
        case .dateNavigator: resource("history.date-navigator", "Date navigator", "History date navigator accessibility label")
        case .futureDayHint: resource("history.future-day.hint", "Future day, history is read only.", "History future date accessibility hint")
        case let .dateChipState(selected, future, inRange, selectable):
            switch (selected, future, inRange, selectable) {
            case (true, true, _, _):
                resource("history.date-chip.selected-future", "Selected, Future date, Read only", "History selected future date chip state")
            case (true, false, _, _):
                resource("history.date-chip.selected", "Selected", "History selected date chip state")
            case (false, true, _, _):
                resource("history.date-chip.future", "Future date, Read only", "History future date chip state")
            case (false, false, true, _):
                resource("history.date-chip.in-range", "In selected range", "History date chip range state")
            case (false, false, false, true):
                resource("history.date-chip.empty", "", "History date chip empty state")
            case (false, false, false, false):
                resource("history.date-chip.future-short", "Future date", "History unavailable date chip state")
            }
        case .motionUnavailableTitle: resource("history.motion.unavailable.title", "History temporarily unavailable", "History motion loading error title")
        case .motionUnavailableMessage: resource("history.motion.unavailable.message", "Your saved records are still safe on this iPhone. Try loading this runway again.", "History motion loading error explanation")
        case .retry: resource("history.retry", "Try again", "History initial retry action")
        case .motionExtensionMessage: resource("history.motion.extension.message", "More history is still available to load.", "History motion extension error explanation")
        case .extensionRetry: resource("history.extension-retry", "Retry", "History motion extension retry action")
        case .eyebrow: resource("history.eyebrow", "HISTORY", "History section eyebrow")
        case .chooseDate: resource("history.choose-date", "Choose date", "History choose-date action")
        case .chooseDateLabel: resource("history.choose-date.label", "Choose a date", "History choose-date VoiceOver label")
        case .addAtSelectedTime: resource("history.add-at-selected-time", "Add at selected time", "History direct-entry action")
        case .addAtSelectedTimeHint: resource("history.add-at-selected-time.hint", "Opens native date and time controls before choosing food or drink.", "History direct-entry VoiceOver hint")
        case .emptyEyebrow: resource("history.empty.eyebrow", "Fasts in this view", "History empty-state eyebrow")
        case .emptyTitle: resource("history.empty.title", "No completed fasts", "History empty-state title")
        case .emptyMessage: resource("history.empty.message", "Completed fasts will appear here.", "History empty-state message")
        case .detailsEyebrow: resource("history.details.eyebrow", "Details", "History fast detail eyebrow")
        case .fastsInView: resource("history.fasts-in-view", "Fasts in this view", "History fast detail heading")
        case .futureReadOnly: resource("history.future.read-only", "Future day · History is read only", "History future-day notice")
        case .futureReadOnlyHint: resource("history.future.read-only.hint", "Return to a completed day to add or repair history.", "History future-day VoiceOver hint")
        case .chooseDateSheetTitle: resource("history.choose-date.title", "Choose a date", "History date picker title")
        case .done: resource("common.done", "Done", "Common completion action")
        case .groupExactTimes: resource("history.group.exact-times", "Exact times", "History event group detail heading")
        case .groupHint: resource("history.group.hint", "Shows exact times and actions.", "History event group VoiceOver hint")
        case .groupCancel: resource("history.group.cancel", "Cancel", "History event group cancellation action")
        case .groupAddEvent: resource("history.group.add-event", "Add event", "History event group add action")
        case .groupAddHint: resource("history.group.add.hint", "Adds an event within this bucket.", "History event group add VoiceOver hint")
        case .groupNoEligibleTime: resource("history.group.add.no-eligible-time", "No eligible time remains in this bucket.", "History event group unavailable add VoiceOver hint")
        case .groupMemberFoodHint: resource("history.group.member.food.hint", "Opens this food event for editing.", "History food group member VoiceOver hint")
        case .groupMemberDrinkHint: resource("history.group.member.drink.hint", "Opens this drink event for editing.", "History drink group member VoiceOver hint")
        case .memberDetailHint: resource("history.group.member.hint", "Opens details and available actions.", "History event member VoiceOver hint")
        case .carouselLabel: resource("history.carousel", "History day carousel", "History carousel VoiceOver label")
        case .selectedDateLabel: resource("history.selected-date.label", "Selected day, %@", "History selected-day VoiceOver label")
        case .previousDay: resource("history.previous-day", "Previous day", "History carousel accessibility action")
        case .nextDay: resource("history.next-day", "Next day", "History carousel accessibility action")
        case .selectedDay: resource("history.selected-day", "Selected day", "History selected-day label")
        case .timelineEmpty: resource("history.timeline.empty", "No recorded items in this time window.", "History empty timeline message")
        case .eventFood: resource("history.event.food", "Food", "History food event category")
        case .eventDrink: resource("history.event.drink", "Drink", "History drink event category")
        case .caloric: resource("history.event.caloric", "Caloric", "History caloric event status")
        case .nonCaloric: resource("history.event.non-caloric", "Non-caloric", "History non-caloric event status")
        case .food: resource("history.family.food", "food", "History food group family")
        case .drink: resource("history.family.drink", "drink", "History drink group family")
        case .recordedFast: resource("history.fast.recorded", "Recorded fast", "History recorded fast title")
        case .activeFast: resource("history.fast.active", "Active Fast", "History active fast title")
        case .fast: resource("history.fast.automatic", "Fast", "History automatic fast title")
        case .inferredFastInProgress: resource("history.fast.inferred.in-progress", "Inferred fast in progress", "History inferred fast in-progress title")
        case .inferredFast: resource("history.fast.inferred", "Inferred fast", "History inferred fast title")
        case .previouslySavedFast: resource("history.fast.previously-saved", "Previously saved fast", "History previously saved fast title")
        case .previouslySavedFastNeedsReview: resource("history.fast.previously-saved.needs-review", "Previously saved fast · Needs review", "History previously saved fast review title")
        case .unavailableFast: resource("history.fast.unavailable", "Saved fast · Details unavailable", "History unavailable fast title")
        case .startActionAvailable: resource("history.fast.action.start", "Start fast available", "History inferred fast start action detail")
        case .saveActionAvailable: resource("history.fast.action.save", "Save fast available", "History inferred fast save action detail")
        case .currentlyActive: resource("history.fast.currently-active", "currently active", "History active fast accessibility detail")
        case .boundaryEvidenceUnavailable: resource("history.fast.boundary.unavailable", "boundary evidence unavailable", "History unavailable boundary detail")
        case .formerBoundaryUnavailable: resource("history.fast.boundary.former", "former boundary unavailable", "History former boundary detail")
        case .sourceLabel: resource("history.fast.source.label", "source", "History inferred-fast source label")
        case .durationLessThanMinute: resource("duration.less-than-minute", "Less than 1 minute", "Localized duration below one minute")
        case .durationDayAbbreviation: resource("duration.day.abbreviation", "d", "Localized active-duration day abbreviation")
        case .separatorMiddleDot: resource("history.separator.middle-dot", "·", "History detail separator")
        case .separatorArrow: resource("history.separator.arrow", "→", "History fast range separator")
        case .separatorRange: resource("history.separator.range", "–", "History event time range separator")
        case .separatorComma: resource("history.separator.comma", ",", "History accessibility separator")
        case .separatorSpace: resource("history.separator.space", " ", "History text separator")
        case .to: resource("common.to", "to", "Common range separator")
        }
    }

    private func durationComponentResource(value: Int, unit: DurationUnit) -> LocalizedStringResource {
        switch unit {
        case .day:
            resource("duration.day", "\(value) day", "Localized duration component with plural count")
        case .hour:
            resource("duration.hour", "\(value) hour", "Localized duration component with plural count")
        case .minute:
            resource("duration.minute", "\(value) minute", "Localized duration component with plural count")
        case .second:
            resource("duration.second", "\(value) second", "Localized duration component with plural count")
        }
    }

    private func historyDateResource(_ value: String) -> LocalizedStringResource {
        resource("history.date.value", "\(value)", "History localized date value")
    }

    private func historyGroupTitleResource(count: Int, family: HistoryEventFamily) -> LocalizedStringResource {
        switch family {
        case .food:
            resource(
                "history.group.food.title",
                "\(count) food event",
                "History food event group title with plural count"
            )
        case .drink:
            resource(
                "history.group.drink.title",
                "\(count) drink",
                "History drink group title with plural count"
            )
        }
    }

    private func historyGroupAccessibilityResource(
        count: Int,
        family: HistoryEventFamily,
        start: String,
        end: String,
        classification: String
    ) -> LocalizedStringResource {
        switch family {
        case .food:
            resource(
                "history.group.food.accessibility",
                "\(count) food events, \(start) to \(end), \(classification)",
                "History food event group VoiceOver value with plural count"
            )
        case .drink:
            resource(
                "history.group.drink.accessibility",
                "\(count) drinks, \(start) to \(end), \(classification)",
                "History drink event group VoiceOver value with plural count"
            )
        }
    }

    private func historyEventDetailResource(kind: HistoryEventKind, date: String) -> LocalizedStringResource {
        switch kind {
        case .food:
            resource("history.event.food.detail", "Food · Caloric · \(date)", "History food event detail")
        case .caloricDrink:
            resource("history.event.caloric-drink.detail", "Caloric drink · \(date)", "History caloric drink event detail")
        case .nonCaloricDrink:
            resource("history.event.non-caloric-drink.detail", "Non-caloric drink · \(date)", "History non-caloric drink event detail")
        }
    }

    private func historyEventAccessibilityResource(
        kind: HistoryEventKind,
        name: String,
        volumeMillilitres: Int,
        date: String
    ) -> LocalizedStringResource {
        switch kind {
        case .food:
            resource(
                "history.event.food.accessibility",
                "\(name), food, caloric, \(date)",
                "History food event VoiceOver value"
            )
        case .caloricDrink:
            resource(
                "history.event.drink.accessibility.caloric",
                "\(name), \(volumeMillilitres) millilitres, caloric drink, \(date)",
                "History caloric drink VoiceOver value"
            )
        case .nonCaloricDrink:
            resource(
                "history.event.drink.accessibility.non-caloric",
                "\(name), \(volumeMillilitres) millilitres, non-caloric drink, \(date)",
                "History non-caloric drink VoiceOver value"
            )
        }
    }

    private func historyFastTitleResource(kind: HistoryFastKind, needsReview: Bool) -> LocalizedStringResource {
        switch kind {
        case .recorded: resource("history.fast.recorded", "Recorded fast", "History recorded fast title")
        case .active: resource("history.fast.active", "Active Fast", "History active fast title")
        case .automatic: resource("history.fast.automatic", "Fast", "History automatic fast title")
        case .inferred:
            resource(
                needsReview ? "history.fast.inferred.in-progress" : "history.fast.inferred",
                needsReview ? "Inferred fast in progress" : "Inferred fast",
                "History inferred fast title"
            )
        case .previouslySaved:
            resource(
                needsReview ? "history.fast.previously-saved.needs-review" : "history.fast.previously-saved",
                needsReview ? "Previously saved fast · Needs review" : "Previously saved fast",
                "History previously saved fast title"
            )
        case .unavailable: resource("history.fast.unavailable", "Saved fast · Details unavailable", "History unavailable fast title")
        }
    }

    private func historyFastComponentResource(kind: HistoryFastComponent, value: String) -> LocalizedStringResource {
        switch kind {
        case .start: resource("history.fast.component.start", "start \(value)", "History fast start detail")
        case .end: resource("history.fast.component.end", "end \(value)", "History fast end detail")
        case .duration: resource("history.fast.component.duration", "duration \(value)", "History fast duration detail")
        case .goal: resource("history.fast.component.goal", "goal \(value)", "History fast goal detail")
        case .startAction: resource("history.fast.action.start", "Start fast available", "History inferred fast start action detail")
        case .saveAction: resource("history.fast.action.save", "Save fast available", "History inferred fast save action detail")
        }
    }

    private func resource(
        _ key: StaticString,
        _ value: String.LocalizationValue,
        _ comment: StaticString
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: value, comment: comment)
    }

    private func confirmationTitleResource(
        kind: CaloricEventConfirmationKind,
        noun: CaloricEventNoun,
        count: Int
    ) -> LocalizedStringResource {
        switch kind {
        case .active:
            return resource("caloric.confirmation.active.title", "This entry is during your recorded fast.", "Active-fast caloric event confirmation title")
        case .completed:
            if noun == .drink {
                return resource(
                    "drink.confirmation.completed.title",
                    "This drink updates \(count) recorded fast.",
                    "Completed-fast caloric drink confirmation title with plural count"
                )
            }
            return resource(
                "caloric.confirmation.completed.title",
                "This entry updates \(count) recorded fast.",
                "Completed-fast caloric event confirmation title with plural count"
            )
        case .inferred:
            return resource("caloric.confirmation.inferred.title", "This entry updates inferred History.", "Inferred History caloric event confirmation title")
        }
    }

    private func confirmationActionResource(
        action: CaloricEventConfirmationAction,
        kind: CaloricEventConfirmationKind,
        noun: CaloricEventNoun
    ) -> LocalizedStringResource {
        switch (action, kind, noun) {
        case (.saving, .active, .food):
            resource("food.confirmation.save-end", "Save and end fast", "Food active-fast confirmation action")
        case (.saving, .active, .drink):
            resource("drink.confirmation.save-end", "Save and end fast", "Drink active-fast confirmation action")
        case (.deleting, .inferred, .food), (.deleting, .inferred, .drink):
            resource("caloric.confirmation.delete-update-history", "Delete and update History", "Inferred History deletion confirmation action")
        case (.deleting, _, .food), (.deleting, _, .drink):
            resource("caloric.confirmation.delete-update-fast", "Delete and update fast", "Caloric deletion confirmation action")
        case (.saving, .completed, _):
            resource("caloric.confirmation.save-update", "Save and update fast", "Caloric confirmation action")
        case (.saving, .inferred, _):
            resource("caloric.confirmation.save-update-history", "Save and update History", "Inferred History confirmation action")
        case (.saving, _, .event), (.deleting, _, .event):
            resource("caloric.confirmation.save-update", "Save and update fast", "Caloric confirmation action")
        case (.saving, _, _):
            resource("caloric.confirmation.save-update", "Save and update fast", "Caloric confirmation action")
        }
    }

    private func confirmationMessageResource(
        action: CaloricEventConfirmationAction,
        kind: CaloricEventConfirmationKind,
        noun: CaloricEventNoun,
        count: Int,
        time: String
    ) -> LocalizedStringResource {
        let verb = action == .deleting ? "Deleting" : "Saving"
        switch kind {
        case .active:
            if count > 1 {
                return resource(
                    "caloric.confirmation.active.message.multiple",
                    "Ending your active fast at \(time) updates \(count) persisted fast.",
                    "Active-fast caloric event consequence with plural count"
                )
            }
            if noun == .drink {
                return resource(
                    "drink.confirmation.active.message",
                    "\(verb) this caloric drink records it and ends your fast at \(time).",
                    "Active-fast caloric event consequence"
                )
            }
            return resource(
                "food.confirmation.active.message",
                "\(verb) this caloric event records the food and ends your fast at \(time).",
                "Active-fast caloric event consequence"
            )
        case .completed:
            if noun == .drink {
                return resource(
                    "drink.confirmation.completed.message",
                    "\(verb) this caloric drink updates \(count) recorded fast at \(time).",
                    "Completed-fast caloric event consequence with plural count"
                )
            }
            return resource(
                "food.confirmation.completed.message",
                "\(verb) this caloric event updates \(count) recorded fast at \(time).",
                "Completed-fast caloric event consequence with plural count"
            )
        case .inferred:
            if noun == .drink {
                return resource(
                    "drink.confirmation.inferred.message",
                    "\(verb) this caloric drink refreshes derived inferred History at \(time).",
                    "Inferred History caloric event consequence"
                )
            }
            return resource(
                "food.confirmation.inferred.message",
                "\(verb) this caloric event refreshes derived inferred History at \(time).",
                "Inferred History caloric event consequence"
            )
        }
    }
}

struct AppTextResolver: Equatable, Sendable {
    let pseudolocalizationEnabled: Bool

    init(pseudolocalizationEnabled: Bool = false) {
        self.pseudolocalizationEnabled = pseudolocalizationEnabled
    }

    func callAsFunction(_ text: AppText) -> String {
        let localized = String(localized: text.resource)
        guard pseudolocalizationEnabled else { return localized }
        return AppTextPseudolocalizer.resolve(localized, preserving: text.interpolationValues)
    }
}

private extension AppText {
    var interpolationValues: [String] {
        switch self {
        case let .foodNutritionHint(unit): [unit]
        case let .confirmationTitle(_, _, count): [String(count)]
        case let .confirmationMessage(_, _, _, count, time): [String(count), time]
        case let .drinkAddedAnnouncement(name, volumeMillilitres):
            [name, String(volumeMillilitres)]
        case let .drinkPickerDetail(volumeMillilitres, _): [String(volumeMillilitres)]
        case let .drinkPickerAccessibilityValue(volumeMillilitres): [String(volumeMillilitres)]
        case let .todayFluidTotal(volumeMillilitres): [String(volumeMillilitres)]
        case let .todayTimelineAccessibilityValue(detail, time): [detail, time]
        case let .goalSelectionSummary(hours): [String(hours)]
        case let .goalHours(hours): [String(hours)]
        case let .goalOption(hours): [String(hours)]
        case let .onboardingSelectionSummary(hours): [String(hours)]
        case let .settingsGoalSelected(hours): [String(hours)]
        case let .settingsFavouriteDetail(volumeMillilitres, _): [String(volumeMillilitres)]
        case let .settingsFavouriteAccessibilityValue(volumeMillilitres, _): [String(volumeMillilitres)]
        case let .settingsAmountAccessibilityLabel(label): [label]
        case let .favouriteRemoveConfirmation(name): [name]
        case let .inactiveGoalEyebrow(hours): [String(hours)]
        case let .inactiveGoal(hours): [String(hours)]
        case let .fastingValidation(_, value): [value]
        case let .durationComponent(value, _): [String(value)]
        case let .historyDate(value), let .historyTime(value): [value]
        case let .historyVolume(value): [String(value)]
        case let .historyGroupTitle(count, _): [String(count)]
        case let .historyGroupMemberTitle(title, count): [title, String(count)]
        case .historyGroupClassification: []
        case let .historyGroupAccessibility(count, _, start, end, classification):
            [String(count), start, end, classification]
        case let .historyEventDetail(_, date): [date]
        case let .historyEventAccessibility(_, name, volumeMillilitres, date):
            [name, String(volumeMillilitres), date]
        case let .historyFoodAccessibility(description, date): [description, date]
        case .historyFastTitle: []
        case let .historyFastComponent(_, value): [value]
        case let .historyFastSource(_, description): [description]
        case .historyFastBoundary: []
        case let .historyMemberAccessibility(time, title, detail): [time, title, detail]
        case let .activeFastSummary(elapsed, goal, started, target, _):
            [elapsed, goal, started, target]
        case let .activeFastProgress(percent, goalHours): [String(percent), String(goalHours)]
        default: []
        }
    }
}

enum AppTextPseudolocalizer {
    private static let replacements: [Character: String] = [
        "a": "ȧ", "A": "Ȧ", "e": "ë", "E": "Ë", "i": "ï", "I": "Ï",
        "o": "õ", "O": "Õ", "u": "ü", "U": "Ü", "c": "ç", "C": "Ç",
        "n": "ñ", "N": "Ñ", "s": "š", "S": "Š",
    ]

    static func resolve(_ value: String, preserving tokens: [String] = []) -> String {
        var protected = value
        let protectedTokens = tokens
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .enumerated()
            .compactMap { index, token -> (String, String)? in
                guard let range = protected.range(of: token) else { return nil }
                let marker = "\u{E000}\(index)\u{E001}"
                protected.replaceSubrange(range, with: marker)
                return (marker, token)
            }
        let expanded = protected.map { character in
            replacements[character] ?? String(character)
        }.joined()
        var restored = "［\(expanded) ··］"
        for (marker, token) in protectedTokens {
            restored = restored.replacingOccurrences(of: marker, with: token)
        }
        return restored
    }
}

extension EnvironmentValues {
    @Entry var appTextResolver: AppTextResolver = .init()
}
