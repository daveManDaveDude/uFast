import XCTest

// swiftlint:disable trailing_comma

final class FastEndUITests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testEndNowRequiresConfirmationAndCancellationKeepsFastActive() {
        let app = launchActiveFast()
        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(60)
        )
        app.launch()

        app.buttons["fast.end"].tap()

        let alert = app.alerts["End this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["This will record the end time as now."].exists)
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        alert.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["fast.end"].exists)
        XCTAssertFalse(app.staticTexts["fast.recorded"].exists)
    }

    @MainActor
    func testEndNowReturnsToInactiveStateAndSessionMessageDoesNotRelaunch() {
        let app = launchActiveFast()
        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(3600)
        )
        app.launch()

        app.buttons["fast.end"].tap()
        let alert = app.alerts["End this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["End fast"].tap()

        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["fast.recorded"].exists)
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)

        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(7200)
        )
        app.launch()

        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["fast.recorded"].exists)
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testPastEndEditorInitialisesToNowAndCanCompleteFast() {
        let app = launchActiveFast()
        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(1800)
        )
        app.launch()

        app.buttons["fast.end-past"].tap()

        XCTAssertTrue(app.navigationBars["End time"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["fast.end-date"].exists)
        XCTAssertTrue(app.datePickers["fast.end-time"].exists)
        XCTAssertTrue(app.buttons["fast.end-confirm"].isEnabled)
        let selectedTime = app.datePickers["fast.end-time"].value as? String
        app.buttons["fast.end-confirm"].tap()

        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["fast.recorded"].exists)
        XCTAssertNotNil(selectedTime)
    }

    @MainActor
    func testEndNowFailureKeepsOriginalFastActiveAndShowsRetryMessage() {
        let app = launchActiveFast()
        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(3600),
            simulateSaveFailure: true
        )
        app.launch()

        app.buttons["fast.end"].tap()
        let alert = app.alerts["End this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["End fast"].tap()

        XCTAssertTrue(app.staticTexts["fast.end-error"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["fast.end-error"].label,
            "Your fast couldn’t be ended. Please try again."
        )
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        XCTAssertFalse(app.staticTexts["fast.recorded"].exists)
    }

    @MainActor
    func testPastEndFailureKeepsEditorAndSelectionAvailable() {
        let app = launchActiveFast()
        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: start.addingTimeInterval(3600),
            simulateSaveFailure: true
        )
        app.launch()
        app.buttons["fast.end-past"].tap()
        XCTAssertTrue(app.buttons["fast.end-confirm"].waitForExistence(timeout: 2))
        let selectedDate = app.datePickers["fast.end-date"].value as? String
        let selectedTime = app.datePickers["fast.end-time"].value as? String

        app.buttons["fast.end-confirm"].tap()

        XCTAssertTrue(app.staticTexts["fast.end-save-error"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["fast.end-save-error"].label,
            "Your end time couldn’t be saved. Please try again."
        )
        XCTAssertTrue(app.navigationBars["End time"].exists)
        XCTAssertEqual(app.datePickers["fast.end-date"].value as? String, selectedDate)
        XCTAssertEqual(app.datePickers["fast.end-time"].value as? String, selectedTime)
    }

    @MainActor
    func testClockAtStartDisablesEndNowAndExplainsPastEndValidation() {
        let app = launchActiveFast()

        XCTAssertFalse(app.buttons["fast.end"].isEnabled)
        XCTAssertEqual(
            app.staticTexts["fast.end-unavailable"].label,
            "This fast can’t end until after its recorded start time."
        )

        app.buttons["fast.end-past"].tap()

        XCTAssertTrue(app.staticTexts["fast.end-validation"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["fast.end-validation"].label,
            "End time must be after the start time."
        )
        XCTAssertFalse(app.buttons["fast.end-confirm"].isEnabled)
        app.buttons["fast.end-cancel"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    private func launchActiveFast() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = fixedLaunchArguments(
            now: start,
            resetData: true
        )
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    private func fixedLaunchArguments(
        now: Date,
        resetData: Bool = false,
        simulateSaveFailure: Bool = false
    ) -> [String] {
        var arguments = [
            "--ui-testing",
            "--fixed-now",
            String(now.timeIntervalSince1970),
            "--suppress-automatic-live-activity-offer",
        ]

        if resetData {
            arguments.append("--reset-data")
        }
        if simulateSaveFailure {
            arguments.append("--simulate-fast-save-failure")
        }

        return arguments
    }
}
