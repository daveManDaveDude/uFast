import XCTest

extension HistoryUITests {
    @MainActor
    func testHistorySwipeButtonsAndDateChipShareOneSelectedDay() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let todayLabel = selectedDate.label
        let nextDay = app.buttons["history.next-day"]
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(nextDay.isEnabled, nextDay.debugDescription)

        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let deliberatePreviousLabel = selectedDate.label
        XCTAssertNotEqual(deliberatePreviousLabel, todayLabel)

        let today = Calendar.current.startOfDay(for: start)
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let todayChip = dateNavigator.buttons["temporal.date.\(today.timeIntervalSince1970)"]
        XCTAssertTrue(todayChip.waitForExistence(timeout: 5), dateNavigator.debugDescription)
        XCTAssertTrue(waitForHittable(todayChip, app: app), todayChip.debugDescription)
        todayChip.tap()
        XCTAssertTrue(waitForHistorySelection(selectedDate, expectedLabel: todayLabel), app.debugDescription)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(waitForExistenceIfNeeded(carousel), app.debugDescription)
        carousel.swipeRight(velocity: .slow)
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertNotEqual(selectedDate.label, todayLabel)
        let freelySettledLabel = selectedDate.label
        XCTAssertTrue(nextDay.isEnabled, nextDay.debugDescription)

        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertNotEqual(selectedDate.label, freelySettledLabel)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertTrue(waitForHistorySelection(selectedDate, expectedLabel: freelySettledLabel), app.debugDescription)
    }

    @MainActor
    func testManualDateRailSettlementSelectsNearestCenteredChipAndSynchronizesTimeline() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let originalSelection = selectedDate.label
        let today = Calendar.current.startOfDay(for: start)
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let selectedChip = dateNavigator.buttons["temporal.date.\(today.timeIntervalSince1970)"]
        XCTAssertTrue(selectedChip.waitForExistence(timeout: 5), dateNavigator.debugDescription)
        XCTAssertTrue(waitForHittable(selectedChip, app: app), selectedChip.debugDescription)

        selectedChip.swipeRight(velocity: .slow)
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)

        XCTAssertNotEqual(selectedDate.label, originalSelection)
        let settledChip = dateNavigator.buttons.matching(
            NSPredicate(format: "value CONTAINS %@", "Selected")
        ).firstMatch
        XCTAssertTrue(settledChip.waitForExistence(timeout: 5), dateNavigator.debugDescription)
        XCTAssertEqual(settledChip.frame.midX, app.windows.firstMatch.frame.midX, accuracy: 6)
        XCTAssertTrue(app.buttons["history.next-day"].isEnabled)
    }

    @MainActor
    func testTodayAlternativeAllowsElapsedEntryWhileFutureHistoryRemainsReadOnly() {
        let app = launchHistory(
            arguments: launchArguments(
                now: start.addingTimeInterval(8 * 60 * 60),
                resetData: true,
                seedOnboarded: true
            )
        )
        selectHistoryTab(in: app)

        let add = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(add.label, "Add")
        if !add.isHittable {
            let historyContent = app.scrollViews["history.content"]
            XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
            historyContent.swipeUp()
        }
        XCTAssertTrue(waitForHittable(add, app: app), add.debugDescription)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 5), app.debugDescription)
        let addFood = app.buttons["history.add.food"]
        XCTAssertTrue(addFood.waitForExistence(timeout: 5), app.debugDescription)
        addFood.tap()
        let customFood = app.buttons["food.custom"]
        if customFood.waitForExistence(timeout: 5) {
            customFood.tap()
        }
        let description = app.textFields["food.description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()
        description.typeText("Today lunch")
        let saveFood = app.buttons["food.save"]
        XCTAssertTrue(saveFood.waitForExistence(timeout: 5), app.debugDescription)
        saveFood.tap()
        XCTAssertTrue(app.staticTexts["Today lunch"].waitForExistence(timeout: 5), app.debugDescription)

        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(nextDay.isEnabled, nextDay.debugDescription)
        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertTrue(app.staticTexts["history.future-read-only"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.add-at-selected-time"].waitForNonExistence(timeout: 5), app.debugDescription)

        let adjacentFoodMarker = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "history.visual-event.",
                "Food event"
            )
        ).firstMatch
        XCTAssertTrue(adjacentFoodMarker.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(adjacentFoodMarker.isEnabled, adjacentFoodMarker.debugDescription)
    }

    @MainActor
    func testTomorrowIsFinalHistoryDisplayDay() throws {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)
        let today = Calendar.current.startOfDay(for: start)
        let futureContextDay = try XCTUnwrap(
            Calendar.current.date(
                byAdding: .day,
                value: 3,
                to: today
            )
        )
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let futureContextChip = dateNavigator.buttons[
            "temporal.date.\(futureContextDay.timeIntervalSince1970)"
        ]
        XCTAssertTrue(futureContextChip.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(futureContextChip.isEnabled, futureContextChip.debugDescription)

        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(nextDay.isEnabled, nextDay.debugDescription)
        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertFalse(nextDay.isEnabled, nextDay.debugDescription)
        XCTAssertTrue(app.staticTexts["history.future-read-only"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testFirstBackwardSwipePreservesInitialDateRailAnchor() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true)
        )
        selectHistoryTab(in: app)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: start)
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let todayChip = dateNavigator.buttons[
            "temporal.date.\(today.timeIntervalSince1970)"
        ]
        XCTAssertTrue(todayChip.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(waitForHittable(todayChip, app: app), todayChip.debugDescription)
        XCTAssertEqual(
            todayChip.frame.midX,
            app.windows.firstMatch.frame.midX,
            accuracy: 4
        )
        let initialAnchorX = todayChip.frame.midX

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        carousel.swipeRight(velocity: .slow)
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)

        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        let settledChip = dateNavigator.buttons.matching(
            NSPredicate(format: "value == %@", "Selected")
        ).firstMatch
        XCTAssertTrue(settledChip.waitForExistence(timeout: 5), dateNavigator.debugDescription)
        XCTAssertEqual(
            settledChip.frame.midX,
            initialAnchorX,
            accuracy: 4,
            "The rail should keep the freely settled center day on its initial anchor."
        )
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testFastHistoryFlickCrossesSeveralDaysAndFutureDaysRemainReadOnly() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true),
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        selectHistoryTab(in: app)

        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let todayLabel = selectedDate.label
        let previousDay = app.buttons["history.previous-day"]
        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(previousDay.isEnabled, previousDay.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let yesterdayLabel = selectedDate.label
        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertTrue(waitForHistorySelection(selectedDate, expectedLabel: todayLabel), app.debugDescription)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 2), carousel.debugDescription)

        carousel.swipeRight(velocity: .fast)
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertNotEqual(selectedDate.label, todayLabel)
        XCTAssertNotEqual(
            selectedDate.label,
            yesterdayLabel,
            "A fast native flick should be able to settle more than one day back."
        )
        captureScreenshot(named: "history-multi-day-settled-en-GB", in: app)

        let next = app.buttons["history.next-day"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(next.isEnabled, next.debugDescription)
        next.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertTrue(next.isEnabled, next.debugDescription)

        app.terminate()
        let boundaryApp = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true),
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        selectHistoryTab(in: boundaryApp)
        let boundaryDate = boundaryApp.staticTexts["history.selected-date"]
        XCTAssertTrue(boundaryDate.waitForExistence(timeout: 5), boundaryApp.debugDescription)
        let boundaryTodayLabel = boundaryDate.label
        let boundaryNextDay = boundaryApp.buttons["history.next-day"]
        XCTAssertTrue(boundaryNextDay.waitForExistence(timeout: 5), boundaryApp.debugDescription)
        boundaryNextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: boundaryApp), boundaryApp.debugDescription)
        XCTAssertNotEqual(boundaryDate.label, boundaryTodayLabel)
        XCTAssertTrue(
            boundaryApp.staticTexts["history.future-read-only"]
                .waitForExistence(timeout: 5),
            boundaryApp.debugDescription
        )
        XCTAssertTrue(
            boundaryApp.buttons["history.add-at-selected-time"].waitForNonExistence(timeout: 5),
            boundaryApp.debugDescription
        )
        XCTAssertTrue(
            boundaryApp.buttons["history.review-suggestions"].waitForNonExistence(timeout: 5),
            boundaryApp.debugDescription
        )
    }

    @MainActor
    func testHistoryRunwayStaysPopulatedAfterRepeatedFastFlicksBeyondSevenDays() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true),
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        selectHistoryTab(in: app)
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)

        for _ in 0 ..< 8 {
            carousel.swipeRight(velocity: .fast)
            XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
            XCTAssertTrue(
                waitForExistenceIfNeeded(carousel),
                "carousel disappeared during runway extension: \(app.debugDescription)"
            )
        }

        XCTAssertFalse(app.otherElements["history.motion-unavailable"].exists)
        XCTAssertTrue(app.staticTexts["history.selected-date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.previous-day"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
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
        let app = launchHistory(
            arguments: launchArguments(
                now: now,
                resetData: true,
                seedOnboarded: true
            ),
            additionalArguments: ["-AppleLocale", "en_GB"]
        )
        selectHistoryTab(in: app)

        let heading = app.staticTexts["history.month-heading"]
        let selectedDate = app.staticTexts["history.selected-date"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let januaryHeading = heading.label
        let januaryDate = selectedDate.label

        let previousDay = app.buttons["history.previous-day"]
        let nextDay = app.buttons["history.next-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(nextDay.waitForExistence(timeout: 5), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)

        let decemberDay = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 12, day: 31)
            )
        )
        let canonicalDecemberDay = calendar.startOfDay(for: decemberDay)
        XCTAssertNotEqual(heading.label, januaryHeading)
        XCTAssertNotEqual(selectedDate.label, januaryDate)
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            dateNavigator.buttons[
                "temporal.date.\(canonicalDecemberDay.timeIntervalSince1970)"
            ].waitForExistence(timeout: 5),
            dateNavigator.debugDescription
        )
        XCTAssertTrue(
            app.scrollViews["history.day-carousel"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        captureScreenshot(named: "history-year-boundary-en-GB", in: app)

        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        nextDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        XCTAssertTrue(waitForHistorySelection(selectedDate, expectedLabel: januaryDate), app.debugDescription)
        XCTAssertEqual(heading.label, januaryHeading)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testHistoryAlternativesRemainReachableWithAccessibilityTextAndReduceMotion() {
        let app = launchHistory(
            arguments: launchArguments(now: start, resetData: true, seedOnboarded: true),
            additionalArguments: [
                "-AppleLocale", "en_US",
                "-AppleInterfaceStyle", "Dark",
                "-UIAccessibilityDarkerSystemColorsEnabled", "YES",
                "-UIAccessibilityReduceMotionEnabled", "YES",
                "-UIPreferredContentSizeCategoryName",
                // swiftlint:disable:next trailing_comma
                "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        )
        selectHistoryTab(in: app)

        XCTAssertTrue(app.staticTexts["history.selected-date"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.previous-day"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.next-day"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.choose-date"].waitForExistence(timeout: 5), app.debugDescription)
        let today = Calendar.current.startOfDay(for: start)
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(dateNavigator.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            dateNavigator.buttons[
                "temporal.date.\(today.timeIntervalSince1970)"
            ].waitForExistence(timeout: 5),
            dateNavigator.debugDescription
        )

        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(waitForHittable(previousDay, app: app), previousDay.debugDescription)
        previousDay.tap()
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let addAlternative = app.buttons["history.add-at-selected-time"]
        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        if !addAlternative.isHittable {
            historyContent.swipeUp()
        }
        XCTAssertTrue(addAlternative.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(addAlternative.isHittable, addAlternative.debugDescription)
        let dragStart = historyContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let dragEnd = historyContent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.56))
        dragStart.press(forDuration: 0.1, thenDragTo: dragEnd)
        XCTAssertTrue(addAlternative.isHittable, addAlternative.debugDescription)
        captureScreenshot(named: "history-dark-accessibility-en-US", in: app)
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testPseudolocalizedHistoryAtAXXXLRTLAndReduceMotionUsesStableSelectors() {
        let configuration = UITestLaunchConfiguration(
            resetData: true,
            pseudolocalization: true,
            seedOnboarded: true,
            fixedNow: start,
            seedHistoryMidnightSeam: true,
            startsOnHistory: true,
            historyMotionRetryFixture: true,
            appleLanguages: "(ar)",
            appleLocale: "ar_SA",
            timeZone: "Asia/Riyadh",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        let app = XCUIApplication()
        app.launchArguments = configuration.arguments + [
            // swiftlint:disable:next trailing_comma
            "-UIAccessibilityReduceMotionEnabled", "YES",
        ]
        app.launch()

        selectHistoryTab(in: app)
        let carousel = app.descendants(matching: .any)["history.carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let dayCarousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(dayCarousel.waitForExistence(timeout: 5), app.debugDescription)
        let selectedDate = app.descendants(matching: .any)["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5), app.debugDescription)

        let retry = app.descendants(matching: .any)["history.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), app.debugDescription)
        let retryButton = app.buttons["history.motion-retry"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5), app.debugDescription)
        retryButton.tap()
        XCTAssertTrue(retry.waitForNonExistence(timeout: 5), app.debugDescription)
        let historyContent = app.scrollViews["history.content"]
        XCTAssertTrue(historyContent.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0 ..< 8 where !previousDay.isHittable {
            historyContent.swipeDown()
        }
        XCTAssertTrue(waitForHittable(previousDay, app: app), previousDay.debugDescription)
        previousDay.tap()
        let extensionRetry = app.descendants(matching: .any)["history.extension-retry"]
        XCTAssertTrue(extensionRetry.waitForExistence(timeout: 5), app.debugDescription)
        let extensionRetryButton = app.buttons["history.motion-extension-retry"]
        XCTAssertTrue(extensionRetryButton.waitForExistence(timeout: 5), app.debugDescription)
        extensionRetryButton.tap()
        XCTAssertTrue(extensionRetry.waitForNonExistence(timeout: 5), app.debugDescription)

        let historyList = app.descendants(matching: .any)["history.list"]
        XCTAssertTrue(historyList.waitForExistence(timeout: 5), app.debugDescription)
        let fastRow = historyList.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.fast.")
        ).firstMatch
        XCTAssertTrue(fastRow.waitForExistence(timeout: 5), historyList.debugDescription)
        if !fastRow.isHittable {
            historyContent.swipeUp()
        }
        XCTAssertTrue(waitForHittable(fastRow, app: app), fastRow.debugDescription)
        fastRow.tap()
        let editorCancel = app.buttons["history.edit.cancel"]
        XCTAssertTrue(editorCancel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["history.edit.save"].waitForExistence(timeout: 5), app.debugDescription)
        editorCancel.tap()
        XCTAssertTrue(editorCancel.waitForNonExistence(timeout: 5), app.debugDescription)
    }
}
