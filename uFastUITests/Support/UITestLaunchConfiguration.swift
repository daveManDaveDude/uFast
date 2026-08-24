import Foundation

// swiftlint:disable trailing_comma

struct UITestLaunchConfiguration: Equatable {
    enum ValidationError: Equatable {
        case fixedNowMustBeFinite
        case seedActiveFastStartMustBeFinite
        case liveActivityIdentityMustBeComplete
        case liveActivityIdentityComponentMustBeValid
        case liveActivityAvailabilityIsConflicting
        case appleLanguagesMustNotBeEmpty
        case appleLocaleMustNotBeEmpty
        case timeZoneMustNotBeEmpty
        case preferredSizeCategoryMustNotBeEmpty
    }

    let resetData: Bool
    let pseudolocalization: Bool
    let seedOnboarded: Bool
    let fixedNow: Date?
    let seedActiveFastStart: Date?
    let seedSlice3History: Bool
    let seedHistoryEventGrouping: Bool
    let seedHistoryMidnightSeam: Bool
    let seedHistoryMidnightSeamExtended: Bool
    let seedUnknownProvenance: Bool
    let seedInferredFast: Bool
    let seedTodayMultiYear: Bool
    let seedCaloricBoundaryMultiYear: Bool
    let seedFavouritePopulated: Bool
    let seedFavouriteDuplicateName: Bool
    let seedFavouriteValidation: Bool
    let seedCaloricFavouriteActiveFast: Bool
    let seedMultipleActiveFasts: Bool
    let seedLiveActivityRecovery: Bool
    let liveActivityRelease: String?
    let liveActivityBuild: String?
    let suppressAutomaticLiveActivityOffer: Bool
    let startsOnHistory: Bool
    let historyMotionRetryFixture: Bool
    let simulateFastSaveFailure: Bool
    let simulateFastHistoryFailure: Bool
    let simulateFoodSaveFailure: Bool
    let simulateDrinkSaveFailure: Bool
    let simulateFavouriteSaveFailure: Bool
    let simulateGoalSaveFailure: Bool
    let simulateLiveActivitySettingsSaveFailure: Bool
    let simulateInferredFastDetectionSaveFailure: Bool
    let simulateDeleteAllFailure: Bool
    let simulateBoundaryReconciliationFailure: Bool
    let simulatePersistenceBootstrapFailure: Bool
    let simulateLiveActivityUnsupported: Bool
    let simulateLiveActivityDisabled: Bool
    let simulateLiveActivityRequestFailure: Bool
    let simulateLiveActivityHideFailure: Bool
    let appleLanguages: String?
    let appleLocale: String?
    let timeZone: String?
    let preferredContentSizeCategory: String?

