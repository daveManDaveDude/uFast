import XCTest

// swiftlint:disable function_body_length type_body_length

// swiftlint:disable trailing_comma

final class FastStartUITests: XCTestCase {
    private let fixedStart = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testActiveFastShowsDeterministicElapsedGoalTargetAndProgress() {
        let app = XCUIApplication()
        app.launchArguments = fixedLaunchArguments(
            now: fixedStart,
            resetData: true
        )
        app.launch()
        completeOnboarding(in: app)

        app.buttons["fast.start"].tap()

        let elapsed = app.staticTexts["fast.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 2))
        XCTAssertEqual(elapsed.value as? String, "0 seconds")
        XCTAssertEqual(app.staticTexts["fast.goal"].value as? String, "12 hours")
        XCTAssertTrue(app.staticTexts["fast.target"].exists)
        XCTAssertEqual(
            app.progressIndicators["fast.progress"].value as? String,
            "0 percent of 12-hour goal"
        )
        XCTAssertFalse(app.staticTexts["fast.goal-reached"].exists)
    }

    @MainActor
    func testInactiveTodayShowsStateGoalAndDerivedTargetBeforeStarting() {
        let app = XCUIApplication()
        app.launchArguments = fixedLaunchArguments(
            now: fixedStart,
            resetData: true
        )
        app.launch()
        completeOnboarding(in: app)

        XCTAssertEqual(app.staticTexts["fast.inactive-state"].label, "No fast is running.")
        XCTAssertTrue(app.staticTexts["Your fasting goal is 12 hours."].exists)
        XCTAssertTrue(app.staticTexts["fast.preview-target"].exists)
        XCTAssertTrue(app.buttons["fast.start"].isHittable)
        XCTAssertTrue(app.buttons["fast.start-past"].exists)
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testInactiveTodayKeepsPrimaryActionsReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = fixedLaunchArguments(
            now: fixedStart,
            resetData: true
        ) + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraLarge"]
        app.launch()
        completeOnboarding(in: app)

        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        if !startButton.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(startButton.isHittable)
        XCTAssertTrue(app.buttons["fast.start-past"].exists)
    }

    @MainActor
    func testRelaunchAtAdvancedTimeCatchesUpAndShowsReachedTarget() {
        let app = XCUIApplication()
        app.launchArguments = fixedLaunchArguments(
            now: fixedStart,
            resetData: true
        )
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = fixedLaunchArguments(
            now: fixedStart.addingTimeInterval(13 * 60 * 60)
        )
        app.launch()

        let elapsed = app.staticTexts["fast.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 2))
        XCTAssertEqual(elapsed.value as? String, "13 hours 0 minutes 0 seconds")
        XCTAssertEqual(
            app.progressIndicators["fast.progress"].value as? String,
            "100 percent of 12-hour goal"
        )
        XCTAssertTrue(app.staticTexts["fast.goal-reached"].exists)
    }

    @MainActor
    func testActiveFastElapsedSecondsCountUpWhileTodayIsVisible() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()

        let elapsed = app.staticTexts["fast.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 2))
        let initialValue = elapsed.value as? String

        let valueChanged = NSPredicate { evaluatedObject, _ in
            guard let element = evaluatedObject as? XCUIElement else {
                return false
            }
            return element.value as? String != initialValue
        }
        let expectation = XCTNSPredicateExpectation(
            predicate: valueChanged,
            object: elapsed
        )

        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3),
            .completed
        )
    }

