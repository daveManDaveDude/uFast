import XCTest

extension HistoryUITests {
    @MainActor
    func testLateStartActiveFastUsesReadableUntruncatedTimelineLabel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let start = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 25, hour: 21, minute: 3)
            )
        )
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 26, hour: 6, minute: 27)
            )
        )
        let app = launchHistory(
            arguments: UITestLaunchConfiguration(
                resetData: true,
                seedOnboarded: true,
                fixedNow: now,
                seedActiveFastStart: start,
                suppressAutomaticLiveActivityOffer: true,
                startsOnHistory: true,
                appleLocale: "en_GB",
                timeZone: "Europe/London"
            ).arguments
        )
        openHistory(in: app)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let selectedDate = app.staticTexts["history.selected-date"]
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(
            waitForSettledHistory(
                selectedDate: selectedDate,
                carousel: carousel,
                expectedSelectedDate: "Selected day, Tue 25 Aug"
            ),
            app.debugDescription
        )
        let activeFast = try XCTUnwrap(
            visibleActiveFast(in: app, carousel: carousel),
            app.debugDescription
        )
        let label = activeFast.staticTexts["Active Fast"]

        XCTAssertTrue(label.waitForExistence(timeout: 5), activeFast.debugDescription)
        XCTAssertEqual(label.label, "Active Fast", label.debugDescription)
        XCTAssertLessThanOrEqual(label.frame.maxX, activeFast.frame.maxX, activeFast.debugDescription)
    }
}
