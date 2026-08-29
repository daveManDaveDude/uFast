import XCTest

extension XCUIElement {
    @MainActor
    func waitForExistenceIfNeeded(timeout: TimeInterval = 5) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }
}

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
        if !scrollView.exists {
            XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        }
        return scrollView
    }

    @MainActor
    func drinkPickerScrollView(in app: XCUIApplication) -> XCUIElement {
        let scrollView = app.scrollViews["drink.picker"]
        if !scrollView.exists {
            XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        }
        return scrollView
    }

    @MainActor
    func editorScrollView(in app: XCUIApplication) -> XCUIElement {
        let editor = app.descendants(matching: .any)
            .matching(identifier: "settings.favourite.editor").firstMatch
        if !editor.exists {
            XCTAssertTrue(editor.waitForExistence(timeout: 5), app.debugDescription)
        }
        return editor
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
        guard buttons.firstMatch.exists || buttons.firstMatch.waitForExistence(timeout: 2) else {
            XCTFail(app.debugDescription)
            return false
        }
        for index in 0 ..< buttons.count {
            let button = buttons.element(boundBy: index)
            guard button.exists || button.waitForExistence(timeout: 2) else { continue }
            if button.isHittable {
                button.tap()
                return true
            }
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
        if element.exists, element.isHittable {
            return true
        }
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
        guard element.exists || element.waitForExistence(timeout: 5) else {
            XCTFail(app.debugDescription)
            return false
        }
        if !element.isEnabled {
            return true
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
        if !scrollView.exists {
            guard scrollView.waitForExistence(timeout: 5) else {
                XCTFail(app.debugDescription)
                return
            }
        }
        if !element.exists {
            guard element.waitForExistence(timeout: 5) else {
                XCTFail(app.debugDescription)
                return
            }
        }
        guard !element.isHittable else { return }
        guard scrollView.isHittable else {
            XCTFail(app.debugDescription)
            return
        }

        for _ in 0 ..< 6 where !element.isHittable {
            let elementFrame = element.frame
            let scrollFrame = scrollView.frame
            if elementFrame.minY < scrollFrame.minY {
                scrollView.swipeDown(velocity: .fast)
            } else {
                scrollView.swipeUp(velocity: .fast)
            }
        }

        XCTAssertTrue(waitForHittable(element, app: app), app.debugDescription)
    }
}
