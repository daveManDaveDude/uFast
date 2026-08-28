import XCTest

extension HistoryUITests {
    @MainActor
    // swiftlint:disable:next function_body_length
    func testEditedActiveFastCrossingMidnightIsCoherentBeforeAnyDrinkMutation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 16, hour: 8, minute: 40)
            )
        )
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let app = XCUIApplication()
        app.launchArguments = londonLaunchArguments(
            now: now,
            resetData: true,
            suppressAutomaticLiveActivityOffer: true
        )
        app.launch()
        completeOnboarding(in: app)

        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["fast.edit-start"].tap()
        let startTimeEditor = app.navigationBars["Start time"]
        XCTAssertTrue(startTimeEditor.waitForExistence(timeout: 5), app.debugDescription)
        let datePicker = app.datePickers["fast.start-date"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 5), app.debugDescription)
        datePicker.tap()
        let correctedDate = app.buttons["Saturday 15 August"]
        XCTAssertTrue(correctedDate.waitForExistence(timeout: 5), app.debugDescription)
        correctedDate.tap()
        let datePopoverDismissRegion = app.buttons["PopoverDismissRegion"]
        if datePopoverDismissRegion.exists {
            datePopoverDismissRegion.tap()
        }
        XCTAssertTrue(
            datePopoverDismissRegion.waitForNonExistence(timeout: 5),
            app.debugDescription
        )
        let correctedDateButton = datePicker.buttons["Date Picker"]
        XCTAssertTrue(correctedDateButton.waitForExistence(timeout: 5), app.debugDescription)
        let dateValue = correctedDateButton.value as? String ?? ""
        XCTAssertTrue(
            dateValue.contains("15") && dateValue.contains("2026"),
            "Unexpected corrected date: \(dateValue)\n\(app.debugDescription)"
        )
        let timePicker = app.datePickers["fast.start-time"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: 5), app.debugDescription)
        if !timePicker.isHittable {
            let form = app.tables.firstMatch
            XCTAssertTrue(form.waitForExistence(timeout: 5), app.debugDescription)
            form.swipeUp()
        }
        let timePickerHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: timePicker
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [timePickerHittable], timeout: 5),
            .completed,
            app.debugDescription
        )
        timePicker.tap()
        let timeWheels = app.pickerWheels
        XCTAssertGreaterThanOrEqual(timeWheels.count, 2, app.debugDescription)
        timeWheels.element(boundBy: 0).adjust(toPickerWheelValue: "21")
        timeWheels.element(boundBy: 1).adjust(toPickerWheelValue: "00")
        let timePopoverDismissRegion = app.buttons["PopoverDismissRegion"]
        XCTAssertTrue(timePopoverDismissRegion.waitForExistence(timeout: 5), app.debugDescription)
        timePopoverDismissRegion.tap()
        XCTAssertTrue(timePopoverDismissRegion.waitForNonExistence(timeout: 5), app.debugDescription)
        let correctedTimeButton = timePicker.buttons["Time Picker"]
        XCTAssertTrue(correctedTimeButton.waitForExistence(timeout: 5), app.debugDescription)
        let timeValue = correctedTimeButton.value as? String ?? ""
        XCTAssertTrue(
            timeValue.contains("21:00"),
            "Unexpected corrected time: \(timeValue)\n\(app.debugDescription)"
        )
        app.buttons["fast.start-confirm"].tap()
        XCTAssertTrue(startTimeEditor.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 5), app.debugDescription)

        selectHistoryTab(in: app)
        openHistory(in: app)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let sundaySelectedDate = "Sun 16 Aug"
        let saturdaySelectedDate = "Sat 15 Aug"
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: sundaySelectedDate
        ), app.debugDescription)
        let first = try XCTUnwrap(
            visibleActiveFast(
                in: app,
                carousel: carousel
            )
        )
        let stableIdentifier = first.identifier
        XCTAssertTrue(
            stableIdentifier.hasPrefix("history.active-fast."),
            first.debugDescription
        )
        let structuredFastIdentifier = stableIdentifier.replacingOccurrences(
            of: "history.active-fast.",
            with: "history.fast."
        )
        let structuredFast = app.buttons[structuredFastIdentifier]
        XCTAssertTrue(structuredFast.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            structuredFast.label.contains("start 15 Aug at 21:00"),
            structuredFast.debugDescription
        )
        XCTAssertTrue(
            structuredFast.label.contains("duration 11 hours 40 minutes 0 seconds"),
            structuredFast.debugDescription
        )
        let preDrinkFrames = visibleActiveFastFrames(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        XCTAssertEqual(preDrinkFrames.count, 2, app.debugDescription)
        let activeFastVisualLabel = app.descendants(matching: .any)[
            "history.fast-label-probe.\(stableIdentifier.replacingOccurrences(of: "history.active-fast.", with: ""))"
        ]
        XCTAssertTrue(activeFastVisualLabel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(activeFastVisualLabel.label, "Active fast", activeFastVisualLabel.debugDescription)
        XCTAssertFalse(carousel.staticTexts["11:40:00"].exists, app.debugDescription)
        let preDrinkMarkerIDs = historyMarkerIdentifiers(in: app)
        let preDrinkStructuredLabel = structuredFast.label
        captureScreenshot(named: "history-edited-active-fast-current-day", in: app)
        let saturdayDateButton = app.buttons[
            "temporal.date.\(calendar.startOfDay(for: previousDay).timeIntervalSince1970)"
        ]
        XCTAssertTrue(saturdayDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(saturdayDateButton, app: app), saturdayDateButton.debugDescription)
        saturdayDateButton.tap()
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: saturdaySelectedDate
        ), app.debugDescription)
        let previousDayFrames = visibleActiveFastFrames(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        XCTAssertEqual(previousDayFrames.count, 2, app.debugDescription)
        captureScreenshot(named: "history-edited-active-fast-previous-day", in: app)

        let sundayDateButton = app.buttons[
            "temporal.date.\(calendar.startOfDay(for: now).timeIntervalSince1970)"
        ]
        XCTAssertTrue(sundayDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(sundayDateButton, app: app), sundayDateButton.debugDescription)
        sundayDateButton.tap()
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: sundaySelectedDate
        ), app.debugDescription)
        let currentDayFrames = visibleActiveFastFrames(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        XCTAssertEqual(currentDayFrames.count, 2, app.debugDescription)
        captureScreenshot(named: "history-edited-active-fast-reversed", in: app)

        selectTodayTab(in: app)
        let addDrink = app.buttons["drink.add"]
        XCTAssertTrue(addDrink.waitForExistence(timeout: 5), app.debugDescription)
        if !addDrink.isHittable {
            let todayScroll = app.scrollViews["today.content"]
            XCTAssertTrue(todayScroll.waitForExistence(timeout: 5), app.debugDescription)
            todayScroll.swipeUp()
        }
        XCTAssertTrue(addDrink.isHittable, addDrink.debugDescription)
        addDrink.tap()
        let water = app.buttons["drink.favourite.00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(water.waitForExistence(timeout: 5), app.debugDescription)
        water.tap()
        XCTAssertTrue(
            app.navigationBars["Add a drink"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )
        let waterEntry = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
                "timeline.entry.",
                "Drink, Water"
            )
        ).firstMatch
        XCTAssertTrue(waterEntry.waitForExistence(timeout: 5), app.debugDescription)
        let waterID = waterEntry.identifier.replacingOccurrences(of: "timeline.entry.", with: "")
        selectHistoryTab(in: app)
        openHistory(in: app)
        let postDrinkCarousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(postDrinkCarousel.waitForExistence(timeout: 5), app.debugDescription)
        let postDrinkSelectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(postDrinkSelectedDate.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForSettledHistory(
            selectedDate: postDrinkSelectedDate,
            carousel: postDrinkCarousel,
            expectedSelectedDate: sundaySelectedDate
        ), app.debugDescription)
        let postDrinkStructuredFast = app.buttons[structuredFastIdentifier]
        XCTAssertTrue(postDrinkStructuredFast.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(postDrinkStructuredFast.label, preDrinkStructuredLabel)
        let postDrinkFrames = visibleActiveFastFrames(
            in: app,
            carousel: postDrinkCarousel,
            identifier: stableIdentifier
        )
        XCTAssertEqual(postDrinkFrames.count, 2, app.debugDescription)
        XCTAssertEqual(postDrinkFrames.count, preDrinkFrames.count)
        for (before, after) in zip(
            preDrinkFrames.sorted { $0.minX < $1.minX },
            postDrinkFrames.sorted { $0.minX < $1.minX }
        ) {
            XCTAssertEqual(after.minY, before.minY, accuracy: 1, app.debugDescription)
            XCTAssertEqual(after.width, before.width, accuracy: 1, app.debugDescription)
            XCTAssertEqual(after.height, before.height, accuracy: 1, app.debugDescription)
        }
        let postDrinkMarkerIDs = historyMarkerIdentifiers(in: app)
        XCTAssertNotEqual(postDrinkMarkerIDs, preDrinkMarkerIDs, app.debugDescription)
        XCTAssertTrue(
            postDrinkMarkerIDs.contains { $0.hasSuffix(waterID) },
            "The saved water marker was not published to History.\n(app.debugDescription)"
        )
        captureScreenshot(named: "history-edited-active-fast-after-water", in: app)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testHistoryMidnightSeamRemainsContinuousWhenViewportMovesBothDirections() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let day = calendar.startOfDay(for: start)
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let afterMidnight = try XCTUnwrap(
            calendar.date(
                bySettingHour: 13,
                minute: 19,
                second: 0,
                of: nextDay
            )
        )

        let app = launchHistory(
            arguments: launchArguments(
                now: afterMidnight,
                resetData: true,
                seedOnboarded: true,
                seedHistoryMidnightSeam: true,
                seedHistoryMidnightSeamExtended: true,
                suppressAutomaticLiveActivityOffer: true,
                startsOnHistory: true
            ),
            additionalArguments: [
                // swiftlint:disable:next trailing_comma
                "-AppleInterfaceStyle", "Dark",
            ]
        )
        openHistory(in: app)

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let expectedSelectedDay = nextDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        let expectedSelectedDate = expectedSelectedDay
        XCTAssertEqual(selectedDate.label, expectedSelectedDate)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let settledState = try XCTUnwrap(settledSeamState(
            in: app,
            expectedSelectedDate: expectedSelectedDate
        ), app.debugDescription)
        XCTAssertEqual(settledState.selectedDateLabel, expectedSelectedDate)
        XCTAssertTrue(settledState.activeLabel.contains("Active Fast"), app.debugDescription)
        XCTAssertTrue(
            settledState.activeLabel.contains(
                "duration 1 day 18 hours 13 minutes 0 seconds"
            ),
            app.debugDescription
        )
        XCTAssertEqual(
            settledState.labelProbeCount,
            0,
            "The continuous midpoint belongs to the intervening day, "
                + "not the terminal-day fragment.\n\(app.debugDescription)"
        )
        XCTAssertTrue(settledState.noonMarkerVisible, app.debugDescription)
        XCTAssertTrue(settledState.noonMarkerFrameIntersectsCarousel, app.debugDescription)
        let settledActiveFrame = settledState.activeFrame
        captureScreenshot(named: "history-midnight-seam-settled", in: app)

        carousel.swipeRight(velocity: .slow)
        XCTAssertLessThanOrEqual(
            visibleActiveFastLabelProbe(in: app, carousel: carousel).count,
            1,
            "More than one active-fast visual content region was visible during movement.\n\(app.debugDescription)"
        )
        let originalStartDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: nextDay))
        let originalStartDayLabel = originalStartDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        let originalStartSelectedDate = originalStartDayLabel
        let previousOffsetState = try XCTUnwrap(settledSeamState(
            in: app,
            expectedSelectedDate: originalStartSelectedDate,
            expectedLabelProbeCount: 0
        ), app.debugDescription)
        XCTAssertEqual(previousOffsetState.selectedDateLabel, originalStartSelectedDate)
        XCTAssertFalse(previousOffsetState.noonMarkerVisible, app.debugDescription)
        XCTAssertEqual(previousOffsetState.labelProbeCount, 0, app.debugDescription)
        let previousOffsetActiveFrame = previousOffsetState.activeFrame
        XCTAssertGreaterThan(
            abs(previousOffsetActiveFrame.minX - settledActiveFrame.minX),
            1,
            app.debugDescription
        )
        captureScreenshot(named: "history-midnight-seam-previous-day", in: app)

        let midpointDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: nextDay))
        let midpointDayLabel = midpointDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        let midpointSelectedDate = midpointDayLabel
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        let midpointDateButton = dateNavigator.buttons[
            "temporal.date.\(calendar.startOfDay(for: midpointDay).timeIntervalSince1970)"
        ]
        XCTAssertTrue(midpointDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(midpointDateButton, app: app), midpointDateButton.debugDescription)
        midpointDateButton.tap()
        let midpointState = try XCTUnwrap(settledSeamState(
            in: app,
            expectedSelectedDate: midpointSelectedDate,
            expectedLabelProbeCount: 1
        ), app.debugDescription)
        XCTAssertEqual(midpointState.selectedDateLabel, midpointSelectedDate)
        XCTAssertEqual(midpointState.labelProbeCount, 1, app.debugDescription)

        let currentDateButton = dateNavigator.buttons[
            "temporal.date.\(calendar.startOfDay(for: nextDay).timeIntervalSince1970)"
        ]
        XCTAssertTrue(currentDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(currentDateButton, app: app), currentDateButton.debugDescription)
        currentDateButton.tap()
        let currentOffsetState = try XCTUnwrap(settledSeamState(
            in: app,
            expectedSelectedDate: expectedSelectedDate
        ), app.debugDescription)
        XCTAssertEqual(currentOffsetState.selectedDateLabel, expectedSelectedDate)
        XCTAssertTrue(currentOffsetState.noonMarkerVisible, app.debugDescription)
        XCTAssertTrue(currentOffsetState.noonMarkerFrameIntersectsCarousel, app.debugDescription)
        XCTAssertTrue(
            currentOffsetState.activeLabel.contains(
                "duration 1 day 18 hours 13 minutes 0 seconds"
            ),
            app.debugDescription
        )
        XCTAssertEqual(currentOffsetState.labelProbeCount, 0, app.debugDescription)
        let currentOffsetActiveFrame = currentOffsetState.activeFrame
        XCTAssertGreaterThan(
            abs(currentOffsetActiveFrame.minX - previousOffsetActiveFrame.minX),
            1,
            app.debugDescription
        )
        captureScreenshot(named: "history-midnight-seam-current-day", in: app)
    }

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
            XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
            let carousel = app.scrollViews["history.day-carousel"]
            XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
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
            XCTAssertTrue(structuredDetail.waitForExistence(timeout: 5), app.debugDescription)
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
