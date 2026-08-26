import XCTest

extension FoodFavouriteLifecycleUITests {
    @MainActor
    func testDeleteAllCancelPreservesFoodFavourite() {
        let app = launch(seedOnboarded: true, seedFoodFavouritePopulated: true)
        tapSettings(in: app)
        let deleteAll = app.buttons["settings.data.delete-all"]
        XCTAssertTrue(deleteAll.waitForExistence(timeout: 5), app.debugDescription)
        deleteAll.tap()
        let firstAlert = app.alerts.firstMatch
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5), app.debugDescription)
        firstAlert.buttons["Continue"].tap()
        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 5), app.debugDescription)
        finalAlert.buttons["Cancel"].tap()
        XCTAssertTrue(finalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    func testDeleteAllSuccessRemovesFoodFavouriteWithoutReseeding() {
        let app = launch(seedOnboarded: true, seedFoodFavouritePopulated: true)
        tapSettings(in: app)
        app.buttons["settings.data.delete-all"].tap()
        let firstAlert = app.alerts["Delete all uFast data?"]
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5), app.debugDescription)
        firstAlert.buttons["Continue"].tap()
        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 5), app.debugDescription)
        finalAlert.buttons["Delete everything"].tap()
        XCTAssertTrue(finalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["goal.promise"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["goal.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5), app.debugDescription)
        tapSettings(in: app)
        XCTAssertTrue(app.buttons["settings.food-favourite.add"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].exists)
    }

    @MainActor
    func testDeleteAllFailurePreservesFoodFavourite() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            simulateDeleteAllFailure: true
        )
        tapSettings(in: app)
        app.buttons["settings.data.delete-all"].tap()
        let firstAlert = app.alerts["Delete all uFast data?"]
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5), app.debugDescription)
        firstAlert.buttons["Continue"].tap()
        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 5), app.debugDescription)
        finalAlert.buttons["Delete everything"].tap()
        XCTAssertTrue(finalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["settings.data.delete-error"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    func testFoodFavouriteMigrationFailurePresentsUnavailableState() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(simulateFoodFavouriteMigrationFailure: true)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["persistence.unavailable.title"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.staticTexts["persistence.unavailable.message"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }
}
