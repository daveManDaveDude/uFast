import XCTest

final class FoodEntryUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testCreateValidationPartialNutritionEditDeleteCancelAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(resetData: true)
        app.launch()
        completeOnboarding(in: app)

        openFoodEditor(in: app)
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["food.save"].isEnabled)
        XCTAssertTrue(app.staticTexts["food.description.validation"].exists)

        description.tap()
        description.typeText("  Soup and bread  ")
        app.buttons["food.details.toggle"].tap()
        app.textFields["Energy"].tap()
        app.textFields["Energy"].typeText("350")
        XCTAssertTrue(app.staticTexts["food.nutrition.energy.label"].exists)
        XCTAssertEqual(app.staticTexts["food.nutrition.energy.label"].label, "Energy")
        XCTAssertEqual(app.staticTexts["food.nutrition.energy.unit"].label, "kcal")
        app.buttons["food.save"].tap()

        let savedRow = app.buttons.matching(identifier: "food.entry").firstMatch
        XCTAssertTrue(app.staticTexts["Soup and bread"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = launchArguments()
        app.launch()
        XCTAssertTrue(app.staticTexts["Soup and bread"].waitForExistence(timeout: 2))

        app.staticTexts["Soup and bread"].tap()
        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 2))
        let editedDescription = app.textFields["food.description"]
        editedDescription.tap()
        editedDescription.clearAndEnterText("Soup, bread and fruit")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Soup, bread and fruit"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Soup and bread"].exists)

        app.staticTexts["Soup, bread and fruit"].tap()
        if !app.buttons["food.delete"].exists {
            app.swipeUp()
        }
        app.buttons["food.delete"].tap()
        tapDeleteAlertButton("food.delete.cancel", in: app)
        app.buttons["food.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Soup, bread and fruit"].exists)

        app.staticTexts["Soup, bread and fruit"].tap()
        if !app.buttons["food.delete"].exists {
            app.swipeUp()
        }
        app.buttons["food.delete"].tap()
        tapDeleteAlertButton("food.delete.confirm", in: app)
        XCTAssertFalse(savedRow.exists)
        XCTAssertFalse(app.staticTexts["Soup, bread and fruit"].exists)
    }

    @MainActor
    private func tapDeleteAlertButton(_ identifier: String, in app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.descendants(matching: .any).matching(identifier: identifier).firstMatch.tap()
    }

    @MainActor
    func testWhitespaceOnlyDescriptionCannotSave() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(resetData: true)
        app.launch()
        completeOnboarding(in: app)
        openFoodEditor(in: app)

        let description = app.textFields["food.description"]
        description.tap()
        description.typeText("   ")

        XCTAssertFalse(app.buttons["food.save"].isEnabled)
        XCTAssertEqual(
            app.staticTexts["food.description.validation"].label,
            "Enter what you ate."
        )
    }

    @MainActor
    private func openFoodEditor(in app: XCUIApplication) {
        let addButton = app.buttons["food.add"]
        if !addButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()
        let picker = app.buttons["food.custom"]
        if picker.waitForExistence(timeout: 2) {
            picker.tap()
        }
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    private func launchArguments(resetData: Bool = false) -> [String] {
        UITestLaunchConfiguration(resetData: resetData, fixedNow: now).arguments
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        tap()
        press(forDuration: 0.7)
        if XCUIApplication().menuItems["Select All"].waitForExistence(timeout: 1) {
            XCUIApplication().menuItems["Select All"].tap()
        }
        typeText(text)
    }
}
