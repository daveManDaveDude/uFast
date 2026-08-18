import XCTest

// swiftlint:disable file_length trailing_comma type_body_length function_body_length large_tuple

final class HistoryUITests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testEmptyHistoryShowsCompletedOnlyEmptyStateWithoutStartAction() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)

        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Completed fasts will appear here."].exists)
        XCTAssertFalse(app.buttons["fast.start"].exists)
        XCTAssertTrue(app.buttons["history.choose-date"].exists)
        XCTAssertFalse(app.buttons["history.catch-up"].exists)
    }

    @MainActor
    func testHistoryUsesAccessibleTemporalNavigatorAndRibbonAlternative() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.buttons["history.choose-date"].exists)
        let structuredFastRow = recordedFastRow(in: app)
        XCTAssertTrue(structuredFastRow.waitForExistence(timeout: 2))
        XCTAssertTrue(structuredFastRow.label.contains("start"))
        XCTAssertTrue(structuredFastRow.label.contains("end"))
    }

    @MainActor
    func testHistoryPresentsAnActiveFastThroughTheCurrentTime() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        app.tabBars.buttons["History"].tap()

        let visualActiveFast = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.active-fast.")
        ).firstMatch
        XCTAssertTrue(visualActiveFast.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(visualActiveFast.isEnabled, visualActiveFast.debugDescription)
        XCTAssertGreaterThan(visualActiveFast.frame.width, 0, visualActiveFast.debugDescription)
        XCTAssertFalse(visualActiveFast.label.contains("end"))

        visualActiveFast.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5))
    }

    @MainActor
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
        let correctedStart = try XCTUnwrap(
            calendar.date(bySettingHour: 21, minute: 0, second: 0, of: previousDay)
        )
        let app = XCUIApplication()
        app.launchArguments = londonLaunchArguments(now: now, resetData: true)
            + ["--suppress-automatic-live-activity-offer"]
        app.launch()
        completeOnboarding(in: app)

        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["fast.edit-start"].tap()
        let startTimeEditor = app.navigationBars["Start time"]
        XCTAssertTrue(startTimeEditor.waitForExistence(timeout: 5), app.debugDescription)
        setStartTimePicker(in: app, calendar: calendar, date: correctedStart)
        app.buttons["fast.start-confirm"].tap()
        XCTAssertTrue(startTimeEditor.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["History"].tap()
        openHistory(in: app)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let sundaySelectedDate = "Selected day, Sun 16 Aug"
        let saturdaySelectedDate = "Selected day, Sat 15 Aug"
        waitForSettledHistory(
            in: app,
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: sundaySelectedDate
        )
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
            structuredFast.label.contains("duration 11:40:00"),
            structuredFast.debugDescription
        )
        let preDrinkFrames = assertVisibleActiveFastFragments(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        let preDrinkMarkerIDs = historyMarkerIdentifiers(in: app)
        let preDrinkStructuredLabel = structuredFast.label
        captureScreenshot(named: "history-edited-active-fast-current-day", in: app)

        let saturdayDateButton = app.buttons[
            "temporal.date.\(calendar.startOfDay(for: previousDay).timeIntervalSince1970)"
        ]
        XCTAssertTrue(saturdayDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(saturdayDateButton.isHittable, saturdayDateButton.debugDescription)
        saturdayDateButton.tap()
        waitForSettledHistory(
            in: app,
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: saturdaySelectedDate
        )
        _ = assertVisibleActiveFastFragments(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        captureScreenshot(named: "history-edited-active-fast-previous-day", in: app)

        let sundayDateButton = app.buttons[
            "temporal.date.\(calendar.startOfDay(for: now).timeIntervalSince1970)"
        ]
        XCTAssertTrue(sundayDateButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(sundayDateButton.isHittable, sundayDateButton.debugDescription)
        sundayDateButton.tap()
        waitForSettledHistory(
            in: app,
            selectedDate: selectedDate,
            carousel: carousel,
            expectedSelectedDate: sundaySelectedDate
        )
        _ = assertVisibleActiveFastFragments(
            in: app,
            carousel: carousel,
            identifier: stableIdentifier
        )
        captureScreenshot(named: "history-edited-active-fast-reversed", in: app)

        let waterID = addWaterFromToday(in: app)
        app.tabBars.buttons["History"].tap()
        openHistory(in: app)
        let postDrinkCarousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(postDrinkCarousel.waitForExistence(timeout: 5), app.debugDescription)
        let postDrinkSelectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(postDrinkSelectedDate.waitForExistence(timeout: 5), app.debugDescription)
        waitForSettledHistory(
            in: app,
            selectedDate: postDrinkSelectedDate,
            carousel: postDrinkCarousel,
            expectedSelectedDate: sundaySelectedDate
        )
        let postDrinkStructuredFast = app.buttons[structuredFastIdentifier]
        XCTAssertTrue(postDrinkStructuredFast.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(postDrinkStructuredFast.label, preDrinkStructuredLabel)
        let postDrinkFrames = assertVisibleActiveFastFragments(
            in: app,
            carousel: postDrinkCarousel,
            identifier: stableIdentifier
        )
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
    func testHistoryKeepsActiveFastLabelOnSelectedPageAcrossMidnight() {
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
        app.tabBars.buttons["History"].tap()

        let activeFast = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Active Fast")
        ).firstMatch
        XCTAssertTrue(activeFast.waitForExistence(timeout: 2))
        XCTAssertTrue(activeFast.label.contains("19:06"))
        XCTAssertTrue(activeFast.label.contains("18:13:00"))
        XCTAssertFalse(activeFast.label.contains("end"))
        captureScreenshot(named: "history-active-fast-midnight-seam", in: app)
    }

    @MainActor
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

        let app = launchMidnightSeam(
            now: afterMidnight,
            additionalArguments: [
                "-AppleInterfaceStyle", "Dark",
                "--seed-history-midnight-seam-extended",
            ]
        )
        let activeFastIdentifier = "history.active-fast.10200000-0000-0000-0000-000000000002"
        let noonMarkerIdentifier = "history.visual-event.10200000-0000-0000-0000-000000000013"
        openHistory(in: app)

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let expectedSelectedDay = nextDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        let expectedSelectedDate = "Selected day, \(expectedSelectedDay)"
        XCTAssertEqual(selectedDate.label, expectedSelectedDate)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let settledActiveFrame = assertSettledSeamState(
            in: app,
            carousel: carousel,
            selectedDate: selectedDate,
            expectedSelectedDate: expectedSelectedDate,
            allowedSelectedDates: nearbySelectedDateLabels(
                around: nextDay,
                calendar: calendar
            ),
            activeFastIdentifier: activeFastIdentifier,
            noonMarkerIdentifier: noonMarkerIdentifier,
            requireNoonMarkerIdentifier: true,
            expectedActiveDuration: "1d 18:13:00"
        )
        captureScreenshot(named: "history-midnight-seam-settled", in: app)

        carousel.swipeRight(velocity: .slow)
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: nextDay))
        let previousDayLabel = previousDay.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        )
        let previousSelectedDate = "Selected day, \(previousDayLabel)"
        let previousOffsetActiveFrame = assertSettledSeamState(
            in: app,
            carousel: carousel,
            selectedDate: selectedDate,
            expectedSelectedDate: previousSelectedDate,
            allowedSelectedDates: nearbySelectedDateLabels(
                around: nextDay,
                calendar: calendar
            ),
            activeFastIdentifier: activeFastIdentifier,
            noonMarkerIdentifier: noonMarkerIdentifier,
            expectedNoonMarkerVisibility: false,
            expectedActiveDuration: nil
        )
        XCTAssertGreaterThan(
            abs(previousOffsetActiveFrame.minX - settledActiveFrame.minX),
            1,
            app.debugDescription
        )
        captureScreenshot(named: "history-midnight-seam-previous-day", in: app)

        carousel.swipeLeft(velocity: .slow)
        let currentOffsetActiveFrame = assertSettledSeamState(
            in: app,
            carousel: carousel,
            selectedDate: selectedDate,
            expectedSelectedDate: expectedSelectedDate,
            allowedSelectedDates: nearbySelectedDateLabels(
                around: nextDay,
                calendar: calendar
            ),
            activeFastIdentifier: activeFastIdentifier,
            noonMarkerIdentifier: noonMarkerIdentifier,
            expectedNoonMarkerVisibility: true,
            expectedActiveDuration: "1d 18:13:00"
        )
        XCTAssertGreaterThan(
            abs(currentOffsetActiveFrame.minX - previousOffsetActiveFrame.minX),
            1,
            app.debugDescription
        )
        captureScreenshot(named: "history-midnight-seam-current-day", in: app)
    }

    @MainActor
    func testHistoryMidnightSeamAccessibilityPresentationAcrossDynamicTypeRTLAndTwelveHourLocale() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let day = calendar.startOfDay(for: start)
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let afterMidnight = try XCTUnwrap(
            calendar.date(bySettingHour: 13, minute: 19, second: 0, of: nextDay)
        )
        let activeFastIdentifier = "history.active-fast.10200000-0000-0000-0000-000000000002"
        let noonMarkerIdentifier = "history.visual-event.10200000-0000-0000-0000-000000000013"
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

        for configuration in configurations {
            let app = launchMidnightSeam(
                now: afterMidnight,
                additionalArguments: configuration.arguments
            )
            openHistory(in: app)

            let selectedDate = app.staticTexts["history.selected-date"]
            XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
            let carousel = app.scrollViews["history.day-carousel"]
            XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
            _ = assertSettledSeamState(
                in: app,
                carousel: carousel,
                selectedDate: selectedDate,
                expectedSelectedDate: selectedDate.label,
                activeFastIdentifier: activeFastIdentifier,
                noonMarkerIdentifier: noonMarkerIdentifier,
                requireNoonMarkerIdentifier: true
            )
            let structuredDetail = app.buttons[
                "history.fast.10200000-0000-0000-0000-000000000002"
            ]
            XCTAssertTrue(structuredDetail.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(structuredDetail.label.contains("Active Fast"))
            XCTAssertTrue(structuredDetail.label.contains("duration 18:13:00"))
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

    @MainActor
    func testHistorySwipeButtonsAndDateChipShareOneSelectedDay() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 2))
        let todayLabel = selectedDate.label
        XCTAssertTrue(app.buttons["history.next-day"].isEnabled)

        app.buttons["history.previous-day"].tap()
        let deliberatePreviousLabel = selectedDate.label
        XCTAssertNotEqual(deliberatePreviousLabel, todayLabel)

        let today = Calendar.current.startOfDay(for: start)
        let todayChip = app.buttons["temporal.date.\(today.timeIntervalSince1970)"]
        XCTAssertTrue(todayChip.waitForExistence(timeout: 2))
        todayChip.tap()
        XCTAssertEqual(selectedDate.label, todayLabel)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 2))
        carousel.swipeRight(velocity: .slow)
        XCTAssertNotEqual(selectedDate.label, todayLabel)
        let freelySettledLabel = selectedDate.label
        XCTAssertTrue(app.buttons["history.next-day"].isEnabled)

        app.buttons["history.next-day"].tap()
        XCTAssertNotEqual(selectedDate.label, freelySettledLabel)
        app.buttons["history.previous-day"].tap()
        XCTAssertEqual(selectedDate.label, freelySettledLabel)
    }

    @MainActor
    func testManualDateRailSettlementSelectsNearestCenteredChipAndSynchronizesTimeline() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 2))
        let originalSelection = selectedDate.label
        let today = Calendar.current.startOfDay(for: start)
        let selectedChip = app.buttons["temporal.date.\(today.timeIntervalSince1970)"]
        XCTAssertTrue(selectedChip.waitForExistence(timeout: 2))

        selectedChip.swipeRight(velocity: .slow)

        XCTAssertNotEqual(selectedDate.label, originalSelection)
        let settledChip = app.buttons.matching(
            NSPredicate(format: "value CONTAINS %@", "Selected")
        ).firstMatch
        XCTAssertTrue(settledChip.waitForExistence(timeout: 2))
        XCTAssertEqual(settledChip.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 6)
        XCTAssertTrue(app.buttons["history.next-day"].isEnabled)
    }

    @MainActor
    func testTodayAlternativeAllowsElapsedEntryWhileFutureHistoryRemainsReadOnly() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()

        let add = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(add.waitForExistence(timeout: 2))
        add.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 2))
        app.buttons["history.add.food"].tap()
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 2))
        description.tap()
        description.typeText("Today lunch")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Today lunch"].waitForExistence(timeout: 2))

        app.buttons["history.next-day"].tap()
        XCTAssertTrue(app.staticTexts["history.future-read-only"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["history.add-at-selected-time"].exists)
    }

    @MainActor
    func testTomorrowIsFinalHistoryDisplayDay() throws {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()
        let today = Calendar.current.startOfDay(for: start)
        let futureContextDay = try XCTUnwrap(
            Calendar.current.date(
                byAdding: .day,
                value: 3,
                to: today
            )
        )
        let futureContextChip = app.buttons[
            "temporal.date.\(futureContextDay.timeIntervalSince1970)"
        ]
        XCTAssertTrue(futureContextChip.waitForExistence(timeout: 2))
        XCTAssertFalse(futureContextChip.isEnabled)

        for _ in 0 ..< 1 {
            XCTAssertTrue(app.buttons["history.next-day"].isEnabled)
            app.buttons["history.next-day"].tap()
        }
        XCTAssertFalse(app.buttons["history.next-day"].isEnabled)
        XCTAssertTrue(app.staticTexts["history.future-read-only"].exists)
    }

    @MainActor
    func testFirstBackwardSwipePreservesInitialDateRailAnchor() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: start)
        let todayChip = app.buttons[
            "temporal.date.\(today.timeIntervalSince1970)"
        ]
        XCTAssertTrue(todayChip.waitForExistence(timeout: 2))
        XCTAssertEqual(
            todayChip.frame.midX,
            app.windows.firstMatch.frame.midX,
            accuracy: 4
        )
        let initialAnchorX = todayChip.frame.midX

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 2))
        carousel.swipeRight(velocity: .slow)

        let settledChip = app.buttons.matching(
            NSPredicate(format: "value == %@", "Selected")
        ).firstMatch
        XCTAssertTrue(settledChip.waitForExistence(timeout: 2))
        XCTAssertEqual(
            settledChip.frame.midX,
            initialAnchorX,
            accuracy: 4,
            "The rail should keep the freely settled center day on its initial anchor."
        )
    }

    @MainActor
    func testFastHistoryFlickCrossesSeveralDaysAndFutureDaysRemainReadOnly() {
        let app = launchOnboardedHistory(
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        app.tabBars.buttons["History"].tap()

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 2))
        let todayLabel = selectedDate.label
        app.buttons["history.previous-day"].tap()
        let yesterdayLabel = selectedDate.label
        app.buttons["history.next-day"].tap()
        XCTAssertEqual(selectedDate.label, todayLabel)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 2))

        carousel.swipeRight(velocity: .fast)
        XCTAssertNotEqual(selectedDate.label, todayLabel)
        XCTAssertNotEqual(
            selectedDate.label,
            yesterdayLabel,
            "A fast native flick should be able to settle more than one day back."
        )
        captureScreenshot(named: "history-multi-day-settled-en-GB", in: app)

        let next = app.buttons["history.next-day"]
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(next.isEnabled)

        app.terminate()
        let boundaryApp = launchOnboardedHistory(
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        boundaryApp.tabBars.buttons["History"].tap()
        let boundaryDate = boundaryApp.staticTexts["history.selected-date"]
        XCTAssertTrue(boundaryDate.waitForExistence(timeout: 2))
        let boundaryTodayLabel = boundaryDate.label
        boundaryApp.buttons["history.next-day"].tap()
        XCTAssertNotEqual(boundaryDate.label, boundaryTodayLabel)
        XCTAssertTrue(
            boundaryApp.staticTexts["history.future-read-only"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(boundaryApp.buttons["history.add-at-selected-time"].exists)
        XCTAssertFalse(boundaryApp.buttons["history.review-suggestions"].exists)
    }

    @MainActor
    func testHistoryRunwayStaysPopulatedAfterRepeatedFastFlicksBeyondSevenDays() {
        let app = launchOnboardedHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)

        for _ in 0 ..< 8 {
            carousel.swipeRight(velocity: .fast)
            XCTAssertTrue(
                carousel.waitForExistence(timeout: 5),
                "carousel disappeared during runway extension: \(app.debugDescription)"
            )
        }

        XCTAssertFalse(app.otherElements["history.motion-unavailable"].exists)
        XCTAssertTrue(app.staticTexts["history.selected-date"].exists)
        XCTAssertTrue(app.buttons["history.previous-day"].exists)
    }

    @MainActor
    func testCarouselRailAndHeadingStaySynchronizedAcrossYearBoundary() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2027,
                    month: 1,
                    day: 2,
                    hour: 12
                )
            )
        )
        let app = launchOnboardedHistory(
            now: now,
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        app.tabBars.buttons["History"].tap()

        let heading = app.staticTexts["history.month-heading"]
        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(heading.waitForExistence(timeout: 2))
        let januaryHeading = heading.label
        let januaryDate = selectedDate.label

        app.buttons["history.previous-day"].tap()
        app.buttons["history.previous-day"].tap()

        let decemberDay = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 12, day: 31)
            )
        )
        let canonicalDecemberDay = calendar.startOfDay(for: decemberDay)
        XCTAssertNotEqual(heading.label, januaryHeading)
        XCTAssertNotEqual(selectedDate.label, januaryDate)
        XCTAssertTrue(app.buttons[
            "temporal.date.\(canonicalDecemberDay.timeIntervalSince1970)"
        ].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.scrollViews["history.day-carousel"].waitForExistence(timeout: 2)
        )
        captureScreenshot(named: "history-year-boundary-en-GB", in: app)

        app.buttons["history.next-day"].tap()
        app.buttons["history.next-day"].tap()
        XCTAssertEqual(heading.label, januaryHeading)
        XCTAssertEqual(selectedDate.label, januaryDate)
    }

    @MainActor
    func testHistoryAlternativesRemainReachableWithAccessibilityTextAndReduceMotion() {
        let app = launchOnboardedHistory(
            additionalArguments: [
                "-AppleLocale", "en_US",
                "-AppleInterfaceStyle", "Dark",
                "-UIAccessibilityDarkerSystemColorsEnabled", "YES",
                "-UIAccessibilityReduceMotionEnabled", "YES",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        )
        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["history.selected-date"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["history.previous-day"].exists)
        XCTAssertTrue(app.buttons["history.next-day"].exists)
        XCTAssertTrue(app.buttons["history.choose-date"].exists)
        let today = Calendar.current.startOfDay(for: start)
        XCTAssertTrue(app.buttons[
            "temporal.date.\(today.timeIntervalSince1970)"
        ].waitForExistence(timeout: 2))

        app.buttons["history.previous-day"].tap()
        let addAlternative = app.buttons["history.add-at-selected-time"]
        if !addAlternative.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(addAlternative.exists)
        XCTAssertTrue(addAlternative.isHittable)
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.56))
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)
        XCTAssertTrue(addAlternative.isHittable)
        captureScreenshot(named: "history-dark-accessibility-en-US", in: app)
    }

    @MainActor
    func testMidnightMarkerRemainsVisibleAtAccessibilityTextSizeInLTRAndRTL() {
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

        for configuration in configurations {
            let app = launchOnboardedHistory(
                additionalArguments: configuration.arguments
            )
            app.tabBars.buttons["History"].tap()
            XCTAssertTrue(app.staticTexts["history.selected-date"].waitForExistence(timeout: 2))
            app.buttons["history.previous-day"].tap()
            XCTAssertTrue(app.scrollViews["history.day-carousel"].exists)
            captureScreenshot(
                named: "history-midnight-marker-accessibility-\(configuration.name)",
                in: app
            )
            app.terminate()
        }
    }

    @MainActor
    func testDirectHistoryEntryConfirmsTimeAndSavesFoodAndFavouriteDrink() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()
        selectYesterday(in: app)

        app.buttons["history.add-at-selected-time"].tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["history.add.summary"].exists)
        XCTAssertTrue(app.datePickers["history.add.date"].exists)
        XCTAssertTrue(app.datePickers["history.add.time"].exists)
        app.buttons["history.add.food"].tap()
        XCTAssertTrue(app.textFields["food.description"].waitForExistence(timeout: 2))
        app.textFields["food.description"].tap()
        app.textFields["food.description"].typeText("Historical lunch")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Historical lunch"].waitForExistence(timeout: 2))

        app.buttons["history.add-at-selected-time"].tap()
        app.buttons["history.add.drink"].tap()
        XCTAssertTrue(app.buttons["drink.favourite.water"].waitForExistence(timeout: 2))
        app.buttons["drink.favourite.water"].tap()
        XCTAssertTrue(app.buttons["drink.editor.save"].waitForExistence(timeout: 2))
        app.buttons["drink.editor.save"].tap()
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDirectHistoryEntryCancellationWritesNothingAndFailedSaveRetainsDraft() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true) + [
            "--seed-onboarded",
            "--simulate-food-save-failure",
        ]
        app.launch()
        app.tabBars.buttons["History"].tap()
        selectYesterday(in: app)

        app.buttons["history.add-at-selected-time"].tap()
        app.buttons["history.add.cancel"].tap()
        XCTAssertFalse(app.navigationBars["Add to history"].exists)
        XCTAssertFalse(app.staticTexts["Unpersisted meal"].exists)

        app.buttons["history.add-at-selected-time"].tap()
        app.buttons["history.add.food"].tap()
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 2))
        description.tap()
        description.typeText("Unpersisted meal")
        app.buttons["food.save"].tap()

        XCTAssertTrue(app.staticTexts["food.save-error"].waitForExistence(timeout: 2))
        XCTAssertEqual(description.value as? String, "Unpersisted meal")
        app.buttons["food.cancel"].tap()
        XCTAssertFalse(app.staticTexts["Unpersisted meal"].exists)
    }

    @MainActor
    func testDirectHistoryEntrySavesCustomNonCaloricAndCaloricDrinks() {
        let app = launchOnboardedHistory()
        app.tabBars.buttons["History"].tap()
        selectYesterday(in: app)

        addCustomDrink(
            named: "Sparkling water",
            volume: "330",
            caloric: false,
            in: app
        )
        XCTAssertTrue(app.staticTexts["Sparkling water"].waitForExistence(timeout: 2))

        addCustomDrink(
            named: "Orange juice",
            volume: "200",
            caloric: true,
            in: app
        )
        XCTAssertTrue(app.staticTexts["Sparkling water"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Orange juice"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Mixed fasting classifications")
        ).firstMatch.exists)
    }

    @MainActor
    func testHistoricalFoodEditorKeepsStoredLocalDateAndTime() {
        let now = Date(timeIntervalSince1970: 2_300_000_000)
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: now, resetData: true) + [
            "--seed-slice3-history",
            "-AppleLocale",
            "en_GB",
        ]
        app.launch()
        app.tabBars.buttons["History"].tap()
        app.buttons["history.previous-day"].tap()
        app.buttons["history.previous-day"].tap()
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 2))
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settledExpectation], timeout: 5), .completed)

        let breakfastCandidates = app.otherElements["history.event-info-panel"].buttons.matching(
            NSPredicate(
                format: "label CONTAINS %@ AND enabled == true",
                "Breakfast"
            )
        )
        XCTAssertGreaterThan(breakfastCandidates.count, 0)
        let breakfast = breakfastCandidates.element(boundBy: breakfastCandidates.count - 1)
        XCTAssertTrue(breakfast.waitForExistence(timeout: 2))
        tapFullyVisible(breakfast, in: app.scrollViews["history.content"], app: app)

        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.buttons["Date Picker"].value as? String)?.contains("17 Nov 2042") == true)
        XCTAssertEqual(app.buttons["Time Picker"].value as? String, "08:53")
    }

    @MainActor
    func testCompletedFastAppearsAndEditorUsesStoredBoundaries() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()

        let row = recordedFastRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.label.contains("Recorded fast"))
        XCTAssertTrue(row.label.contains("duration 1 hour"))
        XCTAssertTrue(row.label.contains("goal 12 hours"))

        row.tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["history.edit.start-date"].exists)
        XCTAssertTrue(app.datePickers["history.edit.start-time"].exists)
        XCTAssertTrue(app.datePickers["history.edit.end-date"].exists)
        XCTAssertTrue(app.datePickers["history.edit.end-time"].exists)
    }

    @MainActor
    func testEditAndDeleteCancellationLeaveCompletedRecordAvailable() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.navigationBars["Edit fast"].waitForExistence(timeout: 2))

        app.buttons["history.edit.delete"].tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["This removes the record from this device."].exists)
        alert.buttons["Cancel"].tap()

        XCTAssertTrue(app.navigationBars["Edit fast"].exists)
        app.buttons["history.edit.cancel"].tap()
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 2))
    }

    @MainActor
    func testConfirmedDeletePersistsAcrossRelaunch() {
        let app = launchCompletedFast()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.delete"].waitForExistence(timeout: 2))
        app.buttons["history.edit.delete"].tap()
        let alert = app.alerts["Delete this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["Delete fast"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(7200))
        app.launch()
        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.staticTexts["No completed fasts"].waitForExistence(timeout: 2))
        let deletedRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
        XCTAssertFalse(deletedRow.exists)
    }

    @MainActor
    func testDeleteFailureKeepsEditorAndRecordAvailable() {
        let app = launchCompletedFast()
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        app.tabBars.buttons["History"].tap()
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.delete"].waitForExistence(timeout: 2))
        app.buttons["history.edit.delete"].tap()
        app.alerts["Delete this fast?"].buttons["Delete fast"].tap()

        let error = app.staticTexts["history.edit.delete-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(
            error.label,
            "This fast couldn’t be deleted. Please try again."
        )
        XCTAssertTrue(app.navigationBars["Edit fast"].exists)

        app.buttons["history.edit.cancel"].tap()
        XCTAssertTrue(recordedFastRow(in: app).waitForExistence(timeout: 2))
    }

    @MainActor
    func testEditFailureKeepsEditorSelectionsAndStoredRowAvailable() {
        let app = launchCompletedFast()
        app.terminate()
        app.launchArguments = launchArguments(
            now: start.addingTimeInterval(3600),
            simulateHistoryFailure: true
        )
        app.launch()
        app.tabBars.buttons["History"].tap()
        let originalRowLabel = recordedFastRow(in: app).label
        recordedFastRow(in: app).tap()
        XCTAssertTrue(app.buttons["history.edit.save"].waitForExistence(timeout: 2))
        let selectedStart = app.datePickers["history.edit.start-time"].value as? String
        let selectedEnd = app.datePickers["history.edit.end-time"].value as? String

        app.buttons["history.edit.save"].tap()

        let error = app.staticTexts["history.edit.save-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(
            error.label,
            "Your changes couldn’t be saved. Please try again."
        )
        XCTAssertEqual(
            app.datePickers["history.edit.start-time"].value as? String,
            selectedStart
        )
        XCTAssertEqual(
            app.datePickers["history.edit.end-time"].value as? String,
            selectedEnd
        )
        app.buttons["history.edit.cancel"].tap()
        XCTAssertEqual(recordedFastRow(in: app).label, originalRowLabel)
    }

    @MainActor
    private func launchCompletedFast() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: start, resetData: true)
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = launchArguments(now: start.addingTimeInterval(3600))
        app.launch()
        app.buttons["fast.end"].tap()
        let alert = app.alerts["End this fast?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["End fast"].tap()
        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        return app
    }

    @MainActor
    private func launchOnboardedHistory(
        now: Date? = nil,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let appearanceArguments = additionalArguments.contains(
            "-AppleInterfaceStyle"
        ) ? [] : ["-AppleInterfaceStyle", "Light"]
        app.launchArguments = launchArguments(
            now: now ?? start,
            resetData: true
        ) + ["--seed-onboarded"] + appearanceArguments + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    private func launchMidnightSeam(
        now: Date,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(now: now, resetData: true)
            + [
                "--seed-history-midnight-seam",
                "--seed-onboarded",
                "--suppress-automatic-live-activity-offer",
                "--ui-testing-start-history",
            ]
            + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    private func selectYesterday(in app: XCUIApplication) {
        let previous = app.buttons["history.previous-day"]
        XCTAssertTrue(previous.waitForExistence(timeout: 2))
        previous.tap()
        XCTAssertTrue(app.buttons["history.add-at-selected-time"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func addCustomDrink(
        named name: String,
        volume: String,
        caloric: Bool,
        in app: XCUIApplication
    ) {
        app.buttons["history.add-at-selected-time"].tap()
        app.buttons["history.add.drink"].tap()
        app.buttons["drink.custom"].tap()
        XCTAssertTrue(app.navigationBars["Add another drink"].waitForExistence(timeout: 2))
        app.textFields["drink.name"].tap()
        app.textFields["drink.name"].typeText(name)
        let volumeField = app.textFields["drink.volume"]
        volumeField.tap()
        volumeField.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        volumeField.typeText(volume)
        if caloric {
            app.buttons["Caloric"].tap()
        }
        app.buttons["drink.editor.save"].tap()
    }

    @MainActor
    private func captureScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func nearbySelectedDateLabels(
        around day: Date,
        calendar: Calendar
    ) -> Set<String> {
        Set((-1 ... 1).compactMap { offset in
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: day) else {
                return nil
            }
            let label = candidate.formatted(
                .dateTime.weekday(.abbreviated).day().month(.abbreviated)
            )
            return "Selected day, \(label)"
        })
    }

    @MainActor
    @discardableResult
    private func assertSettledSeamState(
        in app: XCUIApplication,
        carousel: XCUIElement,
        selectedDate: XCUIElement,
        expectedSelectedDate: String? = nil,
        allowedSelectedDates: Set<String> = [],
        activeFastIdentifier: String,
        noonMarkerIdentifier: String,
        requireNoonMarkerIdentifier: Bool = false,
        expectedNoonMarkerVisibility: Bool? = nil,
        expectedActiveDuration: String? = "18:13:00"
    ) -> CGRect {
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settledExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        let selectedDateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", "Selected day, "),
            object: selectedDate
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedDateExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        if let expectedSelectedDate {
            XCTAssertEqual(selectedDate.label, expectedSelectedDate)
        } else {
            XCTAssertTrue(
                allowedSelectedDates.contains(selectedDate.label),
                "Unexpected settled History selection: \(selectedDate.label)"
            )
        }

        let activeCandidates = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label BEGINSWITH %@",
                activeFastIdentifier,
                "Active Fast"
            )
        )
        let visibleActiveExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Self.visibleElement(
                    in: activeCandidates,
                    boundedBy: carousel
                ) != nil
            },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [visibleActiveExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        guard let activeFast = Self.visibleElement(
            in: activeCandidates,
            boundedBy: carousel
        ) else {
            XCTFail("No visible active-fast candidate inside history.day-carousel")
            return activeCandidates.firstMatch.frame
        }
        XCTAssertFalse(activeFast.label.isEmpty, app.debugDescription)
        XCTAssertTrue(activeFast.label.contains("Active Fast"))
        if let expectedActiveDuration {
            XCTAssertTrue(activeFast.label.contains(expectedActiveDuration), activeFast.debugDescription)
        }
        XCTAssertTrue(carousel.frame.intersects(activeFast.frame))
        Self.assertVisualInteractionState(activeFast, boundedBy: carousel.frame)

        let noonCandidates = app.buttons.matching(
            NSPredicate(format: "identifier == %@", noonMarkerIdentifier)
        )
        if requireNoonMarkerIdentifier {
            XCTAssertGreaterThan(noonCandidates.count, 0, app.debugDescription)
        }
        let visibleNoonCandidates = (0 ..< noonCandidates.count).compactMap { index -> XCUIElement? in
            let candidate = noonCandidates.element(boundBy: index)
            return candidate.exists
                && Self.isVisibleFrame(candidate.frame, boundedBy: carousel.frame)
                ? candidate
                : nil
        }
        let labelledNoonMarker = visibleNoonCandidates.first { $0.label.contains("12:00") }
        if let expectedNoonMarkerVisibility {
            if expectedNoonMarkerVisibility {
                XCTAssertNotNil(labelledNoonMarker, app.debugDescription)
                if let labelledNoonMarker {
                    XCTAssertTrue(
                        carousel.frame.intersects(labelledNoonMarker.frame),
                        app.debugDescription
                    )
                }
            } else {
                let hasOutsideOrClippedNoonMarker = (0 ..< noonCandidates.count).contains { index in
                    let candidate = noonCandidates.element(boundBy: index)
                    let frame = candidate.frame
                    return candidate.exists
                        && (!carousel.frame.intersects(frame)
                            || frame.minX < carousel.frame.minX
                            || frame.maxX > carousel.frame.maxX)
                }
                XCTAssertTrue(hasOutsideOrClippedNoonMarker, app.debugDescription)
            }
        }
        if let noonMarker = labelledNoonMarker {
            Self.assertVisualInteractionState(noonMarker, boundedBy: carousel.frame)
        } else {
            XCTAssertTrue(
                visibleNoonCandidates.allSatisfy { !$0.label.contains("12:00") },
                "The 12:00 marker must be labelled when visible, not replaced by an unrelated day.\n"
                    + app.debugDescription
            )
        }
        return activeFast.frame
    }

    @MainActor
    private static func assertVisualInteractionState(
        _ candidate: XCUIElement,
        boundedBy container: CGRect
    ) {
        if !candidate.isEnabled {
            XCTAssertFalse(candidate.isEnabled, candidate.debugDescription)
            return
        }
        if candidate.isHittable {
            XCTAssertTrue(candidate.isEnabled, candidate.debugDescription)
            return
        }

        // Visual interval buttons may be exposed in the accessibility tree
        // while their ancestor surface is not hit-testable. Their frame and
        // label remain the visual evidence; semantic detail rows provide the
        // accessible interaction target.
        if candidate.isEnabled {
            return
        }

        // Native scrolling can leave an enabled visual mark partly clipped at
        // the viewport edge. It remains valid visual evidence even though
        // XCTest cannot hit its full accessibility frame.
        if !container.contains(candidate.frame) {
            XCTAssertTrue(candidate.isEnabled, candidate.debugDescription)
            return
        }

        XCTAssertFalse(
            candidate.isEnabled,
            "A fully visible, non-hittable visual interval must be explicitly disabled.\n"
                + candidate.debugDescription
        )
        let accessibilityState = "\(candidate.value ?? "")\n\(candidate.debugDescription)"
        XCTAssertFalse(accessibilityState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @MainActor
    private static func visibleElement(
        in query: XCUIElementQuery,
        boundedBy container: XCUIElement
    ) -> XCUIElement? {
        for index in 0 ..< query.count {
            let candidate = query.element(boundBy: index)
            let frame = candidate.frame
            guard candidate.exists,
                  isVisibleFrame(frame, boundedBy: container.frame)
            else { continue }
            return candidate
        }
        return nil
    }

    private static func isVisibleFrame(_ candidate: CGRect, boundedBy container: CGRect) -> Bool {
        guard candidate.origin.x.isFinite, candidate.origin.y.isFinite,
              candidate.size.width.isFinite, candidate.size.height.isFinite,
              container.origin.x.isFinite, container.origin.y.isFinite,
              container.size.width.isFinite, container.size.height.isFinite,
              candidate.width > 0, candidate.height > 0,
              container.width > 0, container.height > 0
        else { return false }
        return candidate.intersects(container)
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func openHistory(in app: XCUIApplication) {
        let historyTitle = app.staticTexts["screen-title.history"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5), app.debugDescription)
        let visibleTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: historyTitle
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [visibleTitle], timeout: 5),
            .completed,
            app.debugDescription
        )
        XCTAssertGreaterThan(historyTitle.frame.height, 35, app.debugDescription)
    }

    @MainActor
    private func setStartTimePicker(
        in app: XCUIApplication,
        calendar _: Calendar,
        date: Date
    ) {
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
            let form = app.scrollViews.firstMatch
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
        _ = date
    }

    @MainActor
    private func visibleActiveFast(
        in app: XCUIApplication,
        carousel: XCUIElement
    ) -> XCUIElement? {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.active-fast.")
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Self.visibleElement(in: candidates, boundedBy: carousel) != nil
            },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        guard let candidate = Self.visibleElement(in: candidates, boundedBy: carousel) else {
            XCTFail("No visible edited active-fast fragment.\n\(app.debugDescription)")
            return nil
        }
        XCTAssertTrue(
            candidate.identifier.hasPrefix("history.active-fast."),
            candidate.debugDescription
        )
        XCTAssertTrue(Self.isVisibleFrame(candidate.frame, boundedBy: carousel.frame))
        return candidate
    }

    @MainActor
    private func addWaterFromToday(in app: XCUIApplication) -> String {
        app.tabBars.buttons["Today"].tap()
        let addDrink = app.buttons["drink.add"]
        XCTAssertTrue(addDrink.waitForExistence(timeout: 5), app.debugDescription)
        if !addDrink.isHittable {
            let todayScroll = app.scrollViews.firstMatch
            XCTAssertTrue(todayScroll.waitForExistence(timeout: 5), app.debugDescription)
            todayScroll.swipeUp()
        }
        XCTAssertTrue(addDrink.isHittable, addDrink.debugDescription)
        addDrink.tap()
        let water = app.buttons["drink.favourite.water"]
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
        return waterEntry.identifier.replacingOccurrences(of: "timeline.entry.", with: "")
    }

    @MainActor
    private func historyMarkerIdentifiers(in app: XCUIApplication) -> Set<String> {
        let markers = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                "history.event.",
                "history.visual-event."
            )
        )
        return Set((0 ..< markers.count).map { markers.element(boundBy: $0).identifier })
    }

    @MainActor
    private func assertVisibleActiveFastFragments(
        in app: XCUIApplication,
        carousel: XCUIElement,
        identifier: String
    ) -> [CGRect] {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier == %@", identifier)
        )
        let fragmentsExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                guard candidates.count == 2 else { return false }
                return (0 ..< candidates.count).allSatisfy { index in
                    let candidate = candidates.element(boundBy: index)
                    return candidate.exists
                        && Self.isVisibleFrame(candidate.frame, boundedBy: carousel.frame)
                }
            },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [fragmentsExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        XCTAssertEqual(candidates.count, 2, app.debugDescription)
        var frames: [CGRect] = []
        for index in 0 ..< candidates.count {
            let candidate = candidates.element(boundBy: index)
            let frame = candidate.frame
            frames.append(frame)
            XCTAssertEqual(candidate.identifier, identifier, candidate.debugDescription)
            XCTAssertTrue(
                frame.origin.x.isFinite
                    && frame.origin.y.isFinite
                    && frame.width.isFinite
                    && frame.height.isFinite,
                candidate.debugDescription
            )
            XCTAssertGreaterThan(frame.width, 0, candidate.debugDescription)
            XCTAssertGreaterThan(frame.height, 0, candidate.debugDescription)
            XCTAssertTrue(carousel.frame.intersects(frame), candidate.debugDescription)
        }
        return frames
    }

    @MainActor
    private func waitForSettledHistory(
        in app: XCUIApplication,
        selectedDate: XCUIElement,
        carousel: XCUIElement,
        expectedSelectedDate: String
    ) {
        let selectedDateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedSelectedDate),
            object: selectedDate
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [selectedDateExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [settledExpectation], timeout: 5),
            .completed,
            app.debugDescription
        )
    }

    @MainActor
    private func recordedFastRow(in app: XCUIApplication) -> XCUIElement {
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        if !row.isHittable {
            app.swipeUp()
        }
        return row
    }

    @MainActor
    private func tapFullyVisible(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        app: XCUIApplication
    ) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2), app.debugDescription)
        if !element.isHittable || element.frame.maxY > app.frame.maxY - 120 {
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(
                    forDuration: 0.05,
                    thenDragTo: scrollView.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
                    )
                )
        }
        let fullyVisible = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let candidate = object as? XCUIElement else { return false }
                return candidate.isHittable
                    && candidate.frame.minY >= scrollView.frame.minY + 8
                    && candidate.frame.maxY <= app.frame.maxY - 120
            },
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [fullyVisible], timeout: 5),
            .completed,
            app.debugDescription
        )
        element.tap()
    }

    private func launchArguments(
        now: Date,
        resetData: Bool = false,
        simulateHistoryFailure: Bool = false
    ) -> [String] {
        var arguments = ["--ui-testing", "--fixed-now", String(now.timeIntervalSince1970)]
        if resetData {
            arguments.append("--reset-data")
        }
        if simulateHistoryFailure {
            arguments.append("--simulate-fast-history-failure")
        }
        return arguments
    }

    private func londonLaunchArguments(now: Date, resetData: Bool = false) -> [String] {
        launchArguments(now: now, resetData: resetData)
            + ["-AppleLocale", "en_GB", "-NSTimeZone", "Europe/London"]
    }
}
