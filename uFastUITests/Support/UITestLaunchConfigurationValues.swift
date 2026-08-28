import Foundation

struct CoreValues: Equatable {
    let resetData: Bool
    let pseudolocalization: Bool
    let seedOnboarded: Bool
    let fixedNow: Date?
    let seedActiveFastStart: Date?
}

struct SeedValues: Equatable {
    let seedSlice3History: Bool
    let seedHistoryEventGrouping: Bool
    let seedHistoryMidnightSeam: Bool
    let seedHistoryMidnightSeamExtended: Bool
    let seedHistoryFastLabelLayout: Bool
    let seedUnknownProvenance: Bool
    let seedInferredFast: Bool
    let seedInferredFastEligibility: Bool
    let seedSuppressedInferredFast: Bool
    let seedTodayMultiYear: Bool
    let seedCaloricBoundaryMultiYear: Bool
    let seedFavouritePopulated: Bool
    let seedFavouriteDuplicateName: Bool
    let seedFavouriteValidation: Bool
    let seedCaloricFavouriteActiveFast: Bool
    let seedFoodFavouritePopulated: Bool
    let seedFoodFavouriteDuplicateName: Bool
    let seedFoodFavouriteValidation: Bool
    let seedFoodFavouriteActiveFast: Bool
    let seedMultipleActiveFasts: Bool
    let seedLiveActivityRecovery: Bool
}

struct FlowValues: Equatable {
    let suppressAutomaticLiveActivityOffer: Bool
    let startsOnHistory: Bool
    let historyMotionRetryFixture: Bool
}

struct FailureValues: Equatable {
    let simulateFastSaveFailure: Bool
    let simulateFastHistoryFailure: Bool
    let simulateFoodSaveFailure: Bool
    let simulateDrinkSaveFailure: Bool
    let simulateFavouriteSaveFailure: Bool
    let simulateGoalSaveFailure: Bool
    let simulateLiveActivitySettingsSaveFailure: Bool
    let simulateInferredFastDetectionSaveFailure: Bool
    let simulateSuppressionSaveFailure: Bool
    let simulateSuppressionReenableStale: Bool
    let simulateDeleteAllFailure: Bool
    let simulateBoundaryReconciliationFailure: Bool
    let simulatePersistenceBootstrapFailure: Bool
    let simulateFoodFavouriteMigrationFailure: Bool
    let simulateFoodFavouriteSaveFailure: Bool
    let simulateFoodFavouriteStale: Bool
    let simulateFoodFavStaleAfterConfirm: Bool
    let simulateLiveActivityUnsupported: Bool
    let simulateLiveActivityDisabled: Bool
    let simulateLiveActivityRequestFailure: Bool
    let simulateLiveActivityHideFailure: Bool
}

struct EnvironmentValues: Equatable {
    let liveActivityRelease: String?
    let liveActivityBuild: String?
    let appleLanguages: String?
    let appleLocale: String?
    let timeZone: String?
    let preferredContentSizeCategory: String?
}

extension SeedValues {
    init(
        _ seedSlice3History: Bool,
        _ seedHistoryEventGrouping: Bool,
        _ seedHistoryMidnightSeam: Bool,
        _ seedHistoryMidnightSeamExtended: Bool,
        _ seedUnknownProvenance: Bool,
        _ seedInferredFast: Bool,
        _ seedInferredFastEligibility: Bool,
        _ seedSuppressedInferredFast: Bool,
        _ seedTodayMultiYear: Bool,
        _ seedCaloricBoundaryMultiYear: Bool,
        _ seedFavouritePopulated: Bool,
        _ seedFavouriteDuplicateName: Bool,
        _ seedFavouriteValidation: Bool,
        _ seedCaloricFavouriteActiveFast: Bool,
        _ seedFoodFavouritePopulated: Bool,
        _ seedFoodFavouriteDuplicateName: Bool,
        _ seedFoodFavouriteValidation: Bool,
        _ seedFoodFavouriteActiveFast: Bool,
        _ seedMultipleActiveFasts: Bool,
        _ seedLiveActivityRecovery: Bool,
        _ seedHistoryFastLabelLayout: Bool = false
    ) {
        self.init(
            seedSlice3History: seedSlice3History,
            seedHistoryEventGrouping: seedHistoryEventGrouping,
            seedHistoryMidnightSeam: seedHistoryMidnightSeam,
            seedHistoryMidnightSeamExtended: seedHistoryMidnightSeamExtended,
            seedHistoryFastLabelLayout: seedHistoryFastLabelLayout,
            seedUnknownProvenance: seedUnknownProvenance,
            seedInferredFast: seedInferredFast,
            seedInferredFastEligibility: seedInferredFastEligibility,
            seedSuppressedInferredFast: seedSuppressedInferredFast,
            seedTodayMultiYear: seedTodayMultiYear,
            seedCaloricBoundaryMultiYear: seedCaloricBoundaryMultiYear,
            seedFavouritePopulated: seedFavouritePopulated,
            seedFavouriteDuplicateName: seedFavouriteDuplicateName,
            seedFavouriteValidation: seedFavouriteValidation,
            seedCaloricFavouriteActiveFast: seedCaloricFavouriteActiveFast,
            seedFoodFavouritePopulated: seedFoodFavouritePopulated,
            seedFoodFavouriteDuplicateName: seedFoodFavouriteDuplicateName,
            seedFoodFavouriteValidation: seedFoodFavouriteValidation,
            seedFoodFavouriteActiveFast: seedFoodFavouriteActiveFast,
            seedMultipleActiveFasts: seedMultipleActiveFasts,
            seedLiveActivityRecovery: seedLiveActivityRecovery
        )
    }
}

