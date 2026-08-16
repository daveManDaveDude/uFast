import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command type_body_length
// swiftlint:disable trailing_comma file_length

final class HydrationQuickAddUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce() {
        runWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce()
    }

    @MainActor
    func testTeaAndCoffeeUseTheirVisibleDefaults() {
        runTeaAndCoffeeUseTheirVisibleDefaults()
    }

    @MainActor
    func testFavouriteDoesNotChangeActiveFast() {
        runFavouriteDoesNotChangeActiveFast()
    }

    @MainActor
    func testSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd() {
        runSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd()
    }

    @MainActor
    func testCreateCustomFavouriteShowsClassificationAndQuickAddsIt() {
        runCreateCustomFavouriteShowsClassificationAndQuickAddsIt()
    }

    @MainActor
    func testCaloricFavouriteAddsImmediatelyWithoutFastAndUsesActiveFastChoice() {
        runCaloricFavouriteAddsImmediatelyWithoutFastAndUsesActiveFastChoice()
    }

    @MainActor
    func testCaloricFavouriteFailureStaysVisibleAndCanBeRetriedDuringActiveFast() {
        runCaloricFavouriteFailureStaysVisibleAndCanBeRetriedDuringActiveFast()
    }
}

final class HydrationFavouriteLifecycleUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testCustomFavouriteEditAndRemoveCancelThenConfirm() {
        runCustomFavouriteEditAndRemoveCancelThenConfirm()
    }

    @MainActor
    func testFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder() {
        runFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder()
    }

    @MainActor
    func testEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent() {
        runEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent()
    }

    @MainActor
    func testRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch() {
        runRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch()
    }
}

final class HydrationFavouriteValidationUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testValidationKeepsSaveDisabledAndExplainsEachInvalidFavouriteField() {
        runValidationKeepsSaveDisabledAndExplainsEachInvalidFavouriteField()
    }

    @MainActor
    func testFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState() {
        runFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState()
    }

    @MainActor
    func testDeleteAllDataSupportsCancelSuccessAndFailure() {
        runDeleteAllDataSupportsCancelSuccessAndFailure()
    }
}