    init(
        resetData: Bool = false,
        pseudolocalization: Bool = false,
        seedOnboarded: Bool = false,
        fixedNow: Date? = nil,
        seedActiveFastStart: Date? = nil,
        seedSlice3History: Bool = false,
        seedHistoryEventGrouping: Bool = false,
        seedHistoryMidnightSeam: Bool = false,
        seedHistoryMidnightSeamExtended: Bool = false,
        seedUnknownProvenance: Bool = false,
        seedInferredFast: Bool = false,
        seedTodayMultiYear: Bool = false,
        seedCaloricBoundaryMultiYear: Bool = false,
        seedFavouritePopulated: Bool = false,
        seedFavouriteDuplicateName: Bool = false,
        seedFavouriteValidation: Bool = false,
        seedCaloricFavouriteActiveFast: Bool = false,
        seedMultipleActiveFasts: Bool = false,
        seedLiveActivityRecovery: Bool = false,
        liveActivityRelease: String? = nil,
        liveActivityBuild: String? = nil,
        suppressAutomaticLiveActivityOffer: Bool = false,
        startsOnHistory: Bool = false,
        historyMotionRetryFixture: Bool = false,
        simulateFastSaveFailure: Bool = false,
        simulateFastHistoryFailure: Bool = false,
        simulateFoodSaveFailure: Bool = false,
        simulateDrinkSaveFailure: Bool = false,
        simulateFavouriteSaveFailure: Bool = false,
        simulateGoalSaveFailure: Bool = false,
        simulateLiveActivitySettingsSaveFailure: Bool = false,
        simulateInferredFastDetectionSaveFailure: Bool = false,
        simulateDeleteAllFailure: Bool = false,
        simulateBoundaryReconciliationFailure: Bool = false,
        simulatePersistenceBootstrapFailure: Bool = false,
        simulateLiveActivityUnsupported: Bool = false,
        simulateLiveActivityDisabled: Bool = false,
        simulateLiveActivityRequestFailure: Bool = false,
        simulateLiveActivityHideFailure: Bool = false,
        appleLanguages: String? = nil,
        appleLocale: String? = nil,
        timeZone: String? = nil,
        preferredContentSizeCategory: String? = nil
    ) {
        self.resetData = resetData
        self.pseudolocalization = pseudolocalization
        self.seedOnboarded = seedOnboarded
        self.fixedNow = fixedNow
        self.seedActiveFastStart = seedActiveFastStart
        self.seedSlice3History = seedSlice3History
        self.seedHistoryEventGrouping = seedHistoryEventGrouping
        self.seedHistoryMidnightSeam = seedHistoryMidnightSeam
        self.seedHistoryMidnightSeamExtended = seedHistoryMidnightSeamExtended
        self.seedUnknownProvenance = seedUnknownProvenance
        self.seedInferredFast = seedInferredFast
        self.seedTodayMultiYear = seedTodayMultiYear
        self.seedCaloricBoundaryMultiYear = seedCaloricBoundaryMultiYear
        self.seedFavouritePopulated = seedFavouritePopulated
        self.seedFavouriteDuplicateName = seedFavouriteDuplicateName
        self.seedFavouriteValidation = seedFavouriteValidation
        self.seedCaloricFavouriteActiveFast = seedCaloricFavouriteActiveFast
        self.seedMultipleActiveFasts = seedMultipleActiveFasts
        self.seedLiveActivityRecovery = seedLiveActivityRecovery
        self.liveActivityRelease = liveActivityRelease
        self.liveActivityBuild = liveActivityBuild
        self.suppressAutomaticLiveActivityOffer = suppressAutomaticLiveActivityOffer
        self.startsOnHistory = startsOnHistory
        self.historyMotionRetryFixture = historyMotionRetryFixture
        self.simulateFastSaveFailure = simulateFastSaveFailure
        self.simulateFastHistoryFailure = simulateFastHistoryFailure
        self.simulateFoodSaveFailure = simulateFoodSaveFailure
        self.simulateDrinkSaveFailure = simulateDrinkSaveFailure
        self.simulateFavouriteSaveFailure = simulateFavouriteSaveFailure
        self.simulateGoalSaveFailure = simulateGoalSaveFailure
        self.simulateLiveActivitySettingsSaveFailure = simulateLiveActivitySettingsSaveFailure
        self.simulateInferredFastDetectionSaveFailure = simulateInferredFastDetectionSaveFailure
        self.simulateDeleteAllFailure = simulateDeleteAllFailure
        self.simulateBoundaryReconciliationFailure = simulateBoundaryReconciliationFailure
        self.simulatePersistenceBootstrapFailure = simulatePersistenceBootstrapFailure
        self.simulateLiveActivityUnsupported = simulateLiveActivityUnsupported
        self.simulateLiveActivityDisabled = simulateLiveActivityDisabled
        self.simulateLiveActivityRequestFailure = simulateLiveActivityRequestFailure
        self.simulateLiveActivityHideFailure = simulateLiveActivityHideFailure
        self.appleLanguages = appleLanguages
        self.appleLocale = appleLocale
        self.timeZone = timeZone
        self.preferredContentSizeCategory = preferredContentSizeCategory
    }

