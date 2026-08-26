import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length trailing_comma

final class HydrationCustomAndTimelineUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testCustomDrinkValidationCreateEditAndDeleteUpdatesTimelineAndTotal() {
        let app = launch()
        openCustomEditor(in: app)
        XCTAssertFalse(app.buttons["drink.editor.save"].isEnabled)
        XCTAssertTrue(app.staticTexts["drink.volume.validation"].exists)
        app.textFields["drink.name"].tap(); app.textFields["drink.name"].typeText("Kombucha")
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].typeText("250")
        app.buttons["drink.editor.save"].tap()

        XCTAssertTrue(app.staticTexts["Kombucha"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["drink.total"].label, "250 ml")
        XCTAssertTrue(app.staticTexts["Today timeline"].exists)

        app.staticTexts["Kombucha"].tap()
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 2))
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].clearAndType("400")
        app.buttons["drink.editor.save"].tap()
        XCTAssertEqual(app.staticTexts["drink.total"].label, "400 ml")

        app.staticTexts["Kombucha"].tap()
        if !app.buttons["drink.delete"].exists {
            app.swipeUp()
        }
        app.buttons["drink.delete"].tap()
        let deleteAlert = app.alerts.firstMatch
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 2), app.debugDescription)
        deleteAlert.descendants(matching: .any)
            .matching(identifier: "drink.delete.confirm").firstMatch.tap()
        XCTAssertEqual(app.staticTexts["drink.total"].label, "0 ml")
        XCTAssertTrue(app.staticTexts["timeline.empty"].exists)
    }

    @MainActor
    func testCaloricCustomDrinkRequiresMandatoryConfirmationAndCancelMutatesNothing() {
        let app = launch(activeFastStart: now.addingTimeInterval(-3600))
        openCustomEditor(in: app)
        app.textFields["drink.name"].tap(); app.textFields["drink.name"].typeText("Juice")
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].typeText("200")
        app.buttons["drink.classification.caloric"].tap()
        app.buttons["drink.editor.save"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["This entry is during your recorded fast."].exists)
        XCTAssertTrue(
            alert.descendants(matching: .any)
                .matching(identifier: "drink.confirmation.primary").firstMatch.exists
        )
        XCTAssertTrue(
            alert.descendants(matching: .any)
                .matching(identifier: "drink.confirmation.cancel").firstMatch.exists
        )
        XCTAssertEqual(
            alert.descendants(matching: .any)
                .matching(identifier: "drink.confirmation.primary").firstMatch.label,
            "Save and end fast"
        )
        XCTAssertFalse(alert.buttons["Save entry only"].exists)
        alert.descendants(matching: .any)
            .matching(identifier: "drink.confirmation.cancel").firstMatch.tap()
        app.buttons["drink.cancel"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
        XCTAssertFalse(app.staticTexts["Juice"].exists)
    }

    @MainActor
    func testPseudolocalizedCaloricDrinkConfirmationUsesStableIdentifiers() {
        let app = launch(activeFastStart: now.addingTimeInterval(-3600), pseudolocalization: true)
        openCustomEditor(in: app)
        app.textFields["drink.name"].tap(); app.textFields["drink.name"].typeText("Juice")
        app.textFields["drink.volume"].tap(); app.textFields["drink.volume"].typeText("200")
        app.buttons["drink.classification.caloric"].tap()
        app.buttons["drink.editor.save"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let primary = alert.descendants(matching: .any)
            .matching(identifier: "drink.confirmation.primary").firstMatch
        let consequence = alert.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH '［'"))
            .firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(consequence.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(primary.label.hasPrefix("［"), app.debugDescription)
        XCTAssertTrue(consequence.label.hasPrefix("［"), app.debugDescription)
        primary.tap()
        XCTAssertTrue(app.staticTexts["fast.inactive-state"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testExistingDrinkRowOpensFromItsOpenAreaDuringAnActiveFast() {
        let app = launch(activeFastStart: now.addingTimeInterval(-3600))
        app.buttons["drink.add"].tap()
        app.buttons["drink.favourite.00000000-0000-0000-0000-000000000001"].tap()

        let drinkRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.'")
        ).firstMatch
        XCTAssertTrue(drinkRow.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 4 where !drinkRow.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(drinkRow.isHittable, app.debugDescription)

        drinkRow.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.78)).tap()

        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testExistingFoodRowOpensFromItsOpenAreaDuringAnActiveFast() {
        let app = launch()
        app.buttons["food.add"].tap()
        if app.buttons["food.custom"].waitForExistence(timeout: 5) {
            app.buttons["food.custom"].tap()
        }
        app.textFields["food.description"].typeText("Lunch")
        let saveFood = app.buttons["food.save"]
        XCTAssertTrue(saveFood.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForEnabled(saveFood), app.debugDescription)
        saveFood.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Lunch"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)

        let foodRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'timeline.entry.'")
        ).firstMatch
        XCTAssertTrue(foodRow.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 4 where !foodRow.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(foodRow.isHittable, app.debugDescription)

        foodRow.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.78)).tap()

        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func openCustomEditor(in app: XCUIApplication) {
        let add = app.buttons["drink.add"]
        if !add.isHittable {
            app.swipeUp()
        }
        add.tap()
        app.buttons["drink.custom"].tap()
        XCTAssertTrue(app.textFields["drink.name"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func launch(activeFastStart: Date? = nil, pseudolocalization: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = UITestLaunchConfiguration(
            resetData: true,
            pseudolocalization: pseudolocalization,
            seedOnboarded: true,
            fixedNow: now,
            seedActiveFastStart: activeFastStart,
            suppressAutomaticLiveActivityOffer: true
        ).arguments
        app.launch()
        XCTAssertTrue(app.buttons["drink.add"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap(); press(forDuration: 0.7)
        if XCUIApplication().menuItems["Select All"].waitForExistence(timeout: 1) {
            XCUIApplication().menuItems["Select All"].tap()
        }
        typeText(text)
    }
}
