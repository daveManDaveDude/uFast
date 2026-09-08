import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class BF106CaptureUITests: XCTestCase {
    private let bundleID = "com.davidmcgrath.bf106.uFast"
    private let qualificationMaxEvents = 16384
    private let manualInteractionWindowSeconds: TimeInterval = 60
    private let attachOnlyEnvironmentKey = "BF106_ATTACH_ONLY"
    private let manualFixtureSelectedDay: Date = {
        var calendar = Calendar(identifier: .gregorian)
        guard let london = TimeZone(identifier: "Europe/London") else {
            fatalError("Europe/London time zone must be available for BF-106")
        }
        calendar.timeZone = london
        guard let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26)) else {
            fatalError("BF-106 selected day could not be derived")
        }
        return selectedDay
    }()

    func testCaptureControlsResetAndExport() throws {
        let app = launchFixture()
        defer { app.terminate() }
        let first = try capture(in: app, leftward: true, name: "controls-first")
        XCTAssertFalse(first.isEmpty)
        let second = try capture(in: app, leftward: false, name: "controls-reset")
        XCTAssertEqual(second.first?["sequence"] as? Int, 1)
        XCTAssertFalse(app.descendants(matching: .any)["history.fast-label-trace"].exists)
    }

    func testMidnightFixtureCaptureControls() throws {
        let app = launchFixture(midnight: true)
        defer { app.terminate() }
        XCTAssertFalse(try capture(in: app, leftward: true, name: "midnight-controls").isEmpty)
    }

    /// Invoke explicitly on the isolated physical build, never as a simulator
    /// performance substitute. Each sample relaunches the same synthetic store.
    func testPhysicalNativeReleaseQualification() throws {
        let app = launchFixture(maxEvents: qualificationMaxEvents)
        defer { app.terminate() }
        let report = try captureReport(
            in: app,
            leftward: false,
            name: "physical-qualification",
            manualStyleRelease: true
        )
        let outcome = try XCTUnwrap(report["outcome"] as? [String: Any])
        XCTAssertEqual(outcome["status"] as? String, "captured")
        let native = try XCTUnwrap(report["native"] as? [String: Any])
        let decelerationStart = try XCTUnwrap(native["decelerationStartUptime"] as? Double)
        let idle = try XCTUnwrap(native["idleUptime"] as? Double)
        let captureEnd = try XCTUnwrap(native["captureEndUptime"] as? Double)
        XCTAssertLessThan(decelerationStart, idle, "Native phase order is invalid")
        XCTAssertGreaterThan(idle - decelerationStart, 0, "Native deceleration duration is not positive")
        XCTAssertGreaterThanOrEqual(
            captureEnd - idle,
            0.25,
            "The capture ended before the full post-idle observation window"
        )
        let phases = try XCTUnwrap(report["phases"] as? [[String: Any]])
        let tail = try XCTUnwrap(phases.first { $0["phase"] as? String == "nativeDecelerationTail" })
        let postIdle = try XCTUnwrap(phases.first { $0["phase"] as? String == "postIdle" })
        XCTAssertGreaterThan(tail["duration"] as? Double ?? 0, 0)
        XCTAssertGreaterThanOrEqual(postIdle["duration"] as? Double ?? 0, 0.25)
        XCTAssertEqual(postIdle["shorterThanRequestedWindow"] as? Bool, false)
        let events = try XCTUnwrap(report["events"] as? [[String: Any]])
        XCTAssertTrue(events.contains { $0["nativePhase"] as? String == "idle" })
        let tailStart = try XCTUnwrap(tail["startUptime"] as? Double)
        let postIdleEnd = try XCTUnwrap(postIdle["endUptime"] as? Double)
        XCTAssertTrue(events.contains { row in
            guard let timestamp = row["uptime"] as? Double else { return false }
            return timestamp >= tailStart && timestamp < idle
        }, "Retained native deceleration-tail evidence is absent")
        XCTAssertTrue(events.contains { row in
            guard let timestamp = row["uptime"] as? Double else { return false }
            return timestamp > idle && timestamp <= postIdleEnd
        }, "Retained post-idle evidence is absent")
        XCTAssertEqual(report["dropped"] as? Int, 0, "Capture evidence was truncated")
    }

    /// Dedicated manual-only physical capture. The test deliberately does not
    /// issue a gesture: the armed app remains available for the user to swipe.
    func testManualPhysicalRightwardReleaseQualification() throws {
        let app = launchManualFixture()
        defer { app.terminate() }

        let selectedDate = app.descendants(matching: .any)["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(selectedDate.label, "Wed 26 Aug", app.debugDescription)

        let emptyState = app.descendants(matching: .any)["history.empty"]
        XCTAssertTrue(
            emptyState.waitForNonExistence(timeout: 5),
            "Manual capture must be armed on the populated 2026-08-26 timeline.\n\(app.debugDescription)"
        )

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        add(manualProtocolMetadataAttachment(for: carousel))

        let start = app.buttons["history.scroll-performance-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription)
        start.tap()
        print(
            "BF-106 MANUAL CAPTURE READY | swipe right slowly across populated Wed 26 Aug content, "
                + "release naturally | interaction window=\(Int(manualInteractionWindowSeconds))s | "
                + "no further test gestures"
        )
        waitForManualInteractionWindow()

        let finish = app.buttons["history.scroll-performance-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), app.debugDescription)
        finish.tap()

        let raw = try finishedSnapshot(in: app)
        let attachment = XCTAttachment(string: raw)
        attachment.name = "manual-rightward-raw.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        try assertStrictCapturedQualification(report)
    }

    private func manualProtocolMetadataAttachment(
        for carousel: XCUIElement,
        testName: String = "testManualPhysicalRightwardReleaseQualification"
    ) -> XCTAttachment {
        let protocolMetadata = [
            "story=BF-106",
            "test=\(testName)",
            "bundle=\(bundleID)",
            "fixture=seedBF106BusyHistory",
            "fixtureCounts=fasts:6;foods:16;hydrations:73;events:89;"
                + "selectedDayEvents:14;lowerWindowMarkers:15",
            "fixedNow=2026-08-27T09:00:00Z;fixedNowEpoch=1787821200",
            "selectedDay=2026-08-26;locale=en_GB;timeZone=Europe/London",
            "maxEvents=\(qualificationMaxEvents)",
            "viewport=\(carousel.frame)",
            "direction=rightward;startFraction=0.25;endFraction=0.75;yFraction=0.5",
            "velocity=slow;release=natural-user-release",
            "interactionWindowSeconds=\(manualInteractionWindowSeconds)",
            "gestureIssuedByTest=false",
            "sequence=diagnostic-start;manual-swipe;bounded-wait;diagnostic-finish",
        ].joined(separator: "\n")
        let metadata = XCTAttachment(string: protocolMetadata)
        metadata.name = "manual-rightward-protocol"
        metadata.lifetime = .keepAlways
        return metadata
    }

    private func waitForManualInteractionWindow() {
        let observation = expectation(description: "Allow the bounded manual interaction window")
        DispatchQueue.main.asyncAfter(deadline: .now() + manualInteractionWindowSeconds) {
            observation.fulfill()
        }
        wait(for: [observation], timeout: manualInteractionWindowSeconds + 1)
    }

    private func finishedSnapshot(in app: XCUIApplication) throws -> String {
        let snapshot = app.descendants(matching: .any)["history.scroll-performance-snapshot"]
        XCTAssertTrue(snapshot.waitForExistence(timeout: 5), app.debugDescription)
        let finishedJSON = NSPredicate { _, _ in
            guard let raw = snapshot.value as? String,
                  let data = raw.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
            else { return false }
            return object is [String: Any]
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: finishedJSON, object: snapshot)],
                timeout: 5
            ),
            .completed,
            "Finished diagnostic snapshot was not exported.\n\(app.debugDescription)"
        )
        return try XCTUnwrap(snapshot.value as? String)
    }

    private func launchManualFixture() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments = [
            "--ui-testing", "--ui-testing-history-scroll-diagnostics", "--reset-data",
            "--seed-onboarded", "--seed-bf106-busy-history", "--ui-testing-start-history",
            "--fixed-now", "1787821200", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)",
            "-AppleInterfaceStyle", "Light", "--bf106-max-events", String(qualificationMaxEvents),
        ]
        app.launchEnvironment["TZ"] = "Europe/London"
        app.launch()
        XCTAssertTrue(app.buttons["history.scroll-performance-start"].waitForExistence(timeout: 10))
        let selected = app.descendants(matching: .any)["history.selected-date"]
        let before = selected.label
        app.buttons["history.previous-day"].tap()
        let changed = NSPredicate { _, _ in selected.label != before }
        XCTAssertEqual(XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: changed, object: nil)],
            timeout: 5
        ), .completed)
        return app
    }

    private func launchFixture(midnight: Bool = false, maxEvents: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        var launchArguments = [
            "--ui-testing", "--ui-testing-history-scroll-diagnostics", "--reset-data",
            "--seed-onboarded", midnight ? "--seed-history-midnight-seam" : "--seed-bf106-busy-history",
            "--ui-testing-start-history",
            "--fixed-now", "1787821200", "-AppleLocale", "en_GB", "-AppleLanguages", "(en-GB)",
            "-AppleInterfaceStyle", "Light",
        ]
        if let maxEvents {
            launchArguments += ["--bf106-max-events", String(maxEvents)]
        }
        app.launchArguments = launchArguments
        app.launchEnvironment["TZ"] = "Europe/London"
        app.launch()
        XCTAssertTrue(app.buttons["history.scroll-performance-start"].waitForExistence(timeout: 10))
        for _ in 0 ..< 3 {
            let selected = app.descendants(matching: .any)["history.selected-date"]
            let before = selected.label
            app.buttons["history.previous-day"].tap()
            let changed = NSPredicate { _, _ in selected.label != before }
            XCTAssertEqual(XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: changed, object: nil)],
                timeout: 5
            ), .completed)
        }
        return app
    }

    private func assertStrictCapturedQualification(_ report: [String: Any]) throws {
        let outcome = try XCTUnwrap(report["outcome"] as? [String: Any])
        XCTAssertEqual(outcome["status"] as? String, "captured")
        let native = try XCTUnwrap(report["native"] as? [String: Any])
        let decelerationStart = try XCTUnwrap(native["decelerationStartUptime"] as? Double)
        let idle = try XCTUnwrap(native["idleUptime"] as? Double)
        let captureEnd = try XCTUnwrap(native["captureEndUptime"] as? Double)
        XCTAssertLessThan(decelerationStart, idle, "Native phase order is invalid")
        XCTAssertGreaterThan(idle - decelerationStart, 0, "Native deceleration duration is not positive")
        XCTAssertGreaterThanOrEqual(
            captureEnd - idle,
            0.25,
            "The capture ended before the full post-idle observation window"
        )
        let phases = try XCTUnwrap(report["phases"] as? [[String: Any]])
        let tail = try XCTUnwrap(phases.first { $0["phase"] as? String == "nativeDecelerationTail" })
        let postIdle = try XCTUnwrap(phases.first { $0["phase"] as? String == "postIdle" })
        XCTAssertGreaterThan(tail["duration"] as? Double ?? 0, 0)
        XCTAssertGreaterThanOrEqual(postIdle["duration"] as? Double ?? 0, 0.25)
        XCTAssertEqual(postIdle["shorterThanRequestedWindow"] as? Bool, false)
        let events = try XCTUnwrap(report["events"] as? [[String: Any]])
        XCTAssertTrue(events.contains { $0["nativePhase"] as? String == "idle" })
        let tailStart = try XCTUnwrap(tail["startUptime"] as? Double)
        let postIdleEnd = try XCTUnwrap(postIdle["endUptime"] as? Double)
        XCTAssertTrue(events.contains { row in
            guard let timestamp = row["uptime"] as? Double else { return false }
            return timestamp >= tailStart && timestamp < idle
        }, "Retained native deceleration-tail evidence is absent")
        XCTAssertTrue(events.contains { row in
            guard let timestamp = row["uptime"] as? Double else { return false }
            return timestamp > idle && timestamp <= postIdleEnd
        }, "Retained post-idle evidence is absent")
        XCTAssertEqual(report["dropped"] as? Int, 0, "Capture evidence was truncated")
    }

    private func capture(in app: XCUIApplication, leftward: Bool, name: String) throws -> [[String: Any]] {
        let object = try captureReport(in: app, leftward: leftward, name: name)
        return try XCTUnwrap(object["events"] as? [[String: Any]])
    }

    private func captureReport(
        in app: XCUIApplication,
        leftward: Bool,
        name: String,
        manualStyleRelease: Bool = false
    ) throws -> [String: Any] {
        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        let frame = carousel.frame
        let start = carousel.coordinate(withNormalizedOffset: CGVector(dx: leftward ? 0.75 : 0.25, dy: 0.5))
        let end = carousel.coordinate(withNormalizedOffset: CGVector(dx: leftward ? 0.25 : 0.75, dy: 0.5))
        let finish = app.buttons["history.scroll-performance-finish"]
            .coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        let pressDuration: TimeInterval = manualStyleRelease ? 0.15 : 0.05
        let releaseHoldDuration: TimeInterval = manualStyleRelease ? 0.15 : 0
        let metadata = XCTAttachment(string:
            "bundle=\(bundleID);viewport=\(frame);leftward=\(leftward);"
                + "fractions=0.25,0.75;y=0.5;press=\(pressDuration);"
                + "velocity=slow;hold=\(releaseHoldDuration)")
        metadata.name = name + "-protocol"
        metadata.lifetime = .keepAlways
        add(metadata)
        app.buttons["history.scroll-performance-start"].tap()
        // One bounded manual-style slow release variant for the physical gate;
        // do not tune gesture parameters after this attempt.
        start.press(
            forDuration: pressDuration,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: releaseHoldDuration
        )
        // One external driver delay; no app timer and no accessibility polling
        // during capture. Native idle timestamps determine valid phase windows.
        let observation = expectation(description: "Allow native release and post-idle observation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { observation.fulfill() }
        wait(for: [observation], timeout: 4)
        finish.tap()
        let snapshot = app.descendants(matching: .any)["history.scroll-performance-snapshot"]
        let raw = try XCTUnwrap(snapshot.value as? String)
        let attachment = XCTAttachment(string: raw)
        attachment.name = name + "-raw.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
}

extension BF106CaptureUITests {
    /// Manual-only attach path for an isolated app launched externally with
    /// devicectl before the test starts. The gate prevents accidental use
    /// against a normal install; this path calls `activate()` only and never
    /// launches, resets, seeds, or issues a gesture.
    func testManualPhysicalRightwardReleaseQualificationAttachOnly() throws {
        guard ProcessInfo.processInfo.environment[attachOnlyEnvironmentKey] == "1" else {
            throw XCTSkip(
                "Requires an externally direct-launched isolated BF106Profile app and "
                    + "BF106_ATTACH_ONLY=1; no app launch or gesture is performed by this test."
            )
        }

        let app = try attachToRunningManualFixture()
        defer { app.terminate() }
        try captureAttachedManualQualification(in: app)
    }

    private func attachToRunningManualFixture() throws -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        guard app.state != .unknown, app.state != .notRunning else {
            throw XCTSkip(
                "The isolated BF-106 app is not already running; launch it directly with "
                    + "devicectl before running the attach-only qualification."
            )
        }

        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "The externally launched isolated BF-106 app did not become foreground-active.\n"
                + app.debugDescription
        )
        XCTAssertTrue(
            app.buttons["history.scroll-performance-start"].waitForExistence(timeout: 10),
            "The attached app is not the prepared BF-106 diagnostic fixture.\n"
                + app.debugDescription
        )

        selectManualFixtureDate(in: app)
        return app
    }

    private func selectManualFixtureDate(in app: XCUIApplication) {
        let dateNavigator = app.descendants(matching: .any)["temporal.date-navigator"]
        XCTAssertTrue(
            dateNavigator.waitForExistence(timeout: 5),
            "The attached BF-106 fixture did not expose its semantic date selector.\n"
                + app.debugDescription
        )

        let populatedDay = dateNavigator.buttons[
            "temporal.date.\(manualFixtureSelectedDay.timeIntervalSince1970)"
        ]
        XCTAssertTrue(populatedDay.waitForExistence(timeout: 5), dateNavigator.debugDescription)
        let hittable = NSPredicate { _, _ in populatedDay.isHittable }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: hittable, object: populatedDay)],
                timeout: 5
            ),
            .completed,
            "The populated BF-106 date selector was not hittable.\n"
                + dateNavigator.debugDescription
        )
        populatedDay.tap()

        let selected = app.descendants(matching: .any)["history.selected-date"]
        let selectedPopulatedDay = NSPredicate { _, _ in selected.label == "Wed 26 Aug" }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: selectedPopulatedDay, object: selected)],
                timeout: 5
            ),
            .completed,
            "The attached BF-106 fixture did not select Wed 26 Aug.\n"
                + app.debugDescription
        )

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        let settled = NSPredicate { _, _ in carousel.value as? String == "Settled" }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: settled, object: carousel)],
                timeout: 5
            ),
            .completed,
            "The attached BF-106 fixture did not settle after semantic date selection.\n"
                + app.debugDescription
        )
    }

    private func captureAttachedManualQualification(in app: XCUIApplication) throws {
        let selectedDate = app.descendants(matching: .any)["history.selected-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(selectedDate.label, "Wed 26 Aug", app.debugDescription)

        let emptyState = app.descendants(matching: .any)["history.empty"]
        XCTAssertTrue(
            emptyState.waitForNonExistence(timeout: 5),
            "Attached manual capture must use the populated 2026-08-26 timeline.\n"
                + app.debugDescription
        )

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 5), app.debugDescription)
        add(
            manualProtocolMetadataAttachment(
                for: carousel,
                testName: "testManualPhysicalRightwardReleaseQualificationAttachOnly"
            )
        )

        let start = app.buttons["history.scroll-performance-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), app.debugDescription)
        start.tap()
        print(
            "BF-106 MANUAL ATTACH CAPTURE READY | external direct isolated launch | "
                + "swipe right slowly across populated Wed 26 Aug content, release naturally | "
                + "interaction window=\(Int(manualInteractionWindowSeconds))s | "
                + "no test gesture"
        )
        waitForManualInteractionWindow()

        let finish = app.buttons["history.scroll-performance-finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), app.debugDescription)
        finish.tap()

        let raw = try finishedSnapshot(in: app)
        let attachment = XCTAttachment(string: raw)
        attachment.name = "manual-rightward-attached-raw.json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        try assertStrictCapturedQualification(report)
    }
}
