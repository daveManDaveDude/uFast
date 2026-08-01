import XCTest

// swiftlint:disable file_length trailing_comma type_body_length

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

        let activeFast = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Started fast")
        ).firstMatch
        XCTAssertTrue(activeFast.waitForExistence(timeout: 2))
        XCTAssertTrue(activeFast.label.contains("end"))
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

        let carousel = app.otherElements["history.day-carousel"]
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

        let carousel = app.otherElements["history.day-carousel"]
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

        let carousel = app.otherElements["history.day-carousel"]
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
            app.otherElements["history.day-carousel"].waitForExistence(timeout: 2)
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
            XCTAssertTrue(app.otherElements["history.day-carousel"].exists)
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
        XCTAssertTrue(app.staticTexts["Orange juice"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Caloric drink")
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

        let breakfast = app.buttons.matching(
            NSPredicate(
                format: "label CONTAINS %@ AND enabled == true",
                "Breakfast"
            )
        ).firstMatch
        XCTAssertTrue(breakfast.waitForExistence(timeout: 2))
        if !breakfast.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(breakfast.isHittable)
        breakfast.tap()

        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 2))
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
        XCTAssertFalse(recordedFastRow(in: app).exists)
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
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func recordedFastRow(in app: XCUIApplication) -> XCUIElement {
        let row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Recorded fast")
        ).firstMatch
        for _ in 0 ..< 4 where !row.exists {
            app.swipeUp()
        }
        return row
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
}
