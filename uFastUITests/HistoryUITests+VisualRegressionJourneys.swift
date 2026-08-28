import XCTest

extension HistoryUITests {
    @MainActor
    // swiftlint:disable:next function_body_length
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
                expectedSelectedDate: "Tue 25 Aug"
            ),
            app.debugDescription
        )
        let activeFast = try XCTUnwrap(
            visibleActiveFast(in: app, carousel: carousel),
            app.debugDescription
        )
        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        nextDay.tap()
        XCTAssertTrue(
            waitForSettledHistory(
                selectedDate: selectedDate,
                carousel: carousel,
                expectedSelectedDate: "Wed 26 Aug"
            ),
            app.debugDescription
        )
        let label = try XCTUnwrap(
            visibleActiveFastLabelProbe(in: app, carousel: carousel, timeout: 5),
            app.debugDescription
        )
        XCTAssertEqual(label.label, "Active fast", label.debugDescription)
        XCTAssertTrue(
            Self.isVisibleFrame(label.frame, boundedBy: carousel.frame),
            "The complete-bar label should be visible on the containing day.\n\(app.debugDescription)"
        )
    }
}
