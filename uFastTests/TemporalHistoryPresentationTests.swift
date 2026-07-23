@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length trailing_comma type_body_length

final class TemporalHistoryPresentationTests: XCTestCase {
    func testWindowShowsEveningMidnightAndFollowingEvening() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let window = try XCTUnwrap(TemporalHistoryPresentation.ribbonWindow(containing: day, calendar: calendar))

        XCTAssertEqual(calendar.component(.hour, from: window.interval.start), 18)
        XCTAssertEqual(calendar.component(.day, from: window.interval.start), 21)
        XCTAssertEqual(calendar.component(.hour, from: window.interval.end), 18)
        XCTAssertEqual(calendar.component(.day, from: window.interval.end), 23)
        XCTAssertEqual(window.midnightMarkers.count, 2)
    }

    func testSameDayAndOvernightIntervalsClipWithoutMutation() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let window = try XCTUnwrap(TemporalHistoryPresentation.ribbonWindow(containing: day, calendar: calendar))
        let same = try TemporalIntervalInput(
            id: UUID(),
            start: date(2026, 7, 22, 9, calendar: calendar),
            end: date(2026, 7, 22, 11, calendar: calendar)
        )
        let overnight = try TemporalIntervalInput(
            id: UUID(),
            start: date(2026, 7, 21, 19, calendar: calendar),
            end: date(2026, 7, 22, 8, calendar: calendar)
        )

        let result = TemporalHistoryPresentation.clip([same, overnight], to: window)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.id == overnight.id }?.originalStart, overnight.start)
        XCTAssertEqual(result.first { $0.id == overnight.id }?.originalEnd, overnight.end)
        XCTAssertFalse(try XCTUnwrap(result.first { $0.id == overnight.id }).continuesBefore)
        XCTAssertFalse(try XCTUnwrap(result.first { $0.id == overnight.id }).continuesAfter)
    }

    func testContinuationAcrossViewportAndMonthYearBoundary() throws {
        let calendar = try londonCalendar()
        let day = try date(2027, 1, 1, 12, calendar: calendar)
        let window = try XCTUnwrap(TemporalHistoryPresentation.ribbonWindow(containing: day, calendar: calendar))
        let interval = try TemporalIntervalInput(
            id: UUID(),
            start: date(2026, 12, 30, 20, calendar: calendar),
            end: date(2027, 1, 3, 8, calendar: calendar)
        )

        let segment = try XCTUnwrap(TemporalHistoryPresentation.clip([interval], to: window).first)

        XCTAssertTrue(segment.continuesBefore)
        XCTAssertTrue(segment.continuesAfter)
        XCTAssertEqual(segment.originalStart, interval.start)
        XCTAssertEqual(segment.originalEnd, interval.end)
    }

    func testLondonSpringAndAutumnWindowsUseActualElapsedTime() throws {
        let calendar = try londonCalendar()
        let spring = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 3, 29, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let autumn = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 10, 25, 12, calendar: calendar),
                calendar: calendar
            )
        )

        XCTAssertEqual(spring.duration, 47 * 60 * 60)
        XCTAssertEqual(autumn.duration, 49 * 60 * 60)
    }

    func testWeekUsesCalendarFirstWeekday() throws {
        var calendar = try londonCalendar()
        calendar.firstWeekday = 2
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let week = TemporalHistoryPresentation.week(containing: day, calendar: calendar)

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(try calendar.component(.weekday, from: XCTUnwrap(week.first)), 2)
    }

    func testAdjacentDayUsesLocalCalendarAcrossMonthYearLeapDayAndLondonDST() throws {
        let calendar = try londonCalendar()
        let cases = try [
            (
                date(2026, 1, 31, 12, calendar: calendar),
                1,
                date(2026, 2, 1, 0, calendar: calendar)
            ),
            (
                date(2026, 1, 1, 12, calendar: calendar),
                -1,
                date(2025, 12, 31, 0, calendar: calendar)
            ),
            (
                date(2028, 2, 28, 12, calendar: calendar),
                1,
                date(2028, 2, 29, 0, calendar: calendar)
            ),
            (
                date(2026, 3, 29, 12, calendar: calendar),
                1,
                date(2026, 3, 30, 0, calendar: calendar)
            ),
            (
                date(2026, 10, 25, 12, calendar: calendar),
                1,
                date(2026, 10, 26, 0, calendar: calendar)
            ),
        ]

        for (input, direction, expected) in cases {
            XCTAssertEqual(
                TemporalHistoryPresentation.adjacentDay(
                    to: input,
                    direction: direction,
                    calendar: calendar
                ),
                expected
            )
        }
    }

    func testSelectionCoordinatorCanonicalisesDaysAndSuppressesFeedbackLoops() throws {
        let calendar = try londonCalendar()
        var coordinator = try TemporalDaySelectionCoordinator(
            selectedDate: date(2026, 7, 22, 15, calendar: calendar),
            calendar: calendar
        )

        XCTAssertNil(
            try coordinator.select(
                date(2026, 7, 22, 8, calendar: calendar),
                source: .dateChip,
                calendar: calendar
            )
        )
        let pagerChange = try XCTUnwrap(
            coordinator.select(
                date(2026, 7, 23, 17, calendar: calendar),
                source: .pager,
                calendar: calendar
            )
        )
        XCTAssertEqual(pagerChange.revision, 1)
        XCTAssertEqual(pagerChange.source, .pager)
        XCTAssertTrue(calendar.isDate(pagerChange.day, inSameDayAs: coordinator.selectedDay))
        XCTAssertNil(
            try coordinator.select(
                date(2026, 7, 23, 9, calendar: calendar),
                source: .datePicker,
                calendar: calendar
            )
        )
    }

    func testCarouselMovementPhasesGateAutomaticAlignmentAndTimelineActions() {
        XCTAssertFalse(TemporalCarouselMovementPhase.settled.suppressesAutomaticAlignment)
        XCTAssertTrue(TemporalCarouselMovementPhase.settled.allowsTimelineInteraction)

        for phase in [
            TemporalCarouselMovementPhase.userDriven,
            .decelerating,
            .programmatic,
        ] {
            XCTAssertTrue(phase.suppressesAutomaticAlignment)
            XCTAssertFalse(phase.allowsTimelineInteraction)
        }
    }

    func testCarouselSettlementResolvesSlowAndFastNativeTargetsWithoutTiming() throws {
        let calendar = try londonCalendar()
        let today = try date(2027, 1, 2, 12, calendar: calendar)
        let buffer = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 6
        )
        let todayDay = calendar.startOfDay(for: today)
        let slowTarget = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: todayDay)
        )
        let fastTarget = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -4, to: todayDay)
        )

        XCTAssertEqual(
            TemporalHistoryPresentation.settledCarouselDay(
                centeredPage: slowTarget,
                currentSelection: today,
                availableDays: buffer.days,
                maximumDate: today,
                calendar: calendar
            ),
            slowTarget
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.settledCarouselDay(
                centeredPage: fastTarget,
                currentSelection: today,
                availableDays: buffer.days,
                maximumDate: today,
                calendar: calendar
            ),
            fastTarget
        )
    }

    func testCarouselSettlementRejectsUnknownAndFuturePageIdentities() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let selected = try date(2026, 7, 22, 12, calendar: calendar)
        let buffer = TemporalDayBuffer(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            radius: 2
        )
        let selectedDay = calendar.startOfDay(for: selected)
        let future = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: today)
        )
        let unknownPast = try date(2020, 1, 1, 12, calendar: calendar)

        for invalidTarget in [future, unknownPast, nil] {
            XCTAssertEqual(
                TemporalHistoryPresentation.settledCarouselDay(
                    centeredPage: invalidTarget,
                    currentSelection: selected,
                    availableDays: buffer.days,
                    maximumDate: today,
                    calendar: calendar
                ),
                selectedDay
            )
        }
    }

    func testDayBufferUsesCalendarDaysAndStopsAtToday() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 4, 2, 12, calendar: calendar)
        let selected = try date(2026, 3, 29, 12, calendar: calendar)
        let buffer = TemporalDayBuffer(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            radius: 5
        )

        XCTAssertEqual(buffer.days.count, 10)
        XCTAssertEqual(buffer.days.last, calendar.startOfDay(for: today))
        XCTAssertTrue(buffer.days.contains(calendar.startOfDay(for: selected)))
        XCTAssertEqual(
            buffer.days[6].timeIntervalSince(buffer.days[5]),
            23 * 60 * 60
        )
    }

    func testDayBufferExpandsWithoutChangingExistingDayIdentityOrOrder() throws {
        let calendar = try londonCalendar()
        let today = try date(2027, 1, 15, 12, calendar: calendar)
        let selected = try date(2027, 1, 1, 12, calendar: calendar)
        var buffer = TemporalDayBuffer(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            radius: 4
        )
        let original = buffer.days

        try buffer.ensureCoverage(
            around: XCTUnwrap(original.first),
            maximumDate: today,
            calendar: calendar,
            edgeThreshold: 1,
            expansion: 3
        )

        XCTAssertEqual(Array(buffer.days.dropFirst(3).prefix(original.count)), original)
        XCTAssertEqual(buffer.days, buffer.days.sorted())
        XCTAssertEqual(Set(buffer.days).count, buffer.days.count)
    }

    func testDayBufferExpandsForwardOnlyThroughMaximumDay() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 11, 3, 12, calendar: calendar)
        let selected = try date(2026, 10, 25, 12, calendar: calendar)
        var buffer = TemporalDayBuffer(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            radius: 2
        )

        try buffer.ensureCoverage(
            around: XCTUnwrap(buffer.days.last),
            maximumDate: today,
            calendar: calendar,
            edgeThreshold: 1,
            expansion: 30
        )

        XCTAssertEqual(buffer.days.last, calendar.startOfDay(for: today))
        XCTAssertFalse(buffer.days.contains {
            $0 > calendar.startOfDay(for: today)
        })
    }

    func testDayBufferRecentresForLongDistanceDatePickerJump() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        var buffer = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 5
        )
        let distant = try date(2021, 2, 14, 12, calendar: calendar)

        buffer.ensureCoverage(
            around: distant,
            maximumDate: today,
            calendar: calendar,
            expansion: 8
        )

        XCTAssertTrue(buffer.days.contains(calendar.startOfDay(for: distant)))
        XCTAssertEqual(buffer.days.count, 17)
        XCTAssertFalse(buffer.days.contains(calendar.startOfDay(for: today)))
    }

    func testTapMappingUsesActualWindowAndMarkHitPriority() throws {
        let calendar = try londonCalendar()
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 10, 25, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let eventID = UUID()
        let intervalID = UUID()
        let repeatedGMT = Date(timeIntervalSince1970: 1_792_891_800)
        let position = window.fraction(for: repeatedGMT) * 400

        XCTAssertEqual(
            TemporalHistoryPresentation.ribbonHitTarget(
                at: position,
                width: 400,
                window: window,
                hitRegions: []
            ),
            .empty(instant: repeatedGMT)
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.ribbonHitTarget(
                at: position,
                width: 400,
                window: window,
                hitRegions: [
                    .init(
                        id: intervalID,
                        range: (position / 400 - 0.02) ... (position / 400 + 0.02),
                        kind: .interval
                    ),
                    .init(
                        id: eventID,
                        range: (position / 400 - 0.01) ... (position / 400 + 0.01),
                        kind: .event
                    ),
                ]
            ),
            .mark(id: eventID, kind: .event)
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.ribbonHitTarget(
                at: 0,
                width: 400,
                window: window,
                hitRegions: []
            ),
            .empty(instant: window.interval.start)
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.ribbonHitTarget(
                at: 400,
                width: 400,
                window: window,
                hitRegions: []
            ),
            .empty(instant: window.interval.end)
        )
    }

    func testSpringTapCannotProduceMissingHourAndAutumnInstantsRemainDistinct() throws {
        let calendar = try londonCalendar()
        let springWindow = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 3, 29, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let springInstant = Date(timeIntervalSince1970: 1_774_747_800)
        let mapped = springWindow.instant(at: springWindow.fraction(for: springInstant))
        XCTAssertEqual(calendar.component(.hour, from: mapped), 2)

        let autumnWindow = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 10, 25, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let firstOneThirty = Date(timeIntervalSince1970: 1_792_888_200)
        let secondOneThirty = Date(timeIntervalSince1970: 1_792_891_800)
        XCTAssertEqual(calendar.component(.hour, from: firstOneThirty), 1)
        XCTAssertEqual(calendar.component(.hour, from: secondOneThirty), 1)
        XCTAssertNotEqual(
            autumnWindow.fraction(for: firstOneThirty),
            autumnWindow.fraction(for: secondOneThirty)
        )
    }

    func testSelectedInstantSummaryUsesLocaleAndDisambiguatesRepeatedHour() throws {
        let calendar = try londonCalendar()
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 10, 25, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let bst = Date(timeIntervalSince1970: 1_792_888_200)
        let gmt = Date(timeIntervalSince1970: 1_792_891_800)
        let british = TemporalFormattingContext(
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: zone
        )
        let american = TemporalFormattingContext(
            locale: Locale(identifier: "en_US"),
            calendar: calendar,
            timeZone: zone
        )

        XCTAssertTrue(
            TemporalHistoryPresentation.selectedInstantSummary(
                bst,
                in: window,
                context: british
            ).contains("BST")
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.selectedInstantSummary(
                gmt,
                in: window,
                context: british
            ).contains("GMT")
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.selectedInstantSummary(
                gmt,
                in: window,
                context: american
            ).contains("AM")
        )
    }

    func testStableEventOrderingAndLaneAllocation() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let window = try XCTUnwrap(TemporalHistoryPresentation.ribbonWindow(containing: day, calendar: calendar))
        let firstID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let instant = try date(2026, 7, 22, 9, calendar: calendar)
        let ordered = TemporalHistoryPresentation.chronological([
            TemporalEventOrderingValue(id: secondID, occurredAt: instant),
            TemporalEventOrderingValue(id: firstID, occurredAt: instant),
        ])
        XCTAssertEqual(ordered.map(\.id), [firstID, secondID])

        let segments = TemporalHistoryPresentation.clip([
            TemporalIntervalInput(id: firstID, start: instant, end: instant.addingTimeInterval(7200)),
            TemporalIntervalInput(
                id: secondID,
                start: instant.addingTimeInterval(3600),
                end: instant.addingTimeInterval(10800)
            ),
        ], to: window)
        XCTAssertEqual(Set(segments.map(\.lane)), [0, 1])
    }

    func testProvenanceUnknownAndTwelveTwentyFourHourSummaries() throws {
        let calendar = try londonCalendar()
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let start = try date(2026, 7, 21, 20, calendar: calendar)
        let end = try date(2026, 7, 22, 8, calendar: calendar)
        let britishSummary = TemporalHistoryPresentation.intervalSummary(
            provenance: .reconstructed(adjusted: true, needsReview: true),
            start: start,
            end: end,
            context: TemporalFormattingContext(
                locale: Locale(identifier: "en_GB"),
                calendar: calendar,
                timeZone: zone
            )
        )
        let americanSummary = TemporalHistoryPresentation.intervalSummary(
            provenance: .unknown,
            start: start,
            end: end,
            context: TemporalFormattingContext(
                locale: Locale(identifier: "en_US"),
                calendar: calendar,
                timeZone: zone
            )
        )

        XCTAssertTrue(britishSummary.contains("Needs review"))
        XCTAssertTrue(britishSummary.contains("Adjusted by you"))
        XCTAssertTrue(britishSummary.contains("20:00"))
        XCTAssertTrue(americanSummary.contains("Unknown period"))
        XCTAssertTrue(americanSummary.contains("PM"))
    }

    func testNarrowAndWideGeometryRemainDeterministic() {
        let narrow = TemporalRibbonGeometry.policy(for: 320, accessibilitySize: false)
        let wide = TemporalRibbonGeometry.policy(for: 430, accessibilitySize: false)
        let accessible = TemporalRibbonGeometry.policy(for: 320, accessibilitySize: true)

        XCTAssertEqual(narrow.contentWidth, 900)
        XCTAssertGreaterThan(wide.contentWidth, narrow.contentWidth)
        XCTAssertGreaterThan(accessible.contentWidth, narrow.contentWidth)
        XCTAssertGreaterThan(accessible.eventLaneHeight, narrow.eventLaneHeight)
    }

    private func londonCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
