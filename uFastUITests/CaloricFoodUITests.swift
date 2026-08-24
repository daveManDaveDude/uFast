import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

final class CaloricFoodUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testFoodEditorDoesNotOfferNonCaloricClassification() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)

        XCTAssertFalse(app.switches["food.caloric"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "drink.classification.non-caloric").firstMatch.exists
        )
        XCTAssertEqual(
            app.staticTexts["food.caloric.explanation"].label,
            "Food events count as caloric and are used as fasting boundaries. "
                + "If this event falls during your active fast, saving it ends the fast at this time."
        )
    }

    @MainActor
    func testCaloricFoodCancelChangesNeitherRecordAndConfirmationHasOnlyRequiredChoices() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["This entry is during your recorded fast."].exists)
        XCTAssertTrue(
            alert.descendants(matching: .any)
                .matching(identifier: "food.confirmation.primary").firstMatch.exists
        )
        XCTAssertTrue(
            alert.descendants(matching: .any)
                .matching(identifier: "food.confirmation.cancel").firstMatch.exists
        )
        XCTAssertEqual(
            alert.descendants(matching: .any)
                .matching(identifier: "food.confirmation.primary").firstMatch.label,
            "Save and end fast"
        )
        XCTAssertFalse(alert.buttons["Save entry only"].exists)
        alert.descendants(matching: .any)
            .matching(identifier: "food.confirmation.cancel").firstMatch.tap()
        app.buttons["food.cancel"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Lunch"].exists)
    }

    @MainActor
    func testSaveAndEndFastAtomicallyRecordsFoodAndEndsAtEventTime() {
        let app = launchWithActiveFast()
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        let primaryAction = alert.descendants(matching: .any)
            .matching(identifier: "food.confirmation.primary").firstMatch
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 2), app.debugDescription)
        primaryAction.tap()

        XCTAssertTrue(app.staticTexts["fast.inactive-state"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Lunch"].exists)
        XCTAssertTrue(app.staticTexts["Caloric"].exists)
    }

    @MainActor
    func testPseudolocalizedFoodConfirmationUsesStableIdentifiers() {
        let app = launchWithActiveFast(pseudolocalization: true)
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let primary = alert.descendants(matching: .any)
            .matching(identifier: "food.confirmation.primary").firstMatch
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
    func testFoodConfirmationRemainsReachableAtAccessibilityXXXL() {
        let app = launchWithActiveFast(
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        openFoodEditor(in: app)
        enterDescription("Lunch", in: app)
        app.buttons["food.save"].tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(alert.staticTexts["This entry is during your recorded fast."].exists)
        let primary = alert.descendants(matching: .any)
            .matching(identifier: "food.confirmation.primary").firstMatch
        let consequence = alert.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'ends your fast'"))
            .firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(consequence.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(primary.isHittable, app.debugDescription)
        primary.tap()
        XCTAssertTrue(app.staticTexts["fast.inactive-state"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testCaloricFoodAtExactActiveStartCannotSave() {
        let app = XCUIApplication()
        app.launchArguments = baseArguments(activeFastStart: now)
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        openFoodEditor(in: app)
        enterDescription("Exact boundary", in: app)

        XCTAssertFalse(app.buttons["food.save"].isEnabled)
        XCTAssertEqual(
            app.staticTexts["food.fast-start.validation"].label,
            "Choose a time after the fast started, or change the fast start time."
        )
    }

    @MainActor
    private func launchWithActiveFast(
        pseudolocalization: Bool = false,
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = baseArguments(
            activeFastStart: now.addingTimeInterval(-3600),
            pseudolocalization: pseudolocalization,
            preferredContentSizeCategory: preferredContentSizeCategory
        )
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func openFoodEditor(in app: XCUIApplication) {
        let button = app.buttons["food.add"]
        if !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        button.tap()
    }

    @MainActor
    private func enterDescription(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["food.description"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.tap()
        field.typeText(text)
    }

    private func baseArguments(
        activeFastStart: Date,
        pseudolocalization: Bool = false,
        preferredContentSizeCategory: String? = nil
    ) -> [String] {
        UITestLaunchConfiguration(
            resetData: true,
            pseudolocalization: pseudolocalization,
            seedOnboarded: true,
            fixedNow: now,
            seedActiveFastStart: activeFastStart,
            preferredContentSizeCategory: preferredContentSizeCategory
        ).arguments
    }
}