    static let supportedFlags: Set<String> = [
        "--ui-testing", "--ui-testing-pseudolocalization", "--ui-testing-start-history", "--reset-data",
        "--seed-onboarded",
        "--fixed-now", "--seed-active-fast-start", "--seed-slice3-history",
        "--seed-history-event-grouping", "--seed-history-midnight-seam",
        "--seed-history-midnight-seam-extended", "--seed-unknown-provenance",
        "--seed-inferred-fast", "--seed-today-multi-year", "--seed-caloric-boundary-multi-year",
        "--seed-favourite-populated", "--seed-favourite-duplicate-name", "--seed-favourite-validation",
        "--seed-caloric-favourite-active-fast", "--seed-multiple-active-fasts",
        "--seed-live-activity-recovery", "--live-activity-release", "--live-activity-build",
        "--suppress-automatic-live-activity-offer", "--simulate-fast-save-failure",
        "--simulate-fast-history-failure", "--ui-testing-history-retry-fixture",
        "--simulate-food-save-failure", "--simulate-drink-save-failure",
        "--simulate-favourite-save-failure", "--simulate-goal-save-failure",
        "--simulate-live-activity-settings-save-failure", "--simulate-inferred-fast-detection-save-failure",
        "--simulate-delete-all-failure", "--simulate-caloric-boundary-reconciliation-failure",
        "--simulate-persistence-bootstrap-failure", "--simulate-live-activity-unsupported",
        "--simulate-live-activity-disabled", "--simulate-live-activity-request-failure",
        "--simulate-live-activity-hide-failure",
    ]

    var validationError: ValidationError? {
        if let fixedNow, !fixedNow.timeIntervalSince1970.isFinite {
            return .fixedNowMustBeFinite
        }
        if let seedActiveFastStart, !seedActiveFastStart.timeIntervalSince1970.isFinite {
            return .seedActiveFastStartMustBeFinite
        }
        if (liveActivityRelease == nil) != (liveActivityBuild == nil) {
            return .liveActivityIdentityMustBeComplete
        }
        if let liveActivityRelease, !Self.isValidIdentityComponent(liveActivityRelease) {
            return .liveActivityIdentityComponentMustBeValid
        }
        if let liveActivityBuild, !Self.isValidIdentityComponent(liveActivityBuild) {
            return .liveActivityIdentityComponentMustBeValid
        }
        if simulateLiveActivityUnsupported, simulateLiveActivityDisabled {
            return .liveActivityAvailabilityIsConflicting
        }
        if appleLanguages?.isEmpty == true {
            return .appleLanguagesMustNotBeEmpty
        }
        if appleLocale?.isEmpty == true {
            return .appleLocaleMustNotBeEmpty
        }
        if timeZone?.isEmpty == true {
            return .timeZoneMustNotBeEmpty
        }
        if preferredContentSizeCategory?.isEmpty == true {
            return .preferredSizeCategoryMustNotBeEmpty
        }
        return nil
    }

    var isValid: Bool {
        validationError == nil
    }

