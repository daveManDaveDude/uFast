import XCTest

extension HistoryUITests {
    @MainActor
    func testCompletedFastAppearsAndEditorUsesStoredBoundaries() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        selectHistoryTab(in: app)

        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row.label.contains("Recorded fast"))
        XCTAssertTrue(row.label.contains("duration 1 hour"))
        XCTAssertTrue(row.label.contains("goal 12 hours"))

        XCTAssertTrue(row.isHittable, row.debugDescription)
        row.tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.edit.start-date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.edit.start-time"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.edit.end-date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.edit.end-time"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testEditAndDeleteCancellationLeaveCompletedRecordAvailable() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        selectHistoryTab(in: app)
        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.isHittable, row.debugDescription)
        row.tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 5), app.debugDescription)

        let deleteButton = app.buttons["history.edit.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), app.debugDescription)
        deleteButton.tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            alert.staticTexts["This removes the record from this device."].waitForExistence(timeout: 5),
            alert.debugDescription
        )
        let cancelDelete = alert.buttons["Cancel"]
        XCTAssertTrue(cancelDelete.waitForExistence(timeout: 5), alert.debugDescription)
        cancelDelete.tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 5), app.debugDescription)
        let cancelEdit = app.buttons["history.edit.cancel"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5), app.debugDescription)
        cancelEdit.tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testConfirmedDeletePersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        selectHistoryTab(in: app)
        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.isHittable, row.debugDescription)
        row.tap()
        let deleteButton = app.buttons["history.edit.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), app.debugDescription)
        deleteButton.tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmDelete = alert.buttons["Delete fast"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), alert.debugDescription)
        confirmDelete.tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(7200))
        app.launch()
        selectHistoryTab(in: app)

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 5), app.debugDescription)
        let deletedRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
        XCTAssertTrue(deletedRow.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testDeleteFailureKeepsEditorAndRecordAvailable() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        selectHistoryTab(in: app)
        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.isHittable, row.debugDescription)
        row.tap()
        let deleteButton = app.buttons["history.edit.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), app.debugDescription)
        deleteButton.tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmDelete = alert.buttons["Delete fast"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5), alert.debugDescription)
        confirmDelete.tap()

        let error = app.staticTexts["history.edit.delete-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(
            error.label,
            "This fast couldn’t be deleted. Please try again."
        )
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 5), app.debugDescription)

        let cancelEdit = app.buttons["history.edit.cancel"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5), app.debugDescription)
        cancelEdit.tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testEditFailureKeepsEditorSelectionsAndStoredRowAvailable() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        selectHistoryTab(in: app)
        let originalRowLabel = recordedFastRow(in: app).label
        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.isHittable, row.debugDescription)
        row.tap()
        XCTAssertTrue(app.buttons["history.edit.save"].waitForExistence(timeout: 5), app.debugDescription)
        let selectedStart = app.datePickers["history.edit.start-time"].value as? String
        let selectedEnd = app.datePickers["history.edit.end-time"].value as? String

        let saveButton = app.buttons["history.edit.save"]
        XCTAssertTrue(saveButton.isHittable, saveButton.debugDescription)
        saveButton.tap()

        let error = app.staticTexts["history.edit.save-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
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
        let cancelEdit = app.buttons["history.edit.cancel"]
        XCTAssertTrue(cancelEdit.waitForExistence(timeout: 5), app.debugDescription)
        cancelEdit.tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(recordedFastRow(in: app).label, originalRowLabel)
    }
}
