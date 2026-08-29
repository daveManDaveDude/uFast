import XCTest

extension HistoryUITests {
    @MainActor
    func launchHistory(
        arguments: [String],
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let appearanceArguments = additionalArguments.contains(
            "-AppleInterfaceStyle"
        ) ? [] : ["-AppleInterfaceStyle", "Light"]
        app.launchArguments = arguments + appearanceArguments + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    func selectYesterday(in app: XCUIApplication) {
        let previous = app.buttons["history.previous-day"]
        if !previous.exists {
            XCTAssertTrue(previous.waitForExistence(timeout: 5), app.debugDescription)
        }
        XCTAssertTrue(waitForHittable(previous, app: app), previous.debugDescription)
        previous.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let add = app.buttons["history.add-at-selected-time"]
        if !add.exists {
            XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        }
        if !add.isHittable {
            let content = app.scrollViews["history.content"]
            if !content.exists {
                XCTAssertTrue(content.waitForExistence(timeout: 5), app.debugDescription)
            }
            content.swipeUp()
        }
        XCTAssertTrue(waitForHittable(add, app: app), add.debugDescription)
    }

    @MainActor
    func captureScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
