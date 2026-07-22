import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

final class Slice3CatchUpUITests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_300_000_000)

    @MainActor
    func testCatchUpDefaultsToSevenCompletedDaysAndNavigatesChronologically() {
        let app = launch(reset: true)
        app.tabBars.buttons["History"].tap()
        app.buttons["history.catch-up"].tap()

        XCTAssertTrue(app.navigationBars["Catch up"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["catch-up.day-count"].label, "7 days selected")
        app.buttons["catch-up.review-days"].tap()

        XCTAssertEqual(app.staticTexts["catch-up.day-progress"].label, "Day 1 of 7")
        XCTAssertTrue(app.staticTexts["catch-up.day-empty"].exists)
        app.buttons["catch-up.add-entry"].tap()
        app.buttons["Food"].tap()
        XCTAssertTrue(app.textFields["food.description"].waitForExistence(timeout: 2))
        app.textFields["food.description"].tap()
        app.textFields["food.description"].typeText("Remembered supper")
        app.buttons["food.save"].tap()
        XCTAssertTrue(app.staticTexts["Remembered supper"].waitForExistence(timeout: 2))

        app.buttons["catch-up.next"].tap()
        XCTAssertEqual(app.staticTexts["catch-up.day-progress"].label, "Day 2 of 7")
        XCTAssertTrue(app.buttons["catch-up.previous"].exists)
        app.buttons["catch-up.add-entry"].tap()
        app.buttons["Drink"].tap()
        XCTAssertTrue(app.buttons["drink.favourite.water"].waitForExistence(timeout: 2))
        app.buttons["drink.favourite.water"].tap()
        XCTAssertTrue(app.buttons["drink.editor.save"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["drink.editor.save"].isEnabled)
        app.navigationBars["Add another drink"].buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["catch-up.day-empty"].waitForExistence(timeout: 2))

        app.buttons["catch-up.next"].tap()
        XCTAssertEqual(app.staticTexts["catch-up.day-progress"].label, "Day 3 of 7")
        XCTAssertTrue(app.buttons["catch-up.add-entry"].exists)
    }

    @MainActor
    func testHistoryDistinguishesProvenanceAndChangedHistoryCanBeReconfirmed() {
        let app = launch(reset: true, seedHistory: true)
        app.tabBars.buttons["History"].tap()

        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown period")
        ).firstMatch.waitForExistence(timeout: 2))
        let needsReview = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Needs review")
        ).firstMatch
        XCTAssertTrue(needsReview.exists)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Reconstructed · Confirmed by you")
        ).firstMatch.exists)

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
}
