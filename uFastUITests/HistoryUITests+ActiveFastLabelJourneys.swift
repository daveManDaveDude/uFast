import XCTest

extension HistoryUITests {
    @MainActor
    // swiftlint:disable:next function_body_length
    func testHistoryKeepsOneActiveFastLabelAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let day = calendar.startOfDay(for: start)
        let beforeMidnight = calendar.date(
            bySettingHour: 19,
            minute: 6,
            second: 0,
            of: day
        ) ?? start
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? start
        let afterMidnight = calendar.date(
            bySettingHour: 13,
            minute: 19,
            second: 0,
            of: nextDay
        ) ?? start

        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: beforeMidnight, resetData: true)
            + ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()

        app.terminate()
        app.launchArguments = launchArguments(now: afterMidnight)
            + ["-AppleInterfaceStyle", "Dark"]
        app.launch()
        selectHistoryTab(in: app)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertEqual(visibleActiveFastLabelProbe(in: app, carousel: carousel).count, 1, app.debugDescription)

        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let originalStartDateButton = dateNavigator.buttons[
            "temporal.date.\(calendar.startOfDay(for: day).timeIntervalSince1970)"
        ]
        XCTAssertTrue(originalStartDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(originalStartDateButton, app: app), originalStartDateButton.debugDescription)
        originalStartDateButton.tap()
        let selectedDate = app.staticTexts["history.selected-date"]
        let expectedSelectedDay = day.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: expectedSelectedDay
        ), app.debugDescription)
        XCTAssertEqual(
            visibleActiveFastLabelProbe(in: app, carousel: carousel).count,
            0,
            "The label midpoint is on the following day, not the start-day fragment.\n\(app.debugDescription)"
        )

        let currentDateButton = dateNavigator.buttons[
            "temporal.date.\(calendar.startOfDay(for: nextDay).timeIntervalSince1970)"
        ]
        XCTAssertTrue(currentDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(currentDateButton, app: app), currentDateButton.debugDescription)
        currentDateButton.tap()
        let currentDay = nextDay.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: currentDay
        ), app.debugDescription)
        XCTAssertEqual(visibleActiveFastLabelProbe(in: app, carousel: carousel).count, 1, app.debugDescription)

        XCTAssertTrue(waitForHittable(originalStartDateButton, app: app), originalStartDateButton.debugDescription)
        originalStartDateButton.tap()
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: expectedSelectedDay
        ), app.debugDescription)
        XCTAssertEqual(visibleActiveFastLabelProbe(in: app, carousel: carousel).count, 0, app.debugDescription)
        captureScreenshot(named: "history-active-fast-midnight-seam", in: app)
    }
}
