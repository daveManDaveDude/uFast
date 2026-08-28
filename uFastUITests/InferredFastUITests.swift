import XCTest

// swiftlint:disable type_body_length file_length

final class InferredFastUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let historicalID = "10200000-0000-0000-0000-000000000001"
    private let currentID = "10200000-0000-0000-0000-000000000002"
    private let suppressedID = "10300000-0000-0000-0000-000000000001"
    private let capHydrationID = "10400000-0000-0000-0000-000000000001"
    private let postFoodID = "10400000-0000-0000-0000-000000000003"
    private let eligibilityHydrationID = "10400000-0000-0000-0000-000000000004"

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
        let historical = fastButton(in: historicalDetails, containing: "Save fast available")
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
        let current = fastButton(in: currentDetails, containing: "Start fast available")
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
    func testHistoricalInferredFastDeleteConfirmationCancelAndCommittedDeleteAreObservable() {
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
        let historical = fastButton(in: historicalDetails, containing: "Save fast available")
        XCTAssertTrue(historical.waitForExistence(timeout: 5), app.debugDescription)
        tapFullyVisible(historical, in: historyContent, app: app)

        let delete = app.buttons["history.inferred.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), app.debugDescription)
        delete.tap()
        let cancel = app.buttons["history.inferred.delete.cancel"].firstMatch
        let confirmation = app.buttons["history.inferred.delete.confirm"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        let accessibilitySnapshot = app.debugDescription
        XCTAssertTrue(
            accessibilitySnapshot.contains("This hides the inferred fast from History.")
                && accessibilitySnapshot.contains("Your food or drink record will stay."),
            accessibilitySnapshot
        )
        cancel.tap()
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(historical.exists, app.debugDescription)

        delete.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        confirmation.tap()

        XCTAssertTrue(delete.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(historical.waitForNonExistence(timeout: 5), app.debugDescription)
        let recovery = app.otherElements[
            "history.inferred.hidden.food.\(historicalID)"
        ]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            recovery.label.contains("Hidden inferred fast")
                && recovery.label.contains("start")
                && recovery.label.contains("end"),
            recovery.debugDescription
        )
    }

    @MainActor
    func testInProgressInferredFastDeleteConfirmationCommitLeavesSourceBoundRecovery() {
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
        let details = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
        let running = fastButton(in: details, containing: "Start fast available")
        XCTAssertTrue(running.waitForExistence(timeout: 5), app.debugDescription)
        tapFullyVisible(running, in: historyContent, app: app)

        let delete = app.buttons["history.inferred.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), app.debugDescription)
        delete.tap()
        let confirmation = app.buttons["history.inferred.delete.confirm"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.debugDescription.contains("This hides the inferred fast from History."),
            app.debugDescription
        )
        confirmation.tap()

        XCTAssertTrue(delete.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(running.waitForNonExistence(timeout: 5), app.debugDescription)
        let recovery = app.otherElements[
            "history.inferred.hidden.food.\(currentID)"
        ]
        if !recovery.exists {
            historyContent.swipeUp()
        }
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["history.inferred.reenable.food.\(currentID)"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testFoodAndCaloricHydrationEligibilityAndCapTransitionsAreObservable() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedInferredFastEligibility: true,
            startsOnHistory: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        historyContent.swipeUp()
        let exactHydration = app.otherElements[
            "history.inferred.hidden.hydration.\(eligibilityHydrationID)"
        ]
        XCTAssertTrue(exactHydration.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            exactHydration.label.contains("Hidden inferred fast")
                && exactHydration.label.contains("source drink Coffee"),
            exactHydration.debugDescription
        )
        XCTAssertTrue(
            app.buttons["history.inferred.reenable.hydration.\(eligibilityHydrationID)"]
                .waitForExistence(timeout: 5),
            app.debugDescription
        )

        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)
        historyContent.swipeUp()
        let postFood = app.otherElements["history.inferred.hidden.food.\(postFoodID)"]
        XCTAssertTrue(postFood.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(postFood.label.contains("source food Post food"), postFood.debugDescription)
        XCTAssertEqual(
            app.otherElements.matching(identifier: "history.inferred.hidden.food.\(postFoodID)").count,
            1,
            app.debugDescription
        )

        previousDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)
        historyContent.swipeUp()
        let exactCap = app.otherElements[
            "history.inferred.hidden.hydration.\(capHydrationID)"
        ]
        XCTAssertTrue(exactCap.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            exactCap.label.contains("source drink Coffee")
                && exactCap.label.contains("start")
                && exactCap.label.contains("end"),
            exactCap.debugDescription
        )
        XCTAssertEqual(
            app.otherElements.matching(identifier: "history.inferred.hidden.hydration.\(capHydrationID)").count,
            1,
            app.debugDescription
        )
    }

    @MainActor
    func testFoodBeforeEligibilityIsAbsentAfterClockRewind() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedInferredFast: true,
            startsOnHistory: true
        )
        app.launch()

        let details = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
        let exactCurrent = fastButton(in: details, containing: "Start fast available")
        XCTAssertTrue(exactCurrent.waitForExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(
            clockNow: now.addingTimeInterval(-60),
            startsOnHistory: true
        )
        app.launch()
        let rewoundDetails = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(rewoundDetails.waitForExistence(timeout: 5), app.debugDescription)
        let rewoundCurrent = fastButton(in: rewoundDetails, containing: "Start fast available")
        XCTAssertTrue(rewoundCurrent.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testSuppressedInferredFastOffersOneAccessibleRecoveryAndRestoresAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedSuppressedInferredFast: true,
            startsOnHistory: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        historyContent.swipeUp()
        let recovery = app.otherElements[
            "history.inferred.hidden.food.\(suppressedID)"
        ]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        let reenable = app.buttons["history.inferred.reenable.food.\(suppressedID)"]
        XCTAssertTrue(reenable.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(reenable.isHittable, reenable.debugDescription)
        reenable.tap()

        XCTAssertTrue(reenable.waitForNonExistence(timeout: 5), app.debugDescription)
        let details = app.otherElements["history.event-info-panel"]
        let restored = fastButton(in: details, containing: "source food Hidden inferred supper")
        XCTAssertTrue(restored.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(restored.label.contains("Inferred fast"), restored.debugDescription)

        app.terminate()
        app.launchArguments = launchArguments(startsOnHistory: true)
        app.launch()
        let relaunchedDetails = app.otherElements["history.event-info-panel"]
        let relaunchedRestored = fastButton(
            in: relaunchedDetails,
            containing: "source food Hidden inferred supper"
        )
        XCTAssertTrue(relaunchedRestored.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testInferredFastDeleteFailureRetainsCandidateAndShowsAccessibleFeedback() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedInferredFast: true,
            startsOnHistory: true,
            simulateSuppressionSaveFailure: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForSettledHistory(in: app), app.debugDescription)

        let details = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
        let candidate = fastButton(in: details, containing: "Save fast available")
        XCTAssertTrue(candidate.waitForExistence(timeout: 5), app.debugDescription)
        tapFullyVisible(candidate, in: historyContent, app: app)

        let delete = app.buttons["history.inferred.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), app.debugDescription)
        delete.tap()
        let confirmation = app.buttons["history.inferred.delete.confirm"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        confirmation.tap()

        let error = app.staticTexts["history.inferred.delete-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(
            error.label,
            "This inferred fast could not be hidden. Your local records were unchanged."
        )
        XCTAssertTrue(delete.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(candidate.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testInferredFastStaleReenableShowsAccessibleFeedbackAndRetainsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedSuppressedInferredFast: true,
            startsOnHistory: true,
            simulateSuppressionReenableStale: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        historyContent.swipeUp()
        let recovery = app.otherElements["history.inferred.hidden.food.\(suppressedID)"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        let reenable = app.buttons["history.inferred.reenable.food.\(suppressedID)"]
        XCTAssertTrue(reenable.waitForExistence(timeout: 5), app.debugDescription)
        reenable.tap()

        let error = app.staticTexts["history.inferred.reenable-unavailable"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(
            error.label,
            "This inferred fast is no longer available. History was refreshed."
        )
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(reenable.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testInferredFastReenableFailureShowsAccessibleFeedbackAndRetainsRecovery() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(
            resetData: true,
            seedOnboarded: true,
            seedSuppressedInferredFast: true,
            startsOnHistory: true,
            simulateSuppressionSaveFailure: true
        )
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityXXXL"
        app.launch()

        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        historyContent.swipeUp()
        let recovery = app.otherElements[
            "history.inferred.hidden.food.\(suppressedID)"
        ]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        let reenable = app.buttons["history.inferred.reenable.food.\(suppressedID)"]
        XCTAssertTrue(reenable.waitForExistence(timeout: 5), app.debugDescription)
        reenable.tap()

        let error = app.staticTexts["history.inferred.reenable-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(
            error.label,
            "This inferred fast could not be re-enabled. Your local records were unchanged."
        )
        XCTAssertTrue(recovery.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(reenable.waitForExistence(timeout: 5), app.debugDescription)
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
    private func fastButton(in details: XCUIElement, containing text: String) -> XCUIElement {
        details.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func launchArguments(
        clockNow: Date? = nil,
        resetData: Bool = false,
        seedOnboarded: Bool = false,
        seedInferredFast: Bool = false,
        seedInferredFastEligibility: Bool = false,
        seedSuppressedInferredFast: Bool = false,
        startsOnHistory: Bool = false,
        simulateSuppressionSaveFailure: Bool = false,
        simulateSuppressionReenableStale: Bool = false
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: resetData,
            seedOnboarded: seedOnboarded,
            fixedNow: clockNow ?? now,
            seedInferredFast: seedInferredFast,
            seedInferredFastEligibility: seedInferredFastEligibility,
            seedSuppressedInferredFast: seedSuppressedInferredFast,
            startsOnHistory: startsOnHistory,
            simulateSuppressionSaveFailure: simulateSuppressionSaveFailure,
            simulateSuppressionReenableStale: simulateSuppressionReenableStale
        ).arguments
    }
}
