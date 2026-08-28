import XCTest

final class InferredFastUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let historicalID = "10200000-0000-0000-0000-000000000001"
    private let currentID = "10200000-0000-0000-0000-000000000002"

    @MainActor
    func testInferredFastSettingPersistsAcrossRelaunchAndHasStableAccessibility() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(resetData: true, seedOnboarded: true)
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        let toggle = app.switches["settings.inferred-fasts.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        let disabled = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.value as? String == "0"
            },
            object: toggle
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [disabled], timeout: 5),
            .completed,
            app.debugDescription
        )

        app.terminate()
        app.launchArguments = launchArguments()
        app.launch()
        app.tabBars.buttons["Settings"].tap()

        let relaunchedToggle = app.switches["settings.inferred-fasts.toggle"]
        XCTAssertTrue(relaunchedToggle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(relaunchedToggle.value as? String, "0")
    }

    @MainActor
    func testHistoricalSaveAndCurrentStartUseExplicitAccessibleActionsAtDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedInferredFast: true,
            startsOnHistory: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)

        let historicalDetails = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(historicalDetails.waitForExistence(timeout: 5), app.debugDescription)
        let historical = historicalDetails.buttons["history.fast.\(historicalID)"]
        XCTAssertTrue(historical.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(historical.label.contains("Inferred fast"), historical.debugDescription)
        XCTAssertTrue(historical.label.contains("source food"), historical.debugDescription)
        tapFullyVisible(historical, in: historyContent, app: app)

        let save = app.buttons["history.inferred.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Inferred fast"].exists)
        let historicalDuration = app.staticTexts["history.inferred.duration"]
        XCTAssertTrue(historicalDuration.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(historicalDuration.label, "Duration, 12 hours")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), app.debugDescription)

        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        nextDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)

        let currentDetails = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(currentDetails.waitForExistence(timeout: 5), app.debugDescription)
        let current = currentDetails.buttons["history.fast.\(currentID)"]
        XCTAssertTrue(current.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(current.label.contains("Inferred fast in progress"), current.debugDescription)
        tapFullyVisible(current, in: historyContent, app: app)

        let start = app.buttons["history.inferred.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Inferred fast in progress"].exists)
        let currentDuration = app.staticTexts["history.inferred.duration"]
        XCTAssertTrue(currentDuration.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(currentDuration.label, "Duration, 8 hours")
        XCTAssertTrue(start.isHittable, start.debugDescription)
        app.buttons["history.inferred.cancel"].tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func waitForSettledHistory(in app: XCUIApplication) -> Bool {
        let carousel = app.scrollViews["history.day-carousel"]
        guard carousel.waitForExistence(timeout: 5) else { return false }
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        return XCTWaiter.wait(for: [settled], timeout: 5) == .completed
    }

    @MainActor
    private func tapFullyVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication
    ) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2), app.debugDescription)
        if !element.isHittable || element.frame.maxY > app.frame.maxY - 120 {
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(
                    forDuration: 0.05,
                    thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
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

    @MainActor
    private func launchArguments(
        resetData: Bool = false,
        seedOnboarded: Bool = false,
        seedInferredFast: Bool = false,
        startsOnHistory: Bool = false
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: seedOnboarded,
            fixedNow: now,
            seedInferredFast: seedInferredFast,
            startsOnHistory: startsOnHistory
        ).arguments
    }
}
