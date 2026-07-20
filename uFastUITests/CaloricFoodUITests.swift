import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

final class CaloricFoodUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testNonCaloricFoodDuringActiveFastLeavesFastActive() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)
        enterDescription("Black coffee", in: app)
        let caloricSwitch = app.switches["food.caloric"]
        caloricSwitch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)
        ).press(
            forDuration: 0.1,
            thenDragTo: caloricSwitch.coordinate(
                withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)
            )
        )
        XCTAssertEqual(caloricSwitch.value as? String, "0")
        app.buttons["food.save"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.alerts["This entry is during your recorded fast."].exists)
        XCTAssertFalse(app.navigationBars["Log food"].exists)
    }

    @MainActor
    func testCaloricFoodCancelChangesNeitherRecordAndConfirmationHasOnlyRequiredChoices() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()

        let alert = app.alerts["This entry is during your recorded fast."]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.buttons["Save and end fast"].exists)
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        XCTAssertFalse(alert.buttons["Save entry only"].exists)
        XCTAssertEqual(alert.buttons.count, 2)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Log food"].exists)
        app.buttons["food.cancel"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Lunch"].exists)
    }

    @MainActor
    func testSaveAndEndFastAtomicallyRecordsFoodAndEndsAtEventTime() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()
        let alert = app.alerts["This entry is during your recorded fast."]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["Save and end fast"].tap()

        XCTAssertTrue(app.staticTexts["fast.inactive-state"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Lunch"].exists)
        XCTAssertTrue(app.staticTexts["Caloric"].exists)
    }

    @MainActor
    func testCaloricFoodAtExactActiveStartCannotSave() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments(activeFastStart: now)
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        openFoodEditor(in: app)
        enterDescription("Exact boundary", in: app)

        XCTAssertFalse(app.buttons["food.save"].isEnabled)
        XCTAssertEqual(
            app.staticTexts["food.fast-start.validation"].label,
            "Choose a time after the fast started, or change the fast start time."
        )
    }

    @MainActor
    private func launchWithActiveFast() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = baseArguments(
            activeFastStart: now.addingTimeInterval(-3600)
        )
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func openFoodEditor(in app: XCUIApplication) {
        let button = app.buttons["food.add"]
        if !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        button.tap()
    }

    @MainActor
    private func enterDescription(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["food.description"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(text)
    }

    private func baseArguments(activeFastStart: Date) -> [String] {
        [
            "--ui-testing",
            "--reset-data",
            "--seed-onboarded",
            "--fixed-now",
            String(now.timeIntervalSince1970),
            "--seed-active-fast-start",
            String(activeFastStart.timeIntervalSince1970),
        ]
    }
}
