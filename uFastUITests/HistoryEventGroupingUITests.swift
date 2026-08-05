import XCTest

// swiftlint:disable trailing_comma type_body_length

final class HistoryEventGroupingUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_043_200)

    @MainActor
    func testRestingGroupsDisclosureAndRemovesGroupManager() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()

        let groups = [
            app.buttons[foodGroupMarkerIdentifier],
            app.buttons[caloricDrinkGroupMarkerIdentifier],
            app.buttons[groupMarkerIdentifier],
        ]
        for group in groups {
            XCTAssertTrue(group.waitForExistence(timeout: 3), app.debugDescription)
            XCTAssertEqual(group.value as? String, "2")
            XCTAssertTrue(group.isEnabled)
            XCTAssertTrue(group.isHittable, app.debugDescription)
        }

        openGroupDisclosure(in: app)
        XCTAssertTrue(app.buttons[drinkMemberID].exists)
        XCTAssertTrue(app.buttons[secondDrinkMemberID].exists)
        XCTAssertFalse(app.buttons["history.event-group.edit"].exists)
        XCTAssertFalse(app.otherElements["history.event-group.manager"].exists)
        XCTAssertFalse(app.buttons["history.event-group.done"].exists)
        XCTAssertFalse(app.buttons["history.event-group.delete"].exists)
        XCTAssertFalse(
            app.buttons["history.event-group.edit-member.39700000-0000-0000-0000-000000000012"].exists
        )
        XCTAssertTrue(app.buttons[drinkMemberID].label.contains("Tea"))
        captureScreenshot(named: "history-event-grouping-disclosure-en-GB", in: app)
    }

    @MainActor
    func testInformationPanelReturnsAfterNativeIdle() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        let panel = app.otherElements["history.event-info-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        let addAtSelectedTime = app.buttons["history.add-at-selected-time"]
        XCTAssertTrue(addAtSelectedTime.waitForExistence(timeout: 3))
        let fastList = app.otherElements["history.list"]
        XCTAssertTrue(fastList.waitForExistence(timeout: 3))

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 3))

        carousel.swipeRight(velocity: .slow)
        XCTAssertEqual(
            waitForSettled(carousel),
            .completed,
            app.debugDescription
        )
        carousel.swipeLeft(velocity: .slow)

        XCTAssertEqual(waitForSettled(carousel), .completed, app.debugDescription)
        XCTAssertTrue(panel.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(app.buttons[groupRowIdentifier].exists)
    }

    @MainActor
    func testCaloricDrinkGroupUsesHydrationDisclosureAndEditor() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()

        let group = app.buttons[caloricDrinkGroupMarkerIdentifier]
        XCTAssertTrue(group.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(group.value as? String, "2")
        group.tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))

        tapMember(caloricDrinkMemberID, in: app)
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["drink.type"].value as? String, "Custom")
        XCTAssertEqual(app.textFields["drink.name"].value as? String, "Juice")
        XCTAssertTrue(app.buttons["Caloric"].exists)
        app.navigationBars["Edit drink"].buttons["Cancel"].tap()
    }

    @MainActor
    func testUngroupedDrinkAndFoodOpenExistingEditorsDirectly() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()

        app.buttons[ungroupedDrinkRowID].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["drink.type"].value as? String, "Tea")
        app.navigationBars["Edit drink"].buttons["Cancel"].tap()

        app.buttons[ungroupedFoodRowID].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["food.description"].value as? String, "Snack")
        app.navigationBars["Edit food"].buttons["Cancel"].tap()
    }

    @MainActor
    func testDrinkMemberOpensStoredEditorCancelReturnsDisclosureAndSaveRefreshesAnotherMember() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)

        tapMember(secondDrinkMemberID, in: app)
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["drink.volume"].value as? String, "300")
        app.navigationBars["Edit drink"].buttons["Cancel"].tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))

        tapMember(secondDrinkMemberID, in: app)
        replaceText("301", in: app.textFields["drink.volume"], app: app)
        app.buttons["drink.editor.save"].tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))

        tapMember(drinkMemberID, in: app)
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["drink.volume"].value as? String, "300")
        app.navigationBars["Edit drink"].buttons["Cancel"].tap()
    }

    @MainActor
    func testFoodMemberOpensExistingFoodEditor() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        app.buttons[foodGroupMarkerIdentifier].tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))

        tapMember(foodMemberID, in: app)
        XCTAssertTrue(app.navigationBars["Edit food"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["food.description"].value as? String, "Lunch")
        app.navigationBars["Edit food"].buttons["Cancel"].tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].exists)
    }

    @MainActor
    func testFailedFoodAndDrinkSavesKeepDraftAndCommittedGroupUnchanged() {
        let foodApp = launchHistory(additionalArguments: [
            "-AppleLocale", "en_GB",
            "--simulate-food-save-failure",
        ])
        foodApp.tabBars.buttons["History"].tap()
        foodApp.buttons[foodGroupMarkerIdentifier].tap()
        tapMember(foodMemberID, in: foodApp)
        replaceText("Changed lunch", in: foodApp.textFields["food.description"], app: foodApp)
        foodApp.buttons["food.save"].tap()
        XCTAssertTrue(foodApp.staticTexts["food.save-error"].waitForExistence(timeout: 3))
        XCTAssertEqual(foodApp.textFields["food.description"].value as? String, "Changed lunch")
        foodApp.buttons["food.cancel"].tap()

        let drinkApp = launchHistory(additionalArguments: [
            "-AppleLocale", "en_GB",
            "--simulate-drink-save-failure",
        ])
        drinkApp.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: drinkApp)
        tapMember(secondDrinkMemberID, in: drinkApp)
        replaceText("301", in: drinkApp.textFields["drink.volume"], app: drinkApp)
        drinkApp.buttons["drink.editor.save"].tap()
        XCTAssertTrue(drinkApp.staticTexts["drink.editor.save-error"].waitForExistence(timeout: 3))
        XCTAssertEqual(drinkApp.textFields["drink.volume"].value as? String, "301")
        drinkApp.navigationBars["Edit drink"].buttons["Cancel"].tap()
    }

    @MainActor
    func testMovingMemberOutOfBucketDismissesStaleDisclosureAndRecomputesHistory() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        tapMember(secondDrinkMemberID, in: app)

        let timePicker = app.datePickers["drink.time"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: 3))
        timePicker.tap()
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "13")
        app.navigationBars["Edit drink"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["drink.editor.save"].tap()

        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons[groupMarkerIdentifier].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons[ungroupedDrinkRowID].waitForExistence(timeout: 3))
    }

    @MainActor
    func testReclassifyingHydrationMovesItToTheOtherCategory() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        tapMember(secondDrinkMemberID, in: app)

        let caloricChoice = app.buttons["Caloric"]
        XCTAssertTrue(caloricChoice.waitForExistence(timeout: 3), app.debugDescription)
        caloricChoice.tap()
        app.buttons["drink.editor.save"].tap()

        XCTAssertTrue(
            app.buttons[groupMarkerIdentifier].waitForNonExistence(timeout: 3),
            app.debugDescription
        )
        let caloricGroup = app.buttons[caloricDrinkGroupMarkerIdentifier]
        XCTAssertTrue(caloricGroup.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(caloricGroup.value as? String, "3")
    }

    @MainActor
    func testDeletingFromThreeMemberGroupReturnsToRemainingTwoMemberDisclosure() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        app.buttons["history.event-group.add"].tap()
        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 3))
        app.buttons["history.add.drink"].tap()
        app.buttons["drink.favourite.tea"].tap()
        app.buttons["drink.editor.save"].tap()

        let threeMemberGroup = app.buttons[groupMarkerIdentifier]
        XCTAssertTrue(threeMemberGroup.waitForExistence(timeout: 3))
        XCTAssertEqual(threeMemberGroup.value as? String, "3")
        threeMemberGroup.tap()
        tapMember(secondDrinkMemberID, in: app)
        app.buttons["drink.delete"].tap()
        app.alerts["Delete this drink?"].buttons["Delete"].tap()

        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons[groupMarkerIdentifier].value as? String, "2")
        XCTAssertTrue(app.buttons[drinkMemberID].exists)
    }

    @MainActor
    func testDeletingFromTwoMemberGroupReturnsToHistoryWithSingleEditableMarker() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        tapMember(secondDrinkMemberID, in: app)
        app.buttons["drink.delete"].tap()
        app.alerts["Delete this drink?"].buttons["Delete"].tap()

        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons[groupMarkerIdentifier].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons[ungroupedDrinkRowID].firstMatch.waitForExistence(timeout: 3))
        app.buttons[ungroupedDrinkRowID].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddEventRemainsBucketConstrained() {
        let app = launchHistory(additionalArguments: ["-AppleLocale", "en_GB"])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        app.buttons["history.event-group.add"].tap()

        XCTAssertTrue(app.navigationBars["Add to history"].waitForExistence(timeout: 3))
        let time = app.datePickers["history.add.time"]
        XCTAssertTrue(time.exists)
        let summary = app.staticTexts["history.add.summary"]
        XCTAssertTrue(summary.label.contains("11"), "Unexpected add summary: \(summary.label)")
        app.buttons["history.add.cancel"].tap()
        XCTAssertTrue(app.buttons[groupMarkerIdentifier].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAccessibilitySizeAndMemberActionsRemainUsable() {
        let app = launchHistory(additionalArguments: [
            "-AppleLocale", "en_GB",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "-UIAccessibilityDarkerSystemColorsEnabled", "YES",
        ])
        app.tabBars.buttons["History"].tap()
        openGroupDisclosure(in: app)
        XCTAssertTrue(app.buttons[drinkMemberID].isEnabled)
        XCTAssertTrue(app.buttons[drinkMemberID].isHittable)
        XCTAssertTrue(app.buttons[drinkMemberID].label.contains("10:"))
        captureScreenshot(named: "history-event-group-accessibility-xxxl", in: app)

        app.buttons[drinkMemberID].tap()
        XCTAssertTrue(app.navigationBars["Edit drink"].waitForExistence(timeout: 3))
        app.navigationBars["Edit drink"].buttons["Cancel"].tap()
    }

    @MainActor
    private func openGroupDisclosure(in app: XCUIApplication) {
        app.buttons[groupMarkerIdentifier].tap()
        XCTAssertTrue(app.otherElements["history.event-group.disclosure"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func waitForSettled(_ carousel: XCUIElement) -> XCTWaiter.Result {
        XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", "Settled"),
                    object: carousel
                ),
            ],
            timeout: 5
        )
    }

    @MainActor
    private func tapMember(_ identifier: String, in app: XCUIApplication) {
        let member = app.buttons[identifier].firstMatch
        XCTAssertTrue(member.waitForExistence(timeout: 3), app.debugDescription)
        let disclosure = app.otherElements["history.event-group.disclosure"]
        let scrollView = disclosure.scrollViews.firstMatch
        for _ in 0 ..< 4 where !member.isHittable {
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(member.isHittable, app.debugDescription)
        member.tap()
    }

    @MainActor
    private func replaceText(_ value: String, in element: XCUIElement, app: XCUIApplication) {
        element.tap()
        element.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        element.typeText(value)
    }

    private var drinkMemberID: String {
        "history.event-group.member.39700000-0000-0000-0000-000000000011"
    }

    private var secondDrinkMemberID: String {
        "history.event-group.member.39700000-0000-0000-0000-000000000012"
    }

    private var foodMemberID: String {
        "history.event-group.member.39700000-0000-0000-0000-000000000020"
    }

    private var caloricDrinkMemberID: String {
        "history.event-group.member.39700000-0000-0000-0000-000000000030"
    }

    private var groupMarkerIdentifier: String {
        "history.event-group.non-caloric-drink.\(bucketStartEpoch(hour: 10))"
    }

    private var foodGroupMarkerIdentifier: String {
        "history.event-group.food.\(bucketStartEpoch(hour: 10))"
    }

    private var caloricDrinkGroupMarkerIdentifier: String {
        "history.event-group.caloric-drink.\(bucketStartEpoch(hour: 10))"
    }

    private var groupRowIdentifier: String {
        "history.event-group.row.non-caloric-drink.\(bucketStartEpoch(hour: 10))"
    }

    private var ungroupedDrinkRowID: String {
        "history.event.39700000-0000-0000-0000-000000000010"
    }

    private var ungroupedFoodRowID: String {
        "history.event.39700000-0000-0000-0000-000000000022"
    }

    @MainActor
    private func launchHistory(additionalArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--seed-history-event-grouping",
            "--fixed-now",
            String(now.timeIntervalSince1970),
        ] + additionalArguments
        app.launch()
        return app
    }

    private func bucketStartEpoch(hour: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let day = calendar.startOfDay(for: now)
        guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else {
            return 0
        }
        return Int(date.timeIntervalSince1970)
    }

    @MainActor
    private func captureScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
