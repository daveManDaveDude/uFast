import XCTest

final class HistoryUITests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testEmptyHistoryShowsCompletedOnlyEmptyStateWithoutStartAction() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)

        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Completed fasts will appear here."].exists)
        XCTAssertFalse(app.buttons["fast.start"].exists)
    }

    @MainActor
    func testCompletedFastAppearsAndEditorUsesStoredBoundaries() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()

        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.label.contains("Recorded fast"))
        XCTAssertTrue(row.label.contains("duration 1 hour"))
        XCTAssertTrue(row.label.contains("goal 12 hours"))

        row.tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["history.edit.start-date"].exists)
        XCTAssertTrue(app.datePickers["history.edit.start-time"].exists)
        XCTAssertTrue(app.datePickers["history.edit.end-date"].exists)
        XCTAssertTrue(app.datePickers["history.edit.end-time"].exists)
    }

    @MainActor
    func testEditAndDeleteCancellationLeaveCompletedRecordAvailable() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 2))

        app.buttons["history.edit.delete"].tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["This removes the record from this device."].exists)
        alert.buttons["Cancel"].tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].exists)
        app.buttons["history.edit.cancel"].tap()
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 2))
    }

    @MainActor
    func testConfirmedDeletePersistsAcrossRelaunch() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.delete"].waitForExistence(timeout: 2))
        app.buttons["history.edit.delete"].tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["Delete fast"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(7200))
        app.launch()
        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))
        XCTAssertFalse(recordedFastRow(in: app).exists)
    }

    @MainActor
    func testDeleteFailureKeepsEditorAndRecordAvailable() {
        let app = launchCompletedFast()
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.delete"].waitForExistence(timeout: 2))
        app.buttons["history.edit.delete"].tap()
        app.alerts["Delete this fast?"].buttons["Delete fast"].tap()

        let error = app.staticTexts["history.edit.delete-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(
            error.label,
            "This fast couldn’t be deleted. Please try again."
        )
        XCTAssertTrue(app.navigationBars["Edit fast"].exists)

        app.buttons["history.edit.cancel"].tap()
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 2))
    }

    @MainActor
    func testEditFailureKeepsEditorSelectionsAndStoredRowAvailable() {
        let app = launchCompletedFast()
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        app.tabBars.buttons["History"].tap()
        let originalRowLabel = recordedFastRow(in: app).label
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.save"].waitForExistence(timeout: 2))
        let selectedStart = app.datePickers["history.edit.start-time"].value as? String
        let selectedEnd = app.datePickers["history.edit.end-time"].value as? String

        app.buttons["history.edit.save"].tap()

        let error = app.staticTexts["history.edit.save-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(
            error.label,
            "Your changes couldn’t be saved. Please try again."
        )
        XCTAssertEqual(
            app.datePickers["history.edit.start-time"].value as? String,
            selectedStart
        )
        XCTAssertEqual(
            app.datePickers["history.edit.end-time"].value as? String,
            selectedEnd
        )
        app.buttons["history.edit.cancel"].tap()
        XCTAssertEqual(recordedFastRow(in: app).label, originalRowLabel)
    }

    @MainActor
    private func launchCompletedFast() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        app.buttons["fast.end"].tap()
        let alert = app.alerts["End this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["End fast"].tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    private func recordedFastRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
    }

    private func launchArguments(
        now: Date,
        resetData: Bool = false,
        simulateHistoryFailure: Bool = false
    ) -> [String] {
        var arguments = ["--ui-testing", "--fixed-now", String(now.timeIntervalSince1970)]
        if resetData {
            arguments.append("--reset-data")
        }
        if simulateHistoryFailure {
            arguments.append("--simulate-fast-history-failure")
        }
        return arguments
    }
}
