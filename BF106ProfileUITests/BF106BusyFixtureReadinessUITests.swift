import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class BF106BusyFixtureReadinessUITests: XCTestCase {
    private let bundleID = "com.davidmcgrath.bf106.uFast"
    private let busyFixtureVisibleMarkerMinimum = 15

    func testBusyFixturePopulatedAndCarouselUsable() {
        let app = launchBusyFixture()
        defer { app.terminate() }

        let carousel = assertPopulatedHistory(in: app)
        let markerIDs = waitForBusyMarkers(in: app)
        assertStableMarkers(markerIDs, in: app)
        assertExistingLabelLayoutRecords(in: app)

        let metadata = XCTAttachment(string: [
            "story=BF-106",
            "fixture=seedBF106BusyHistory",
            "fastRecords=6;foodRecords=16;hydrationRecords=73;eventRecords=89",
            "selectedDay=2026-08-26;lowerWindowMarkers=15",
            "viewport=\(carousel.frame);state=\(carousel.value ?? "nil");hittable=\(carousel.isHittable)",
            "gesture=none;validation=populated-marker-count-and-stable-identifiers",
        ].joined(separator: "\n"))
        metadata.name = "busy-fixture-simulator-readiness"
        metadata.lifetime = .keepAlways
        add(metadata)
    }

    private func launchBusyFixture() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments = [
            "--ui-testing", "--ui-testing-history-scroll-diagnostics", "--reset-data",
            "--seed-onboarded", "--seed-bf106-busy-history", "--ui-testing-start-history",
            "--fixed-now", "1787821200", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)",
            "-AppleInterfaceStyle", "Light",
        ]
        app.launchEnvironment["TZ"] = "Europe/London"
        app.launch()
        XCTAssertTrue(
            app.buttons["history.scroll-performance-start"].waitForExistence(timeout: 10),
            app.debugDescription
        )
        let selected = app.descendants(matching: .any)["history.selected-date"]
        let before = selected.label
        app.buttons["history.previous-day"].tap()
        let changed = NSPredicate { _, _ in selected.label != before }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: changed, object: nil)],
                timeout: 5
            ),
            .completed,
            app.debugDescription
        )
        return app
    }

    private func assertPopulatedHistory(in app: XCUIApplication) -> XCUIElement {
        let selectedDate = app.descendants(matching: .any)["history.selected-date"]
        XCTAssertEqual(selectedDate.label, "Wed 26 Aug", app.debugDescription)
        let emptyState = app.descendants(matching: .any)["history.empty"]
        XCTAssertTrue(emptyState.waitForNonExistence(timeout: 5), app.debugDescription)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(carousel.isHittable, carousel.debugDescription)
        XCTAssertGreaterThan(carousel.frame.width, 0, carousel.debugDescription)
        XCTAssertEqual(carousel.value as? String, "Settled", carousel.debugDescription)
        return carousel
    }

    private func waitForBusyMarkers(in app: XCUIApplication) -> [String] {
        let markers = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.visual-event.10600000-")
        )
        let populated = XCTNSPredicateExpectation(
            predicate: NSPredicate { [self] _, _ in
                markers.count >= busyFixtureVisibleMarkerMinimum
            },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [populated], timeout: 5),
            .completed,
            "Busy BF-106 fixture did not expose the expected lower-timeline markers.\n"
                + app.debugDescription
        )
        return (0 ..< markers.count).map { markers.element(boundBy: $0).identifier }
    }

    private func assertStableMarkers(_ markerIDs: [String], in app: XCUIApplication) {
        XCTAssertGreaterThanOrEqual(
            Set(markerIDs).count,
            busyFixtureVisibleMarkerMinimum,
            app.debugDescription
        )
        XCTAssertTrue(
            markerIDs.contains("history.visual-event.10600000-0000-0003-0000-000000000061"),
            app.debugDescription
        )
    }

    private func assertExistingLabelLayoutRecords(in app: XCUIApplication) {
        let records = app.descendants(matching: .any)
        XCTAssertTrue(
            records[
                "history.visual-event.10400000-0000-0000-0000-000000000010"
            ].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            records[
                "history.visual-event.10400000-0000-0000-0000-000000000011"
            ].waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.buttons["history.interval.10400000-0000-0000-0000-000000000001"]
                .waitForExistence(timeout: 5),
            app.debugDescription
        )
        XCTAssertTrue(
            app.buttons["history.active-fast.10400000-0000-0000-0000-000000000002"]
                .waitForExistence(timeout: 5),
            app.debugDescription
        )
    }
}
