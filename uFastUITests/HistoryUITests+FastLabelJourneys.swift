import XCTest

// This focused journey retains its trace parser and assertions beside the
// scenario so the result-bundle attachment remains directly auditable.
// swiftlint:disable file_length
extension HistoryUITests {
    @MainActor
    // swiftlint:disable:next function_body_length
    func testContinuousFastLabelsProjectOnceAndStayIdleStable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 27, hour: 10, minute: 0)
            )
        )
        let launchArguments = UITestLaunchConfiguration(
            resetData: true,
            seedOnboarded: true,
            fixedNow: now,
            seedHistoryFastLabelLayout: true,
            suppressAutomaticLiveActivityOffer: true,
            startsOnHistory: true,
            appleLocale: "en_GB",
            timeZone: "Europe/London"
        ).arguments

        // Capture an actual pre-decoration layout using the same fixture and
        // launch configuration. The baseline run does not render the
        // decorative label views, while retaining the same diagnostics and
        // measured content-layout preference.
        let baselineApp = launchHistory(
            arguments: launchArguments,
            additionalArguments: ["--ui-testing-history-label-layout-baseline"]
        )
        openHistory(in: baselineApp)
        XCTAssertTrue(
            waitForHistoryCarouselToSettle(in: baselineApp),
            baselineApp.debugDescription
        )
        let baselineSnapshotElement = baselineApp.descendants(matching: .any)[
            "history.fast-label-layout-snapshot"
        ]
        let baselineAppearedSegmentElement = baselineApp.descendants(matching: .any)[
            "history.fast-label-appeared-segment-count"
        ]
        let baselineProjectionElement = baselineApp.descendants(matching: .any)[
            "history.fast-label-projection-count"
        ]
        let baselineMetricsElement = baselineApp.descendants(matching: .any)[
            "history.fast-label-metrics-resolution-count"
        ]
        let baselineTraceElement = baselineApp.descendants(matching: .any)[
            "history.fast-label-trace"
        ]
        XCTAssertTrue(
            waitForExistenceIfNeeded(baselineSnapshotElement),
            baselineApp.debugDescription
        )
        XCTAssertTrue(
            waitForExistenceIfNeeded(baselineAppearedSegmentElement),
            baselineApp.debugDescription
        )
        XCTAssertTrue(
            waitForExistenceIfNeeded(baselineProjectionElement),
            baselineApp.debugDescription
        )
        XCTAssertTrue(
            waitForExistenceIfNeeded(baselineMetricsElement),
            baselineApp.debugDescription
        )
        XCTAssertTrue(
            waitForExistenceIfNeeded(baselineTraceElement),
            baselineApp.debugDescription
        )
        let baselineSnapshot = baselineSnapshotElement.value as? String ?? ""
        let baselineLayout = try XCTUnwrap(
            FastLabelLayoutValues(snapshot: baselineSnapshot),
            baselineSnapshot
        )
        let baselineAppearedSegments = try XCTUnwrap(
            Int(baselineAppearedSegmentElement.value as? String ?? ""),
            baselineApp.debugDescription
        )
        XCTAssertGreaterThan(baselineAppearedSegments, 0, baselineApp.debugDescription)
        XCTAssertEqual(
            baselineProjectionElement.value as? String,
            "0",
            "Pre-decoration baseline must not project labels.\n\(baselineApp.debugDescription)"
        )
        XCTAssertEqual(
            baselineMetricsElement.value as? String,
            "0",
            "Pre-decoration baseline must not resolve label metrics.\n\(baselineApp.debugDescription)"
        )
        XCTAssertEqual(
            extractField("descriptors=", from: baselineSnapshot),
            "0",
            baselineSnapshot
        )
        XCTAssertEqual(
            extractField("metrics=", from: baselineSnapshot),
            "0",
            baselineSnapshot
        )
        XCTAssertEqual(
            baselineApp.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "history.fast-label-probe.")
            ).count,
            0,
            "Pre-decoration baseline must not expose projected label probes.\n\(baselineApp.debugDescription)"
        )
        let baselineTrace = baselineTraceElement.value as? String ?? ""
        let baselineTraceRows = try XCTUnwrap(
            FastLabelTraceRow.parse(baselineTrace),
            baselineTrace
        )
        XCTAssertTrue(
            baselineTraceRows.allSatisfy { !$0.event.hasPrefix("input.")
                && !$0.event.hasPrefix("title.")
                && !$0.event.hasPrefix("metrics.")
                && !$0.event.hasPrefix("projection.")
            },
            "Pre-decoration baseline recorded label work.\n\(baselineTrace)"
        )
        let baseline = XCTAttachment(
            string: "BF-104 pre-decoration baseline: \(baselineSnapshot); "
                + "appearedSegments=\(baselineAppearedSegments)"
        )
        baseline.name = "BF-104-layout-baseline"
        baseline.lifetime = .keepAlways
        add(baseline)
        baselineApp.terminate()

        let app = launchHistory(arguments: launchArguments)
        openHistory(in: app)

        let carousel = app.scrollViews["history.day-carousel"]
        XCTAssertTrue(waitForHistoryCarouselToSettle(in: app), app.debugDescription)
        let snapshot = app.descendants(matching: .any)["history.fast-label-layout-snapshot"]
        let projectionCount = app.descendants(matching: .any)["history.fast-label-projection-count"]
        let metricsCount = app.descendants(matching: .any)["history.fast-label-metrics-resolution-count"]
        let inputCount = app.descendants(matching: .any)["history.fast-label-input-resolution-count"]
        let titleCount = app.descendants(matching: .any)["history.fast-label-title-resolution-count"]
        let traceElement = app.descendants(matching: .any)["history.fast-label-trace"]
        let callbackOverlapCount = app.descendants(matching: .any)[
            "history.fast-label-work-during-scroll-callback-count"
        ]
        let appearedSegmentCount = app.descendants(matching: .any)[
            "history.fast-label-appeared-segment-count"
        ]
        XCTAssertTrue(waitForExistenceIfNeeded(snapshot), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(projectionCount), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(metricsCount), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(inputCount), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(titleCount), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(traceElement), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(callbackOverlapCount), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(appearedSegmentCount), app.debugDescription)

        let candidateInitialSnapshot = snapshot.value as? String ?? ""
        let candidateInitialLayout = try XCTUnwrap(
            FastLabelLayoutValues(snapshot: candidateInitialSnapshot),
            candidateInitialSnapshot
        )
        let candidateInitialAppearedSegments = try XCTUnwrap(
            Int(appearedSegmentCount.value as? String ?? ""),
            app.debugDescription
        )
        XCTAssertLessThanOrEqual(
            candidateInitialAppearedSegments,
            baselineAppearedSegments + 2,
            "Label overlay exceeded the baseline lazy-segment budget.\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            candidateInitialLayout.contentWidth,
            baselineLayout.contentWidth,
            accuracy: 0.5,
            "Decorative labels changed scroll content width.\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            candidateInitialLayout.dayStride,
            baselineLayout.dayStride,
            accuracy: 0.5,
            "Decorative labels changed measured day stride.\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            candidateInitialLayout.initialOffset,
            baselineLayout.initialOffset,
            accuracy: 0.5,
            "Decorative labels changed initial content offset.\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            candidateInitialLayout.selectedDayCenter,
            baselineLayout.selectedDayCenter,
            accuracy: 0.5,
            "Decorative labels changed selected-day centre.\n\(app.debugDescription)"
        )

        // The recorded fast crosses 25–26 August. Select 26 August before
        // reading frames so both lazy day fragments are instantiated; the
        // midpoint assertion must cover the full interval rather than the
        // fragment which happened to be materialised at launch.
        let selectedDate = app.staticTexts["history.selected-date"]
        let previousDay = app.buttons["history.previous-day"]
        XCTAssertTrue(waitForExistenceIfNeeded(selectedDate), app.debugDescription)
        XCTAssertTrue(waitForHittable(previousDay, app: app), previousDay.debugDescription)
        previousDay.tap()
        XCTAssertTrue(
            waitForSettledHistory(
                selectedDate: selectedDate,
                carousel: carousel,
                expectedSelectedDate: "Wed 26 Aug"
            ),
            app.debugDescription
        )

        let recordedProbe = app.descendants(matching: .any)[
            "history.fast-label-probe.10400000-0000-0000-0000-000000000001"
        ]
        let activeProbe = app.descendants(matching: .any)[
            "history.fast-label-probe.10400000-0000-0000-0000-000000000002"
        ]
        XCTAssertTrue(waitForExistenceIfNeeded(recordedProbe), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(activeProbe), app.debugDescription)
        XCTAssertEqual(recordedProbe.label, "Fast", recordedProbe.debugDescription)
        XCTAssertEqual(activeProbe.label, "Active fast", activeProbe.debugDescription)

        let probeIDs = [recordedProbe.identifier, activeProbe.identifier]
        let allProbes = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.fast-label-probe.")
        )
        XCTAssertEqual(allProbes.count, 2, app.debugDescription)
        for id in probeIDs {
            XCTAssertEqual(
                app.descendants(matching: .any).matching(
                    NSPredicate(format: "identifier == %@", id)
                ).count,
                1,
                app.debugDescription
            )
        }
        let recordedFragmentsAtMidpoint = intervalFragments(
            in: app,
            identifier: "history.interval.10400000-0000-0000-0000-000000000001"
        )
        XCTAssertEqual(
            recordedFragmentsAtMidpoint.count,
            2,
            "Expected both 25–26 August recorded-fast fragments before measuring its midpoint.\n\(app.debugDescription)"
        )
        assertLabelIsCenteredOnFragmentUnion(
            probe: recordedProbe,
            fragments: recordedFragmentsAtMidpoint,
            app: app
        )
        let activeFragmentsAtMidpoint = intervalFragments(
            in: app,
            identifier: "history.active-fast.10400000-0000-0000-0000-000000000002"
        )
        XCTAssertEqual(
            activeFragmentsAtMidpoint.count,
            2,
            "Expected both active-fast day fragments before measuring its midpoint.\n\(app.debugDescription)"
        )
        assertLabelIsCenteredOnFragmentUnion(
            probe: activeProbe,
            fragments: activeFragmentsAtMidpoint,
            app: app
        )

        // Start the idle window after the deliberate date selection above.
        // It is navigation, not label work, and must not be attributed to
        // the five-second no-work assertion.
        let candidateInitialTrace = traceElement.value as? String ?? ""
        let candidateInitialTraceRows = try XCTUnwrap(
            FastLabelTraceRow.parse(candidateInitialTrace),
            candidateInitialTrace
        )
        XCTAssertTrue(
            candidateInitialTraceRows.contains { $0.event == "metrics.begin" },
            "Candidate did not record metrics resolution.\n\(candidateInitialTrace)"
        )
        XCTAssertTrue(
            candidateInitialTraceRows.contains { $0.event == "projection.begin" },
            "Candidate did not record label projection.\n\(candidateInitialTrace)"
        )

        let projectionBaseline = projectionCount.value as? String ?? ""
        let metricsBaseline = metricsCount.value as? String ?? ""
        let inputBaseline = inputCount.value as? String ?? ""
        let titleBaseline = titleCount.value as? String ?? ""
        let callbackOverlapBaseline = callbackOverlapCount.value as? String ?? ""
        let selectedDateBaseline = selectedDate.label
        for requiredField in [
            "contentWidth=", "dayStride=", "initialOffset=", "selectedDayCenter=",
            // swiftlint:disable:next trailing_comma
            "appearedSegments=", "descriptors=", "metrics=",
        ] {
            XCTAssertTrue(
                candidateInitialSnapshot.contains(requiredField),
                "Missing \(requiredField) in deterministic layout snapshot: \(candidateInitialSnapshot)"
            )
        }
        XCTAssertEqual(callbackOverlapBaseline, "0", app.debugDescription)

        let idleDeadline = Date(timeIntervalSinceNow: 5)
        while Date() < idleDeadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        let idleTrace = traceElement.value as? String ?? ""
        XCTAssertEqual(
            idleTrace,
            candidateInitialTrace,
            "Label trace changed during five-second idle window.\n\(idleTrace)"
        )
        XCTAssertEqual(projectionCount.value as? String, projectionBaseline, app.debugDescription)
        XCTAssertEqual(metricsCount.value as? String, metricsBaseline, app.debugDescription)
        XCTAssertEqual(inputCount.value as? String, inputBaseline, app.debugDescription)
        XCTAssertEqual(titleCount.value as? String, titleBaseline, app.debugDescription)

        XCTAssertTrue(carousel.isHittable, carousel.debugDescription)
        for index in 0 ..< 10 {
            if index.isMultiple(of: 2) {
                carousel.swipeRight(velocity: .slow)
            } else {
                carousel.swipeLeft(velocity: .slow)
            }
            XCTAssertTrue(
                waitForHistoryCarouselToSettle(in: app),
                "Alternating swipe \(index + 1) did not settle.\n\(app.debugDescription)"
            )
            XCTAssertEqual(
                app.descendants(matching: .any).matching(
                    NSPredicate(format: "identifier BEGINSWITH %@", "history.fast-label-probe.")
                ).count,
                2,
                app.debugDescription
            )
            XCTAssertEqual(
                callbackOverlapCount.value as? String,
                "0",
                "Label work overlapped a scroll callback after swipe \(index + 1).\n\(app.debugDescription)"
            )
        }
        XCTAssertEqual(selectedDate.label, selectedDateBaseline, app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(recordedProbe), app.debugDescription)
        XCTAssertTrue(waitForExistenceIfNeeded(activeProbe), app.debugDescription)
        let recordedFragmentsAfterSwipes = intervalFragments(
            in: app,
            identifier: "history.interval.10400000-0000-0000-0000-000000000001"
        )
        XCTAssertEqual(recordedFragmentsAfterSwipes.count, 2, app.debugDescription)
        assertLabelIsCenteredOnFragmentUnion(
            probe: recordedProbe,
            fragments: recordedFragmentsAfterSwipes,
            app: app
        )
        let activeFragmentsAfterSwipes = intervalFragments(
            in: app,
            identifier: "history.active-fast.10400000-0000-0000-0000-000000000002"
        )
        XCTAssertEqual(activeFragmentsAfterSwipes.count, 2, app.debugDescription)
        assertLabelIsCenteredOnFragmentUnion(
            probe: activeProbe,
            fragments: activeFragmentsAfterSwipes,
            app: app
        )
        XCTAssertEqual(projectionCount.value as? String, projectionBaseline, app.debugDescription)
        XCTAssertEqual(metricsCount.value as? String, metricsBaseline, app.debugDescription)
        XCTAssertEqual(inputCount.value as? String, inputBaseline, app.debugDescription)
        XCTAssertEqual(titleCount.value as? String, titleBaseline, app.debugDescription)
        XCTAssertEqual(callbackOverlapCount.value as? String, "0", app.debugDescription)

        let candidateSnapshot = snapshot.value as? String ?? ""
        let candidateTrace = traceElement.value as? String ?? ""
        let candidateTraceRows = try XCTUnwrap(FastLabelTraceRow.parse(candidateTrace), candidateTrace)
        assertFastLabelTrace(candidateTraceRows, app: app)
        let traceAttachment = XCTAttachment(
            string: "BF-104 deterministic label-work trace\n"
                + "baselineRows=\(baselineTraceRows.count)\n\(baselineTrace)\n"
                + "candidateInitialRows=\(candidateInitialTraceRows.count)\n"
                + "candidateFinalRows=\(candidateTraceRows.count)\n"
                + "idleTraceUnchanged=true\n"
                + candidateTrace
        )
        traceAttachment.name = "BF-104-label-work-trace"
        traceAttachment.lifetime = .keepAlways
        add(traceAttachment)
        let candidate = XCTAttachment(string: "BF-104 deterministic candidate: initial=\(candidateInitialSnapshot); "
            + "afterSwipes=\(candidateSnapshot); "
            + "projectionCount=\(projectionCount.value ?? ""); metricsResolutionCount=\(metricsCount.value ?? ""); "
            + "callbackOverlap=\(callbackOverlapCount.value ?? ""); "
            + "baselinePlusTwoLimit=\(baselineAppearedSegments + 2); "
            + "candidateInitialAppearedSegments=\(candidateInitialAppearedSegments)")
        candidate.name = "BF-104-layout-candidate"
        candidate.lifetime = .keepAlways
        add(candidate)
        let signpostEvidence = XCTAttachment(
            string: "BF-104 scroll callback evidence: baseline=\(baselineSnapshot); "
                + "candidateInitial=\(candidateInitialSnapshot); candidateAfterSwipes=\(candidateSnapshot); "
                + "geometryDelta=contentWidth:\(candidateInitialLayout.contentWidth - baselineLayout.contentWidth), "
                + "dayStride:\(candidateInitialLayout.dayStride - baselineLayout.dayStride), "
                + "initialOffset:\(candidateInitialLayout.initialOffset - baselineLayout.initialOffset), "
                + "selectedDayCenter:\(candidateInitialLayout.selectedDayCenter - baselineLayout.selectedDayCenter); "
                + "callbackOverlap=\(callbackOverlapCount.value ?? ""); "
                + "maxCallbackDepth=\(extractField("maxScrollCallbackDepth=", from: candidateSnapshot) ?? "")"
        )
        signpostEvidence.name = "BF-104-scroll-callback-evidence"
        signpostEvidence.lifetime = .keepAlways
        add(signpostEvidence)
    }

    @MainActor
    private func intervalFragments(
        in app: XCUIApplication,
        identifier: String
    ) -> [CGRect] {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier == %@", identifier)
        )
        return (0 ..< candidates.count).compactMap { index in
            let candidate = candidates.element(boundBy: index)
            let frame = candidate.frame
            guard candidate.exists,
                  frame.width > 0,
                  frame.height > 0,
                  frame.origin.x.isFinite,
                  frame.origin.y.isFinite,
                  frame.width.isFinite,
                  frame.height.isFinite
            else { return nil }
            return frame
        }
    }

    @MainActor
    private func assertLabelIsCenteredOnFragmentUnion(
        probe: XCUIElement,
        fragments: [CGRect],
        app: XCUIApplication
    ) {
        XCTAssertFalse(fragments.isEmpty, "No interval fragments for \(probe.identifier).\n\(app.debugDescription)")
        guard let first = fragments.first else { return }
        let union = fragments.dropFirst().reduce(first) { $0.union($1) }
        XCTAssertEqual(
            probe.frame.midX,
            union.midX,
            accuracy: 2,
            "Label is not centred on the complete fragment union.\n\(app.debugDescription)"
        )
        XCTAssertGreaterThanOrEqual(
            probe.frame.minY,
            union.minY,
            "Label escaped the interval lane vertically.\n\(app.debugDescription)"
        )
        XCTAssertLessThanOrEqual(
            probe.frame.maxY,
            union.maxY,
            "Label escaped the interval lane vertically.\n\(app.debugDescription)"
        )
    }

    private func extractField(_ prefix: String, from value: String) -> String? {
        guard let range = value.range(of: prefix) else { return nil }
        let suffix = value[range.upperBound...]
        return suffix.split(separator: ";", maxSplits: 1).first.map(String.init)
    }

    @MainActor
    private func assertFastLabelTrace(_ rows: [FastLabelTraceRow], app: XCUIApplication) {
        XCTAssertFalse(rows.isEmpty, app.debugDescription)
        XCTAssertTrue(
            zip(rows, rows.dropFirst()).allSatisfy { $0.sequence < $1.sequence
                && $0.timestamp <= $1.timestamp
            },
            "Trace sequence/timestamps are not monotonic.\n\(rows)"
        )
        let scrollIntervals = pairedIntervals(
            rows,
            beginEvent: "scroll.begin",
            endEvent: "scroll.end",
            app: app
        )
        XCTAssertFalse(scrollIntervals.isEmpty, "Trace has no scroll callbacks.\n\(rows)")
        XCTAssertTrue(
            scrollIntervals.allSatisfy { $0.begin.depth == 1 && $0.end.depth == 1 },
            "Scroll callback depth was not exactly one.\n\(rows)"
        )
        let labelIntervals = ["input", "title", "metrics", "projection"].flatMap { kind in
            pairedIntervals(rows, beginEvent: "\(kind).begin", endEvent: "\(kind).end", app: app)
        }
        XCTAssertTrue(
            labelIntervals.allSatisfy { $0.begin.depth == 0 && $0.end.depth == 0 },
            "Label work ran at non-zero scroll callback depth.\n\(rows)"
        )
        XCTAssertTrue(
            labelIntervals.allSatisfy { work in
                scrollIntervals.allSatisfy { scroll in
                    work.end.timestamp <= scroll.begin.timestamp
                        || scroll.end.timestamp <= work.begin.timestamp
                }
            },
            "Label-work trace overlaps a scroll callback.\n\(rows)"
        )
    }

    @MainActor
    private func pairedIntervals(
        _ rows: [FastLabelTraceRow],
        beginEvent: String,
        endEvent: String,
        app: XCUIApplication
    ) -> [FastLabelTraceInterval] {
        var starts: [FastLabelTraceRow] = []
        var intervals: [FastLabelTraceInterval] = []
        for row in rows {
            if row.event == beginEvent {
                starts.append(row)
            } else if row.event == endEvent {
                guard let start = starts.popLast() else {
                    XCTFail("Trace ended \(endEvent) without \(beginEvent).\n\(app.debugDescription)")
                    continue
                }
                intervals.append(FastLabelTraceInterval(begin: start, end: row))
            }
        }
        XCTAssertTrue(
            starts.isEmpty,
            "Trace has unclosed \(beginEvent) rows.\n\(app.debugDescription)"
        )
        return intervals
    }
}

