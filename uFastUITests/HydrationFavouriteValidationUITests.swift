import XCTest

final class HydrationFavouriteValidationUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testValidationKeepsSaveDisabledAndExplainsEachInvalidFavouriteField() {
        let app = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(
            app.navigationBars["Add favourite"].waitForExistence(timeout: 3),
            app.debugDescription
        )
        let save = app.buttons["settings.favourite.save"]
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText(String(repeating: "a", count: 81), in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        let validation = app.staticTexts["settings.favourite.validation"]
        XCTAssertTrue(
            waitForLabel(validation, containing: "Enter a name up to 80 characters."),
            app.debugDescription
        )
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("Ｓｐａｒｋｌｉｎｇ　ｗａｔｅｒ", in: app.textFields["settings.favourite.name"], app: app)
        XCTAssertTrue(
            waitForLabel(validation, containing: "Choose a name that isn’t already in your favourites."),
            app.debugDescription
        )
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("Water", in: app.textFields["settings.favourite.name"], app: app)
        XCTAssertTrue(
            waitForLabel(validation, containing: "Choose a name that isn’t already in your favourites."),
            app.debugDescription
        )
        replaceText("0", in: app.textFields["settings.favourite.amount"], app: app)
        XCTAssertTrue(
            waitForLabel(validation, containing: "Enter an amount from 1 to 5,000 ml."),
            app.debugDescription
        )
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)

