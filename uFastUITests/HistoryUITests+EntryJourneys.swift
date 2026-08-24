import XCTest

extension HistoryUITests {
    @MainActor
    func testDirectHistoryEntryConfirmsTimeAndSavesFoodAndFavouriteDrink() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)
        selectYesterday(in: app)

        let addAtSelectedTime = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(addAtSelectedTime, app: app), app.debugDescription)
        addAtSelectedTime.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["history.add.summary"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.add.date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.datePickers["history.add.time"].waitForExistence(timeout: 5), app.debugDescription)
        let addFood = app.buttons["history.add.food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5), app.debugDescription)
        addFood.tap()
        let foodDescription = app.textFields["food.description"]
        XCTAssertTrue(foodDescription.waitForExistence(timeout: 5), app.debugDescription)
        foodDescription.tap()
        foodDescription.typeText("Historical lunch")
        let foodSave = app.buttons["food.save"]
        XCTAssertTrue(foodSave.waitForExistence(timeout: 5), app.debugDescription)
        foodSave.tap()
        XCTAssertTrue(app.staticTexts["Historical lunch"].waitForExistence(timeout: 5), app.debugDescription)

        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        addAtSelectedTime.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 5), app.debugDescription)
        let addDrink = app.buttons["history.add.drink"]
        XCTAssertTrue(addDrink.waitForExistence(timeout: 5), app.debugDescription)
        addDrink.tap()
        let waterFavourite = app.buttons["drink.favourite.water"]
        XCTAssertTrue(waterFavourite.waitForExistence(timeout: 5), app.debugDescription)
        waterFavourite.tap()
        let drinkSave = app.buttons["drink.editor.save"]
        XCTAssertTrue(drinkSave.waitForExistence(timeout: 5), app.debugDescription)
        drinkSave.tap()
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testDirectHistoryEntryCancellationWritesNothingAndFailedSaveRetainsDraft() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            now: start,
            resetData: true,
            seedOnboarded: true,
            simulateFoodSaveFailure: true
        )
        app.launch()
        selectHistoryTab(in: app)
        selectYesterday(in: app)

        let addAtSelectedTime = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        addAtSelectedTime.tap()
        let cancelAdd = app.buttons["history.add.cancel"]
        XCTAssertTrue(cancelAdd.waitForExistence(timeout: 5), app.debugDescription)
        cancelAdd.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Unpersisted meal"].waitForNonExistence(timeout: 5), app.debugDescription)

        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        addAtSelectedTime.tap()
        let addFood = app.buttons["history.add.food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5), app.debugDescription)
        addFood.tap()
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Unpersisted meal")
        let foodSave = app.buttons["food.save"]
        XCTAssertTrue(foodSave.waitForExistence(timeout: 5), app.debugDescription)
        foodSave.tap()

        XCTAssertTrue(app.staticTexts["food.save-error"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(description.value as? String, "Unpersisted meal")
        let foodCancel = app.buttons["food.cancel"]
        XCTAssertTrue(foodCancel.waitForExistence(timeout: 5), app.debugDescription)
        foodCancel.tap()
        XCTAssertTrue(app.staticTexts["Unpersisted meal"].waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testDirectHistoryEntrySavesCustomNonCaloricAndCaloricDrinks() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)
        selectYesterday(in: app)

        let addAtSelectedTime = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        addAtSelectedTime.tap()
        let addDrink = app.buttons["history.add.drink"]
        XCTAssertTrue(addDrink.waitForExistence(timeout: 5), app.debugDescription)
        addDrink.tap()
        let customDrink = app.buttons["drink.custom"]
        XCTAssertTrue(customDrink.waitForExistence(timeout: 5), app.debugDescription)
        customDrink.tap()
        XCTAssertTrue(app.navigationBars["Add another drink"].waitForExistence(timeout: 5), app.debugDescription)
        let drinkName = app.textFields["drink.name"]
        XCTAssertTrue(drinkName.waitForExistence(timeout: 5), app.debugDescription)
        drinkName.tap()
        drinkName.typeText("Sparkling water")
        let sparklingVolume = app.textFields["drink.volume"]
        XCTAssertTrue(sparklingVolume.waitForExistence(timeout: 5), app.debugDescription)
        sparklingVolume.tap()
        sparklingVolume.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        sparklingVolume.typeText("330")
        let drinkSave = app.buttons["drink.editor.save"]
        XCTAssertTrue(drinkSave.waitForExistence(timeout: 5), app.debugDescription)
        drinkSave.tap()
        XCTAssertTrue(app.staticTexts["Sparkling water"].waitForExistence(timeout: 5), app.debugDescription)

        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 5), app.debugDescription)
        addAtSelectedTime.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(addDrink.waitForExistence(timeout: 5), app.debugDescription)
        addDrink.tap()
        XCTAssertTrue(customDrink.waitForExistence(timeout: 5), app.debugDescription)
        customDrink.tap()
        XCTAssertTrue(app.navigationBars["Add another drink"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(drinkName.waitForExistence(timeout: 5), app.debugDescription)
        drinkName.tap()
        drinkName.typeText("Orange juice")
        let orangeVolume = app.textFields["drink.volume"]
        XCTAssertTrue(orangeVolume.waitForExistence(timeout: 5), app.debugDescription)
        orangeVolume.tap()
        orangeVolume.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        orangeVolume.typeText("200")
        let caloricClassification = app.buttons["drink.classification.caloric"]
        XCTAssertTrue(caloricClassification.waitForExistence(timeout: 5), app.debugDescription)
        caloricClassification.tap()
        XCTAssertTrue(drinkSave.waitForExistence(timeout: 5), app.debugDescription)
        drinkSave.tap()
        XCTAssertTrue(app.staticTexts["Sparkling water"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Orange juice"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Mixed fasting classifications")
        ).firstMatch.exists)
    }

    @MainActor
    func testHistoricalFoodEditorKeepsStoredLocalDateAndTime() {
        let now = Date(timeIntervalSince1970: 2_300_000_000)
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            now: now,
            resetData: true,
            seedSlice3History: true,
            appleLocale: "en_GB"
        )
        app.launch()
        selectHistoryTab(in: app)
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settledExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )

        let breakfastCandidates = app.otherElements["history.event-info-panel"].buttons.matching(
            NSPredicate(
                format: "label CONTAINS %@ AND enabled == true",
                "Breakfast"
            )
        )
        XCTAssertGreaterThan(breakfastCandidates.count, 0)
        let breakfast = breakfastCandidates.element(boundBy: breakfastCandidates.count - 1)
        XCTAssertTrue(breakfast.waitForExistence(timeout: 5), app.debugDescription)
        tapFullyVisible(breakfast, in: app.scrollViews["history.content"], app: app)

        XCTAssertTrue(
            app.navigationBars["Edit food"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue((app.buttons["Date Picker"].value as? String)?.contains("17 Nov 2042") == true)
        XCTAssertEqual(app.buttons["Time Picker"].value as? String, "08:53")
    }
}