private struct FastLabelTraceRow: Equatable, CustomStringConvertible {
    let sequence: Int
    let event: String
    let timestamp: Double
    let depth: Int

    var description: String {
        "seq=\(sequence);event=\(event);timestamp=\(timestamp);depth=\(depth)"
    }

    static func parse(_ snapshot: String) -> [FastLabelTraceRow]? {
        guard !snapshot.isEmpty else { return [] }
        let lines: [String] = snapshot.components(separatedBy: CharacterSet.newlines)
        return lines.compactMap { (line: String) -> FastLabelTraceRow? in
            guard !line.isEmpty else { return nil }
            var fields: [String: String] = [:]
            for field in line.split(separator: ";", omittingEmptySubsequences: true) {
                let pair = field.split(separator: "=", maxSplits: 1)
                guard pair.count == 2 else { return nil }
                fields[String(pair[0])] = String(pair[1])
            }
            guard let sequence = fields["seq"].flatMap(Int.init),
                  let event = fields["event"],
                  let timestamp = fields["timestamp"].flatMap(Double.init),
                  let depth = fields["depth"].flatMap(Int.init),
                  timestamp.isFinite
            else { return nil }
            return FastLabelTraceRow(
                sequence: sequence,
                event: event,
                timestamp: timestamp,
                depth: depth
            )
        }
    }
}

private struct FastLabelTraceInterval {
    let begin: FastLabelTraceRow
    let end: FastLabelTraceRow
}

private struct FastLabelLayoutValues {
    let contentWidth: Double
    let dayStride: Double
    let initialOffset: Double
    let selectedDayCenter: Double

    init?(snapshot: String) {
        guard let contentWidth = Self.number("contentWidth=", in: snapshot),
              let dayStride = Self.number("dayStride=", in: snapshot),
              let initialOffset = Self.number("initialOffset=", in: snapshot),
              let selectedDayCenter = Self.number("selectedDayCenter=", in: snapshot),
              contentWidth.isFinite, dayStride.isFinite,
              initialOffset.isFinite, selectedDayCenter.isFinite
        else { return nil }
        self.contentWidth = contentWidth
        self.dayStride = dayStride
        self.initialOffset = initialOffset
        self.selectedDayCenter = selectedDayCenter
    }

    private static func number(_ prefix: String, in snapshot: String) -> Double? {
        guard let range = snapshot.range(of: prefix) else { return nil }
        let suffix = snapshot[range.upperBound...]
        let value = suffix.split(separator: ";", maxSplits: 1).first.map(String.init)
        return value.flatMap(Double.init)
    }
}
