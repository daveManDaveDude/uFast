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

    let core: CoreValues
    let seeds: SeedValues
    let flow: FlowValues
    let failures: FailureValues
    let environment: EnvironmentValues

    private init(
        core: CoreValues,
        seeds: SeedValues,
        flow: FlowValues,
        failures: FailureValues,
        environment: EnvironmentValues
    ) {
        self.core = core
        self.seeds = seeds
        self.flow = flow
        self.failures = failures
        self.environment = environment
    }

    static let completeForTesting = Self(
        core: CoreValues(
            resetData: true,
            pseudolocalization: true,
            seedOnboarded: true,
            fixedNow: Date(timeIntervalSince1970: 1234.5),
            seedActiveFastStart: Date(timeIntervalSince1970: 1200)
        ),
        seeds: SeedValues(
            seedSlice3History: true,
            seedHistoryEventGrouping: true,
            seedHistoryMidnightSeam: true,
            seedHistoryMidnightSeamExtended: true,
            seedHistoryFastLabelLayout: true,
            seedUnknownProvenance: true,
            seedInferredFast: true,
            seedTodayMultiYear: true,
            seedCaloricBoundaryMultiYear: true,
            seedFavouritePopulated: true,
            seedFavouriteDuplicateName: true,
            seedFavouriteValidation: true,
            seedCaloricFavouriteActiveFast: true,
            seedFoodFavouritePopulated: true,
            seedFoodFavouriteDuplicateName: true,
            seedFoodFavouriteValidation: true,
            seedFoodFavouriteActiveFast: true,
            seedMultipleActiveFasts: true,
            seedLiveActivityRecovery: true
        ),
        flow: FlowValues(
            suppressAutomaticLiveActivityOffer: true,
            startsOnHistory: true,
            historyMotionRetryFixture: true
        ),
        failures: FailureValues(
            simulateFastSaveFailure: true,
            simulateFastHistoryFailure: true,
            simulateFoodSaveFailure: true,
            simulateDrinkSaveFailure: true,
            simulateFavouriteSaveFailure: true,
            simulateGoalSaveFailure: true,
            simulateLiveActivitySettingsSaveFailure: true,
            simulateInferredFastDetectionSaveFailure: true,
            simulateDeleteAllFailure: true,
            simulateBoundaryReconciliationFailure: true,
            simulatePersistenceBootstrapFailure: true,
            simulateFoodFavouriteMigrationFailure: true,
            simulateFoodFavouriteSaveFailure: true,
            simulateFoodFavouriteStale: true,
            simulateFoodFavStaleAfterConfirm: true,
            simulateLiveActivityUnsupported: true,
            simulateLiveActivityDisabled: false,
            simulateLiveActivityRequestFailure: true,
            simulateLiveActivityHideFailure: true
        ),
        environment: EnvironmentValues(
            liveActivityRelease: "1.2.3",
            liveActivityBuild: "B",
            appleLanguages: "(ar)",
            appleLocale: "ar_SA",
            timeZone: "Europe/London",
            preferredContentSizeCategory: nil
        )
    )

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
        seedHistoryFastLabelLayout: Bool = false,
        seedUnknownProvenance: Bool = false,
        seedInferredFast: Bool = false,
        seedTodayMultiYear: Bool = false,
        seedCaloricBoundaryMultiYear: Bool = false,
        seedFavouritePopulated: Bool = false,
        seedFavouriteDuplicateName: Bool = false,
        seedFavouriteValidation: Bool = false,
        seedCaloricFavouriteActiveFast: Bool = false,
        seedFoodFavouritePopulated: Bool = false,
        seedFoodFavouriteDuplicateName: Bool = false,
        seedFoodFavouriteValidation: Bool = false,
        seedFoodFavouriteActiveFast: Bool = false,
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
        simulateFoodFavouriteMigrationFailure: Bool = false,
        simulateFoodFavouriteSaveFailure: Bool = false,
        simulateFoodFavouriteStale: Bool = false,
        simulateFoodFavStaleAfterConfirm: Bool = false,
        simulateLiveActivityUnsupported: Bool = false,
        simulateLiveActivityDisabled: Bool = false,
        simulateLiveActivityRequestFailure: Bool = false,
        simulateLiveActivityHideFailure: Bool = false,
        appleLanguages: String? = nil,
        appleLocale: String? = nil,
        timeZone: String? = nil,
        preferredContentSizeCategory: String? = nil
    ) {
        core = CoreValues(
            resetData: resetData,
            pseudolocalization: pseudolocalization,
            seedOnboarded: seedOnboarded,
            fixedNow: fixedNow,
            seedActiveFastStart: seedActiveFastStart
        )
        seeds = SeedValues(
            seedSlice3History, seedHistoryEventGrouping,
            seedHistoryMidnightSeam, seedHistoryMidnightSeamExtended,
            seedUnknownProvenance, seedInferredFast,
            seedTodayMultiYear, seedCaloricBoundaryMultiYear,
            seedFavouritePopulated, seedFavouriteDuplicateName,
            seedFavouriteValidation, seedCaloricFavouriteActiveFast,
            seedFoodFavouritePopulated, seedFoodFavouriteDuplicateName,
            seedFoodFavouriteValidation, seedFoodFavouriteActiveFast,
            seedMultipleActiveFasts, seedLiveActivityRecovery,
            seedHistoryFastLabelLayout
        )
        flow = FlowValues(
            suppressAutomaticLiveActivityOffer: suppressAutomaticLiveActivityOffer,
            startsOnHistory: startsOnHistory,
            historyMotionRetryFixture: historyMotionRetryFixture
        )
        failures = FailureValues(
            simulateFastSaveFailure, simulateFastHistoryFailure,
            simulateFoodSaveFailure, simulateDrinkSaveFailure,
            simulateFavouriteSaveFailure, simulateGoalSaveFailure,
            simulateLiveActivitySettingsSaveFailure, simulateInferredFastDetectionSaveFailure,
            simulateDeleteAllFailure, simulateBoundaryReconciliationFailure,
            simulatePersistenceBootstrapFailure, simulateFoodFavouriteMigrationFailure,
            simulateFoodFavouriteSaveFailure, simulateFoodFavouriteStale,
            simulateFoodFavStaleAfterConfirm, simulateLiveActivityUnsupported,
            simulateLiveActivityDisabled, simulateLiveActivityRequestFailure,
            simulateLiveActivityHideFailure
        )
        environment = EnvironmentValues(
            liveActivityRelease: liveActivityRelease,
            liveActivityBuild: liveActivityBuild,
            appleLanguages: appleLanguages,
            appleLocale: appleLocale,
            timeZone: timeZone,
            preferredContentSizeCategory: preferredContentSizeCategory
        )
    }

    static let supportedFlags: Set<String> = [
        "--ui-testing", "--ui-testing-pseudolocalization", "--ui-testing-start-history", "--reset-data",
        "--seed-onboarded",
        "--fixed-now", "--seed-active-fast-start", "--seed-slice3-history",
        "--seed-history-event-grouping", "--seed-history-midnight-seam",
        "--seed-history-midnight-seam-extended", "--seed-history-fast-label-layout", "--seed-unknown-provenance",
        "--seed-inferred-fast", "--seed-today-multi-year", "--seed-caloric-boundary-multi-year",
        "--seed-favourite-populated", "--seed-favourite-duplicate-name", "--seed-favourite-validation",
        "--seed-caloric-favourite-active-fast", "--seed-multiple-active-fasts",
        "--seed-food-favourite-populated", "--seed-food-favourite-duplicate-name",
        "--seed-food-favourite-validation", "--seed-food-favourite-active-fast",
        "--seed-live-activity-recovery", "--live-activity-release", "--live-activity-build",
        "--suppress-automatic-live-activity-offer", "--simulate-fast-save-failure",
        "--simulate-fast-history-failure", "--ui-testing-history-retry-fixture",
        "--simulate-food-save-failure", "--simulate-drink-save-failure",
        "--simulate-favourite-save-failure", "--simulate-goal-save-failure",
        "--simulate-live-activity-settings-save-failure", "--simulate-inferred-fast-detection-save-failure",
        "--simulate-delete-all-failure", "--simulate-caloric-boundary-reconciliation-failure",
        "--simulate-persistence-bootstrap-failure", "--simulate-live-activity-unsupported",
        "--simulate-food-favourite-migration-failure", "--simulate-food-favourite-save-failure",
        "--simulate-food-favourite-stale", "--simulate-food-favourite-stale-after-confirmation",
        "--simulate-live-activity-disabled", "--simulate-live-activity-request-failure",
        "--simulate-live-activity-hide-failure",
    ]
}

