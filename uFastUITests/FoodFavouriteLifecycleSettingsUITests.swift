import XCTest

extension FoodFavouriteLifecycleUITests {
    @MainActor
    func testFreshEmptySettingsTodayPickerAndBlankEditorRemainUsable() {
        let app = launch(seedOnboarded: true)
        tapSettings(in: app)

        XCTAssertTrue(app.staticTexts["settings.food-favourites"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["settings.food-favourite.add"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].exists)

        app.tabBars.buttons["Today"].tap()
        let foodAdd = app.buttons["food.add"]
        XCTAssertTrue(foodAdd.waitForExistence(timeout: 5), app.debugDescription)
        foodAdd.tap()
        XCTAssertTrue(foodPicker(in: app).waitForExistence(timeout: 5), app.debugDescription)
        let customFood = app.buttons["food.custom"]
        XCTAssertTrue(customFood.waitForExistence(timeout: 5), app.debugDescription)
        customFood.tap()

        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(description.value as? String, "What did you eat?")
        XCTAssertFalse(app.buttons["food.favourite.\(populatedFoodFavouriteID)"].exists)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(foodPicker(in: app).waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testSettingsCreatesFoodFavouriteAndKeepsItAfterRelaunch() {
        let app = launch(seedOnboarded: true)
        tapSettings(in: app)

        let add = app.buttons["settings.food-favourite.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        let editor = app.descendants(matching: .any).matching(identifier: "settings.food-favourite.editor").firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), app.debugDescription)
        let description = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Rice bowl")
        app.buttons["settings.food-favourite.details.toggle"].tap()
        let energy = app.textFields["settings.food-favourite.nutrition.energy"]
        XCTAssertTrue(energy.waitForExistence(timeout: 5), app.debugDescription)
        energy.tap()
        energy.typeText("0")
        app.buttons["settings.food-favourite.save"].tap()

        let row = firstSavedFoodFavouriteRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Rice bowl"].waitForExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(resetData: false, seedOnboarded: true)
        app.launch()
        tapSettings(in: app)
        XCTAssertTrue(app.staticTexts["Rice bowl"].waitForExistence(timeout: 5), app.debugDescription)

        let savedRow = firstSavedFoodFavouriteRow(in: app)
        XCTAssertTrue(savedRow.waitForExistence(timeout: 5), app.debugDescription)
        savedRow.tap()
        let editDescription = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(editDescription.waitForExistence(timeout: 5), app.debugDescription)
        replaceText("Rice bowl with berries", in: editDescription, app: app)
        app.buttons["settings.food-favourite.save"].tap()
        XCTAssertTrue(app.staticTexts["Rice bowl with berries"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Rice bowl"].waitForNonExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["Today"].tap()
        let foodAdd = app.buttons["food.add"]
        XCTAssertTrue(foodAdd.waitForExistence(timeout: 5), app.debugDescription)
        foodAdd.tap()
        XCTAssertTrue(app.staticTexts["Rice bowl with berries"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Rice bowl"].exists)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(foodPicker(in: app).waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testSettingsDuplicateDescriptionHasScopedAccessibleValidation() {
        let app = launch(seedOnboarded: true, seedFoodFavouritePopulated: true)
        tapSettings(in: app)
        let add = app.buttons["settings.food-favourite.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        let description = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Overnight oats")

        let validation = app.descendants(matching: .any)
            .matching(identifier: "settings.food-favourite.validation.description").firstMatch
        XCTAssertTrue(validation.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.food-favourite.save"].isEnabled)
    }

    @MainActor
    func testSettingsFoodFavouriteRemovalFailureUsesRemovalCopyAndRetainsCommittedState() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            simulateFoodFavouriteSaveFailure: true
        )
        tapSettings(in: app)
        let row = app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.tap()

        let editor = identifiedInApp("settings.food-favourite.editor", in: app)
        XCTAssertTrue(editor.waitForExistence(timeout: 5), app.debugDescription)
        let remove = app.buttons["settings.food-favourite.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        remove.tap()
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        let confirm = identifiedInContainer("settings.food-favourite.remove-confirm", in: confirmation)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        confirm.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)

        let error = app.staticTexts["settings.food-favourite.save-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(error.label, "Your food favourite couldn’t be removed. Please try again.")
        XCTAssertTrue(editor.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(
            app.textFields["settings.food-favourite.description"].value as? String,
            "Overnight oats"
        )

        app.buttons["settings.food-favourite.cancel"].tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testSettingsRemovalCancelSuccessLastRowPickerAndRelaunch() {
        let app = launch(seedOnboarded: true, seedFoodFavouritePopulated: true)
        tapSettings(in: app)

        let row = app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.tap()
        XCTAssertTrue(
            identifiedInApp("settings.food-favourite.editor", in: app).waitForExistence(timeout: 5),
            app.debugDescription
        )

        let remove = app.buttons["settings.food-favourite.remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        remove.tap()
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            confirmation.staticTexts["Remove “Overnight oats” from food favourites?"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        let cancel = confirmation.descendants(matching: .any)
            .matching(identifier: "settings.food-favourite.remove-cancel").firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)

        // Cancelling only the removal confirmation deliberately leaves the
        // editor open. Reuse its removal action rather than tapping the row
        // behind that presentation.
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        remove.tap()
        let successConfirmation = app.alerts.firstMatch
        XCTAssertTrue(successConfirmation.waitForExistence(timeout: 5), app.debugDescription)
        let confirm = successConfirmation.descendants(matching: .any)
            .matching(identifier: "settings.food-favourite.remove-confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        confirm.tap()
        XCTAssertTrue(
            identifiedInApp("settings.food-favourite.editor", in: app).waitForNonExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["Today"].tap()
        app.buttons["food.add"].tap()
        XCTAssertTrue(app.buttons["food.custom"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["food.favourite.\(populatedFoodFavouriteID)"].exists)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(foodPicker(in: app).waitForNonExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(resetData: false, seedOnboarded: true)
        app.launch()
        XCTAssertTrue(app.buttons["food.add"].waitForExistence(timeout: 5), app.debugDescription)
        tapSettings(in: app)
        XCTAssertTrue(app.buttons["settings.food-favourite.add"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].exists)
    }

    @MainActor
    func testFoodFavouriteSaveFailureRetainsEditorForRetryOrCancel() {
        let app = launch(seedOnboarded: true, simulateFoodFavouriteSaveFailure: true)
        tapSettings(in: app)
        app.buttons["settings.food-favourite.add"].tap()
        let description = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Uncommitted meal")
        app.buttons["settings.food-favourite.save"].tap()
        XCTAssertTrue(
            identifiedInApp("settings.food-favourite.save-error", in: app).waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(description.value as? String, "Uncommitted meal")
        app.buttons["settings.food-favourite.cancel"].tap()
        XCTAssertTrue(
            identifiedInApp("settings.food-favourite.editor", in: app).waitForNonExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertFalse(app.staticTexts["Uncommitted meal"].exists)
    }

    @MainActor
    func testStaleSettingsSaveRetainsCommittedTemplateWithoutGhostWrite() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            simulateFoodFavouriteStale: true
        )
        tapSettings(in: app)
        app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].tap()
        let description = app.textFields["settings.food-favourite.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        replaceText("Rejected oats", in: description, app: app)
        app.buttons["settings.food-favourite.save"].tap()
        XCTAssertTrue(
            app.staticTexts["settings.food-favourite.stale"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(description.value as? String, "Rejected oats")
        app.buttons["settings.food-favourite.cancel"].tap()
        XCTAssertTrue(
            app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Rejected oats"].exists)
    }
}