    @MainActor
    func testStartFastPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)

        let startButton = app.buttons["fast.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        startButton.tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["fast.goal"].value as? String, "12 hours")
        XCTAssertTrue(app.staticTexts["fast.target"].exists)

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["fast.start"].exists)
        XCTAssertTrue(app.buttons["fast.edit-start"].exists)
    }

    @MainActor
    func testSaveFailureKeepsInactiveStateAndOffersRetry() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--simulate-fast-save-failure",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)

        app.buttons["fast.start"].tap()

        XCTAssertTrue(app.staticTexts["fast.start-error"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["fast.start"].label, "Try again")
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testInactivePastStartEditorCanBeCancelledWithoutStartingFast() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)

        XCTAssertTrue(app.buttons["fast.start-past"].waitForExistence(timeout: 2))
        app.buttons["fast.start-past"].tap()

        XCTAssertTrue(app.navigationBars["Start time"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.datePickers["fast.start-date"].exists)
        XCTAssertTrue(app.datePickers["fast.start-time"].exists)
        XCTAssertEqual(app.buttons["fast.start-confirm"].label, "Start fast")
        app.buttons["fast.start-cancel"].tap()

        XCTAssertTrue(app.buttons["fast.start"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testPastStartConfirmationPersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start-past"].tap()
        XCTAssertTrue(app.buttons["fast.start-confirm"].waitForExistence(timeout: 2))

        app.buttons["fast.start-confirm"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["fast.edit-start"].exists)
    }

    @MainActor
    func testPastStartSaveFailureKeepsEditorSelectionAvailableForRetry() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--simulate-fast-save-failure",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start-past"].tap()
        XCTAssertTrue(app.buttons["fast.start-confirm"].waitForExistence(timeout: 2))
        let selectedDate = app.datePickers["fast.start-date"].value as? String
        let selectedTime = app.datePickers["fast.start-time"].value as? String

        app.buttons["fast.start-confirm"].tap()

        XCTAssertTrue(app.staticTexts["fast.start-save-error"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["Start time"].exists)
        XCTAssertEqual(app.datePickers["fast.start-date"].value as? String, selectedDate)
        XCTAssertEqual(app.datePickers["fast.start-time"].value as? String, selectedTime)
        XCTAssertFalse(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testPastStartEditorPreventsSelectingAFutureTime() {
        let app = XCUIApplication()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launchArguments.append("--fixed-now")
        app.launchArguments.append(String(startOfToday.timeIntervalSince1970))
        app.launchArguments.append(contentsOf: ["-AppleLocale", "en_GB"])
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start-past"].tap()
        XCTAssertTrue(app.datePickers["fast.start-time"].waitForExistence(timeout: 2))
        let latestAllowedTime = app.datePickers["fast.start-time"].value as? String

        app.datePickers["fast.start-time"].tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 2))
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "01")

        XCTAssertEqual(app.datePickers["fast.start-time"].value as? String, latestAllowedTime)
        XCTAssertFalse(app.staticTexts["fast.start-validation"].exists)
        XCTAssertTrue(app.buttons["fast.start-confirm"].isEnabled)
    }

    @MainActor
    func testActiveFastEditorUsesSaveActionAndCancellationKeepsPresentation() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--suppress-automatic-live-activity-offer",
        ]
        app.launch()
        completeOnboarding(in: app)
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 2))
        let originalTarget = app.staticTexts["fast.target"].value as? String

        app.buttons["fast.edit-start"].tap()

        XCTAssertTrue(app.navigationBars["Start time"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["fast.start-confirm"].label, "Save")
        XCTAssertTrue(app.datePickers["fast.start-date"].exists)
        XCTAssertTrue(app.datePickers["fast.start-time"].exists)
        app.buttons["fast.start-cancel"].tap()

        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["fast.target"].value as? String,
            originalTarget
        )
        XCTAssertTrue(app.buttons["fast.edit-start"].exists)
    }

    @MainActor
    func testLegacyActiveFastShowsStoredInvalidDraftAndCanChooseBoundedReplacement() {
        let app = XCUIApplication()
        let legacyStart = fixedStart.addingTimeInterval(-48 * 60 * 60)
        app.launchArguments = londonLaunchArguments(now: fixedStart, resetData: true)
            + [
                "--seed-onboarded",
                "--seed-active-fast-start",
                String(legacyStart.timeIntervalSince1970),
            ]
        app.launch()

        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 2))
        app.buttons["fast.edit-start"].tap()

        XCTAssertTrue(app.navigationBars["Start time"].waitForExistence(timeout: 2))
        assertDatePicker(
            in: app,
            app.datePickers["fast.start-date"],
            contains: ["13", "2027"]
        )
        assertDatePicker(in: app, app.datePickers["fast.start-time"], contains: ["8:00"])
        XCTAssertTrue(app.staticTexts["fast.start-validation"].exists)
        XCTAssertEqual(
            app.staticTexts["fast.start-validation"].label,
            "Start time must be within the past 36 hours."
        )
        XCTAssertFalse(app.buttons["fast.start-confirm"].isEnabled)
        XCTAssertTrue(app.buttons["fast.start-use-earliest"].exists)

        app.buttons["fast.start-cancel"].tap()
        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 2))
        assertDateDisplay(app.staticTexts["fast.started"], containsTime: "8:00")

        app.buttons["fast.edit-start"].tap()
        XCTAssertTrue(app.buttons["fast.start-use-earliest"].waitForExistence(timeout: 2))
        assertDatePicker(
            in: app,
            app.datePickers["fast.start-date"],
            contains: ["13", "2027"]
        )
        assertDatePicker(in: app, app.datePickers["fast.start-time"], contains: ["8:00"])
        app.buttons["fast.start-use-earliest"].tap()

        XCTAssertTrue(app.buttons["fast.start-confirm"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["fast.start-confirm"].isEnabled)
        assertDatePicker(in: app, app.datePickers["fast.start-time"], contains: ["20:00"])
        XCTAssertFalse(app.staticTexts["fast.start-validation"].exists)
        app.buttons["fast.start-confirm"].tap()

        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["fast.start-validation"].exists)
        assertDateDisplay(app.staticTexts["fast.started"], containsTime: "20:00")

        app.terminate()
        app.launchArguments = londonLaunchArguments(now: fixedStart)
        app.launch()

        XCTAssertTrue(app.buttons["fast.edit-start"].waitForExistence(timeout: 2))
        assertDateDisplay(app.staticTexts["fast.started"], containsTime: "20:00")
        app.buttons["fast.edit-start"].tap()
        XCTAssertTrue(app.navigationBars["Start time"].waitForExistence(timeout: 2))
        assertDatePicker(in: app, app.datePickers["fast.start-date"], contains: ["13", "2027"])
        assertDatePicker(in: app, app.datePickers["fast.start-time"], contains: ["20:00"])
        app.buttons["fast.start-cancel"].tap()
    }

    @MainActor
    private func assertDatePicker(
        in app: XCUIApplication,
        _ datePicker: XCUIElement,
        contains expectedComponents: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(datePicker.waitForExistence(timeout: 2), file: file, line: line)
        let value = displayedValue(of: datePicker)
        for component in expectedComponents {
            XCTAssertTrue(
                value.contains(component),
                "Expected date picker value \(value) to contain \(component).\n\(app.debugDescription)",
                file: file,
                line: line
            )
        }
    }

    @MainActor
    private func assertDateDisplay(
        _ element: XCUIElement,
        containsTime expectedTime: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 2), file: file, line: line)
        let value = displayedValue(of: element)
        XCTAssertTrue(
            value.contains("13") && value.contains("2027") && value.contains(expectedTime),
            "Expected date display value \(value) to contain 13, 2027, and \(expectedTime).",
            file: file,
            line: line
        )
    }

    @MainActor
    private func displayedValue(of element: XCUIElement) -> String {
        let valueCandidates: [XCUIElement] = [element]
            + element.descendants(matching: .button).allElementsBoundByIndex
            + element.descendants(matching: .staticText).allElementsBoundByIndex

        for candidate in valueCandidates {
            if let value = candidate.value as? String, !value.isEmpty {
                return value
            }
        }

        for candidate in valueCandidates where !candidate.label.isEmpty {
            return candidate.label
        }

        return ""
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 2))
    }

    private func fixedLaunchArguments(
        now: Date,
        resetData: Bool = false
    ) -> [String] {
        var arguments = [
            "--ui-testing",
            "--fixed-now",
            String(now.timeIntervalSince1970),
            "--suppress-automatic-live-activity-offer",
        ]

        if resetData {
            arguments.append("--reset-data")
        }

        return arguments
    }

    private func londonLaunchArguments(
        now: Date,
        resetData: Bool = false
    ) -> [String] {
        fixedLaunchArguments(now: now, resetData: resetData)
            + ["-AppleLocale", "en_GB", "-NSTimeZone", "Europe/London"]
    }
}
