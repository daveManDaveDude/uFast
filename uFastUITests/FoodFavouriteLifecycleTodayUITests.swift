import XCTest

extension FoodFavouriteLifecycleUITests {
    @MainActor
    func testTodayFavouriteCreatesSuccessStateAndActiveFastCancelClearsStateBeforeRetryingSelection() {
        let app = launch(seedOnboarded: true, seedFoodFavouritePopulated: true)
        let foodAdd = app.buttons["food.add"]
        XCTAssertTrue(foodAdd.waitForExistence(timeout: 5), app.debugDescription)
        foodAdd.tap()
        let favourite = app.buttons["food.favourite.10300000-0000-0000-0000-000000000001"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            identifiedInApp("food.favourite.success", in: app).waitForExistence(timeout: 5),
            app.debugDescription
        )

        app.terminate()
        let active = launch(seedOnboarded: true, seedFoodFavouriteActiveFast: true)
        active.buttons["food.add"].tap()
        let activeFavourite = active.buttons["food.favourite.10300000-0000-0000-0000-000000000001"]
        XCTAssertTrue(activeFavourite.waitForExistence(timeout: 5), active.debugDescription)
        activeFavourite.tap()
        let confirmation = active.descendants(matching: .any)
            .matching(identifier: "food.favourite.confirmation").firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), active.debugDescription)
        let savingState = active.descendants(matching: .any)
            .matching(identifier: "food.favourite.commit-state").firstMatch
        XCTAssertTrue(savingState.waitForExistence(timeout: 5), active.debugDescription)
        XCTAssertEqual(savingState.label, "Saving favourite food…")
        let cancelConfirmation = identifiedInContainer("food.favourite.confirmation.cancel", in: confirmation)
        let primaryConfirmation = identifiedInContainer("food.favourite.confirmation.primary", in: confirmation)
        let consequence = identifiedInContainer("food.favourite.confirmation.consequence", in: confirmation)
        XCTAssertTrue(cancelConfirmation.waitForExistence(timeout: 5), active.debugDescription)
        XCTAssertTrue(primaryConfirmation.waitForExistence(timeout: 5), active.debugDescription)
        XCTAssertTrue(consequence.waitForExistence(timeout: 5), active.debugDescription)
        cancelConfirmation.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), active.debugDescription)
        XCTAssertFalse(identifiedInContainer("food.favourite.commit-state", in: active).exists)
        XCTAssertTrue(active.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), active.debugDescription)
        XCTAssertFalse(active.staticTexts["Overnight oats"].exists)

        active.buttons["food.add"].tap()
        XCTAssertTrue(activeFavourite.waitForExistence(timeout: 5), active.debugDescription)
        activeFavourite.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), active.debugDescription)
        primaryConfirmation.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), active.debugDescription)
        XCTAssertTrue(
            identifiedInContainer("food.favourite.success", in: active).waitForExistence(timeout: 5),
            active.debugDescription
        )
        XCTAssertTrue(active.staticTexts["Overnight oats"].waitForExistence(timeout: 5), active.debugDescription)
    }

    @MainActor
    func testTodayActiveFastFoodFavouriteFailureKeepsFastAndProvidesRetry() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouriteActiveFast: true,
            simulateFoodSaveFailure: true
        )
        app.buttons["food.add"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()
        let confirmation = app.descendants(matching: .any)
            .matching(identifier: "food.favourite.confirmation").firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        confirmation.descendants(matching: .any)
            .matching(identifier: "food.favourite.confirmation.primary").firstMatch.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Overnight oats"].exists)
        XCTAssertTrue(
            identifiedInApp("food.favourite.save-error", in: app).waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.buttons["food.favourite.retry"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testTodayActiveFastFavouriteStaleAfterConfirmationShowsScopedStateAndRetainsRetry() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouriteActiveFast: true,
            simulateFoodFavStaleAfterConfirm: true
        )
        app.buttons["food.add"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()

        let confirmation = app.descendants(matching: .any)
            .matching(identifier: "food.favourite.confirmation").firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        let primary = identifiedInContainer("food.favourite.confirmation.primary", in: confirmation)
        XCTAssertTrue(primary.waitForExistence(timeout: 5), app.debugDescription)
        primary.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)

        XCTAssertTrue(app.staticTexts["food.favourite.stale"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["food.favourite.save-error"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["food.favourite.retry"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Overnight oats"].exists)

        app.buttons["food.favourite.retry"].tap()
        XCTAssertTrue(
            app.staticTexts["food.favourite.success"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["Overnight oats"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["fast.inactive-state"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testStaleTodayFavouriteSelectionCreatesNoGhostEvent() {
        let app = launch(
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            simulateFoodFavouriteStale: true
        )
        app.buttons["food.add"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        favourite.tap()
        XCTAssertTrue(app.staticTexts["food.favourite.stale"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["food.favourite.save-error"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(foodPicker(in: app).waitForNonExistence(timeout: 5), app.debugDescription)
        assertNoGhostFoodEventAfterRelaunch(in: app)
    }

    @MainActor
    func testFoodFavouriteControlsRemainReadableAtLargeTypeInDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedFoodFavouritePopulated: true,
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        ) + ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        tapSettings(in: app)
        XCTAssertTrue(app.staticTexts["settings.food-favourites"].waitForExistence(timeout: 5), app.debugDescription)
        let row = app.buttons["settings.food-favourite.\(populatedFoodFavouriteID)"]
        reveal(row, in: app.scrollViews["settings.content"], app: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row.isHittable, row.debugDescription)
        app.tabBars.buttons["Today"].tap()
        app.buttons["food.add"].tap()
        let favourite = app.buttons["food.favourite.\(populatedFoodFavouriteID)"]
        reveal(favourite, in: foodPicker(in: app), app: app)
        XCTAssertTrue(favourite.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(favourite.isHittable, favourite.debugDescription)
        app.buttons["food.cancel"].tap()
    }
}