class HydrationFavouriteUITestCase: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    fileprivate func runWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce() {
        let app = launch()
        tapDrinkAdd(in: app)
        let water = app.buttons["drink.favourite.water"]
        reveal(water, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(water.value as? String, "500 millilitres")
        water.doubleTap()

        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["drink.total"].label, "500 ml")
        XCTAssertTrue(
            app.navigationBars["Add a drink"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    fileprivate func runTeaAndCoffeeUseTheirVisibleDefaults() {
        for (identifier, amount) in [("tea", "300 ml"), ("coffee", "300 ml")] {
            let app = launch()
            tapDrinkAdd(in: app)
            let favourite = app.buttons["drink.favourite.\(identifier)"]
            tapWhenReady(favourite, in: drinkPickerScrollView(in: app), app: app)
            XCTAssertEqual(app.staticTexts["drink.total"].label, amount)
        }
    }

    @MainActor
    fileprivate func runFavouriteDoesNotChangeActiveFast() {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            "--seed-active-fast-start",
            String(now.addingTimeInterval(-3600).timeIntervalSince1970),
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        dismissOptionalLiveActivityOffer(in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(
            app.buttons["drink.favourite.water"],
            in: drinkPickerScrollView(in: app),
            app: app
        )
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
    }

    @MainActor
    fileprivate func runSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd() {
        let app = launch()
        tapTab("Settings", in: app)

        let waterAmount = app.textFields["settings.drink.water"]
        reveal(waterAmount, in: settingsScrollView(in: app), app: app)
        tapWhenReady(waterAmount, in: settingsScrollView(in: app), app: app)
        waterAmount.press(forDuration: 0.7)
        XCTAssertTrue(app.menuItems["Select All"].waitForExistence(timeout: 1))
        tapWhenReady(app.menuItems["Select All"], app: app)
        waterAmount.typeText("650")

        let done = app.buttons["settings.keyboard.done"]
        XCTAssertTrue(waitForHittable(done, app: app), app.debugDescription)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(done.frame.maxY, keyboard.frame.minY)
        XCTAssertGreaterThan(done.frame.minY, keyboard.frame.minY - 80)
        tapWhenReady(done, app: app)
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["settings.drink.save"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        let water = app.buttons["drink.favourite.water"]
        XCTAssertTrue(water.waitForExistence(timeout: 2))
        XCTAssertEqual(water.value as? String, "650 millilitres")
        tapWhenReady(water, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "650 ml")
    }

    @MainActor
    fileprivate func runCreateCustomFavouriteShowsClassificationAndQuickAddsIt() {
        let app = launch()
        tapTab("Settings", in: app)
        let add = app.buttons["settings.favourite.add"]
        tapSettingsControl(add, in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 2))

        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        let saved = app.buttons["Sparkling water"]
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        XCTAssertEqual(saved.value as? String, "330 millilitres, Non-caloric")

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        let custom = app.buttons["Sparkling water"]
        XCTAssertTrue(custom.waitForExistence(timeout: 3))
        XCTAssertTrue(custom.label.contains("Sparkling water"))
        tapWhenReady(custom, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")
    }

    @MainActor
    fileprivate func runCustomFavouriteEditAndRemoveCancelThenConfirm() {
        let app = launch(additionalArguments: ["--seed-favourite-populated"])
        tapTab("Settings", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label == 'Sparkling water'")).firstMatch
        tapSettingsControl(row, in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistence(timeout: 2))
        replaceText("Soda water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("355", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.buttons["Soda water"].waitForExistence(timeout: 3))

        tapSettingsControl(
            app.buttons.matching(NSPredicate(format: "label == 'Soda water'")).firstMatch,
            in: app
        )
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let removalAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistence(timeout: 2))
        tapAlertButton("Cancel", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistence(timeout: 2))
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let confirmationAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Soda water'")
        ).firstMatch
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: confirmationAlert, app: app)
        XCTAssertTrue(confirmationAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Drink favourites"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == 'Soda water'")).firstMatch
                .waitForNonExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    fileprivate func runFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder() {
        let app = launch()
        tapTab("Settings", in: app)
        createFavourite(named: "Sparkling water", amount: "330", in: app)
        createFavourite(named: "Juice", amount: "250", in: app)
        assertSettingsOrder(["Sparkling water", "Juice"], in: app)

        app.terminate()
        let relaunched = launch(resetData: false)
        tapTab("Settings", in: relaunched)
        assertSettingsOrder(["Sparkling water", "Juice"], in: relaunched)

        tapTab("Today", in: relaunched)
        tapDrinkAdd(in: relaunched)
        assertPickerOrder(["Sparkling water", "Juice"], in: relaunched)

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
        assertPickerOrder(["Sparkling water", "Juice"], in: historyApp)
    }

    @MainActor
    fileprivate func runEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent() {
        let app = launch()
        tapTab("Settings", in: app)
        createFavourite(named: "Sparkling water", amount: "330", in: app)

        tapTab("Today", in: app)
        addFavourite(named: "Sparkling water", in: app)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")

        tapTab("Settings", in: app)
        editFavourite(
            named: "Sparkling water", replacement: "Soda water", amount: "355", in: app
        )
        tapTab("Today", in: app)
        addFavourite(named: "Soda water", in: app)
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
    fileprivate func runRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch() {
        let app = launch()
        tapTab("Settings", in: app)
        createFavourite(named: "Sparkling water", amount: "330", in: app)
        tapTab("Today", in: app)
        addFavourite(named: "Sparkling water", in: app)

        tapTab("Settings", in: app)
        removeFavourite(named: "Sparkling water", in: app)
        app.terminate()

        let relaunched = launch(resetData: false)
        let event = relaunched.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.' AND label CONTAINS 'Sparkling water'")
        ).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 3), relaunched.debugDescription)
        tapWhenReady(event, in: relaunched.scrollViews["today.content"], app: relaunched)
        XCTAssertTrue(relaunched.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        XCTAssertEqual(relaunched.textFields["drink.name"].value as? String, "Sparkling water")
        XCTAssertEqual(relaunched.textFields["drink.volume"].value as? String, "330")
    }

    @MainActor
    fileprivate func runValidationKeepsSaveDisabledAndExplainsEachInvalidFavouriteField() {
        let app = launch(additionalArguments: ["--seed-favourite-populated"])
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3))
        let save = app.buttons["settings.favourite.save"]
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText(String(repeating: "a", count: 81), in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        assertValidation("Enter a name up to 80 characters.", in: app)
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("Ｓｐａｒｋｌｉｎｇ　ｗａｔｅｒ", in: app.textFields["settings.favourite.name"], app: app)
        assertValidation("Choose a name that isn’t already in your favourites.", in: app)
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("Water", in: app.textFields["settings.favourite.name"], app: app)
        assertValidation("Choose a name that isn’t already in your favourites.", in: app)
        replaceText("0", in: app.textFields["settings.favourite.amount"], app: app)
        assertValidation("Enter an amount from 1 to 5,000 ml.", in: app)
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("5001", in: app.textFields["settings.favourite.amount"], app: app)
        assertValidation("Enter an amount from 1 to 5,000 ml.", in: app)
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)
    }

