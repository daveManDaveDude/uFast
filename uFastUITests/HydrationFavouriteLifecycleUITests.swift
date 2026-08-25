import XCTest

final class HydrationFavouriteLifecycleUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testRemovingLastFavouriteKeepsSettingsAndPickerUsable() {
        let app = launch()
        tapTab("Settings", in: app)
        let water = app.buttons["settings.favourite.\(waterFavouriteID)"]
        tapSettingsControl(water, in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistence(timeout: 3), app.debugDescription)
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3), app.debugDescription)
        tapAlertButton("Remove", in: confirmation, app: app)
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["settings.favourite.add"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.favourite.\(waterFavouriteID)"].exists)

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        XCTAssertTrue(app.buttons["drink.custom"].waitForExistence(timeout: 5), app.debugDescription)
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
            app.navigationBars["Edit favourite"].waitForExistence(timeout: 2),
            app.debugDescription
        )
        replaceText("Soda water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("355", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(
            app.buttons["Soda water"].waitForExistence(timeout: 3),
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
        XCTAssertTrue(removalAlert.waitForExistence(timeout: 2), removalAlert.debugDescription)
        tapAlertButton("Cancel", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.navigationBars["Edit favourite"].waitForExistence(timeout: 2),
            app.debugDescription
        )
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let confirmationAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: confirmationAlert, app: app)
        XCTAssertTrue(confirmationAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.staticTexts["Drink favourites"].waitForExistence(timeout: 3),
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
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3), app.debugDescription)
        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        reveal(app.buttons["Sparkling water"], in: settingsScrollView(in: app), app: app)

        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3), app.debugDescription)
        replaceText("Juice", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("250", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        reveal(app.buttons["Juice"], in: settingsScrollView(in: app), app: app)
        let sparkling = app.buttons["Sparkling water"]
        let juice = app.buttons["Juice"]
        reveal(sparkling, in: settingsScrollView(in: app), app: app)
        reveal(juice, in: settingsScrollView(in: app), app: app)
        XCTAssertLessThan(sparkling.frame.minY, juice.frame.minY)

        app.terminate()
        let relaunched = launch(resetData: false)
        tapTab("Settings", in: relaunched)
        let relaunchedSparkling = relaunched.buttons["Sparkling water"]
        let relaunchedJuice = relaunched.buttons["Juice"]
        reveal(relaunchedSparkling, in: settingsScrollView(in: relaunched), app: relaunched)
        reveal(relaunchedJuice, in: settingsScrollView(in: relaunched), app: relaunched)
        XCTAssertLessThan(relaunchedSparkling.frame.minY, relaunchedJuice.frame.minY)

        tapTab("Today", in: relaunched)
        tapDrinkAdd(in: relaunched)
        let todaySparkling = relaunched.buttons["Sparkling water"]
        let todayJuice = relaunched.buttons["Juice"]
        reveal(todaySparkling, in: drinkPickerScrollView(in: relaunched), app: relaunched)
        reveal(todayJuice, in: drinkPickerScrollView(in: relaunched), app: relaunched)
        XCTAssertLessThan(todaySparkling.frame.minY, todayJuice.frame.minY)

        // Relaunching closes the transient picker without making the persistence journey
        // depend on the sheet toolbar being exposed under parallel simulator load.
        relaunched.terminate()
        let historyApp = launch(resetData: false)
        tapTab("History", in: historyApp)
        tapWhenReady(
            historyApp.buttons["history.add-at-selected-time"],
            in: historyApp.scrollViews["history.content"],
            app: historyApp
        )
        XCTAssertTrue(
            historyApp.navigationBars["Add to history"].waitForExistence(timeout: 5),
            historyApp.debugDescription
        )
        tapWhenReady(historyApp.buttons["history.add.drink"], app: historyApp)
        XCTAssertTrue(
            historyApp.navigationBars["Add a drink"].waitForExistence(timeout: 5),
            historyApp.debugDescription
        )
        let historySparkling = historyApp.buttons["Sparkling water"]
        let historyJuice = historyApp.buttons["Juice"]
        reveal(historySparkling, in: drinkPickerScrollView(in: historyApp), app: historyApp)
        reveal(historyJuice, in: drinkPickerScrollView(in: historyApp), app: historyApp)
        XCTAssertLessThan(historySparkling.frame.minY, historyJuice.frame.minY)
    }

    @MainActor
    func testEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent() {
        let app = launch()
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3), app.debugDescription)
        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        reveal(app.buttons["Sparkling water"], in: settingsScrollView(in: app), app: app)

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Sparkling water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")

        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["Sparkling water"], in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistence(timeout: 3), app.debugDescription)
        replaceText("Soda water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("355", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        reveal(app.buttons["Soda water"], in: settingsScrollView(in: app), app: app)
        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Soda water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "685 ml")

        let oldEvent = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Sparkling water'")
        ).firstMatch
        let newEvent = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(oldEvent.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(newEvent.waitForExistence(timeout: 3), app.debugDescription)
        let todayScrollView = app.scrollViews["today.content"]
        reveal(oldEvent, in: todayScrollView, app: app)
        reveal(newEvent, in: todayScrollView, app: app)
        let oldValue = oldEvent.value as? String ?? ""
        XCTAssertTrue(oldValue.contains("330 ml"), oldValue)
    }

    @MainActor
    func testRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch() {
        let app = launch()
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3), app.debugDescription)
        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        reveal(app.buttons["Sparkling water"], in: settingsScrollView(in: app), app: app)
        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Sparkling water"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3), app.debugDescription)

        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["Sparkling water"], in: app)
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let removalAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS %@", "Sparkling water")
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Drink favourites"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["Sparkling water"].waitForNonExistence(timeout: 5), app.debugDescription)
        app.terminate()

        let relaunched = launch(resetData: false)
        let event = relaunched.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Sparkling water'")
        ).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 3), relaunched.debugDescription)
        tapWhenReady(event, in: relaunched.scrollViews["today.content"], app: relaunched)
        XCTAssertTrue(
            relaunched.navigationBars["Edit drink"].waitForExistence(timeout: 3),
            relaunched.debugDescription
        )
        XCTAssertEqual(relaunched.textFields["drink.name"].value as? String, "Sparkling water")
        XCTAssertEqual(relaunched.textFields["drink.volume"].value as? String, "330")
    }
}
