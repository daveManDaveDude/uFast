import XCTest

// swiftlint:disable trailing_comma

final class NavigationShellUITests: XCTestCase {
    @MainActor
    func testMultipleActiveFastsShowIntegrityErrorWithoutChoosingOne() {
        let app = XCUIApplication()
        app.launchArguments = UITestLaunchConfiguration(
            resetData: true,
            seedOnboarded: true,
            fixedNow: Date(timeIntervalSince1970: 1_800_000_000),
            seedMultipleActiveFasts: true
        ).arguments
        app.launch()

        let error = app.staticTexts["today.data-integrity-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(error.label.contains("Nothing was changed"))
        XCTAssertFalse(app.buttons["fast.start"].exists)
        XCTAssertFalse(app.buttons["fast.end"].exists)
    }

    @MainActor
    func testUnknownFastProvenanceIsExplicitlyUnavailable() {
        let app = XCUIApplication()
        app.launchArguments = UITestLaunchConfiguration(
            resetData: true,
            seedOnboarded: true,
            fixedNow: Date(timeIntervalSince1970: 1_800_000_000),
            seedUnknownProvenance: true
        ).arguments
        app.launch()
        app.tabBars.buttons["History"].tap()

        let unavailable = app.staticTexts["Saved fast · Details unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Recorded fast"].exists)
        XCTAssertFalse(app.staticTexts["Confirmed"].exists)
    }

    @MainActor
    func testPersistenceBootstrapFailureShowsNonDestructiveUnavailableState() {
        let app = XCUIApplication()
        app.launchArguments = UITestLaunchConfiguration(
            simulatePersistenceBootstrapFailure: true
        ).arguments
        app.launch()

        let title = app.staticTexts["persistence.unavailable.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(title.label, "Your local data couldn’t be opened")
        XCTAssertEqual(
            app.staticTexts["persistence.unavailable.message"].label,
            "Nothing was deleted or replaced. Close uFast and try again."
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
    }

    @MainActor
    func testThreePrimaryDestinationsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = UITestLaunchConfiguration(resetData: true).arguments
        app.launch()
        completeOnboardingIfNeeded(in: app)

        assertDestination("Today", in: app)
        assertDestination("History", in: app)
        assertDestination("Settings", in: app)
    }

    @MainActor
    private func completeOnboardingIfNeeded(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
        }
    }

    @MainActor
    private func assertDestination(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons[name].tap()
        let identifier = "screen-title.\(name.lowercased())"
        let title = app.staticTexts[identifier]

        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(title.frame.height, 35)
    }
}
