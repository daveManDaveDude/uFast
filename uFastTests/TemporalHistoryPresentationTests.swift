@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length trailing_comma type_body_length

final class TemporalHistoryPresentationTests: XCTestCase {
    func testWindowShowsFullSelectedDayWithOneHourContextAtEachEdge() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let window = try XCTUnwrap(TemporalHistoryPresentation.ribbonWindow(containing: day, calendar: calendar))

        XCTAssertEqual(calendar.component(.hour, from: window.interval.start), 23)
        XCTAssertEqual(calendar.component(.day, from: window.interval.start), 21)
        XCTAssertEqual(calendar.component(.hour, from: window.interval.end), 1)
        XCTAssertEqual(calendar.component(.day, from: window.interval.end), 23)
        XCTAssertEqual(window.midnightMarkers.count, 2)
        XCTAssertEqual(window.duration, 26 * 60 * 60)
    }

    func testContinuousTimelineResolvesAnArbitraryVisibleWindowWithoutDaySnapping() throws {
        let calendar = try londonCalendar()
        let firstDay = try date(2026, 7, 21, 0, calendar: calendar)
        let days = (0 ..< 4).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDay)
        }
        let segmentWidth = 240.0
        let containerWidth = 260.0
        let geometry = TemporalContinuousTimelineGeometry(
            contentOffset: 290,
            contentWidth: segmentWidth * Double(days.count),
            containerWidth: containerWidth
        )

        let window = try XCTUnwrap(
            geometry.visibleWindow(
                days: days,
                calendar: calendar,
                layoutDirection: .leftToRight
            )
        )
        let progress = try XCTUnwrap(
            geometry.centerProgress(
                days: days,
                layoutDirection: .leftToRight
            )
        )

        XCTAssertEqual(calendar.component(.day, from: window.interval.start), 22)
        XCTAssertEqual(calendar.component(.hour, from: window.interval.start), 5)
        XCTAssertEqual(calendar.component(.day, from: window.interval.end), 23)
        XCTAssertEqual(calendar.component(.hour, from: window.interval.end), 7)
        XCTAssertEqual(window.duration, 26 * 60 * 60)
        XCTAssertEqual(progress.leadingDay, days[1])
        XCTAssertEqual(progress.trailingDay, days[2])
        XCTAssertEqual(progress.fraction, 0.25, accuracy: 0.000_001)
    }

    func testContinuousTimelineVisibleWindowUsesActualLondonDSTDayDurations() throws {
        let calendar = try londonCalendar()
        let firstDay = try date(2026, 3, 28, 0, calendar: calendar)
        let days = (0 ..< 4).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDay)
        }
        let geometry = TemporalContinuousTimelineGeometry(
            contentOffset: 230,
            contentWidth: 240 * Double(days.count),
            containerWidth: 260
        )

        let window = try XCTUnwrap(
            geometry.visibleWindow(
                days: days,
                calendar: calendar,
                layoutDirection: .leftToRight
            )
        )

        XCTAssertEqual(calendar.component(.hour, from: window.interval.start), 23)
        XCTAssertEqual(calendar.component(.hour, from: window.interval.end), 1)
        XCTAssertEqual(window.duration, 25 * 60 * 60)
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
        XCTAssertTrue(try XCTUnwrap(result.first { $0.id == overnight.id }).continuesBefore)
        XCTAssertFalse(try XCTUnwrap(result.first { $0.id == overnight.id }).continuesAfter)
    }

    func testLiveIntervalContinuationKeepsAdjacentPageBackgroundSeamless() {
        XCTAssertTrue(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: true,
                continuesBefore: false,
                isSelectedPage: true
            )
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: true,
                continuesBefore: true,
                isSelectedPage: true
            )
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: true,
                continuesBefore: true,
                isSelectedPage: false
            )
        )
        XCTAssertFalse(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: true,
                continuesBefore: false,
                isSelectedPage: false
            )
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: true,
                continuesBefore: true,
                continuesAfter: true,
                isSelectedPage: false
            )
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.intervalContinuationShowsContent(
                isActive: false,
                continuesBefore: true,
                isSelectedPage: false
            )
        )
        XCTAssertFalse(TemporalHistoryPresentation.intervalContinuationShowsMarkers(isActive: true))
        XCTAssertTrue(TemporalHistoryPresentation.intervalContinuationShowsMarkers(isActive: false))
    }

    func testOvernightIntervalLaneOrderUsesOriginalStartsAcrossMidnight() throws {
        let calendar = try londonCalendar()
        let longInterval = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000011")),
            start: date(2026, 7, 21, 20, calendar: calendar),
            end: date(2026, 7, 23, 8, calendar: calendar)
        )
        let shortInterval = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000012")),
            start: date(2026, 7, 22, 22, calendar: calendar),
            end: date(2026, 7, 23, 2, calendar: calendar)
        )
        let firstWindow = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 7, 22, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let nextWindow = try XCTUnwrap(
            TemporalHistoryPresentation.ribbonWindow(
                containing: date(2026, 7, 23, 12, calendar: calendar),
                calendar: calendar
            )
        )

        let firstLongSegment = try XCTUnwrap(
            TemporalHistoryPresentation.clip([longInterval, shortInterval], to: firstWindow)
                .first(where: { $0.id == longInterval.id })
        )
        let nextLongSegment = try XCTUnwrap(
            TemporalHistoryPresentation.clip([longInterval, shortInterval], to: nextWindow)
                .first(where: { $0.id == longInterval.id })
        )

        XCTAssertEqual(firstLongSegment.lane, 0)
        XCTAssertEqual(nextLongSegment.lane, firstLongSegment.lane)
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

        XCTAssertEqual(spring.duration, 25 * 60 * 60)
        XCTAssertEqual(autumn.duration, 27 * 60 * 60)
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
        XCTAssertTrue(TemporalCarouselMovementPhase.settled.showsTimelineDetails)

        for phase in [
            TemporalCarouselMovementPhase.userDriven,
            .decelerating,
            .aligning,
            .programmatic,
        ] {
            XCTAssertTrue(phase.suppressesAutomaticAlignment)
            XCTAssertFalse(phase.allowsTimelineInteraction)
            XCTAssertFalse(phase.showsTimelineDetails)
        }
    }

    func testFlushPageGeometryUsesOneContainerWidthPerCalendarDay() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let days = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 3
        ).days
        let containerWidth = 320.0
        let contentWidth = containerWidth * Double(days.count)

        let progress = try XCTUnwrap(
            TemporalDaySpaceProgress.resolve(
                contentOffset: containerWidth * 2.5,
                contentWidth: contentWidth,
                containerWidth: containerWidth,
                days: days,
                layoutDirection: .leftToRight
            )
        )

        XCTAssertEqual(progress.lowerPageStride, containerWidth, accuracy: 0.000_001)
        XCTAssertEqual(progress.leadingDay, days[2])
        XCTAssertEqual(progress.trailingDay, days[3])
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.000_001)
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

    func testDayBufferCentersTodayWithinBoundedFutureCalendarDays() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 3, 29, 12, calendar: calendar)
        let maximumDisplayDay = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 400, to: today)
        )
        let buffer = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: maximumDisplayDay,
            calendar: calendar,
            radius: 400
        )
        let todayDay = calendar.startOfDay(for: today)

        XCTAssertEqual(buffer.days.count, 801)
        XCTAssertEqual(buffer.days[400], todayDay)
        XCTAssertEqual(
            buffer.days.last,
            calendar.startOfDay(for: maximumDisplayDay)
        )
        XCTAssertEqual(
            buffer.days[401].timeIntervalSince(buffer.days[400]),
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

    func testDaySpaceProgressMapsForwardBackwardReversalAndMultipleDays() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let days = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 5
        ).days
        let stride = 332.0
        let contentWidth = stride * Double(days.count - 1) + 320

        let samples = [
            (2.25, 2, 0.25),
            (1.75, 1, 0.75),
            (2.1, 2, 0.1),
            (4.6, 4, 0.6),
        ]
        for (index, leadingIndex, fraction) in samples {
            let progress = try XCTUnwrap(
                TemporalDaySpaceProgress.resolve(
                    contentOffset: index * stride,
                    contentWidth: contentWidth,
                    containerWidth: 320,
                    days: days,
                    layoutDirection: .leftToRight
                )
            )
            XCTAssertEqual(progress.leadingDay, days[leadingIndex])
            XCTAssertEqual(progress.trailingDay, days[leadingIndex + 1])
            XCTAssertEqual(progress.fraction, fraction, accuracy: 0.000_001)
            XCTAssertEqual(progress.lowerPageStride, stride, accuracy: 0.000_001)
        }
    }

    func testDaySpaceProgressMapsRTLGeometryToTheSameCalendarProgress() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let days = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 3
        ).days
        let stride = 340.0
        let container = 320.0
        let content = stride * Double(days.count - 1) + container
        let chronologicalProgress = 2.4
        let ltr = try XCTUnwrap(
            TemporalDaySpaceProgress.resolve(
                contentOffset: chronologicalProgress * stride,
                contentWidth: content,
                containerWidth: container,
                days: days,
                layoutDirection: .leftToRight
            )
        )
        let rtl = try XCTUnwrap(
            TemporalDaySpaceProgress.resolve(
                contentOffset: content - container - chronologicalProgress * stride,
                contentWidth: content,
                containerWidth: container,
                days: days,
                layoutDirection: .rightToLeft
            )
        )

        XCTAssertEqual(rtl.leadingDay, ltr.leadingDay)
        XCTAssertEqual(rtl.trailingDay, ltr.trailingDay)
        XCTAssertEqual(rtl.fraction, ltr.fraction, accuracy: 0.000_001)
    }

    func testDaySpaceProgressUsesMeasuredLowerAndUpperStridesProportionally() throws {
        let calendar = try londonCalendar()
        let leading = try date(2026, 7, 21, 0, calendar: calendar)
        let trailing = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: leading,
                direction: 1,
                calendar: calendar
            )
        )
        let progress = TemporalDaySpaceProgress(
            leadingDay: leading,
            trailingDay: trailing,
            fraction: 0.4,
            lowerPageStride: 347
        )

        XCTAssertEqual(
            try XCTUnwrap(progress.upperTranslation(measuredChipStride: 57)),
            22.8,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(progress.upperTranslation(measuredChipStride: 87)),
            34.8,
            accuracy: 0.000_001
        )
        XCTAssertNil(progress.upperTranslation(measuredChipStride: 0))
    }

    func testCenteredCalendarDayChangesAtTheMidnightSeamAndReversesImmediately() throws {
        let calendar = try londonCalendar()
        let leading = try date(2026, 7, 21, 0, calendar: calendar)
        let trailing = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: leading,
                direction: 1,
                calendar: calendar
            )
        )

        for (fraction, expected) in [
            (0.0, leading),
            (0.4999, leading),
            (0.5, trailing),
            (0.5001, trailing),
            (1.0, trailing),
            (0.4999, leading),
        ] {
            XCTAssertEqual(
                TemporalDaySpaceProgress(
                    leadingDay: leading,
                    trailingDay: trailing,
                    fraction: fraction,
                    lowerPageStride: 320
                ).centeredCalendarDay,
                expected
            )
        }
    }

    func testAccessibleHistoryDayRemainsSettledWhileLivePresentationCrossesMidnight() throws {
        let calendar = try londonCalendar()
        let settled = try date(2026, 12, 31, 12, calendar: calendar)
        let live = try date(2027, 1, 1, 12, calendar: calendar)

        let moving = TemporalHistoryDayPresentation(
            settledDay: settled,
            liveDay: live,
            calendar: calendar
        )
        XCTAssertEqual(moving.visualDay, calendar.startOfDay(for: live))
        XCTAssertEqual(moving.settledDay, calendar.startOfDay(for: settled))

        let settledPresentation = TemporalHistoryDayPresentation(
            settledDay: live,
            liveDay: nil,
            calendar: calendar
        )
        XCTAssertEqual(settledPresentation.visualDay, calendar.startOfDay(for: live))
        XCTAssertEqual(settledPresentation.settledDay, calendar.startOfDay(for: live))
    }

    func testMidnightMarkerUsesLocaleAwareTimeAndMirrorsLabelPlacement() throws {
        let calendar = try londonCalendar()
        let midnight = try date(2026, 7, 22, 0, calendar: calendar)
        let british = TemporalMidnightMarkerText(
            date: midnight,
            context: TemporalFormattingContext(
                locale: Locale(identifier: "en_GB"),
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        )
        let american = TemporalMidnightMarkerText(
            date: midnight,
            context: TemporalFormattingContext(
                locale: Locale(identifier: "en_US"),
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        )

        XCTAssertTrue(british.localTime.hasSuffix(":00"))
        XCTAssertFalse(british.localTime.localizedCaseInsensitiveContains("AM"))
        XCTAssertTrue(american.localTime.contains("12"))
        XCTAssertTrue(american.localTime.localizedCaseInsensitiveContains("AM"))
        XCTAssertEqual(
            TemporalMidnightMarkerLayout.labelCenterX(
                markerX: 100,
                labelWidth: 128,
                availableWidth: 600,
                layoutDirection: .leftToRight
            ),
            164
        )
        XCTAssertEqual(
            TemporalMidnightMarkerLayout.labelCenterX(
                markerX: 100,
                labelWidth: 128,
                availableWidth: 600,
                layoutDirection: .rightToLeft
            ),
            64
        )
    }

    @MainActor
    func testCoupledPresentationPublishesLiveDayOnlyAtASeamAndClearsAtSettlement() throws {
        let calendar = try londonCalendar()
        let leading = try date(2026, 12, 31, 0, calendar: calendar)
        let trailing = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: leading,
                direction: 1,
                calendar: calendar
            )
        )
        let presentation = TemporalCoupledScrollPresentation()

        presentation.handle(.preview(.init(
            leadingDay: leading,
            trailingDay: trailing,
            fraction: 0.4999,
            lowerPageStride: 320
        )))
        XCTAssertEqual(presentation.liveCenteredDay, leading)
        presentation.handle(.preview(.init(
            leadingDay: leading,
            trailingDay: trailing,
            fraction: 0.5,
            lowerPageStride: 320
        )))
        XCTAssertEqual(presentation.liveCenteredDay, trailing)
        presentation.handle(.preview(.init(
            leadingDay: leading,
            trailingDay: trailing,
            fraction: 0.4999,
            lowerPageStride: 320
        )))
        XCTAssertEqual(presentation.liveCenteredDay, leading)

        presentation.handle(.end)
        XCTAssertNil(presentation.preview)
        XCTAssertNil(presentation.liveCenteredDay)
    }

    func testCalendarDayWindowOwnsItsLeadingMidnightMarkerExactlyOnce() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 3, 29, 12, calendar: calendar)
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: day, calendar: calendar)
        )

        XCTAssertEqual(window.midnightMarkers, [window.interval.start])
        XCTAssertTrue(try window.contains(XCTUnwrap(window.midnightMarkers.first)))
        XCTAssertFalse(window.contains(window.interval.end))
    }

    func testDaySpaceProgressPreservesCalendarNeighboursAcrossBoundariesAndDST() throws {
        let calendar = try londonCalendar()
        let pairs = try [
            (
                date(2026, 12, 31, 0, calendar: calendar),
                date(2027, 1, 1, 0, calendar: calendar)
            ),
            (
                date(2028, 2, 28, 0, calendar: calendar),
                date(2028, 2, 29, 0, calendar: calendar)
            ),
            (
                date(2026, 3, 29, 0, calendar: calendar),
                date(2026, 3, 30, 0, calendar: calendar)
            ),
            (
                date(2026, 10, 25, 0, calendar: calendar),
                date(2026, 10, 26, 0, calendar: calendar)
            ),
        ]
        for (leading, trailing) in pairs {
            let progress = TemporalDaySpaceProgress(
                leadingDay: leading,
                trailingDay: trailing,
                fraction: 0.5,
                lowerPageStride: 320
            )
            XCTAssertTrue(
                progress.isValid(
                    in: [leading, trailing],
                    maximumDate: trailing,
                    calendar: calendar
                )
            )
        }
        XCTAssertEqual(pairs[2].1.timeIntervalSince(pairs[2].0), 23 * 60 * 60)
        XCTAssertEqual(pairs[3].1.timeIntervalSince(pairs[3].0), 25 * 60 * 60)
    }

    func testCoupledCoordinatorEnforcesExclusiveOwnershipAndRejectsStalePreview() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let buffer = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 2
        )
        let progress = TemporalDaySpaceProgress(
            leadingDay: buffer.days[1],
            trailingDay: buffer.days[2],
            fraction: 0.3,
            lowerPageStride: 330
        )
        var coordinator = TemporalCoupledScrollCoordinator()
        let epoch = try XCTUnwrap(coordinator.begin(.lowerUserDriven))

        XCTAssertNil(coordinator.begin(.upperUserDriven))
        XCTAssertTrue(
            coordinator.publish(
                progress,
                epoch: epoch,
                days: buffer.days,
                maximumDate: today,
                calendar: calendar
            )
        )
        XCTAssertEqual(coordinator.preview, progress)
        XCTAssertNotNil(coordinator.begin(.lowerDecelerating))
        coordinator.settle()
        XCTAssertNil(coordinator.preview)
        XCTAssertEqual(coordinator.owner, .settled)
        XCTAssertFalse(
            coordinator.publish(
                progress,
                epoch: epoch,
                days: buffer.days,
                maximumDate: today,
                calendar: calendar
            )
        )
    }

    func testCoupledCoordinatorRebasePreservesPreviewAndRejectsFutureOrOutOfBuffer() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        var buffer = TemporalDayBuffer(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            radius: 3
        )
        let progress = TemporalDaySpaceProgress(
            leadingDay: buffer.days[1],
            trailingDay: buffer.days[2],
            fraction: 0.65,
            lowerPageStride: 330
        )
        var coordinator = TemporalCoupledScrollCoordinator()
        let epoch = try XCTUnwrap(coordinator.begin(.lowerUserDriven))
        XCTAssertTrue(
            coordinator.publish(
                progress,
                epoch: epoch,
                days: buffer.days,
                maximumDate: today,
                calendar: calendar
            )
        )
        try buffer.ensureCoverage(
            around: XCTUnwrap(buffer.days.first),
            maximumDate: today,
            calendar: calendar,
            edgeThreshold: 1,
            expansion: 4
        )
        XCTAssertTrue(
            coordinator.rebase(
                days: buffer.days,
                maximumDate: today,
                calendar: calendar
            )
        )
        XCTAssertEqual(coordinator.preview, progress)

        let future = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        let invalid = TemporalDaySpaceProgress(
            leadingDay: calendar.startOfDay(for: today),
            trailingDay: calendar.startOfDay(for: future),
            fraction: 0.2,
            lowerPageStride: 330
        )
        XCTAssertFalse(
            coordinator.publish(
                invalid,
                epoch: epoch,
                days: buffer.days,
                maximumDate: today,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            coordinator.rebase(
                days: Array(buffer.days.suffix(2)),
                maximumDate: today,
                calendar: calendar
            )
        )
        XCTAssertEqual(coordinator.owner, .settled)
    }

    func testCoupledCoordinatorInterruptionsEndPreviewDeterministically() {
        var coordinator = TemporalCoupledScrollCoordinator()
        XCTAssertNotNil(coordinator.begin(.lowerUserDriven))
        coordinator.interrupt()
        XCTAssertEqual(coordinator.owner, .settled)
        XCTAssertNil(coordinator.preview)
        XCTAssertNotNil(coordinator.begin(.upperUserDriven))
        coordinator.interrupt()
        XCTAssertEqual(coordinator.owner, .settled)
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

    func testShortIntervalGeometryDoesNotOverrunItsTemporalWidth() {
        XCTAssertEqual(
            TemporalRibbonGeometry.intervalCornerRadius(
                visibleWidth: 12,
                preferredRadius: 20
            ),
            6
        )
        XCTAssertEqual(
            TemporalRibbonGeometry.intervalCornerRadius(
                visibleWidth: 80,
                preferredRadius: 20
            ),
            20
        )
    }

    func testRailSettlementUsesNearestVisualCentreAndDeterministicTieBreak() throws {
        let calendar = try londonCalendar()
        let first = try date(2026, 7, 22, 0, calendar: calendar)
        let second = try date(2026, 7, 23, 0, calendar: calendar)
        let third = try date(2026, 7, 24, 0, calendar: calendar)
        let days = [first, second, third]
        XCTAssertEqual(
            TemporalHistoryPresentation.settledRailDay(
                chipMidpoints: [first: 20, second: 100, third: 180],
                viewportMidpoint: 110,
                availableDays: days,
                maximumDate: third,
                calendar: calendar
            ),
            second
        )
        // Visual coordinates are authoritative, so the same result applies to
        // an RTL rail whose chronological order is mirrored.
        XCTAssertEqual(
            TemporalHistoryPresentation.settledRailDay(
                chipMidpoints: [first: 180, second: 100, third: 20],
                viewportMidpoint: 110,
                availableDays: days,
                maximumDate: third,
                calendar: calendar
            ),
            second
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.settledRailDay(
                chipMidpoints: [first: 50, second: 150],
                viewportMidpoint: 100,
                availableDays: [first, second],
                maximumDate: second,
                calendar: calendar
            ),
            second
        )
    }

    func testTodayEntryEligibilityFutureShadingAndTwoHourRulesUseCalendar() throws {
        let calendar = try londonCalendar()
        let now = try date(2026, 3, 29, 10, 30, calendar: calendar)
        XCTAssertTrue(
            TemporalHistoryPresentation.allowsHistoricalEntry(at: now, now: now, calendar: calendar)
        )
        XCTAssertTrue(
            TemporalHistoryPresentation.allowsHistoricalEntry(
                at: now.addingTimeInterval(-1), now: now, calendar: calendar
            )
        )
        XCTAssertFalse(
            TemporalHistoryPresentation.allowsHistoricalEntry(
                at: now.addingTimeInterval(1), now: now, calendar: calendar
            )
        )
        let today = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: now, calendar: calendar)
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.futureShadingInterval(for: today, now: now, calendar: calendar)?.start,
            now
        )
        let future = try date(2026, 3, 30, 12, calendar: calendar)
        let futureWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: future, calendar: calendar)
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.futureShadingInterval(
                for: futureWindow, now: now, calendar: calendar
            ),
            futureWindow.interval
        )
        let markers = TemporalHistoryPresentation.twoHourMarkers(in: today, calendar: calendar)
        XCTAssertFalse(markers.contains { calendar.component(.hour, from: $0) == 1 })
        XCTAssertTrue(markers.contains { calendar.component(.hour, from: $0) == 2 })
        XCTAssertEqual(Set(markers).count, markers.count)
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
