import XCTest

extension FoodFavouriteLifecycleUITests {
    func foodPicker(in app: XCUIApplication) -> XCUIElement {
        identifiedInApp("food.picker", in: app)
    }

    func identifiedInApp(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func identifiedInContainer(_ identifier: String, in container: XCUIElement) -> XCUIElement {
        container.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func reveal(_ element: XCUIElement, in scrollView: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        guard scrollView.isHittable else {
            XCTFail(scrollView.debugDescription)
            return
        }

        // Large Dynamic Type can place a target thousands of points below the
        // viewport. Scroll the identified container by a fixed amount so each
        // attempt is bounded and deterministic without depending on swipe
        // velocity or an app-wide gesture.
        for _ in 0 ..< 20 {
            guard !element.exists || !element.isHittable else { return }
            scrollView.swipeUp(velocity: .slow)
        }

        XCTAssertTrue(element.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(element.isHittable, element.debugDescription)
    }

    @MainActor
    func assertNoGhostFoodEventAfterRelaunch(in app: XCUIApplication) {
        let todayContent = app.scrollViews["today.content"]
        XCTAssertTrue(todayContent.waitForExistence(timeout: 5), app.debugDescription)
        let todayTimeline = identifiedInContainer("timeline.empty", in: todayContent)
        reveal(todayTimeline, in: todayContent, app: app)
        XCTAssertTrue(todayTimeline.waitForExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(resetData: false, seedOnboarded: true)
        app.launch()
        XCTAssertTrue(app.buttons["food.add"].waitForExistence(timeout: 5), app.debugDescription)

        let relaunchedTodayContent = app.scrollViews["today.content"]
        XCTAssertTrue(relaunchedTodayContent.waitForExistence(timeout: 5), app.debugDescription)
        let relaunchedTodayTimeline = identifiedInContainer("timeline.empty", in: relaunchedTodayContent)
        reveal(relaunchedTodayTimeline, in: relaunchedTodayContent, app: app)
        XCTAssertTrue(relaunchedTodayTimeline.waitForExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["History"].tap()
        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        let historyEmpty = identifiedInContainer("history.empty", in: historyContent)
        reveal(historyEmpty, in: historyContent, app: app)
        XCTAssertTrue(historyEmpty.waitForExistence(timeout: 5), app.debugDescription)
    }

    func firstSavedFoodFavouriteRow(in app: XCUIApplication) -> XCUIElement {
        let prefix = "settings.food-favourite."
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier != %@",
            prefix,
            "\(prefix)add"
        )
        return app.buttons.matching(predicate).firstMatch
    }

    @MainActor
    func launch(
        resetData: Bool = true,
        seedOnboarded: Bool = false,
        seedFoodFavouritePopulated: Bool = false,
        seedFoodFavouriteActiveFast: Bool = false,
        startsOnHistory: Bool = false,
        simulateFoodSaveFailure: Bool = false,
        simulateFoodFavouriteSaveFailure: Bool = false,
        simulateFoodFavouriteStale: Bool = false,
        simulateFoodFavStaleAfterConfirm: Bool = false,
        simulateDeleteAllFailure: Bool = false,
        simulateFoodFavouriteMigrationFailure: Bool = false,
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: resetData,
            seedOnboarded: seedOnboarded,
            seedFoodFavouritePopulated: seedFoodFavouritePopulated,
            seedFoodFavouriteActiveFast: seedFoodFavouriteActiveFast,
            startsOnHistory: startsOnHistory,
            simulateFoodSaveFailure: simulateFoodSaveFailure,
            simulateFoodFavouriteSaveFailure: simulateFoodFavouriteSaveFailure,
            simulateFoodFavouriteStale: simulateFoodFavouriteStale,
            simulateFoodFavStaleAfterConfirm: simulateFoodFavStaleAfterConfirm,
            simulateDeleteAllFailure: simulateDeleteAllFailure,
            simulateFoodFavouriteMigrationFailure: simulateFoodFavouriteMigrationFailure,
            preferredContentSizeCategory: preferredContentSizeCategory
        )
        app.launch()
        let launchTarget = startsOnHistory ? "history.previous-day" : "food.add"
        XCTAssertTrue(app.buttons[launchTarget].waitForExistence(timeout: 5), app.debugDescription)
        return app
    }

    @MainActor
    func tapSettings(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), app.debugDescription)
        tab.tap()
        XCTAssertTrue(
            app.staticTexts["screen-title.settings"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    func launchArguments(
        resetData: Bool = false,
        seedOnboarded: Bool = false,
        seedFoodFavouritePopulated: Bool = false,
        seedFoodFavouriteActiveFast: Bool = false,
        startsOnHistory: Bool = false,
        simulateFoodSaveFailure: Bool = false,
        simulateFoodFavouriteSaveFailure: Bool = false,
        simulateFoodFavouriteStale: Bool = false,
        simulateFoodFavStaleAfterConfirm: Bool = false,
        simulateDeleteAllFailure: Bool = false,
        simulateFoodFavouriteMigrationFailure: Bool = false,
        preferredContentSizeCategory: String? = nil
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: seedOnboarded,
            fixedNow: Date(timeIntervalSince1970: 1_800_000_000),
            seedFoodFavouritePopulated: seedFoodFavouritePopulated,
            seedFoodFavouriteActiveFast: seedFoodFavouriteActiveFast,
            startsOnHistory: startsOnHistory,
            simulateFoodSaveFailure: simulateFoodSaveFailure,
            simulateDeleteAllFailure: simulateDeleteAllFailure,
            simulateFoodFavouriteMigrationFailure: simulateFoodFavouriteMigrationFailure,
            simulateFoodFavouriteSaveFailure: simulateFoodFavouriteSaveFailure,
            simulateFoodFavouriteStale: simulateFoodFavouriteStale,
            simulateFoodFavStaleAfterConfirm: simulateFoodFavStaleAfterConfirm,
            preferredContentSizeCategory: preferredContentSizeCategory
        ).arguments
    }

    @MainActor
    func replaceText(_ value: String, in element: XCUIElement, app: XCUIApplication) {
        element.tap()
        element.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        element.typeText(value)
    }
}
