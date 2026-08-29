import XCTest

final class HydrationQuickAddUITests: HydrationFavouriteUITestCase {
    @MainActor
    func testWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce() {
        let app = launch()
        tapDrinkAdd(in: app)
        let water = app.buttons["drink.favourite.\(waterFavouriteID)"]
        reveal(water, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(water.value as? String, "330 millilitres, Non-caloric")
        water.doubleTap()

        XCTAssertTrue(
            app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")
        XCTAssertTrue(
            app.navigationBars["Add a drink"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    func testNewStoreSeedsOnlyWaterAt330Millilitres() {
        let app = launch()
        tapDrinkAdd(in: app)
        let water = app.buttons["drink.favourite.\(waterFavouriteID)"]
        let picker = drinkPickerScrollView(in: app)
        XCTAssertTrue(water.waitForExistenceIfNeeded(timeout: 2), app.debugDescription)
        XCTAssertEqual(water.value as? String, "330 millilitres, Non-caloric")
        XCTAssertFalse(app.buttons["drink.favourite.00000000-0000-0000-0000-000000000002"].exists)
        XCTAssertFalse(app.buttons["drink.favourite.00000000-0000-0000-0000-000000000003"].exists)
        tapWhenReady(water, in: picker, app: app)
        let total = app.staticTexts["drink.total"]
        XCTAssertTrue(total.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        let totalUpdated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "330 ml"),
            object: total
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [totalUpdated], timeout: 5),
            .completed,
            app.debugDescription
        )
        XCTAssertEqual(total.label, "330 ml")
    }

    @MainActor
    func testFavouriteDoesNotChangeActiveFast() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedActiveFastStart: now.addingTimeInterval(-3600)
        )
        app.launch()
        XCTAssertTrue(
            app.staticTexts["fast.elapsed"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )
        dismissOptionalLiveActivityOffer(in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(
            app.buttons["drink.favourite.\(waterFavouriteID)"],
            in: drinkPickerScrollView(in: app),
            app: app
        )
        XCTAssertTrue(
            app.staticTexts["fast.elapsed"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )
    }

    @MainActor
    func testSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd() {
        let app = launch()
        tapTab("Settings", in: app)

        let waterRow = app.buttons["settings.favourite.\(waterFavouriteID)"]
        reveal(waterRow, in: settingsScrollView(in: app), app: app)
        tapWhenReady(waterRow, in: settingsScrollView(in: app), app: app)
        let waterAmount = app.textFields["settings.favourite.amount"]
        replaceText("650", in: waterAmount, app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(
            app.navigationBars["Edit favourite"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        let water = app.buttons["drink.favourite.\(waterFavouriteID)"]
        XCTAssertTrue(water.waitForExistenceIfNeeded(timeout: 2), water.debugDescription)
        XCTAssertEqual(water.value as? String, "650 millilitres, Non-caloric")
        tapWhenReady(water, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "650 ml")
    }

    @MainActor
    func testCreateCustomFavouriteShowsClassificationAndQuickAddsIt() {
        let app = launch()
        tapTab("Settings", in: app)
        let add = app.buttons["settings.favourite.add"]
        tapSettingsControl(add, in: app)
        XCTAssertTrue(
            app.navigationBars["Add favourite"].waitForExistenceIfNeeded(timeout: 2),
            app.debugDescription
        )

        replaceText("Sparkling water", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("330", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        let saved = app.buttons["Sparkling water"]
        XCTAssertTrue(saved.waitForExistenceIfNeeded(timeout: 3), saved.debugDescription)
        XCTAssertEqual(saved.value as? String, "330 millilitres, Non-caloric")

        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        let custom = app.buttons["Sparkling water"]
        XCTAssertTrue(custom.waitForExistenceIfNeeded(timeout: 3), custom.debugDescription)
        XCTAssertTrue(custom.label.contains("Sparkling water"))
        tapWhenReady(custom, in: drinkPickerScrollView(in: app), app: app)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "330 ml")
    }

    @MainActor
    func testCaloricFavouriteAddsImmediatelyWithoutFastAndUsesActiveFastChoice() {
        let noFast = launch()
        addCaloricFavouriteWithoutFast(in: noFast)

        let active = launch(seedCaloricFavouriteActiveFast: true)
        addCaloricFavouriteDuringActiveFast(in: active)
    }

    @MainActor
    private func addCaloricFavouriteWithoutFast(in app: XCUIApplication) {
        tapTab("Settings", in: app)
        tapSettingsControl(app.buttons["settings.favourite.add"], in: app)
        XCTAssertTrue(
            app.navigationBars["Add favourite"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )
        replaceText("Juice", in: app.textFields["settings.favourite.name"], app: app)
        replaceText("250", in: app.textFields["settings.favourite.amount"], app: app)
        tapWhenReady(app.switches["settings.favourite.caloric"], app: app)
        tapWhenReady(app.buttons["settings.favourite.save"], app: app)
        XCTAssertTrue(app.navigationBars["Add favourite"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.buttons["Juice"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        tapTab("Today", in: app)
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Juice"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.navigationBars["Add a drink"].waitForNonExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "250 ml")
    }

    @MainActor
    private func addCaloricFavouriteDuringActiveFast(in app: XCUIApplication) {
        XCTAssertTrue(
            app.staticTexts["fast.elapsed"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )
        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Juice"], in: drinkPickerScrollView(in: app), app: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistenceIfNeeded(timeout: 3), alert.debugDescription)
        tapWhenReady(
            alert.descendants(matching: .any)
                .matching(identifier: "drink.caloric-favourite.confirmation.cancel").firstMatch,
            app: app
        )
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "0 ml")

        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Juice"], in: drinkPickerScrollView(in: app), app: app)
        XCTAssertTrue(alert.waitForExistenceIfNeeded(timeout: 3), alert.debugDescription)
        tapWhenReady(
            alert.descendants(matching: .any)
                .matching(identifier: "drink.caloric-favourite.confirmation.primary").firstMatch,
            app: app
        )
        XCTAssertTrue(
            app.staticTexts["drink.total"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )
        XCTAssertEqual(app.staticTexts["drink.total"].label, "250 ml")
        XCTAssertTrue(
            app.staticTexts["fast.elapsed"].waitForNonExistence(timeout: 3),
            app.debugDescription
        )
    }

    @MainActor
    func testCaloricFavouriteFailureStaysVisibleAndCanBeRetriedDuringActiveFast() {
        let app = launch(
            seedCaloricFavouriteActiveFast: true,
            simulateDrinkSaveFailure: true
        )
        XCTAssertTrue(
            app.staticTexts["fast.elapsed"].waitForExistenceIfNeeded(timeout: 3),
            app.debugDescription
        )

        tapDrinkAdd(in: app)
        tapWhenReady(app.buttons["Juice"], in: drinkPickerScrollView(in: app), app: app)
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistenceIfNeeded(timeout: 3), confirmation.debugDescription)
        tapWhenReady(
            confirmation.descendants(matching: .any)
                .matching(identifier: "drink.caloric-favourite.confirmation.primary").firstMatch,
            app: app
        )

        let error = app.staticTexts["drink.caloric-favourite.save-error"]
        XCTAssertTrue(error.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertTrue(error.label.contains("drink and fast couldn’t be saved"))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        XCTAssertEqual(app.staticTexts["drink.total"].label, "0 ml")

        let retry = app.buttons["drink.caloric-favourite.retry"]
        tapWhenReady(retry, in: app.scrollViews["today.content"], app: app)
        XCTAssertTrue(error.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
        XCTAssertTrue(retry.exists)
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }
}
