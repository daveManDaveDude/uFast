import XCTest

extension FoodFavouriteLifecycleUITests {
    @MainActor
    func testHistoryFavouritePrefillsSelectedTimeAndCancelDoesNotCreateEvent() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            startsOnHistory: true
        )
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        let add = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        XCTAssertTrue(app.staticTexts["history.add.summary"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.add.date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.add.time"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["history.add.food"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(description.value as? String, "Overnight oats")
        XCTAssertTrue(app.datePickers["food.date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["food.time"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(app.buttons["history.add-at-selected-time"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Overnight oats"].exists)
    }

    @MainActor
    func testHistoryFavouriteExplicitSaveRetainsEventValuesAfterTemplateEdit() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            startsOnHistory: true
        )
        app.buttons["history.previous-day"].tap()
        let add = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        app.buttons["history.add.food"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()
        let foodDescription = app.textFields["food.description"]
        XCTAssertTrue(foodDescription.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(foodDescription.value as? String, "Overnight oats")
        XCTAssertEqual(app.textFields["food.nutrition.energy.input"].value as? String, "420")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)

        tapSettings(in: app)
        let settingsRow = app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5), app.debugDescription)
        settingsRow.tap()
        let templateDescription = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(templateDescription.waitForExistence(timeout: 5), app.debugDescription)
        replaceText("Edited oats", in: templateDescription, app: app)
        replaceText("999", in: app.textFields["settings.food-favourite.nutrition.energy"], app: app)
        app.buttons["settings.food-favourite.save"].tap()
        XCTAssertTrue(app.staticTexts["Edited oats"].waitForExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.buttons["history.previous-day"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["history.previous-day"].tap()
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Edited oats"].exists)
        app.staticTexts["Overnight oats"].tap()
        XCTAssertTrue(app.textFields["food.description"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.textFields["food.description"].value as? String, "Overnight oats")
        XCTAssertEqual(app.textFields["food.nutrition.energy.input"].value as? String, "420")
        app.buttons["food.cancel"].tap()
    }
}