extension UITestLaunchConfiguration {
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
        append("--seed-history-fast-label-layout", when: seedHistoryFastLabelLayout, to: &values)
        append("--seed-unknown-provenance", when: seedUnknownProvenance, to: &values)
        append("--seed-inferred-fast", when: seedInferredFast, to: &values)
        append("--seed-today-multi-year", when: seedTodayMultiYear, to: &values)
        append("--seed-caloric-boundary-multi-year", when: seedCaloricBoundaryMultiYear, to: &values)

        append("--seed-favourite-populated", when: seedFavouritePopulated, to: &values)
        append("--seed-favourite-duplicate-name", when: seedFavouriteDuplicateName, to: &values)
        append("--seed-favourite-validation", when: seedFavouriteValidation, to: &values)
        append("--seed-caloric-favourite-active-fast", when: seedCaloricFavouriteActiveFast, to: &values)
        append("--seed-food-favourite-populated", when: seedFoodFavouritePopulated, to: &values)
        append("--seed-food-favourite-duplicate-name", when: seedFoodFavouriteDuplicateName, to: &values)
        append("--seed-food-favourite-validation", when: seedFoodFavouriteValidation, to: &values)
        append("--seed-food-favourite-active-fast", when: seedFoodFavouriteActiveFast, to: &values)
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
        append("--simulate-food-favourite-migration-failure", when: simulateFoodFavouriteMigrationFailure, to: &values)
        append("--simulate-food-favourite-save-failure", when: simulateFoodFavouriteSaveFailure, to: &values)
        append("--simulate-food-favourite-stale", when: simulateFoodFavouriteStale, to: &values)
        append(
            "--simulate-food-favourite-stale-after-confirmation",
            when: simulateFoodFavStaleAfterConfirm,
            to: &values
        )

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
