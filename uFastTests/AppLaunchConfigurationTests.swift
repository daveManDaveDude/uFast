@testable import uFast
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable function_body_length trailing_comma
final class AppLaunchConfigurationTests: XCTestCase {
    func testParsesEverySupportedUITestOptionIntoTypedConfiguration() {
        let configuration = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--ui-testing-pseudolocalization", "--reset-data", "--seed-onboarded",
            "--seed-slice3-history", "--seed-history-event-grouping",
            "--seed-history-midnight-seam", "--seed-history-midnight-seam-extended",
            "--seed-multiple-active-fasts", "--seed-unknown-provenance",
            "--seed-favourite-populated", "--seed-favourite-duplicate-name",
            "--seed-favourite-validation", "--seed-caloric-favourite-active-fast",
            "--seed-food-favourite-populated", "--seed-food-favourite-duplicate-name",
            "--seed-food-favourite-validation", "--seed-food-favourite-active-fast",
            "--seed-inferred-fast", "--seed-today-multi-year", "--seed-caloric-boundary-multi-year",
            "--fixed-now", "1234.5",
            "--seed-active-fast-start", "1200",
            "--seed-live-activity-recovery", "--live-activity-release", "1.2.3",
            "--live-activity-build", "B",
            "--suppress-automatic-live-activity-offer", "--ui-testing-start-history",
            "--ui-testing-history-retry-fixture",
            "--simulate-persistence-bootstrap-failure",
            "--simulate-food-favourite-migration-failure", "--simulate-food-favourite-save-failure",
            "--simulate-food-favourite-stale", "--simulate-food-favourite-stale-after-confirmation",
            "--simulate-fast-save-failure", "--simulate-fast-history-failure",
            "--simulate-food-save-failure", "--simulate-drink-save-failure",
            "--simulate-favourite-save-failure",
            "--simulate-goal-save-failure",
            "--simulate-live-activity-settings-save-failure",
            "--simulate-inferred-fast-detection-save-failure",
            "--simulate-delete-all-failure", "--simulate-caloric-boundary-reconciliation-failure",
            "--simulate-live-activity-unsupported",
            "--simulate-live-activity-request-failure",
            "--simulate-live-activity-hide-failure",
        ])

        XCTAssertTrue(configuration.isUITesting)
        XCTAssertTrue(configuration.pseudolocalizationEnabled)
        XCTAssertEqual(configuration.fixedNow, Date(timeIntervalSince1970: 1234.5))
        XCTAssertEqual(configuration.fixtures, DevelopmentFixtureConfiguration(
            resetData: true,
            seedOnboarded: true,
            seedSlice3History: true,
            seedHistoryEventGrouping: true,
            seedHistoryMidnightSeam: true,
            seedHistoryMidnightSeamExtended: true,
            seedActiveFastStart: Date(timeIntervalSince1970: 1200),
            seedLiveActivityRecovery: true,
            seedMultipleActiveFasts: true,
            seedUnknownProvenance: true,
            seedFavouritePopulated: true,
            seedFavouriteDuplicateName: true,
            seedFavouriteValidation: true,
            seedCaloricFavouriteActiveFast: true,
            seedFoodFavouritePopulated: true,
            seedFoodFavouriteDuplicateName: true,
            seedFoodFavouriteValidation: true,
            seedFoodFavouriteActiveFast: true,
            seedInferredFast: true,
            seedTodayMultiYear: true,
            seedCaloricBoundaryMultiYear: true
        ))
        XCTAssertEqual(
            configuration.liveActivityBuildIdentity,
            LiveActivityBuildIdentity(releaseVersion: "1.2.3", buildNumber: "B")
        )
        XCTAssertEqual(configuration.commands, ApplicationCommandConfiguration(
            simulateFastSaveFailure: true,
            simulateFastHistoryFailure: true,
            simulateFoodSaveFailure: true,
            simulateDrinkSaveFailure: true,
            simulateFavouriteSaveFailure: true,
            simulateFoodFavouriteSaveFailure: true,
            simulateFoodFavouriteStale: true,
            simulateFoodFavStaleAfterConfirm: true,
            simulateGoalSaveFailure: true,
            simulateLiveActivitySettingsSaveFailure: true,
            simulateInferredFastDetectionSaveFailure: true,
            simulateDeleteAllFailure: true,
            simulateBoundaryReconciliationFailure: true
        ))
        XCTAssertEqual(configuration.liveActivityAdapter, .deterministic(
            availability: .unsupported,
            failRequests: true,
            failEnds: true
        ))
        XCTAssertTrue(configuration.simulatePersistenceBootstrapFailure)
        XCTAssertTrue(configuration.simulateFoodFavouriteMigrationFailure)
        XCTAssertTrue(configuration.suppressAutomaticLiveActivityOffer)
        XCTAssertTrue(configuration.startsOnHistory)
        XCTAssertTrue(configuration.historyMotionRetryFixture)
    }

    func testDisabledLiveActivityOptionIsPreserved() {
        let configuration = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--simulate-live-activity-disabled",
        ])

        XCTAssertEqual(configuration.liveActivityAdapter, .deterministic(
            availability: .disabled,
            failRequests: false,
            failEnds: false
        ))
    }

    func testParsesStartOnHistoryOnlyForTheUITestingLaunch() {
        let uiTesting = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--ui-testing-start-history",
        ])
        let production = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing-start-history",
        ])

        XCTAssertTrue(uiTesting.startsOnHistory)
        XCTAssertFalse(production.startsOnHistory)
    }

    func testProductionIgnoresFixtureAndFailureArgumentsWithoutUITestingGate() {
        let configuration = AppLaunchConfiguration(arguments: [
            "uFast", "--reset-data", "--seed-onboarded", "--fixed-now", "1234",
            "--simulate-persistence-bootstrap-failure", "--simulate-fast-save-failure",
            "--simulate-live-activity-disabled", "--suppress-automatic-live-activity-offer",
        ])

        XCTAssertFalse(configuration.isUITesting)
        XCTAssertFalse(configuration.pseudolocalizationEnabled)
        XCTAssertNil(configuration.fixedNow)
        XCTAssertEqual(configuration.fixtures, .disabled)
        XCTAssertEqual(configuration.commands, .init())
        XCTAssertEqual(configuration.liveActivityAdapter, .activityKit)
        XCTAssertFalse(configuration.simulatePersistenceBootstrapFailure)
        XCTAssertFalse(configuration.suppressAutomaticLiveActivityOffer)
        XCTAssertFalse(configuration.startsOnHistory)
        XCTAssertFalse(configuration.historyMotionRetryFixture)
    }

    func testInvalidOrMissingDateValuesAreIgnored() {
        let invalid = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--fixed-now", "invalid",
            "--seed-active-fast-start",
        ])

        XCTAssertNil(invalid.fixedNow)
        XCTAssertNil(invalid.fixtures.seedActiveFastStart)
    }

    func testDeterministicAdapterDefaultsToEnabledForUITesting() {
        let configuration = AppLaunchConfiguration(arguments: ["uFast", "--ui-testing"])

        XCTAssertEqual(configuration.liveActivityAdapter, .deterministic(
            availability: .enabled,
            failRequests: false,
            failEnds: false
        ))
        XCTAssertEqual(
            configuration.liveActivityBuildIdentity,
            .deterministic()
        )
    }

    func testPseudolocalizationRequiresTheUITestingGate() {
        let uiTesting = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--ui-testing-pseudolocalization",
        ])
        let production = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing-pseudolocalization",
        ])

        XCTAssertTrue(uiTesting.pseudolocalizationEnabled)
        XCTAssertFalse(production.pseudolocalizationEnabled)
    }
}
