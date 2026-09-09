import XCTest

extension HistoryUITests {
    @MainActor
    // swiftlint:disable:next function_body_length
    func testHistoryMidnightSeamAccessibilityPresentationAcrossDynamicTypeRTLAndTwelveHourLocale() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let day = calendar.startOfDay(for: start)
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let afterMidnight = try XCTUnwrap(
            calendar.date(bySettingHour: 13, minute: 19, second: 0, of: nextDay)
        )
        // swiftlint:disable trailing_comma
        // swiftlint:disable:next large_tuple
        let configurations: [(name: String, arguments: [String], timeFragment: String?)] = [
            (
                "dynamic-type",
                [
                    "-AppleLocale", "en_GB",
                    "-UIPreferredContentSizeCategoryName",
                    "UICTContentSizeCategoryAccessibilityXXXL",
                ],
                "19:06"
            ),
            (
                "rtl",
                [
                    "-AppleLanguages", "(ar)",
                    "-AppleLocale", "ar_SA",
                ],
                nil
            ),
            (
                "twelve-hour",
                ["-AppleLocale", "en_US"],
                "7:06"
            ),
        ]
        // swiftlint:enable trailing_comma

        for configuration in configurations {
            let app = launchHistory(
                arguments: launchArguments(
                    now: afterMidnight,
                    resetData: true,
                    seedOnboarded: true,
                    seedHistoryMidnightSeam: true,
                    suppressAutomaticLiveActivityOffer: true,
                    startsOnHistory: true
                ),
                additionalArguments: configuration.arguments
            )
            openHistory(in: app)

            let selectedDate = app.staticTexts["history.selected-date"]
            XCTAssertTrue(selectedDate.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
            let carousel = app.scrollViews["history.day-carousel"]
            XCTAssertTrue(carousel.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
            let state = try XCTUnwrap(settledSeamState(
                in: app,
                expectedSelectedDate: selectedDate.label
            ), app.debugDescription)
            XCTAssertTrue(state.activeLabel.contains("Active Fast"), app.debugDescription)
            XCTAssertTrue(state.noonMarkerVisible, app.debugDescription)
            XCTAssertTrue(state.noonMarkerFrameIntersectsCarousel, app.debugDescription)
            let structuredDetail = app.buttons[
                "history.fast.10200000-0000-0000-0000-000000000002"
            ]
            XCTAssertTrue(structuredDetail.waitForExistenceIfNeeded(timeout: 5), app.debugDescription)
            XCTAssertTrue(structuredDetail.label.contains("Active Fast"))
            XCTAssertTrue(structuredDetail.label.contains("duration 18 hours 13 minutes 0 seconds"))
            if let timeFragment = configuration.timeFragment {
                XCTAssertTrue(
                    structuredDetail.label.contains(timeFragment),
                    "Unexpected \(configuration.name) active-fast detail: \(structuredDetail.label)"
                )
            }
            captureScreenshot(
                named: "history-midnight-seam-accessibility-\(configuration.name)",
                in: app
            )
            app.terminate()
        }
    }
}