extension FailureValues {
    init(
        _ simulateFastSaveFailure: Bool,
        _ simulateFastHistoryFailure: Bool,
        _ simulateFoodSaveFailure: Bool,
        _ simulateDrinkSaveFailure: Bool,
        _ simulateFavouriteSaveFailure: Bool,
        _ simulateGoalSaveFailure: Bool,
        _ simulateLiveActivitySettingsSaveFailure: Bool,
        _ simulateInferredFastDetectionSaveFailure: Bool,
        _ simulateSuppressionSaveFailure: Bool,
        _ simulateSuppressionReenableStale: Bool,
        _ simulateDeleteAllFailure: Bool,
        _ simulateBoundaryReconciliationFailure: Bool,
        _ simulatePersistenceBootstrapFailure: Bool,
        _ simulateFoodFavouriteMigrationFailure: Bool,
        _ simulateFoodFavouriteSaveFailure: Bool,
        _ simulateFoodFavouriteStale: Bool,
        _ simulateFoodFavStaleAfterConfirm: Bool,
        _ simulateLiveActivityUnsupported: Bool,
        _ simulateLiveActivityDisabled: Bool,
        _ simulateLiveActivityRequestFailure: Bool,
        _ simulateLiveActivityHideFailure: Bool
    ) {
        self.init(
            simulateFastSaveFailure: simulateFastSaveFailure,
            simulateFastHistoryFailure: simulateFastHistoryFailure,
            simulateFoodSaveFailure: simulateFoodSaveFailure,
            simulateDrinkSaveFailure: simulateDrinkSaveFailure,
            simulateFavouriteSaveFailure: simulateFavouriteSaveFailure,
            simulateGoalSaveFailure: simulateGoalSaveFailure,
            simulateLiveActivitySettingsSaveFailure: simulateLiveActivitySettingsSaveFailure,
            simulateInferredFastDetectionSaveFailure: simulateInferredFastDetectionSaveFailure,
            simulateSuppressionSaveFailure: simulateSuppressionSaveFailure,
            simulateSuppressionReenableStale: simulateSuppressionReenableStale,
            simulateDeleteAllFailure: simulateDeleteAllFailure,
            simulateBoundaryReconciliationFailure: simulateBoundaryReconciliationFailure,
            simulatePersistenceBootstrapFailure: simulatePersistenceBootstrapFailure,
            simulateFoodFavouriteMigrationFailure: simulateFoodFavouriteMigrationFailure,
            simulateFoodFavouriteSaveFailure: simulateFoodFavouriteSaveFailure,
            simulateFoodFavouriteStale: simulateFoodFavouriteStale,
            simulateFoodFavStaleAfterConfirm: simulateFoodFavStaleAfterConfirm,
            simulateLiveActivityUnsupported: simulateLiveActivityUnsupported,
            simulateLiveActivityDisabled: simulateLiveActivityDisabled,
            simulateLiveActivityRequestFailure: simulateLiveActivityRequestFailure,
            simulateLiveActivityHideFailure: simulateLiveActivityHideFailure
        )
    }
}

extension UITestLaunchConfiguration {
    var resetData: Bool {
        core.resetData
    }

    var pseudolocalization: Bool {
        core.pseudolocalization
    }

    var seedOnboarded: Bool {
        core.seedOnboarded
    }

    var fixedNow: Date? {
        core.fixedNow
    }

    var seedActiveFastStart: Date? {
        core.seedActiveFastStart
    }

    var seedSlice3History: Bool {
        seeds.seedSlice3History
    }

    var seedHistoryEventGrouping: Bool {
        seeds.seedHistoryEventGrouping
    }

    var seedHistoryMidnightSeam: Bool {
        seeds.seedHistoryMidnightSeam
    }

    var seedHistoryMidnightSeamExtended: Bool {
        seeds.seedHistoryMidnightSeamExtended
    }

    var seedHistoryFastLabelLayout: Bool {
        seeds.seedHistoryFastLabelLayout
    }

