import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

final class Slice3CatchUpUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_300_000_000)

    @MainActor
    func testSelectedCompletedDayReviewsAndAcceptsSuggestedFast() {
        let app = launchProposal()
        app.tabBars.buttons["History"].tap()
        app.buttons["history.previous-day"].tap()
        XCTAssertTrue(app.buttons["history.review-suggestions"].waitForExistence(timeout: 2))
        app.buttons["history.review-suggestions"].tap()

        XCTAssertTrue(app.staticTexts["Suggested fast · Needs review"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Accept"].exists)
        XCTAssertTrue(app.buttons["Adjust"].exists)
        XCTAssertTrue(app.buttons["Leave unknown"].exists)
        XCTAssertFalse(app.staticTexts["Reconstructed · Confirmed by you"].exists)
        app.buttons["Accept"].tap()
        app.buttons["reconstruction.save"].tap()

        XCTAssertTrue(app.staticTexts["Reconstructed · Confirmed by you"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Suggested fast · Needs review"].exists)
    }

    @MainActor
    func testContextualReviewFailureKeepsSuggestionUnsavedForRetry() {
        let app = launchProposal(simulateFailure: true)
        app.tabBars.buttons["History"].tap()
        app.buttons["history.previous-day"].tap()
        app.buttons["history.review-suggestions"].tap()
        XCTAssertTrue(app.buttons["Accept"].waitForExistence(timeout: 2))
        app.buttons["Accept"].tap()
        app.buttons["reconstruction.save"].tap()

        XCTAssertTrue(app.staticTexts["reconstruction.save-error"].waitForExistence(timeout: 2))
        app.buttons["history.review-suggestions-cancel"].tap()
        XCTAssertFalse(app.staticTexts["Reconstructed · Confirmed by you"].exists)
    }

    @MainActor
    func testContextualReviewCanAdjustBeforeAtomicSave() {
        let app = launchProposal()
        openContextualReview(in: app)

        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.navigationBars["Adjust reconstructed fast"].waitForExistence(timeout: 2))
        app.buttons["Save adjustment"].tap()
        XCTAssertTrue(app.buttons["reconstruction.save"].waitForExistence(timeout: 2))
        app.buttons["reconstruction.save"].tap()

        XCTAssertTrue(app.staticTexts["Reconstructed · Confirmed by you"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Adjusted by you"].exists)
    }

    @MainActor
    func testContextualReviewCanLeavePeriodUnknown() {
        let app = launchProposal()
        openContextualReview(in: app)

        app.buttons["Leave unknown"].tap()
        app.buttons["reconstruction.save"].tap()

        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown period")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Reconstructed · Confirmed by you"].exists)
    }

    @MainActor
    func testHistoryDistinguishesProvenanceAndChangedHistoryCanBeReconfirmed() {
        let app = launch(reset: true, seedHistory: true)
        app.tabBars.buttons["History"].tap()
        attachScreenshot(named: "history-temporal-ribbon", from: app)

        revealHistory(in: app)

        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown period")
        ).firstMatch.waitForExistence(timeout: 2))
        let needsReview = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch
        XCTAssertTrue(needsReview.exists)
        let confirmed = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Reconstructed · Confirmed by you")
        ).firstMatch
        for _ in 0 ..< 5 where !confirmed.exists {
            app.swipeUp()
        }
        XCTAssertTrue(confirmed.exists)

        needsReview.tap()
        XCTAssertTrue(app.navigationBars["Review changed history"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Currently saved"].exists)
        XCTAssertTrue(app.staticTexts["Updated evidence"].exists)
        XCTAssertTrue(app.staticTexts[
            "A supporting entry changed. Your saved fast has not been altered."
        ].exists)
        XCTAssertTrue(app.buttons["history.needs-review.update"].isEnabled)
        XCTAssertTrue(app.buttons["history.needs-review.keep-recorded"].exists)
        XCTAssertTrue(app.buttons["history.reconstructed.remove"].exists)

        app.buttons["history.needs-review.keep-recorded"].tap()
        let conversion = app.alerts["Keep this as a recorded fast?"]
        XCTAssertTrue(conversion.waitForExistence(timeout: 2))
        conversion.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Review changed history"].exists)

        app.buttons["history.needs-review.update"].tap()
        XCTAssertFalse(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch.waitForExistence(timeout: 1))
    }

    @MainActor
    func testFailedChangedHistoryResolutionStaysNeedsReviewAcrossRelaunch() {
        let app = launch(reset: true, seedHistory: true, simulateFailure: true)
        app.tabBars.buttons["History"].tap()
        revealHistory(in: app)
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch.tap()
        app.buttons["history.needs-review.update"].tap()
        XCTAssertTrue(app.staticTexts[
            "This fast couldn’t be updated. Your saved fast is unchanged."
        ].waitForExistence(timeout: 2))

        app.terminate()
        app.launchArguments = arguments()
        app.launch()
        app.tabBars.buttons["History"].tap()
        revealHistory(in: app)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    func testChangedHistoryRemainsOperableWithAccessibilityTextDarkContrastAndTwelveHourLocale() {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true, seedHistory: true) + [
            "-AppleLocale", "en_US",
            "-AppleInterfaceStyle", "Dark",
            "-UIAccessibilityDarkerSystemColorsEnabled", "YES",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        app.tabBars.buttons["History"].tap()
        let needsReview = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch
        for _ in 0 ..< 5 where !needsReview.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(needsReview.exists)
        XCTAssertTrue(needsReview.isHittable)
        needsReview.tap()

        XCTAssertTrue(app.staticTexts["Currently saved"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Updated evidence"].exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["history.needs-review.update"].exists)
        XCTAssertTrue(app.buttons["history.needs-review.keep-recorded"].exists)
        XCTAssertTrue(app.buttons["history.reconstructed.remove"].exists)
    }

    @MainActor
    private func launch(
        reset: Bool,
        seedHistory: Bool = false,
        simulateFailure: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(
            reset: reset,
            seedHistory: seedHistory,
            simulateFailure: simulateFailure
        )
        app.launch()
        return app
    }

    @MainActor
    private func launchProposal(simulateFailure: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-data",
            "--fixed-now",
            String(now.timeIntervalSince1970),
            "--seed-slice36-proposal",
        ]
        if simulateFailure {
            app.launchArguments.append("--simulate-reconstruction-save-failure")
        }
        app.launch()
        return app
    }

    @MainActor
    private func openContextualReview(in app: XCUIApplication) {
        app.tabBars.buttons["History"].tap()
        app.buttons["history.previous-day"].tap()
        XCTAssertTrue(app.buttons["history.review-suggestions"].waitForExistence(timeout: 2))
        app.buttons["history.review-suggestions"].tap()
        XCTAssertTrue(app.staticTexts["Suggested fast · Needs review"].waitForExistence(timeout: 2))
    }

    private func arguments(
        reset: Bool = false,
        seedHistory: Bool = false,
        simulateFailure: Bool = false
    ) -> [String] {
        var result = [
            "--ui-testing", "--fixed-now", String(now.timeIntervalSince1970),
        ]
        if reset {
            result.append("--reset-data")
        }
        if seedHistory {
            result.append("--seed-slice3-history")
        } else {
            result.append("--seed-onboarded")
        }
        if simulateFailure {
            result.append("--simulate-reconstruction-save-failure")
        }
        return result
    }

    @MainActor
    private func revealHistory(in app: XCUIApplication) {
        let needsReview = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch
        for _ in 0 ..< 5 where !needsReview.exists {
            app.swipeUp()
        }
    }

    @MainActor
    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
