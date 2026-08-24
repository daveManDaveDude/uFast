import XCTest

final class TodayMultiYearUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testScaledMultiYearTodayShowsOnlyTodayAndPersistsMutations() {
        let app = launch(resetData: true)
        let today = app.scrollViews["today.content"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Today breakfast"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Older breakfast"].exists)
        XCTAssertFalse(app.staticTexts["Future breakfast"].exists)
        XCTAssertFalse(app.staticTexts["Historical food 0"].exists)
        XCTAssertFalse(app.staticTexts["Future food 0"].exists)

        let foodAdd = app.buttons["food.add"]
        XCTAssertTrue(foodAdd.waitForExistence(timeout: 5), app.debugDescription)
        if !foodAdd.isHittable {
            app.swipeUp()
        }
        foodAdd.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 5), app.debugDescription)
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Fresh lunch")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Fresh lunch"].waitForExistence(timeout: 5), app.debugDescription)

        let drinkAdd = app.buttons["drink.add"]
        XCTAssertTrue(drinkAdd.waitForExistence(timeout: 5), app.debugDescription)
        if !drinkAdd.isHittable {
            app.swipeUp()
        }
        drinkAdd.tap()
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForExistence(timeout: 5), app.debugDescription)
        let water = app.buttons["drink.favourite.water"]
        XCTAssertTrue(water.waitForExistence(timeout: 5), app.debugDescription)
        water.tap()
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(resetData: false)
        app.launch()
        XCTAssertTrue(app.staticTexts["Fresh lunch"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Today breakfast"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Older breakfast"].exists)
        XCTAssertFalse(app.staticTexts["Future breakfast"].exists)
    }

    @MainActor
    private func launch(resetData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(resetData: resetData)
        app.launch()
        return app
    }

    private func launchArguments(resetData: Bool) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: true,
            fixedNow: now,
            seedTodayMultiYear: true
        ).arguments
    }
}
