import XCTest

extension HistoryUITests {
    @MainActor
    func testMidnightMarkerRemainsVisibleAtAccessibilityTextSizeInLTRAndRTL() {
        // swiftlint:disable trailing_comma
        let configurations: [(name: String, arguments: [String])] = [
            (
                "en-GB-ltr",
                [
                    "-AppleLocale", "en_GB",
                    "-UIPreferredContentSizeCategoryName",
                    "UICTContentSizeCategoryAccessibilityXXXL",
                ]
            ),
            (
                "ar-rtl",
                [
                    "-AppleLanguages", "(ar)",
                    "-AppleLocale", "ar_SA",
                    "-UIPreferredContentSizeCategoryName",
                    "UICTContentSizeCategoryAccessibilityXXXL",
                ]
            ),
        ]
        // swiftlint:enable trailing_comma

        for configuration in configurations {
            let app = launchHistory(
                arguments: launchArguments(now: start, resetData: true, seedOnboarded: true),
                additionalArguments: configuration.arguments
            )
            selectHistoryTab(in: app)
            XCTAssertTrue(
                app.staticTexts["history.selected-date"].waitForExistence(timeout: 5),
                app.debugDescription
            )
            let previousDay = app.buttons["history.previous-day"]
            XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(waitForHittable(previousDay, app: app), previousDay.debugDescription)
            previousDay.tap()
            XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
            XCTAssertTrue(
                app.scrollViews["history.day-carousel"].waitForExistence(timeout: 5),
                app.debugDescription
            )
            captureScreenshot(
                named: "history-midnight-marker-accessibility-\(configuration.name)",
                in: app
            )
            app.terminate()
        }
    }
}