    @MainActor
    fileprivate func runFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState() {
        assertCreateFailureRetainsDraft()
        assertEditFailureRetainsCommittedFavourite()
        assertRemovalFailureRetainsCommittedFavourite()
    }

    @MainActor
    private func assertCreateFailureRetainsDraft() {
        let createApp = launch(additionalArguments: ["--simulate-favourite-save-failure"])
        tapTab("Settings", in: createApp)
        tapSettingsControl(createApp.buttons["settings.favourite.add"], in: createApp)
        replaceText("Juice", in: createApp.textFields["settings.favourite.name"], app: createApp)
        replaceText("250", in: createApp.textFields["settings.favourite.amount"], app: createApp)
        tapWhenReady(createApp.buttons["settings.favourite.save"], app: createApp)
        assertSaveFailure("Your favourite couldn’t be saved. Please try again.", in: createApp)
        XCTAssertEqual(createApp.textFields["settings.favourite.name"].value as? String, "Juice")
        tapWhenReady(createApp.buttons["settings.favourite.cancel"], app: createApp)
        XCTAssertTrue(
            createApp.navigationBars["Add favourite"].waitForNonExistence(timeout: 5),
            createApp.debugDescription
        )
    }

    @MainActor
    private func assertEditFailureRetainsCommittedFavourite() {
        let editApp = launch(
            additionalArguments: ["--seed-favourite-populated", "--simulate-favourite-save-failure"]
        )
        tapTab("Settings", in: editApp)
        tapSettingsControl(editApp.buttons["Sparkling water"], in: editApp)
        replaceText("Soda water", in: editApp.textFields["settings.favourite.name"], app: editApp)
        tapWhenReady(editApp.buttons["settings.favourite.save"], app: editApp)
        assertSaveFailure("Your favourite couldn’t be saved. Please try again.", in: editApp)
        XCTAssertTrue(
            editApp.navigationBars["Edit favourite"].waitForExistence(timeout: 5),
            editApp.debugDescription
        )
        tapWhenReady(editApp.buttons["settings.favourite.cancel"], app: editApp)
        XCTAssertTrue(
            editApp.navigationBars["Edit favourite"].waitForNonExistence(timeout: 5),
            editApp.debugDescription
        )
        reveal(editApp.buttons["Sparkling water"], in: settingsScrollView(in: editApp), app: editApp)
    }

