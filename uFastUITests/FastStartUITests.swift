import XCTest

final class FastStartUITests: XCTestCase {
    @MainActor
    func testStartFastPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        completeOnboarding(in: app)

        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["Fast in progress"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Goal: 12 hours"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@",
            "Target:"
        )).firstMatch.exists)

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Fast in progress"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["fast.start"].exists)
    }

    @MainActor
    func testSaveFailureKeepsInactiveStateAndOffersRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data", "--simulate-fast-save-failure"]
        app.launch()
        completeOnboarding(in: app)

        app.buttons["fast.start"].tap()

        XCTAssertTrue(app.staticTexts["fast.start-error"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["fast.start"].label, "Try again")
        XCTAssertFalse(app.staticTexts["Fast in progress"].exists)
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }
}
