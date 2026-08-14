import XCTest

// swiftlint:disable trailing_comma

final class LiveActivityUITests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testShowDisclosureUsesExactPrivacyCopyAndCancelKeepsActionAvailable() {
        let app = launchLiveActivityApp()
        startFast(in: app)

        let show = app.buttons["fast.live-activity.show"]
        XCTAssertTrue(show.waitForExistence(timeout: 5), app.debugDescription)
        show.tap()

        let alert = app.alerts["Show Live Activity?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        let disclosure = alert.staticTexts.matching(
            NSPredicate(
                format: "label == %@",
                ActiveFastLiveActivityDisclosureCopy.value
            )
        ).firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5), app.debugDescription)
        alert.buttons["fast.live-activity.disclosure.cancel"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["fast.live-activity.show"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testAutomaticOfferUsesExactCopyAndNotNowDoesNotRepeat() {
        let app = launchLiveActivityApp()
        startFast(in: app, dismissAutomaticOffer: false)

        let offer = app.alerts["See your fast at a glance?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            offer.staticTexts.matching(
                NSPredicate(format: "label == %@", automaticOfferMessage)
            ).firstMatch.waitForExistence(timeout: 5),
            app.debugDescription
        )
        offer.buttons["fast.automatic-offer.not-now"].firstMatch.tap()
        XCTAssertTrue(offer.waitForNonExistence(timeout: 5), app.debugDescription)

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--fixed-now",
            String(fixedNow.timeIntervalSince1970),
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(offer.waitForNonExistence(timeout: 5), app.debugDescription)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(
            app.switches["settings.live-activities.toggle"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    func testShowAutomaticallyStartsOneActivityAndRenamesRemovalControl() {
        let app = launchLiveActivityApp()
        startFast(in: app, dismissAutomaticOffer: false)

        let offer = app.alerts["See your fast at a glance?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5), app.debugDescription)
        offer.buttons["fast.automatic-offer.show"].firstMatch.tap()
        XCTAssertTrue(offer.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["fast.live-activity.hide"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testSettingsToggleCanEnableBeforeAStart() {
        let app = launchLiveActivityApp()
        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["settings.live-activities.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--fixed-now",
            String(fixedNow.timeIntervalSince1970),
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), app.debugDescription)
        app.tabBars.buttons["Today"].tap()
        app.buttons["fast.start"].tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.alerts["See your fast at a glance?"].waitForNonExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.buttons["fast.live-activity.hide"].waitForExistence(timeout: 5),
            app.debugDescription
        )
    }

    @MainActor
    func testShowHideAndExplicitReshowPreserveTheActiveFast() {
        let app = launchLiveActivityApp()
        startFast(in: app)
        showLiveActivity(in: app)

        let hide = app.buttons["fast.live-activity.hide"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), app.debugDescription)
        let elapsedBeforeHide = app.staticTexts["fast.elapsed"].value as? String
        hide.tap()

        let showAgain = app.buttons["fast.live-activity.show-again"]
        XCTAssertTrue(showAgain.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["fast.live-activity.hide"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["fast.elapsed"].value as? String, elapsedBeforeHide)

        showAgain.tap()
        let alert = app.alerts["Show Live Activity?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        alert.buttons["fast.live-activity.disclosure.show"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["fast.live-activity.hide"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].exists)
    }

    @MainActor
    func testDisabledLiveActivityShowsTheSettledStatusAndDoesNotMutateTheFast() {
        let app = launchLiveActivityApp(additionalArguments: ["--simulate-live-activity-disabled"])
        startFast(in: app)
        showLiveActivity(in: app)

        let status = app.staticTexts["fast.live-activity.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(status.label, "Live Activities are turned off for uFast in iPhone Settings.")
        XCTAssertTrue(app.buttons["fast.live-activity.show"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRequestFailureUsesSettledCopyAndLeavesActivityAvailableForRetry() {
        let app = launchLiveActivityApp(additionalArguments: ["--simulate-live-activity-request-failure"])
        startFast(in: app)
        showLiveActivity(in: app)

        let status = app.staticTexts["fast.live-activity.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(status.label, "The Live Activity couldn’t be started. Please try again.")
        XCTAssertTrue(app.buttons["fast.live-activity.show-again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUpdateRecoveryUsesDeterministicBuildIdentityAndDoesNotRepeatOnSameBuild() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--fixed-now",
            String(fixedNow.timeIntervalSince1970),
            "--reset-data",
            "--seed-active-fast-start",
            String(fixedNow.addingTimeInterval(-60 * 60).timeIntervalSince1970),
            "--seed-live-activity-recovery",
            "--live-activity-build",
            "B",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["fast.live-activity.hide"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        app.terminate()

        app.launchArguments = [
            "--ui-testing",
            "--fixed-now",
            String(fixedNow.timeIntervalSince1970),
            "--live-activity-build",
            "B",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(
            app.buttons["fast.live-activity.show-again"].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertFalse(app.buttons["fast.live-activity.hide"].exists)
    }

    @MainActor
    private func launchLiveActivityApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--fixed-now",
            String(fixedNow.timeIntervalSince1970),
            "--reset-data",
        ] + additionalArguments
        app.launch()
        completeOnboarding(in: app)
        return app
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let continueButton = app.buttons["goal.continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func startFast(
        in app: XCUIApplication,
        dismissAutomaticOffer: Bool = true
    ) {
        let start = app.buttons["fast.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription)
        start.tap()
        XCTAssertTrue(app.staticTexts["fast.elapsed"].waitForExistence(timeout: 5), app.debugDescription)
        if dismissAutomaticOffer {
            let offer = app.alerts["See your fast at a glance?"]
            if offer.waitForExistence(timeout: 5) {
                offer.buttons["fast.automatic-offer.not-now"].firstMatch.tap()
                XCTAssertTrue(offer.waitForNonExistence(timeout: 5), app.debugDescription)
            }
        }
        XCTAssertTrue(app.buttons["fast.live-activity.show"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func showLiveActivity(in app: XCUIApplication) {
        let show = app.buttons["fast.live-activity.show"]
        if !show.exists {
            let showAgain = app.buttons["fast.live-activity.show-again"]
            XCTAssertTrue(showAgain.waitForExistence(timeout: 5), app.debugDescription)
            showAgain.tap()
        } else {
            show.tap()
        }

        let alert = app.alerts["Show Live Activity?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        alert.buttons["fast.live-activity.disclosure.show"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), app.debugDescription)
    }
}

private enum ActiveFastLiveActivityDisclosureCopy {
    static let value =
        "Shows uFast, elapsed time, goal progress and target on the Lock Screen and Dynamic Island for up to 8 hours. "
            + "You can hide it at any time. Your fast continues if the activity ends."
}

private let automaticOfferMessage =
    "uFast can automatically show elapsed time, goal progress and target on the Lock Screen and Dynamic Island "
        + "when you start a fast. Each Live Activity stays active for up to 8 hours. If your fast continues, "
        + "uFast can show a new one the next time you open the app. "
        + "You can hide it or turn this off at any time in Settings."
