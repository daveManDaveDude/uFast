import XCTest

extension HydrationFavouriteUITestCase {
    @MainActor
    func waitForLabel(
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
    func replaceText(_ value: String, in field: XCUIElement, app: XCUIApplication) {
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
    func dismissKeyboard(in app: XCUIApplication) {
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
    func dismissOptionalLiveActivityOffer(in app: XCUIApplication) {
        let alert = app.alerts["See your fast at a glance?"]
        guard alert.waitForExistence(timeout: 1) else { return }
        tapWhenReady(alert.buttons["Not Now"], app: app)
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    func launchArguments(
        resetData: Bool,
        seedActiveFastStart: Date? = nil,
        seedFavouritePopulated: Bool = false,
        seedCaloricFavouriteActiveFast: Bool = false,
        simulateDrinkSaveFailure: Bool = false,
        simulateFavouriteSaveFailure: Bool = false,
        simulateDeleteAllFailure: Bool = false
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: true,
            fixedNow: now,
            seedActiveFastStart: seedActiveFastStart,
            seedFavouritePopulated: seedFavouritePopulated,
            seedCaloricFavouriteActiveFast: seedCaloricFavouriteActiveFast,
            simulateDrinkSaveFailure: simulateDrinkSaveFailure,
            simulateFavouriteSaveFailure: simulateFavouriteSaveFailure,
            simulateDeleteAllFailure: simulateDeleteAllFailure
        ).arguments
    }
}