        replaceText("5001", in: app.textFields["settings.favourite.amount"], app: app)
        XCTAssertTrue(
            waitForLabel(validation, containing: "Enter an amount from 1 to 5,000 ml."),
            app.debugDescription
        )
        XCTAssertTrue(waitForDisabled(save, app: app), app.debugDescription)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState() {
        let createApp = launch(simulateFavouriteSaveFailure: true)
        tapTab("Settings", in: createApp)
        tapSettingsControl(createApp.buttons["settings.favourite.add"], in: createApp)
        replaceText("Juice", in: createApp.textFields["settings.favourite.name"], app: createApp)
        replaceText("250", in: createApp.textFields["settings.favourite.amount"], app: createApp)
        tapWhenReady(createApp.buttons["settings.favourite.save"], app: createApp)
        let createFailure = createApp.staticTexts["settings.favourite.save-error"]
        XCTAssertTrue(
            waitForLabel(createFailure, containing: "Your favourite couldn’t be saved. Please try again."),
            createApp.debugDescription
        )
        XCTAssertEqual(createApp.textFields["settings.favourite.name"].value as? String, "Juice")
        tapWhenReady(createApp.buttons["settings.favourite.cancel"], app: createApp)
        XCTAssertTrue(
            createApp.navigationBars["Add favourite"].waitForNonExistence(timeout: 5),
            createApp.debugDescription
        )

        let editApp = launch(
            seedFavouritePopulated: true,
            simulateFavouriteSaveFailure: true
        )
        tapTab("Settings", in: editApp)
        tapSettingsControl(editApp.buttons["Sparkling water"], in: editApp)
        replaceText("Soda water", in: editApp.textFields["settings.favourite.name"], app: editApp)
        tapWhenReady(editApp.buttons["settings.favourite.save"], app: editApp)
        let editFailure = editApp.staticTexts["settings.favourite.save-error"]
        XCTAssertTrue(
            waitForLabel(editFailure, containing: "Your favourite couldn’t be saved. Please try again."),
            editApp.debugDescription
        )
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

        let removeApp = launch(
            seedFavouritePopulated: true,
            simulateFavouriteSaveFailure: true
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
        let removalFailure = removeApp.staticTexts["settings.favourite.save-error"]
        XCTAssertTrue(
            waitForLabel(removalFailure, containing: "Your favourite couldn’t be removed. Please try again."),
            removeApp.debugDescription
        )
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
    // swiftlint:disable:next function_body_length
    func testDeleteAllDataSupportsCancelSuccessAndFailure() {
        let cancelled = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: cancelled)
        tapSettingsControl(cancelled.buttons["settings.data.delete-all"], in: cancelled)
        let cancelledAlert = cancelled.alerts["Delete all uFast data?"]
        XCTAssertTrue(cancelledAlert.waitForExistence(timeout: 5), cancelled.debugDescription)
        tapWhenReady(cancelledAlert.buttons["Cancel"], app: cancelled)
        XCTAssertTrue(cancelledAlert.waitForNonExistence(timeout: 5), cancelled.debugDescription)
        reveal(cancelled.buttons["Sparkling water"], in: settingsScrollView(in: cancelled), app: cancelled)

        let failed = launch(
            seedFavouritePopulated: true,
            simulateDeleteAllFailure: true
        )
        tapTab("Settings", in: failed)
        tapSettingsControl(failed.buttons["settings.data.delete-all"], in: failed)
        let failedFirstAlert = failed.alerts["Delete all uFast data?"]
        XCTAssertTrue(failedFirstAlert.waitForExistence(timeout: 5), failed.debugDescription)
        tapWhenReady(failedFirstAlert.buttons["Continue"], app: failed)
        let failedFinalAlert = failed.alerts["Permanently delete everything?"]
        XCTAssertTrue(failedFinalAlert.waitForExistence(timeout: 5), failed.debugDescription)
        tapWhenReady(failedFinalAlert.buttons["Delete everything"], app: failed)
        XCTAssertTrue(failedFinalAlert.waitForNonExistence(timeout: 5), failed.debugDescription)
        reveal(
            failed.staticTexts["settings.data.delete-error"],
            in: settingsScrollView(in: failed),
            app: failed
        )
        reveal(failed.buttons["Sparkling water"], in: settingsScrollView(in: failed), app: failed)

        let succeeded = launch(seedFavouritePopulated: true)
        tapTab("Settings", in: succeeded)
        tapSettingsControl(succeeded.buttons["settings.data.delete-all"], in: succeeded)
        let succeededFirstAlert = succeeded.alerts["Delete all uFast data?"]
        XCTAssertTrue(succeededFirstAlert.waitForExistence(timeout: 5), succeeded.debugDescription)
        tapWhenReady(succeededFirstAlert.buttons["Continue"], app: succeeded)
        let succeededFinalAlert = succeeded.alerts["Permanently delete everything?"]
        XCTAssertTrue(succeededFinalAlert.waitForExistence(timeout: 5), succeeded.debugDescription)
        tapWhenReady(succeededFinalAlert.buttons["Delete everything"], app: succeeded)
        XCTAssertTrue(succeededFinalAlert.waitForNonExistence(timeout: 5), succeeded.debugDescription)
        XCTAssertTrue(
            succeeded.staticTexts["goal.promise"].waitForExistence(timeout: 5),
            succeeded.debugDescription
        )
        tapWhenReady(succeeded.buttons["goal.continue"], app: succeeded)
        XCTAssertTrue(
            succeeded.tabBars.buttons["Settings"].waitForExistence(timeout: 5),
            succeeded.debugDescription
        )
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
        tapTab("Today", in: succeeded)
        tapDrinkAdd(in: succeeded)
        let favouriteRows = succeeded.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "drink.favourite.")
        )
        XCTAssertEqual(favouriteRows.count, 1, succeeded.debugDescription)
        let water = succeeded.buttons["drink.favourite.\(waterFavouriteID)"]
        XCTAssertTrue(water.waitForExistence(timeout: 5), succeeded.debugDescription)
        XCTAssertEqual(water.label, "Water")
        XCTAssertEqual(water.value as? String, "330 millilitres, Non-caloric")
        XCTAssertFalse(succeeded.buttons["drink.favourite.00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertFalse(succeeded.buttons["drink.favourite.00000000-0000-0000-0000-000000000003"].exists)
        XCTAssertFalse(succeeded.staticTexts["drink.save-error"].exists)
        succeeded.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchArguments = UITestLaunchConfiguration(
            resetData: false,
            fixedNow: now
        ).arguments
        relaunched.launch()
        tapDrinkAdd(in: relaunched)
        let relaunchedFavouriteRows = relaunched.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "drink.favourite.")
        )
        XCTAssertEqual(relaunchedFavouriteRows.count, 1, relaunched.debugDescription)
        let relaunchedWater = relaunched.buttons["drink.favourite.\(waterFavouriteID)"]
        XCTAssertTrue(relaunchedWater.waitForExistence(timeout: 5), relaunched.debugDescription)
        XCTAssertEqual(relaunchedWater.label, "Water")
        XCTAssertEqual(relaunchedWater.value as? String, "330 millilitres, Non-caloric")
        XCTAssertFalse(relaunched.buttons["drink.favourite.00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertFalse(relaunched.buttons["drink.favourite.00000000-0000-0000-0000-000000000003"].exists)
    }
}
