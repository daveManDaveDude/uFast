import XCTest

extension HydrationFavouriteUITestCase {
    @MainActor
    func launch(
        resetData: Bool = true,
        seedActiveFastStart: Date? = nil,
        seedFavouritePopulated: Bool = false,
        seedCaloricFavouriteActiveFast: Bool = false,
        simulateDrinkSaveFailure: Bool = false,
        simulateFavouriteSaveFailure: Bool = false,
        simulateDeleteAllFailure: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: resetData,
            seedActiveFastStart: seedActiveFastStart,
            seedFavouritePopulated: seedFavouritePopulated,
            seedCaloricFavouriteActiveFast: seedCaloricFavouriteActiveFast,
            simulateDrinkSaveFailure: simulateDrinkSaveFailure,
            simulateFavouriteSaveFailure: simulateFavouriteSaveFailure,
            simulateDeleteAllFailure: simulateDeleteAllFailure
        )
        app.launch()
        dismissOptionalLiveActivityOffer(in: app)
        let drinkAdd = app.buttons["drink.add"]
        XCTAssertTrue(drinkAdd.waitForExistence(timeout: 5), app.debugDescription)
        reveal(drinkAdd, in: app.scrollViews["today.content"], app: app)
        return app
    }

    @MainActor
    func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        tapWhenReady(tab, app: app)
    }

    @MainActor
    func tapDrinkAdd(in app: XCUIApplication) {
        tapWhenReady(
            app.buttons["drink.add"],
            in: app.scrollViews["today.content"],
            app: app
        )
    }

    @MainActor
    func tapSettingsControl(_ control: XCUIElement, in app: XCUIApplication) {
        tapWhenReady(control, in: settingsScrollView(in: app), app: app)
    }

    @MainActor
    func settingsScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollView = app.scrollViews["settings.content"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        return scrollView
    }

    @MainActor
    func drinkPickerScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollView = app.scrollViews["drink.picker"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        return scrollView
    }

    @MainActor
    func editorScrollView(in app: XCUIApplication) -> XCUIElement {
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
    func tapWhenReady(
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
    func tapAlertButton(
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
    func waitForHittable(_ element: XCUIElement, app: XCUIApplication) -> Bool {
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
    func waitForDisabled(_ element: XCUIElement, app: XCUIApplication) -> Bool {
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
    func reveal(
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
}