    @MainActor
    private func assertRemovalFailureRetainsCommittedFavourite() {
        let removeApp = launch(
            additionalArguments: ["--seed-favourite-populated", "--simulate-favourite-save-failure"]
        )
        tapTab("Settings", in: removeApp)
        tapSettingsControl(removeApp.buttons["Sparkling water"], in: removeApp)
        tapWhenReady(
            removeApp.buttons["settings.favourite.remove"],
            in: editorScrollView(in: removeApp),
            app: removeApp
        )
        let removalAlert = removeApp.alerts.matching(
            NSPredicate(format: "label CONTAINS 'Sparkling water'")
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistence(timeout: 5), removeApp.debugDescription)
        tapAlertButton("Remove", in: removalAlert, app: removeApp)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), removeApp.debugDescription)
        assertSaveFailure("Your favourite couldn’t be removed. Please try again.", in: removeApp)
        XCTAssertTrue(
            removeApp.navigationBars["Edit favourite"].waitForExistence(timeout: 5),
            removeApp.debugDescription
        )
        tapWhenReady(removeApp.buttons["settings.favourite.cancel"], app: removeApp)
        XCTAssertTrue(
            removeApp.navigationBars["Edit favourite"].waitForNonExistence(timeout: 5),
            removeApp.debugDescription
        )
        reveal(removeApp.buttons["Sparkling water"], in: settingsScrollView(in: removeApp), app: removeApp)
    }

    @MainActor
    fileprivate func runDeleteAllDataSupportsCancelSuccessAndFailure() {
        let cancelled = launch(additionalArguments: ["--seed-favourite-populated"])
        tapTab("Settings", in: cancelled)
        tapSettingsControl(cancelled.buttons["settings.data.delete-all"], in: cancelled)
        let cancelledAlert = cancelled.alerts["Delete all uFast data?"]
        XCTAssertTrue(cancelledAlert.waitForExistence(timeout: 5), cancelled.debugDescription)
        tapWhenReady(cancelledAlert.buttons["Cancel"], app: cancelled)
        XCTAssertTrue(cancelledAlert.waitForNonExistence(timeout: 5), cancelled.debugDescription)
        reveal(cancelled.buttons["Sparkling water"], in: settingsScrollView(in: cancelled), app: cancelled)

        let failed = launch(
            additionalArguments: ["--seed-favourite-populated", "--simulate-delete-all-failure"]
        )
        tapTab("Settings", in: failed)
        completeDeleteAll(in: failed)
        reveal(
            failed.staticTexts["settings.data.delete-error"],
            in: settingsScrollView(in: failed),
            app: failed
        )
        reveal(failed.buttons["Sparkling water"], in: settingsScrollView(in: failed), app: failed)

        let succeeded = launch(additionalArguments: ["--seed-favourite-populated"])
        tapTab("Settings", in: succeeded)
        completeDeleteAll(in: succeeded)
        XCTAssertTrue(
            succeeded.staticTexts["goal.promise"].waitForExistence(timeout: 5),
            succeeded.debugDescription
        )
        tapWhenReady(succeeded.buttons["goal.continue"], app: succeeded)
        XCTAssertTrue(succeeded.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        tapTab("Settings", in: succeeded)
        reveal(
            succeeded.buttons["settings.favourite.add"],
            in: settingsScrollView(in: succeeded),
            app: succeeded
        )
        XCTAssertTrue(
            succeeded.buttons["Sparkling water"].waitForNonExistence(timeout: 5),
            succeeded.debugDescription
        )
    }

    @MainActor
    fileprivate func runCaloricFavouriteAddsImmediatelyWithoutFastAndUsesActiveFastChoice() {
        let noFast = launch()
        tapTab("Settings", in: noFast)
        createFavourite(named: "Juice", amount: "250", caloric: true, in: noFast)
        tapTab("Today", in: noFast)
        addFavourite(named: "Juice", in: noFast)
        XCTAssertEqual(noFast.staticTexts["drink.total"].label, "250 ml")

        let active = launch(additionalArguments: ["--seed-caloric-favourite-active-fast"])
        XCTAssertTrue(active.staticTexts["fast.elapsed"].waitForExistence(timeout: 3))
        tapDrinkAdd(in: active)
        tapWhenReady(active.buttons["Juice"], in: drinkPickerScrollView(in: active), app: active)
        let alert = active.alerts["This entry is during your recorded fast."]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        tapWhenReady(alert.buttons["Cancel"], app: active)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), active.debugDescription)
        XCTAssertEqual(active.staticTexts["drink.total"].label, "0 ml")

        tapDrinkAdd(in: active)
        tapWhenReady(active.buttons["Juice"], in: drinkPickerScrollView(in: active), app: active)
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        tapWhenReady(alert.buttons["Save and end fast"], app: active)
        XCTAssertTrue(active.staticTexts["drink.total"].waitForExistence(timeout: 3))
        XCTAssertEqual(active.staticTexts["drink.total"].label, "250 ml")
        XCTAssertTrue(active.staticTexts["fast.elapsed"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    fileprivate func runCaloricFavouriteFailureStaysVisibleAndCanBeRetriedDuringActiveFast() {
        let app = launch(additionalArguments: [
            "--seed-caloric-favourite-active-fast",
            "--simulate-drink-save-failure",
        ])
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 3))

        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Juice"], in: drinkPickerScrollView(in: app), app: app)
        let confirmation = app.alerts["This entry is during your recorded fast."]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        tapWhenReady(confirmation.buttons["Save and end fast"], app: app)

        let error = app.staticTexts["drink.caloric-favourite.save-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(error.label.contains("drink and fast couldn’t be saved"))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "0 ml")

        let retry = app.buttons["drink.caloric-favourite.retry"]
        tapWhenReady(retry, in: app.scrollViews["today.content"], app: app)
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(retry.exists)
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    private func launch() -> XCUIApplication {
        launch(additionalArguments: [], resetData: true)
    }

    @MainActor
    private func launch(resetData: Bool) -> XCUIApplication {
        launch(additionalArguments: [], resetData: resetData)
    }

    @MainActor
    private func launch(
        additionalArguments: [String],
        resetData: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(resetData: resetData) + additionalArguments
        app.launch()
        dismissOptionalLiveActivityOffer(in: app)
        let drinkAdd = app.buttons["drink.add"]
        XCTAssertTrue(drinkAdd.waitForExistence(timeout: 5), app.debugDescription)
        reveal(drinkAdd, in: app.scrollViews["today.content"], app: app)
        return app
    }

    @MainActor
    private func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        tapWhenReady(tab, app: app)
    }

    @MainActor
    private func tapDrinkAdd(in app: XCUIApplication) {
        tapWhenReady(
            app.buttons["drink.add"],
            in: app.scrollViews["today.content"],
            app: app
        )
    }

    @MainActor
    private func tapSettingsControl(_ control: XCUIElement, in app: XCUIApplication) {
        tapWhenReady(control, in: settingsScrollView(in: app), app: app)
    }

    @MainActor
    private func settingsScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollView = app.scrollViews["settings.content"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        return scrollView
    }

    @MainActor
    private func drinkPickerScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollView = app.scrollViews["drink.picker"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        return scrollView
    }

    @MainActor
    private func editorScrollView(in app: XCUIApplication) -> XCUIElement {
        let collectionView = app.collectionViews["settings.favourite.editor"]
        if collectionView.waitForExistence(timeout: 3) {
            return collectionView
        }
        let scrollView = app.scrollViews["settings.favourite.editor"]
        if scrollView.waitForExistence(timeout: 3) {
            return scrollView
        }
        let table = app.tables["settings.favourite.editor"]
        XCTAssertTrue(table.waitForExistence(timeout: 5), app.debugDescription)
        return table
    }

    @MainActor
    private func tapWhenReady(
        _ element: XCUIElement,
        in scrollView: XCUIElement? = nil,
        app: XCUIApplication
    ) {
        if let scrollView {
            reveal(element, in: scrollView, app: app)
        } else {
            XCTAssertTrue(waitForHittable(element, app: app), app.debugDescription)
        }
        guard element.isHittable else {
            XCTFail(app.debugDescription)
            return
        }
        element.tap()
    }

    @MainActor
    @discardableResult
    private func tapAlertButton(
        _ title: String,
        in alert: XCUIElement,
        app: XCUIApplication
    ) -> Bool {
        let buttons = alert.buttons.matching(NSPredicate(format: "label == %@", title))
        guard buttons.firstMatch.waitForExistence(timeout: 2) else {
            XCTFail(app.debugDescription)
            return false
        }
        for index in 0 ..< buttons.count {
            let button = buttons.element(boundBy: index)
            guard button.waitForExistence(timeout: 2) else { continue }
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate { object, _ in
                    (object as? XCUIElement)?.isHittable == true
                },
                object: button
            )
            if XCTWaiter.wait(for: [expectation], timeout: 2) == .completed {
                button.tap()
                return true
            }
        }
        XCTFail(app.debugDescription)
        return false
    }

    @MainActor
    @discardableResult
    private func waitForHittable(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return false
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.isHittable == true
            },
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    @discardableResult
    private func waitForDisabled(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return false
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.isEnabled == false
            },
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication
    ) {
        guard scrollView.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        guard element.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return
        }
        guard !element.isHittable else { return }
        guard scrollView.isHittable else {
            XCTFail(app.debugDescription)
            return
        }

        for _ in 0 ..< 5 where !element.isHittable {
            scrollView.swipeUp()
        }
        for _ in 0 ..< 5 where !element.isHittable {
            scrollView.swipeDown()
        }

        XCTAssertTrue(waitForHittable(element, app: app), app.debugDescription)
    }

    @MainActor
    private func createFavourite(
        named name: String,
        amount: String,
        caloric: Bool = false,
        in app: XCUIApplication
    ) {
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForExistence(timeout: 3))
        replaceText(name, in: app.textFields["settings.favourite.name"], app: app)
        replaceText(amount, in: app.textFields["settings.favourite.amount"], app: app)
        if caloric {
            tapWhenReady(app.switches["settings.favourite.caloric"], app: app)
        }
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3))
        reveal(app.buttons[name], in: settingsScrollView(in: app), app: app)
    }

    @MainActor
    private func editFavourite(
        named name: String,
        replacement: String,
        amount: String,
        in app: XCUIApplication
    ) {
        tapSettingsControl(app.buttons[name], in: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForExistence(timeout: 3))
        replaceText(replacement, in: app.textFields["settings.favourite.name"], app: app)
        replaceText(amount, in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Edit favourite"].waitForNonExistence(timeout: 3))
        reveal(app.buttons[replacement], in: settingsScrollView(in: app), app: app)
    }

    @MainActor
    private func removeFavourite(named name: String, in app: XCUIApplication) {
        tapSettingsControl(app.buttons[name], in: app)
        tapWhenReady(app.buttons["settings.favourite.remove"], in: editorScrollView(in: app), app: app)
        let removalAlert = app.alerts.matching(
            NSPredicate(format: "label CONTAINS %@", name)
        ).firstMatch
        XCTAssertTrue(removalAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapAlertButton("Remove", in: removalAlert, app: app)
        XCTAssertTrue(removalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Drink favourites"].waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons[name].waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func addFavourite(named name: String, in app: XCUIApplication) {
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons[name], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func assertSettingsOrder(_ names: [String], in app: XCUIApplication) {
        let scrollView = settingsScrollView(in: app)
        let rows = names.map { name -> XCUIElement in
            let row = app.buttons[name]
            reveal(row, in: scrollView, app: app)
            return row
        }
        for pair in zip(rows, rows.dropFirst()) {
            XCTAssertLessThan(pair.0.frame.minY, pair.1.frame.minY)
        }
    }

    @MainActor
    private func assertPickerOrder(_ names: [String], in app: XCUIApplication) {
        let scrollView = drinkPickerScrollView(in: app)
        let rows = names.map { name -> XCUIElement in
            let row = app.buttons[name]
            reveal(row, in: scrollView, app: app)
            return row
        }
        for pair in zip(rows, rows.dropFirst()) {
            XCTAssertLessThan(pair.0.frame.minY, pair.1.frame.minY)
        }
    }

    @MainActor
    private func assertValidation(_ message: String, in app: XCUIApplication) {
        let validation = app.staticTexts["settings.favourite.validation"]
        XCTAssertTrue(
            waitForLabel(validation, containing: message),
            app.debugDescription
        )
    }

    @MainActor
    private func assertSaveFailure(_ message: String, in app: XCUIApplication) {
        let failure = app.staticTexts["settings.favourite.save-error"]
        XCTAssertTrue(
            waitForLabel(failure, containing: message),
            app.debugDescription
        )
    }

    @MainActor
    private func waitForLabel(
        _ element: XCUIElement,
        containing message: String
    ) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.label.contains(message) == true
            },
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    private func completeDeleteAll(in app: XCUIApplication) {
        tapSettingsControl(app.buttons["settings.data.delete-all"], in: app)
        let firstAlert = app.alerts["Delete all uFast data?"]
        XCTAssertTrue(firstAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapWhenReady(firstAlert.buttons["Continue"], app: app)
        let finalAlert = app.alerts["Permanently delete everything?"]
        XCTAssertTrue(finalAlert.waitForExistence(timeout: 5), app.debugDescription)
        tapWhenReady(finalAlert.buttons["Delete everything"], app: app)
        XCTAssertTrue(finalAlert.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func replaceText(_ value: String, in field: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(waitForHittable(field, app: app), app.debugDescription)
        field.tap()
        field.press(forDuration: 0.7)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            tapWhenReady(selectAll, app: app)
        } else {
            field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        field.typeText(value)
        dismissKeyboard(in: app)
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        for identifier in ["return", "Return", "done", "Done"] {
            let button = keyboard.buttons[identifier]
            guard button.exists, button.isHittable else { continue }
            button.tap()
            XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5), app.debugDescription)
            return
        }
    }

    @MainActor
    private func dismissOptionalLiveActivityOffer(in app: XCUIApplication) {
        let alert = app.alerts["See your fast at a glance?"]
        guard alert.waitForExistence(timeout: 1) else { return }
        tapWhenReady(alert.buttons["Not Now"], app: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    private var arguments: [String] {
        launchArguments(resetData: true)
    }

    private func launchArguments(resetData: Bool) -> [String] {
        var values = ["--ui-testing", "--seed-onboarded"]
        if resetData {
            values.append("--reset-data")
        }
        values.append(contentsOf: [
            "--fixed-now", String(now.timeIntervalSince1970),
        ])
        return values
    }
}
