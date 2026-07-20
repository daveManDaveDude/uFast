import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length

final class HydrationCustomAndTimelineUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testCustomDrinkValidationCreateEditAndDeleteUpdatesTimelineAndTotal() {
        let app = launch()
        openCustomEditor(in: app)
        XCTAssertFalse(app.buttons["drink.editor.save"].isEnabled)
        XCTAssertTrue(app.staticTexts["drink.volume.validation"].exists)
        app.textFields["drink.name"].tap(); app.textFields["drink.name"].typeText("Kombucha")
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].typeText("250")
        app.buttons["drink.editor.save"].tap()

        XCTAssertTrue(app.staticTexts["Kombucha"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["drink.total"].label, "250 ml")
        XCTAssertTrue(app.staticTexts["Today timeline"].exists)

        app.staticTexts["Kombucha"].tap()
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 2))
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].clearAndType("400")
        app.buttons["drink.editor.save"].tap()
        XCTAssertEqual(app.staticTexts["drink.total"].label, "400 ml")

        app.staticTexts["Kombucha"].tap()
        if !app.buttons["drink.delete"].exists {
            app.swipeUp()
        }
        app.buttons["drink.delete"].tap()
        app.alerts["Delete this drink?"].buttons["Delete"].tap()
        XCTAssertEqual(app.staticTexts["drink.total"].label, "0 ml")
        XCTAssertTrue(app.staticTexts["timeline.empty"].exists)
    }

    @MainActor
    func testCaloricCustomDrinkRequiresMandatoryConfirmationAndCancelMutatesNothing() {
        let app = launch(activeFastStart: now.addingTimeInterval(-3600))
        openCustomEditor(in: app)
        app.textFields["drink.name"].tap(); app.textFields["drink.name"].typeText("Juice")
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].typeText("200")
        app.buttons["Caloric"].tap()
        app.buttons["drink.editor.save"].tap()
        let alert = app.alerts["This entry is during your recorded fast."]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertEqual(alert.buttons.count, 2)
        XCTAssertTrue(alert.buttons["Save and end fast"].exists)
        XCTAssertFalse(alert.buttons["Save entry only"].exists)
        alert.buttons["Cancel"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        XCTAssertFalse(app.staticTexts["Juice"].exists)
    }

    @MainActor
    private func openCustomEditor(in app: XCUIApplication) {
        let add = app.buttons["drink.add"]
        if !add.isHittable {
            app.swipeUp()
        }
        add.tap()
        app.buttons["drink.custom"].tap()
        XCTAssertTrue(app.navigationBars["Add another drink"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func launch(activeFastStart: Date? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-data", "--seed-onboarded", "--fixed-now", String(now.timeIntervalSince1970)]
        if let activeFastStart {
            app.launchArguments += ["--seed-active-fast-start", String(activeFastStart.timeIntervalSince1970)]
        }
        app.launch()
        XCTAssertTrue(app.buttons["drink.add"].waitForExistence(timeout: 2))
        return app
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap(); press(forDuration: 0.7)
        if XCUIApplication().menuItems["Select All"].waitForExistence(timeout: 1) {
            XCUIApplication().menuItems["Select All"].tap()
        }
        typeText(text)
    }
}
