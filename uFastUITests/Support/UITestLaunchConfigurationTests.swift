import XCTest

// swiftlint:disable trailing_comma

final class UITestLaunchConfigurationTests: XCTestCase {
    func testEmitsCompleteGrammarInCanonicalOrder() {
        XCTAssertEqual(completeConfiguration().arguments, [
            "--ui-testing", "--ui-testing-pseudolocalization", "--reset-data", "--seed-onboarded",
            "--fixed-now", "1234.5",
            "--seed-active-fast-start", "1200.0", "--seed-slice3-history", "--seed-history-event-grouping",
            "--seed-history-midnight-seam", "--seed-history-midnight-seam-extended",
            "--seed-unknown-provenance", "--seed-inferred-fast", "--seed-today-multi-year",
            "--seed-caloric-boundary-multi-year", "--seed-favourite-populated", "--seed-favourite-duplicate-name",
            "--seed-favourite-validation", "--seed-caloric-favourite-active-fast", "--seed-multiple-active-fasts",
            "--seed-live-activity-recovery", "--live-activity-release", "1.2.3", "--live-activity-build", "B",
            "--suppress-automatic-live-activity-offer", "--ui-testing-start-history",
            "--ui-testing-history-retry-fixture", "--simulate-fast-save-failure",
            "--simulate-fast-history-failure", "--simulate-food-save-failure",
            "--simulate-drink-save-failure", "--simulate-favourite-save-failure", "--simulate-goal-save-failure",
            "--simulate-live-activity-settings-save-failure", "--simulate-inferred-fast-detection-save-failure",
            "--simulate-delete-all-failure", "--simulate-caloric-boundary-reconciliation-failure",
            "--simulate-persistence-bootstrap-failure", "--simulate-live-activity-unsupported",
            "--simulate-live-activity-request-failure", "--simulate-live-activity-hide-failure",
            "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA", "-NSTimeZone", "Europe/London",
        ])
    }

    private func completeConfiguration() -> UITestLaunchConfiguration {
        UITestLaunchConfiguration(
            resetData: true,
            pseudolocalization: true,
            seedOnboarded: true,
            fixedNow: Date(timeIntervalSince1970: 1234.5),
            seedActiveFastStart: Date(timeIntervalSince1970: 1200),
            seedSlice3History: true,
            seedHistoryEventGrouping: true,
            seedHistoryMidnightSeam: true,
            seedHistoryMidnightSeamExtended: true,
            seedUnknownProvenance: true,
            seedInferredFast: true,
            seedTodayMultiYear: true,
            seedCaloricBoundaryMultiYear: true,
            seedFavouritePopulated: true,
            seedFavouriteDuplicateName: true,
            seedFavouriteValidation: true,
            seedCaloricFavouriteActiveFast: true,
            seedMultipleActiveFasts: true,
            seedLiveActivityRecovery: true,
            liveActivityRelease: "1.2.3",
            liveActivityBuild: "B",
            suppressAutomaticLiveActivityOffer: true,
            startsOnHistory: true,
            historyMotionRetryFixture: true,
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
            simulateLiveActivityUnsupported: true,
            simulateLiveActivityRequestFailure: true,
            simulateLiveActivityHideFailure: true,
            appleLanguages: "(ar)",
            appleLocale: "ar_SA",
            timeZone: "Europe/London"
        )
    }

    func testValueFlagsRequireFiniteValuesAndIdentityPairs() {
        let nonFiniteClock = UITestLaunchConfiguration(fixedNow: Date(timeIntervalSince1970: .infinity))
        XCTAssertEqual(nonFiniteClock.validationError, .fixedNowMustBeFinite)
        XCTAssertFalse(nonFiniteClock.isValid)

        let nonFiniteActiveFast = UITestLaunchConfiguration(
            seedActiveFastStart: Date(timeIntervalSince1970: -.infinity)
        )
        XCTAssertEqual(nonFiniteActiveFast.validationError, .seedActiveFastStartMustBeFinite)

        let incompleteIdentity = UITestLaunchConfiguration(liveActivityBuild: "B")
        XCTAssertEqual(incompleteIdentity.validationError, .liveActivityIdentityMustBeComplete)
        XCTAssertEqual(
            UITestLaunchConfiguration(liveActivityRelease: "1.0.0", liveActivityBuild: "test").arguments,
            ["--ui-testing", "--live-activity-release", "1.0.0", "--live-activity-build", "test"]
        )
    }

    func testInvalidCombinationsAreRejectedBeforeEmission() {
        let conflictingAvailability = UITestLaunchConfiguration(
            simulateLiveActivityUnsupported: true,
            simulateLiveActivityDisabled: true
        )
        XCTAssertEqual(conflictingAvailability.validationError, .liveActivityAvailabilityIsConflicting)

        let emptySystemValues = UITestLaunchConfiguration(appleLocale: "", timeZone: "")
        XCTAssertEqual(emptySystemValues.validationError, .appleLocaleMustNotBeEmpty)

        let emptyLanguages = UITestLaunchConfiguration(appleLanguages: "")
        XCTAssertEqual(emptyLanguages.validationError, .appleLanguagesMustNotBeEmpty)

        let disabled = UITestLaunchConfiguration(simulateLiveActivityDisabled: true)
        XCTAssertEqual(disabled.arguments, ["--ui-testing", "--simulate-live-activity-disabled"])
    }

    func testSingletonFlagsAreEmittedAtMostOnce() {
        let configuration = UITestLaunchConfiguration(
            resetData: true,
            seedOnboarded: true,
            simulateFastSaveFailure: true
        )
        let arguments = configuration.arguments

        for flag in UITestLaunchConfiguration.supportedFlags {
            XCTAssertLessThanOrEqual(arguments.filter { $0 == flag }.count, 1, flag)
        }
    }

    func testPseudolocalizationIsEmittedOnlyAfterTheUITestingGate() {
        XCTAssertEqual(
            UITestLaunchConfiguration(pseudolocalization: true).arguments,
            ["--ui-testing", "--ui-testing-pseudolocalization"]
        )
    }

    func testAccessibilityContentSizeCategoryUsesTheTypedSystemArgument() {
        XCTAssertEqual(
            UITestLaunchConfiguration(
                preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
            ).arguments,
            [
                "--ui-testing",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        )
    }
}
