import XCTest

final class NavigationShellUITests: XCTestCase {
    @MainActor
    func testFourPrimaryDestinationsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["--ui-testing", "--reset-data"])
        app.launch()
        completeOnboardingIfNeeded(in: app)

        assertDestination("Today", in: app)
        assertDestination("History", in: app)
        assertDestination("Progress", in: app)
        assertDestination("Settings", in: app)
    }

    @MainActor
    private func completeOnboardingIfNeeded(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
        }
    }

    @MainActor
    private func assertDestination(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons[name].tap()
        let identifier = "screen-title.\(name.lowercased())"
        let title = app.staticTexts[identifier]

        XCTAssertTrue(title.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(title.frame.height, 35)
    }
}