    var seedUnknownProvenance: Bool {
        seeds.seedUnknownProvenance
    }

    var seedInferredFast: Bool {
        seeds.seedInferredFast
    }

    var seedInferredFastEligibility: Bool {
        seeds.seedInferredFastEligibility
    }

    var seedSuppressedInferredFast: Bool {
        seeds.seedSuppressedInferredFast
    }

    var seedTodayMultiYear: Bool {
        seeds.seedTodayMultiYear
    }

    var seedCaloricBoundaryMultiYear: Bool {
        seeds.seedCaloricBoundaryMultiYear
    }

    var seedFavouritePopulated: Bool {
        seeds.seedFavouritePopulated
    }

    var seedFavouriteDuplicateName: Bool {
        seeds.seedFavouriteDuplicateName
    }

    var seedFavouriteValidation: Bool {
        seeds.seedFavouriteValidation
    }

    var seedCaloricFavouriteActiveFast: Bool {
        seeds.seedCaloricFavouriteActiveFast
    }

    var seedFoodFavouritePopulated: Bool {
        seeds.seedFoodFavouritePopulated
    }

    var seedFoodFavouriteDuplicateName: Bool {
        seeds.seedFoodFavouriteDuplicateName
    }

    var seedFoodFavouriteValidation: Bool {
        seeds.seedFoodFavouriteValidation
    }

    var seedFoodFavouriteActiveFast: Bool {
        seeds.seedFoodFavouriteActiveFast
    }

    var seedMultipleActiveFasts: Bool {
        seeds.seedMultipleActiveFasts
    }

    var seedLiveActivityRecovery: Bool {
        seeds.seedLiveActivityRecovery
    }

    var liveActivityRelease: String? {
        environment.liveActivityRelease
    }

    var liveActivityBuild: String? {
        environment.liveActivityBuild
    }

    var suppressAutomaticLiveActivityOffer: Bool {
        flow.suppressAutomaticLiveActivityOffer
    }

    var startsOnHistory: Bool {
        flow.startsOnHistory
    }

    var historyMotionRetryFixture: Bool {
        flow.historyMotionRetryFixture
    }

    var simulateFastSaveFailure: Bool {
        failures.simulateFastSaveFailure
    }

    var simulateFastHistoryFailure: Bool {
        failures.simulateFastHistoryFailure
    }

    var simulateFoodSaveFailure: Bool {
        failures.simulateFoodSaveFailure
    }

    var simulateDrinkSaveFailure: Bool {
        failures.simulateDrinkSaveFailure
    }

    var simulateFavouriteSaveFailure: Bool {
        failures.simulateFavouriteSaveFailure
    }

    var simulateGoalSaveFailure: Bool {
        failures.simulateGoalSaveFailure
    }

    var simulateLiveActivitySettingsSaveFailure: Bool {
        failures.simulateLiveActivitySettingsSaveFailure
    }

    var simulateInferredFastDetectionSaveFailure: Bool {
        failures.simulateInferredFastDetectionSaveFailure
    }

    var simulateSuppressionSaveFailure: Bool {
        failures.simulateSuppressionSaveFailure
    }

    var simulateSuppressionReenableStale: Bool {
        failures.simulateSuppressionReenableStale
    }

    var simulateDeleteAllFailure: Bool {
        failures.simulateDeleteAllFailure
    }

    var simulateBoundaryReconciliationFailure: Bool {
        failures.simulateBoundaryReconciliationFailure
    }

    var simulatePersistenceBootstrapFailure: Bool {
        failures.simulatePersistenceBootstrapFailure
    }

    var simulateFoodFavouriteMigrationFailure: Bool {
        failures.simulateFoodFavouriteMigrationFailure
    }

    var simulateFoodFavouriteSaveFailure: Bool {
        failures.simulateFoodFavouriteSaveFailure
    }

    var simulateFoodFavouriteStale: Bool {
        failures.simulateFoodFavouriteStale
    }

    var simulateFoodFavStaleAfterConfirm: Bool {
        failures.simulateFoodFavStaleAfterConfirm
    }

    var simulateLiveActivityUnsupported: Bool {
        failures.simulateLiveActivityUnsupported
    }

    var simulateLiveActivityDisabled: Bool {
        failures.simulateLiveActivityDisabled
    }

    var simulateLiveActivityRequestFailure: Bool {
        failures.simulateLiveActivityRequestFailure
    }

    var simulateLiveActivityHideFailure: Bool {
        failures.simulateLiveActivityHideFailure
    }

    var appleLanguages: String? {
        environment.appleLanguages
    }

    var appleLocale: String? {
        environment.appleLocale
    }

    var timeZone: String? {
        environment.timeZone
    }

    var preferredContentSizeCategory: String? {
        environment.preferredContentSizeCategory
    }
}
