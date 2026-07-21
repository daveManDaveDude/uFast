import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

final class HydrationFavouriteUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce() {
        let app = launch()
        app.buttons["drink.add"].tap()
        let water = app.buttons["drink.favourite.water"]
        XCTAssertTrue(water.waitForExistence(timeout: 2))
        XCTAssertEqual(water.value as? String, "500 millilitres")
        water.doubleTap()

        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["drink.total"].label, "500 ml")
        XCTAssertFalse(app.navigationBars["Add a drink"].exists)
    }

    @MainActor
    func testTeaAndCoffeeUseTheirVisibleDefaults() {
        for (identifier, amount) in [("tea", "300 ml"), ("coffee", "300 ml")] {
            let app = launch()
            app.buttons["drink.add"].tap()
            let favourite = app.buttons["drink.favourite.\(identifier)"]
            XCTAssertTrue(favourite.waitForExistence(timeout: 2))
            favourite.tap()
            XCTAssertEqual(app.staticTexts["drink.total"].label, amount)
        }
    }

    @MainActor
    func testFavouriteDoesNotChangeActiveFast() {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            "--seed-active-fast-start",
            String(now.addingTimeInterval(-3600).timeIntervalSince1970),
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        app.buttons["drink.add"].tap()
        app.buttons["drink.favourite.water"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()

        let waterAmount = app.textFields["settings.drink.water"]
        XCTAssertTrue(waterAmount.waitForExistence(timeout: 2))
        waterAmount.tap()
        waterAmount.press(forDuration: 0.7)
        XCTAssertTrue(app.menuItems["Select All"].waitForExistence(timeout: 1))
        app.menuItems["Select All"].tap()
        waterAmount.typeText("650")

        let done = app.buttons["settings.keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 2))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(done.frame.maxY, keyboard.frame.minY)
        XCTAssertGreaterThan(done.frame.minY, keyboard.frame.minY - 80)
        done.tap()
        XCTAssertFalse(keyboard.exists)
        XCTAssertFalse(app.buttons["settings.drink.save"].exists)

        app.tabBars.buttons["Today"].tap()
        app.buttons["drink.add"].tap()
        let water = app.buttons["drink.favourite.water"]
        XCTAssertTrue(water.waitForExistence(timeout: 2))
        XCTAssertEqual(water.value as? String, "650 millilitres")
        water.tap()
        XCTAssertEqual(app.staticTexts["drink.total"].label, "650 ml")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["drink.add"].waitForExistence(timeout: 2))
        return app
    }

    private var arguments: [String] {
        [
            "--ui-testing", "--reset-data", "--seed-onboarded",
            "--fixed-now", String(now.timeIntervalSince1970),
        ]
    }
}
