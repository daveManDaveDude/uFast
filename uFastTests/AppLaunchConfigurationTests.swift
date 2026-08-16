@testable import uFast
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma
final class AppLaunchConfigurationTests: XCTestCase {
    func testParsesEverySupportedUITestOptionIntoTypedConfiguration() {
        let configuration = AppLaunchConfiguration(arguments: [
            "uFast", "--ui-testing", "--reset-data", "--seed-onboarded",
            "--seed-slice3-history", "--seed-history-event-grouping",
            "--seed-multiple-active-fasts",
            "--seed-unknown-provenance", "--fixed-now", "1234.5",
            "--seed-active-fast-start", "1200",
            "--seed-live-activity-recovery", "--live-activity-release", "1.2.3",
            "--live-activity-build", "B",
            "--simulate-persistence-bootstrap-failure",
            "--simulate-fast-save-failure", "--simulate-fast-history-failure",
            "--simulate-food-save-failure", "--simulate-drink-save-failure",
            "--simulate-goal-save-failure",
            "--simulate-live-activity-settings-save-failure",
            "--simulate-delete-all-failure", "--simulate-live-activity-unsupported",
            "--simulate-live-activity-request-failure",
            "--simulate-live-activity-hide-failure",
            "--suppress-automatic-live-activity-offer",
        ])

        XCTAssertTrue(configuration.isUITesting)
        XCTAssertEqual(configuration.fixedNow, Date(timeIntervalSince1970: 1234.5))
        XCTAssertEqual(configuration.fixtures, DevelopmentFixtureConfiguration(
            resetData: true,
            seedOnboarded: true,
            seedSlice3History: true,
            seedHistoryEventGrouping: true,
            seedActiveFastStart: Date(timeIntervalSince1970: 1200),
            seedLiveActivityRecovery: true,
            seedMultipleActiveFasts: true,
            seedUnknownProvenance: true
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
            simulateGoalSaveFailure: true,
            simulateLiveActivitySettingsSaveFailure: true,
            simulateDeleteAllFailure: true
        ))
        XCTAssertEqual(configuration.liveActivityAdapter, .deterministic(
            availability: .unsupported,
            failRequests: true,
            failEnds: true
        ))
        XCTAssertTrue(configuration.simulatePersistenceBootstrapFailure)
        XCTAssertTrue(configuration.suppressAutomaticLiveActivityOffer)
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
        XCTAssertNil(configuration.fixedNow)
        XCTAssertEqual(configuration.fixtures, .disabled)
        XCTAssertEqual(configuration.commands, .init())
        XCTAssertEqual(configuration.liveActivityAdapter, .activityKit)
        XCTAssertFalse(configuration.simulatePersistenceBootstrapFailure)
        XCTAssertFalse(configuration.suppressAutomaticLiveActivityOffer)
        XCTAssertFalse(configuration.startsOnHistory)
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
}
