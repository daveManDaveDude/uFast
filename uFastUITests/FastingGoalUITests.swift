import XCTest

final class FastingGoalUITests: XCTestCase {
    @MainActor
    func testFirstUseDefaultsToTwelveAndPersistsSelectedGoalAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()

        let picker = app.buttons["goal.picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        XCTAssertEqual(picker.value as? String, "12 hours")
        XCTAssertTrue(app.buttons["goal.continue"].isEnabled)

        selectGoal(16, in: app)
        app.buttons["goal.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        let persistedPicker = app.buttons["goal.picker"]
        XCTAssertTrue(persistedPicker.waitForExistence(timeout: 2))
        XCTAssertEqual(persistedPicker.value as? String, "16 hours")
    }

    @MainActor
    func testGoalCanBeChangedToEightHoursInSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        app.buttons["goal.continue"].tap()
        app.tabBars.buttons["Settings"].tap()

        selectGoal(8, in: app)

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Your fasting goal is 8 hours."].waitForExistence(timeout: 2))
    }

    @MainActor
    func testGoalControlRemainsUsableAtLargestAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        selectGoal(8, in: app)

        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func selectGoal(_ hours: Int, in app: XCUIApplication) {
        let picker = app.buttons["goal.picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.tap()

        let option = app.buttons["\(hours) hours"]
        XCTAssertTrue(option.waitForExistence(timeout: 2))
        option.tap()
        XCTAssertEqual(picker.value as? String, "\(hours) hours")
    }
}