    var arguments: [String] {
        precondition(isValid, "Invalid UI-test launch configuration: \(String(describing: validationError))")

        var values = ["--ui-testing"]
        append("--ui-testing-pseudolocalization", when: pseudolocalization, to: &values)
        append("--reset-data", when: resetData, to: &values)
        append("--seed-onboarded", when: seedOnboarded, to: &values)
        append("--fixed-now", value: fixedNow?.timeIntervalSince1970, to: &values)
        append("--seed-active-fast-start", value: seedActiveFastStart?.timeIntervalSince1970, to: &values)

        append("--seed-slice3-history", when: seedSlice3History, to: &values)
        append("--seed-history-event-grouping", when: seedHistoryEventGrouping, to: &values)
        append("--seed-history-midnight-seam", when: seedHistoryMidnightSeam, to: &values)
        append("--seed-history-midnight-seam-extended", when: seedHistoryMidnightSeamExtended, to: &values)
        append("--seed-unknown-provenance", when: seedUnknownProvenance, to: &values)
        append("--seed-inferred-fast", when: seedInferredFast, to: &values)
        append("--seed-today-multi-year", when: seedTodayMultiYear, to: &values)
        append("--seed-caloric-boundary-multi-year", when: seedCaloricBoundaryMultiYear, to: &values)

        append("--seed-favourite-populated", when: seedFavouritePopulated, to: &values)
        append("--seed-favourite-duplicate-name", when: seedFavouriteDuplicateName, to: &values)
        append("--seed-favourite-validation", when: seedFavouriteValidation, to: &values)
        append("--seed-caloric-favourite-active-fast", when: seedCaloricFavouriteActiveFast, to: &values)
        append("--seed-multiple-active-fasts", when: seedMultipleActiveFasts, to: &values)

        append("--seed-live-activity-recovery", when: seedLiveActivityRecovery, to: &values)
        append("--live-activity-release", value: liveActivityRelease, to: &values)
        append("--live-activity-build", value: liveActivityBuild, to: &values)
        append("--suppress-automatic-live-activity-offer", when: suppressAutomaticLiveActivityOffer, to: &values)
        append("--ui-testing-start-history", when: startsOnHistory, to: &values)
        append("--ui-testing-history-retry-fixture", when: historyMotionRetryFixture, to: &values)

        append("--simulate-fast-save-failure", when: simulateFastSaveFailure, to: &values)
        append("--simulate-fast-history-failure", when: simulateFastHistoryFailure, to: &values)
        append("--simulate-food-save-failure", when: simulateFoodSaveFailure, to: &values)
        append("--simulate-drink-save-failure", when: simulateDrinkSaveFailure, to: &values)
        append("--simulate-favourite-save-failure", when: simulateFavouriteSaveFailure, to: &values)
        append("--simulate-goal-save-failure", when: simulateGoalSaveFailure, to: &values)
        append(
            "--simulate-live-activity-settings-save-failure",
            when: simulateLiveActivitySettingsSaveFailure,
            to: &values
        )
        append(
            "--simulate-inferred-fast-detection-save-failure",
            when: simulateInferredFastDetectionSaveFailure,
            to: &values
        )
        append("--simulate-delete-all-failure", when: simulateDeleteAllFailure, to: &values)
        append(
            "--simulate-caloric-boundary-reconciliation-failure",
            when: simulateBoundaryReconciliationFailure,
            to: &values
        )
        append("--simulate-persistence-bootstrap-failure", when: simulatePersistenceBootstrapFailure, to: &values)

        append("--simulate-live-activity-unsupported", when: simulateLiveActivityUnsupported, to: &values)
        append("--simulate-live-activity-disabled", when: simulateLiveActivityDisabled, to: &values)
        append("--simulate-live-activity-request-failure", when: simulateLiveActivityRequestFailure, to: &values)
        append("--simulate-live-activity-hide-failure", when: simulateLiveActivityHideFailure, to: &values)

        append("-AppleLanguages", value: appleLanguages, to: &values)
        append("-AppleLocale", value: appleLocale, to: &values)
        append("-NSTimeZone", value: timeZone, to: &values)
        append(
            "-UIPreferredContentSizeCategoryName",
            value: preferredContentSizeCategory,
            to: &values
        )
        return values
    }

    private static func isValidIdentityComponent(_ value: String) -> Bool {
        !value.isEmpty
            && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
            && value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }

    private func append(_ flag: String, when condition: Bool, to values: inout [String]) {
        if condition {
            values.append(flag)
        }
    }

    private func append(
        _ flag: String,
        value: (some LosslessStringConvertible)?,
        to values: inout [String]
    ) {
        guard let value else { return }
        values.append(flag)
        values.append(String(value))
    }
}
