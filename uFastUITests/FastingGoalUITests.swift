import XCTest

final class FastingGoalUITests: XCTestCase {
    @MainActor
    func testFirstUseDefaultsToTwelveAndPersistsSelectedGoalAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()

        XCTAssertTrue(app.staticTexts["goal.promise"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["goal.promise"].label,
            "A calm, private companion for recording your fasts."
        )
        XCTAssertTrue(app.buttons["goal.option.12"].isSelected)
        XCTAssertTrue(app.buttons["goal.continue"].isEnabled)

        selectGoal(16, in: app)
        app.buttons["goal.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.buttons["goal.option.16"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["goal.option.16"].isSelected)
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
    func testEveryWholeHourChoiceIsAvailableAndSelectedWithoutColourAlone() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()

        for hours in 8 ... 24 {
            XCTAssertTrue(
                app.buttons["goal.option.\(hours)"].exists,
                "Missing \(hours)-hour goal"
            )
        }

        selectGoal(24, in: app)
        XCTAssertTrue(app.buttons["goal.option.24"].isSelected)
        XCTAssertFalse(app.buttons["goal.option.12"].isSelected)
    }

    @MainActor
    func testOnboardingSaveFailureRetainsSelectionAndShowsRetryMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data", "--simulate-goal-save-failure"]
        app.launch()

        selectGoal(16, in: app)
        app.buttons["goal.continue"].tap()

        XCTAssertTrue(app.staticTexts["goal.save-error"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["goal.option.16"].isSelected)
        XCTAssertTrue(app.buttons["goal.continue"].isHittable)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
    }

    @MainActor
    func testSettingsSaveFailureRestoresPreviousGoal() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        app.buttons["goal.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = ["--ui-testing", "--simulate-goal-save-failure"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        let sixteenHours = app.buttons["goal.option.16"]
        XCTAssertTrue(sixteenHours.waitForExistence(timeout: 2))
        if !sixteenHours.isHittable {
            app.swipeUp()
        }
        sixteenHours.tap()

        XCTAssertTrue(
            app.staticTexts["settings.goal.save-error"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(app.buttons["goal.option.12"].isSelected)
        XCTAssertFalse(app.buttons["goal.option.16"].isSelected)
    }

    @MainActor
    func testDeleteAllDataRequiresTwoConfirmationsAndReturnsToOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        app.buttons["goal.continue"].tap()
        app.tabBars.buttons["Settings"].tap()

        let deleteAll = app.buttons["settings.data.delete-all"]
        for _ in 0 ..< 4 where !deleteAll.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(deleteAll.isHittable)
        deleteAll.tap()

        let firstAlert = app.alerts["Delete all uFast data?"]
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 2))
        firstAlert.buttons["Continue"].tap()

        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 2))
        finalAlert.buttons["Cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        deleteAll.tap()
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 2))
        firstAlert.buttons["Continue"].tap()
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 2))
        finalAlert.buttons["Delete everything"].tap()

        XCTAssertTrue(app.staticTexts["goal.promise"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsExplainsLocalStorageAndOpensPrivacySafety() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data"]
        app.launch()
        app.buttons["goal.continue"].tap()
        app.tabBars.buttons["Settings"].tap()

        let privacyLink = app.buttons["settings.privacy-safety"]
        if !privacyLink.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Data on this iPhone"].waitForExistence(timeout: 2))
        XCTAssertTrue(privacyLink.isHittable)
        privacyLink.tap()

        XCTAssertTrue(app.staticTexts["screen-title.privacy-safety"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["What uFast stores"].exists)
        XCTAssertTrue(app.staticTexts["Safety"].exists)
        XCTAssertTrue(app.buttons["privacy.public-policy"].exists)
    }

    @MainActor
    func testDeleteAllDataFailureKeepsSettingsAvailableAndShowsRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data", "--simulate-delete-all-failure"]
        app.launch()
        app.buttons["goal.continue"].tap()
        app.tabBars.buttons["Settings"].tap()

        let deleteAll = app.buttons["settings.data.delete-all"]
        for _ in 0 ..< 4 where !deleteAll.isHittable {
            app.swipeUp()
        }
        deleteAll.tap()
        app.alerts["Delete all uFast data?"].buttons["Continue"].tap()
        app.alerts["Permanently delete everything?"].buttons["Delete everything"].tap()

        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.staticTexts["settings.data.delete-error"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectGoal(_ hours: Int, in app: XCUIApplication) {
        let option = app.buttons["goal.option.\(hours)"]
        XCTAssertTrue(option.waitForExistence(timeout: 2))
        if !option.isHittable {
            app.swipeUp()
        }
        option.tap()
        XCTAssertTrue(option.isSelected)
    }
}
