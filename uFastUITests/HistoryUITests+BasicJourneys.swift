import XCTest

extension HistoryUITests {
    @MainActor
    func testEmptyHistoryShowsCompletedOnlyEmptyStateWithoutStartAction() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)

        selectHistoryTab(in: app)

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.staticTexts["Completed fasts will appear here."].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.buttons["fast.start"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.choose-date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.catch-up"].waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testHistoryUsesAccessibleTemporalNavigatorAndRibbonAlternative() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(waitForHittable(startButton, app: app), app.debugDescription)
        startButton.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        dismissOptionalLiveActivityOffer(in: app)
        let endButton = app.buttons["fast.end"]
        XCTAssertTrue(waitForHittable(endButton, app: app), app.debugDescription)
        endButton.tap()
        let endAlert = app.alerts["End this fast?"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5), app.debugDescription)
        let confirmEnd = endAlert.buttons["End fast"]
        XCTAssertTrue(confirmEnd.waitForExistence(timeout: 5), endAlert.debugDescription)
        confirmEnd.tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 5), app.debugDescription)
        selectHistoryTab(in: app)

        XCTAssertTrue(app.buttons["history.choose-date"].waitForExistence(timeout: 5), app.debugDescription)
        let structuredFastRow = recordedFastRow(in: app)
        XCTAssertTrue(structuredFastRow.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(structuredFastRow.label.contains("start"))
        XCTAssertTrue(structuredFastRow.label.contains("end"))
    }

    @MainActor
    func testHistoryPresentsAnActiveFastThroughTheCurrentTime() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(waitForHittable(startButton, app: app), app.debugDescription)
        startButton.tap()

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        selectHistoryTab(in: app)

        let visualActiveFast = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.active-fast.")
        ).firstMatch
        XCTAssertTrue(visualActiveFast.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(visualActiveFast.isEnabled, visualActiveFast.debugDescription)
        XCTAssertGreaterThan(visualActiveFast.frame.width, 0, visualActiveFast.debugDescription)
        XCTAssertFalse(visualActiveFast.label.contains("end"))

        visualActiveFast.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
    }
}
