import XCTest

extension HistoryUITests {
    @MainActor
    func dismissOptionalLiveActivityOffer(in app: XCUIApplication) {
        let alert = app.alerts["See your fast at a glance?"]
        guard alert.exists || alert.waitForExistence(timeout: 0.25) else { return }
        let notNow = alert.buttons["Not Now"]
        XCTAssertTrue(waitForHittable(notNow, app: app), alert.debugDescription)
        notNow.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func waitForHittable(
        _ element: XCUIElement,
        app _: XCUIApplication,
        timeout: TimeInterval = 5
    ) -> Bool {
        if element.exists, element.isHittable {
            return true
        }
        guard element.waitForExistence(timeout: timeout) else { return false }
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.isHittable == true
            },
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitForExistenceIfNeeded(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        element.exists || element.waitForExistence(timeout: timeout)
    }

    @MainActor
    func completeOnboarding(in app: XCUIApplication) {
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.exists || todayTab.waitForExistence(timeout: 0.25) {
            dismissOptionalLiveActivityOffer(in: app)
            return
        }
        let continueButton = app.buttons["goal.continue"]
        if !continueButton.exists {
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5), app.debugDescription)
        }
        continueButton.tap()
        if !todayTab.exists {
            XCTAssertTrue(todayTab.waitForExistence(timeout: 5), app.debugDescription)
        }
        dismissOptionalLiveActivityOffer(in: app)
    }

    @MainActor
    func selectHistoryTab(in app: XCUIApplication) {
        dismissOptionalLiveActivityOffer(in: app)
        let tabBar = app.tabBars.firstMatch
        if !tabBar.exists {
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), app.debugDescription)
        }
        let historyTab = tabBar.buttons["History"]
        if !historyTab.exists {
            XCTAssertTrue(historyTab.waitForExistence(timeout: 5), tabBar.debugDescription)
        }
        XCTAssertTrue(waitForHittable(historyTab, app: app), tabBar.debugDescription)
        historyTab.tap()
        let title = app.staticTexts["screen-title.history"]
        if !title.exists {
            XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        }
    }

    @MainActor
    func selectTodayTab(in app: XCUIApplication) {
        let tabBar = app.tabBars.firstMatch
        if !tabBar.exists {
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), app.debugDescription)
        }
        let todayTab = tabBar.buttons["Today"]
        if !todayTab.exists {
            XCTAssertTrue(todayTab.waitForExistence(timeout: 5), tabBar.debugDescription)
        }
        XCTAssertTrue(waitForHittable(todayTab, app: app), tabBar.debugDescription)
        todayTab.tap()
        let title = app.staticTexts["screen-title.today"]
        if !title.exists {
            XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        }
    }

    @MainActor
    func openHistory(in app: XCUIApplication) {
        let historyTitle = app.staticTexts["screen-title.history"]
        if !historyTitle.exists {
            XCTAssertTrue(historyTitle.waitForExistence(timeout: 5), app.debugDescription)
        }
        if historyTitle.isHittable {
            return
        }
        let visibleTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: historyTitle
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [visibleTitle], timeout: 5),
            .completed,
            app.debugDescription
        )
    }

    @MainActor
    func waitForHistoryCarouselToSettle(in app: XCUIApplication) -> Bool {
        let carousel = app.scrollViews["history.day-carousel"]
        guard carousel.exists || carousel.waitForExistence(timeout: 5) else { return false }
        if carousel.value as? String == "Settled" {
            return true
        }
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        return XCTWaiter.wait(for: [settled], timeout: 5) == .completed
    }

    @MainActor
    func waitForHistorySelection(
        _ selectedDate: XCUIElement,
        expectedLabel: String
    ) -> Bool {
        if selectedDate.exists, selectedDate.label == expectedLabel {
            return true
        }
        let selection = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedLabel),
            object: selectedDate
        )
        return XCTWaiter.wait(for: [selection], timeout: 5) == .completed
    }

    @MainActor
    func recordedFastRow(in app: XCUIApplication) -> XCUIElement {
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
        if !row.exists {
            XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        }
        if !row.isHittable {
            let content = app.scrollViews["history.content"]
            if !content.exists {
                XCTAssertTrue(content.waitForExistence(timeout: 5), app.debugDescription)
            }
            content.swipeUp()
        }
        return row
    }

    @MainActor
    func tapFullyVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication
    ) {
        if !scrollView.exists {
            XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        }
        let elementIsFullyVisible = element.exists
            && element.isHittable
            && element.frame.minY >= scrollView.frame.minY + 8
            && element.frame.maxY <= app.frame.maxY - 120
        if elementIsFullyVisible {
            element.tap()
            return
        }
        if !element.isHittable || element.frame.maxY > app.frame.maxY - 120 {
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(
                    forDuration: 0.05,
                    thenDragTo: scrollView.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
                    )
                )
        }
        let fullyVisible = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let candidate = object as? XCUIElement else { return false }
                return candidate.isHittable
                    && candidate.frame.minY >= scrollView.frame.minY + 8
                    && candidate.frame.maxY <= app.frame.maxY - 120
            },
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [fullyVisible], timeout: 5),
            .completed,
            app.debugDescription
        )
        element.tap()
    }

    func launchArguments(
        now: Date,
        resetData: Bool = false,
        seedOnboarded: Bool = true,
        seedSlice3History: Bool = false,
        seedHistoryMidnightSeam: Bool = false,
        seedHistoryMidnightSeamExtended: Bool = false,
        suppressAutomaticLiveActivityOffer: Bool = false,
        startsOnHistory: Bool = false,
        simulateHistoryFailure: Bool = false,
        simulateFoodSaveFailure: Bool = false,
        appleLocale: String? = nil,
        timeZone: String? = nil
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: seedOnboarded,
            fixedNow: now,
            seedSlice3History: seedSlice3History,
            seedHistoryMidnightSeam: seedHistoryMidnightSeam,
            seedHistoryMidnightSeamExtended: seedHistoryMidnightSeamExtended,
            suppressAutomaticLiveActivityOffer: suppressAutomaticLiveActivityOffer,
            startsOnHistory: startsOnHistory,
            simulateFastHistoryFailure: simulateHistoryFailure,
            simulateFoodSaveFailure: simulateFoodSaveFailure,
            appleLocale: appleLocale,
            timeZone: timeZone
        ).arguments
    }

    func londonLaunchArguments(
        now: Date,
        resetData: Bool = false,
        suppressAutomaticLiveActivityOffer: Bool = false
    ) -> [String] {
        launchArguments(
            now: now,
            resetData: resetData,
            suppressAutomaticLiveActivityOffer: suppressAutomaticLiveActivityOffer,
            appleLocale: "en_GB",
            timeZone: "Europe/London"
        )
    }
}
