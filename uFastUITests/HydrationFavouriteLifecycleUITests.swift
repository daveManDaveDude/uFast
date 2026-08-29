import XCTest

final class HydrationFavouriteLifecycleUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testRemovingLastFavouriteKeepsSettingsAndPickerUsable() {
        let app = launch()
        tapTab("Settings", in: app)
        let water = app.buttons["settings.favourite.\(waterFavouriteID)"]
        tapSettingsControl(water, in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        tapAlertButton("Remove", in: confirmation, app: app)
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["settings.favourite.add"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.favourite.\(waterFavouriteID)"].exists)

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        XCTAssertTrue(app.buttons["drink.custom"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        let favouriteRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "drink.favourite.")
        )
        XCTAssertEqual(favouriteRows.count, 0, app.debugDescription)
        XCTAssertFalse(app.staticTexts["drink.save-error"].exists)
    }

    @MainActor
    func testCustomFavouriteEditAndRemoveCancelThenConfirm() {
        let app = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label == 'Sparkling water'")).firstMatch
        tapSettingsControl(row, in: app)
        XCTAssertTrue(
            app.navigationBars["Edit favourite"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )
        replaceText("Soda water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("355", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(
            app.buttons["Soda water"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )

        tapSettingsControl(
            app.buttons.matching(NSPredicate(format: "label == 'Soda water'")).firstMatch,
            in: app
        )
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let removalAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistenceIfNeeded(timeout: 2), removalAlert.debugDescription)
        tapAlertButton("Cancel", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.navigationBars["Edit favourite"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let confirmationAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(confirmationAlert.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: confirmationAlert, app: app)
        XCTAssertTrue(confirmationAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.staticTexts["Drink favourites"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == 'Soda water'")).firstMatch
                .waitForNonExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder() {
        let app = launch()
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["Sparkling water"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)

        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        replaceText("Juice", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("250", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["Juice"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        let sparkling = app.buttons["Sparkling water"]
        let juice = app.buttons["Juice"]
        XCTAssertTrue(sparkling.waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        XCTAssertTrue(juice.waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        XCTAssertLessThan(sparkling.frame.minY, juice.frame.minY)

        app.terminate()
        let relaunched = launch(resetData: false)
        tapTab("Settings", in: relaunched)
        let relaunchedSparkling = relaunched.buttons["Sparkling water"]
        let relaunchedJuice = relaunched.buttons["Juice"]
        XCTAssertTrue(relaunchedSparkling.waitForExistenceIfNeeded(timeout: 3), relaunched.debugDescription)
        XCTAssertTrue(relaunchedJuice.waitForExistenceIfNeeded(timeout: 3), relaunched.debugDescription)
        XCTAssertLessThan(relaunchedSparkling.frame.minY, relaunchedJuice.frame.minY)

        tapTab("Today", in: relaunched)
        tapDrinkAdd(in: relaunched)
        let todaySparkling = relaunched.buttons["Sparkling water"]
        let todayJuice = relaunched.buttons["Juice"]
        XCTAssertTrue(todaySparkling.waitForExistenceIfNeeded(timeout: 3), relaunched.debugDescription)
        XCTAssertTrue(todayJuice.waitForExistenceIfNeeded(timeout: 3), relaunched.debugDescription)
        XCTAssertLessThan(todaySparkling.frame.minY, todayJuice.frame.minY)

        // Relaunching closes the transient picker without making the persistence journey
        // depend on the sheet toolbar being exposed under parallel simulator load.
        relaunched.terminate()
        let historyApp = launch(resetData: false)
        tapTab("History", in: historyApp)
        let historyCarousel = historyApp.scrollViews["history.day-carousel"]
        XCTAssertTrue(historyCarousel.waitForExistenceIfNeeded(timeout: 5), historyApp.debugDescription)
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: historyCarousel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settled], timeout: 5),
            .completed,
            historyApp.debugDescription
        )
        tapWhenReady(
            historyApp.buttons["history.add-at-selected-time"],
            in: historyApp.scrollViews["history.content"],
            app: historyApp
        )
        XCTAssertTrue(
            historyApp.navigationBars["Add to history"].waitForExistenceIfNeeded(timeout: 5),
            historyApp.debugDescription
        )
        tapWhenReady(historyApp.buttons["history.add.drink"], app: historyApp)
        XCTAssertTrue(
            historyApp.navigationBars["Add a drink"].waitForExistenceIfNeeded(timeout: 5),
            historyApp.debugDescription
        )
        let historySparkling = historyApp.buttons["Sparkling water"]
        let historyJuice = historyApp.buttons["Juice"]
        XCTAssertTrue(historySparkling.waitForExistenceIfNeeded(timeout: 3), historyApp.debugDescription)
        XCTAssertTrue(historyJuice.waitForExistenceIfNeeded(timeout: 3), historyApp.debugDescription)
        XCTAssertLessThan(historySparkling.frame.minY, historyJuice.frame.minY)
    }

    @MainActor
    func testEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent() {
        let app = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: app)
        XCTAssertTrue(app.buttons["Sparkling water"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Sparkling water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")

        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["Sparkling water"], in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        replaceText("Soda water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("355", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["Soda water"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Soda water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "685 ml")

        let oldEvent = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Sparkling water'")
        ).firstMatch
        let newEvent = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(oldEvent.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertTrue(newEvent.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        let oldValue = oldEvent.value as? String ?? ""
        XCTAssertTrue(oldValue.contains("330 ml"), oldValue)
    }

    @MainActor
    func testRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch() {
        let app = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: app)
        XCTAssertTrue(app.buttons["Sparkling water"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Sparkling water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3), app.debugDescription)

        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["Sparkling water"], in: app)
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let removalAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS %@", "Sparkling water")
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Drink favourites"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["Sparkling water"].waitForNonExistence(timeout: 5), app.debugDescription)
        app.terminate()

        let relaunched = launch(resetData: false)
        let event = relaunched.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Sparkling water'")
        ).firstMatch
        XCTAssertTrue(event.waitForExistenceIfNeeded(timeout: 3), relaunched.debugDescription)
        tapWhenReady(event, in: relaunched.scrollViews["today.content"], app: relaunched)
        XCTAssertTrue(
            relaunched.navigationBars["Edit drink"].waitForExistenceIfNeeded(timeout: 3),
            relaunched.debugDescription
        )
        XCTAssertEqual(relaunched.textFields["drink.name"].value as? String, "Sparkling water")
        XCTAssertEqual(relaunched.textFields["drink.volume"].value as? String, "330")
    }
}
