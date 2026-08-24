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

    func testPageGeometryUsesHalfOpenIntersectionAndOriginalBoundaries() throws {
        let calendar = try londonCalendar()
        let day = try date(2026, 7, 22, 12, calendar: calendar)
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: day, calendar: calendar)
        )
        let before = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000021")),
            start: date(2026, 7, 21, 20, calendar: calendar),
            end: window.interval.start
        )
        let crossing = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000022")),
            start: date(2026, 7, 21, 19, calendar: calendar),
            end: date(2026, 7, 23, 2, calendar: calendar)
        )
        let touchingStart = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000023")),
            start: window.interval.start,
            end: date(2026, 7, 22, 4, calendar: calendar)
        )
        let touchingEnd = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000024")),
            start: date(2026, 7, 22, 20, calendar: calendar),
            end: window.interval.end
        )
        let after = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000025")),
            start: window.interval.end,
            end: date(2026, 7, 23, 4, calendar: calendar)
        )

        let clipped = TemporalHistoryPresentation.clip(
            [before, crossing, touchingStart, touchingEnd, after],
            to: window
        )

        XCTAssertEqual(
            Set(clipped.map(\.id)),
            Set([crossing.id, touchingStart.id, touchingEnd.id])
        )
        let crossingSegment = try XCTUnwrap(clipped.first { $0.id == crossing.id })
        XCTAssertEqual(crossingSegment.visibleStart, window.interval.start)
        XCTAssertEqual(crossingSegment.visibleEnd, window.interval.end)
        XCTAssertTrue(crossingSegment.continuesBefore)
        XCTAssertTrue(crossingSegment.continuesAfter)
        let touchingStartSegment = try XCTUnwrap(clipped.first { $0.id == touchingStart.id })
        XCTAssertEqual(touchingStartSegment.visibleStart, window.interval.start)
        XCTAssertFalse(touchingStartSegment.continuesBefore)
        XCTAssertFalse(touchingStartSegment.continuesAfter)
        let touchingEndSegment = try XCTUnwrap(clipped.first { $0.id == touchingEnd.id })
        XCTAssertEqual(touchingEndSegment.visibleEnd, window.interval.end)
        XCTAssertFalse(touchingEndSegment.continuesBefore)
        XCTAssertFalse(touchingEndSegment.continuesAfter)
    }

    func testAdjacentPageFragmentsKeepIdentityLaneAndComplementaryContinuation() throws {
        let calendar = try londonCalendar()
        let firstDay = try date(2026, 7, 22, 12, calendar: calendar)
        let secondDay = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: firstDay,
                direction: 1,
                calendar: calendar
            )
        )
        let interval = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000026")),
            start: date(2026, 7, 22, 19, 6, calendar: calendar),
            end: date(2026, 7, 23, 13, 19, calendar: calendar)
        )
        let firstWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: firstDay, calendar: calendar)
        )
        let secondWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: secondDay, calendar: calendar)
        )
        let first = try XCTUnwrap(
            TemporalHistoryPresentation.pageGeometry(
                [interval],
                in: firstWindow,
                surfaceWidth: 320
            ).first
        )
        let second = try XCTUnwrap(
            TemporalHistoryPresentation.pageGeometry(
                [interval],
                in: secondWindow,
                surfaceWidth: 320
            ).first
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.lane, second.lane)
        XCTAssertTrue(first.continuesAfter)
        XCTAssertFalse(first.continuesBefore)
        XCTAssertTrue(second.continuesBefore)
        XCTAssertFalse(second.continuesAfter)
        XCTAssertEqual(first.segment.visibleEnd, second.segment.visibleStart)
        XCTAssertEqual(first.segment.visibleEnd, secondWindow.interval.start)
        XCTAssertEqual(second.segment.visibleStart, secondWindow.interval.start)
    }

    func testPageGeometryClipsFiniteFragmentsToThePageBounds() throws {
        let calendar = try londonCalendar()
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(
                containing: date(2026, 7, 22, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let valid = TemporalIntervalInput(
            id: UUID(),
            start: .distantPast,
            end: .distantFuture
        )
        let invalid = TemporalIntervalInput(
            id: UUID(),
            start: Date(timeIntervalSinceReferenceDate: .nan),
            end: Date(timeIntervalSinceReferenceDate: .infinity)
        )

        let geometry = try XCTUnwrap(
            TemporalHistoryPresentation.pageGeometry(
                [valid, invalid],
                in: window,
                surfaceWidth: 320
            ).first
        )
        XCTAssertTrue(geometry.startX.isFinite)
        XCTAssertTrue(geometry.endX.isFinite)
        XCTAssertTrue(geometry.visualStartX.isFinite)
        XCTAssertTrue(geometry.visualWidth.isFinite)
        XCTAssertTrue(geometry.leadingHitPadding.isFinite)
        XCTAssertTrue(geometry.trailingHitPadding.isFinite)
        XCTAssertGreaterThanOrEqual(geometry.startX, 0)
        XCTAssertLessThanOrEqual(geometry.endX, 320)
        XCTAssertGreaterThanOrEqual(geometry.visualStartX, 0)
        XCTAssertLessThanOrEqual(geometry.visualStartX + geometry.visualWidth, 320)
        XCTAssertTrue(
            TemporalHistoryPresentation.pageGeometry(
                [valid],
                in: window,
                surfaceWidth: .nan
            ).isEmpty
        )
    }

    func testPageGeometryTransfersUnavailableEdgeHitPaddingInward() throws {
        let calendar = try londonCalendar()
        let window = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(
                containing: date(2026, 7, 22, 12, calendar: calendar),
                calendar: calendar
            )
        )
        let leadingEdge = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000028")),
            start: window.interval.start,
            end: window.interval.start.addingTimeInterval(1)
        )
        let trailingEdge = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000029")),
            start: window.interval.end.addingTimeInterval(-1),
            end: window.interval.end
        )

        let geometry = TemporalHistoryPresentation.pageGeometry(
            [leadingEdge, trailingEdge],
            in: window,
            surfaceWidth: 320
        )
        let leading = try XCTUnwrap(geometry.first { $0.id == leadingEdge.id })
        let trailing = try XCTUnwrap(geometry.first { $0.id == trailingEdge.id })

        XCTAssertEqual(leading.leadingHitPadding, 0)
        XCTAssertEqual(
            leading.visualWidth + leading.leadingHitPadding + leading.trailingHitPadding,
            44,
            accuracy: 0.000_001
        )
        XCTAssertEqual(trailing.trailingHitPadding, 0)
        XCTAssertEqual(
            trailing.visualWidth + trailing.leadingHitPadding + trailing.trailingHitPadding,
            44,
            accuracy: 0.000_001
        )
    }

    func testLondonMidnightScreenshotFixtureUsesTheSameAbsoluteInterval() throws {
        let calendar = try londonCalendar()
        let previousDay = try date(2026, 7, 21, 12, calendar: calendar)
        let currentDay = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: previousDay,
                direction: 1,
                calendar: calendar
            )
        )
        let nextDay = try XCTUnwrap(
            TemporalHistoryPresentation.adjacentDay(
                to: currentDay,
                direction: 1,
                calendar: calendar
            )
        )
        let interval = try TemporalIntervalInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000027")),
            start: date(2026, 7, 21, 19, 6, calendar: calendar),
            end: date(2026, 7, 22, 13, 19, calendar: calendar)
        )
        let previousWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: previousDay, calendar: calendar)
        )
        let currentWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: currentDay, calendar: calendar)
        )
        let nextWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: nextDay, calendar: calendar)
        )
        let previous = try XCTUnwrap(
            TemporalHistoryPresentation.pageGeometry(
                [interval],
                in: previousWindow,
                surfaceWidth: 320
            ).first
        )
        let current = try XCTUnwrap(
            TemporalHistoryPresentation.pageGeometry(
                [interval],
                in: currentWindow,
                surfaceWidth: 320
            ).first
        )

        XCTAssertEqual(previous.id, current.id)
        XCTAssertEqual(previous.segment.originalStart, interval.start)
        XCTAssertEqual(current.segment.originalEnd, interval.end)
        XCTAssertTrue(previous.continuesAfter)
        XCTAssertTrue(current.continuesBefore)
        XCTAssertFalse(current.continuesAfter)
        XCTAssertTrue(
            TemporalHistoryPresentation.pageGeometry(
                [interval],
                in: nextWindow,
                surfaceWidth: 320
            ).isEmpty
        )
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
        XCTAssertTrue(TemporalCarouselMovementPhase.settled.showsFutureReadOnlyAppearance)

        for phase in [
            TemporalCarouselMovementPhase.userDriven,
            .decelerating,
            .aligning,
            .programmatic,
        ] {
            XCTAssertTrue(phase.suppressesAutomaticAlignment)
            XCTAssertFalse(phase.allowsTimelineInteraction)
            XCTAssertFalse(phase.showsTimelineDetails)
            XCTAssertFalse(phase.showsFutureReadOnlyAppearance)
        }
    }

    @MainActor
    func testCarouselDoesNotRepublishEquivalentMotionAtFingerLift() {
        XCTAssertFalse(TemporalCarouselMovementPhase.userDriven
            .requiresPresentationUpdate(to: .decelerating))
        XCTAssertFalse(TemporalCarouselMovementPhase.decelerating
            .requiresPresentationUpdate(to: .aligning))
        XCTAssertTrue(TemporalCarouselMovementPhase.userDriven
            .requiresPresentationUpdate(to: .settled))
        XCTAssertTrue(TemporalCarouselMovementPhase.settled
            .requiresPresentationUpdate(to: .programmatic))
    }

    @MainActor
    func testFutureAdjacentMotionKeepsTimelineAppearanceWhileActionsStayGated() {
        let moving = TemporalHistoryCarousel.timelineInteractionState(
            movementPhase: .decelerating,
            allowsRecordActivation: false,
            allowsEmptySelection: false
        )
        XCTAssertTrue(moving.isVisuallyEnabled)
        XCTAssertFalse(moving.allowsRecordActivation)
        XCTAssertFalse(moving.allowsEmptySelection)

        let settledFuture = TemporalHistoryCarousel.timelineInteractionState(
            movementPhase: .settled,
            allowsRecordActivation: false,
            allowsEmptySelection: false
        )
        XCTAssertFalse(settledFuture.isVisuallyEnabled)
        XCTAssertFalse(settledFuture.allowsRecordActivation)
        XCTAssertFalse(settledFuture.allowsEmptySelection)
    }

    @MainActor
    func testFutureShadingInputRemainsAvailableDuringAdjacentDayMotion() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let carousel = TemporalHistoryCarousel(
            dates: [],
            selection: .constant(now),
            intervals: [],
            events: [],
            motionIntervals: [],
            motionEvents: [],
            onSelectInterval: { _ in },
            onSelectEvent: { _ in },
            onSelectEmpty: { _ in },
            onNavigateDay: { _ in },
            canNavigateForward: true,
            allowsRecordActivation: false,
            allowsEmptySelection: false,
            showsTimelineDetails: false,
            readOnlyFromDate: now,
            onMovementPhaseChange: { _ in },
            onCoupledPresentationChange: { _ in }
        )
        carousel.movementPhase = .decelerating

        XCTAssertEqual(carousel.futureReadOnlyFromDate, now)
    }

    func testFlushPageGeometryUsesOneContainerWidthPerCalendarDay() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let days = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 3)
        ).days(calendar: calendar)
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
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 6)
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
                availableDays: coverage.days(calendar: calendar),
                maximumDate: today,
                calendar: calendar
            ),
            slowTarget
        )
        XCTAssertEqual(
            TemporalHistoryPresentation.settledCarouselDay(
                centeredPage: fastTarget,
                currentSelection: today,
                availableDays: coverage.days(calendar: calendar),
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
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 2)
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
                    availableDays: coverage.days(calendar: calendar),
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
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 5)
        )

        XCTAssertEqual(coverage.days(calendar: calendar).count, 10)
        XCTAssertEqual(coverage.days(calendar: calendar).last, calendar.startOfDay(for: today))
        XCTAssertTrue(coverage.days(calendar: calendar).contains(calendar.startOfDay(for: selected)))
        XCTAssertEqual(
            coverage.days(calendar: calendar)[6].timeIntervalSince(coverage.days(calendar: calendar)[5]),
            23 * 60 * 60
        )
    }

    func testDayBufferCentersTodayWithinBoundedFutureCalendarDays() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 3, 29, 12, calendar: calendar)
        let maximumDisplayDay = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 400, to: today)
        )
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: maximumDisplayDay,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 400)
        )
        let todayDay = calendar.startOfDay(for: today)

        XCTAssertEqual(coverage.days(calendar: calendar).count, 801)
        XCTAssertEqual(coverage.days(calendar: calendar)[400], todayDay)
        XCTAssertEqual(
            coverage.days(calendar: calendar).last,
            calendar.startOfDay(for: maximumDisplayDay)
        )
        XCTAssertEqual(
            coverage.days(calendar: calendar)[401].timeIntervalSince(coverage.days(calendar: calendar)[400]),
            23 * 60 * 60
        )
    }

    func testDayBufferExpandsWithoutChangingExistingDayIdentityOrOrder() throws {
        let calendar = try londonCalendar()
        let today = try date(2027, 1, 15, 12, calendar: calendar)
        let selected = try date(2027, 1, 1, 12, calendar: calendar)
        var coverage = HistoryMotionCoverage.initial(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 4, extensionLength: 3)
        )
        let original = coverage.days(calendar: calendar)

        coverage = try XCTUnwrap(
            coverage.extended(
                toward: .preceding,
                maximumDate: today,
                calendar: calendar,
                configuration: HistoryMotionConfiguration(initialRadius: 4, extensionLength: 3)
            )
        )

        XCTAssertEqual(Array(coverage.days(calendar: calendar).dropFirst(3).prefix(original.count)), original)
        XCTAssertEqual(coverage.days(calendar: calendar), coverage.days(calendar: calendar).sorted())
        XCTAssertEqual(Set(coverage.days(calendar: calendar)).count, coverage.days(calendar: calendar).count)
    }

    func testDayBufferExpandsForwardOnlyThroughMaximumDay() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 11, 3, 12, calendar: calendar)
        let selected = try date(2026, 10, 25, 12, calendar: calendar)
        var coverage = HistoryMotionCoverage.initial(
            centeredOn: selected,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 2, extensionLength: 30)
        )

        coverage = try XCTUnwrap(
            coverage.extended(
                toward: .following,
                maximumDate: today,
                calendar: calendar,
                configuration: HistoryMotionConfiguration(initialRadius: 2, extensionLength: 30)
            )
        )

        XCTAssertEqual(coverage.days(calendar: calendar).last, calendar.startOfDay(for: today))
        XCTAssertFalse(coverage.days(calendar: calendar).contains {
            $0 > calendar.startOfDay(for: today)
        })
    }

    func testDayBufferRecentresForLongDistanceDatePickerJump() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let distant = try date(2021, 2, 14, 12, calendar: calendar)

        let coverage = HistoryMotionCoverage.initial(
            centeredOn: distant,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 8)
        )

        XCTAssertTrue(coverage.days(calendar: calendar).contains(calendar.startOfDay(for: distant)))
        XCTAssertEqual(coverage.days(calendar: calendar).count, 17)
        XCTAssertFalse(coverage.days(calendar: calendar).contains(calendar.startOfDay(for: today)))
    }

    func testDaySpaceProgressMapsForwardBackwardReversalAndMultipleDays() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        let days = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 5)
        ).days(calendar: calendar)
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
        let days = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 3)
        ).days(calendar: calendar)
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
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 2)
        )
        let progress = TemporalDaySpaceProgress(
            leadingDay: coverage.days(calendar: calendar)[1],
            trailingDay: coverage.days(calendar: calendar)[2],
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
                days: coverage.days(calendar: calendar),
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
                days: coverage.days(calendar: calendar),
                maximumDate: today,
                calendar: calendar
            )
        )
    }

    func testCoupledCoordinatorRebasePreservesPreviewAndRejectsFutureOrOutOfBuffer() throws {
        let calendar = try londonCalendar()
        let today = try date(2026, 7, 23, 12, calendar: calendar)
        var coverage = HistoryMotionCoverage.initial(
            centeredOn: today,
            maximumDate: today,
            calendar: calendar,
            configuration: HistoryMotionConfiguration(initialRadius: 3, extensionLength: 4)
        )
        let progress = TemporalDaySpaceProgress(
            leadingDay: coverage.days(calendar: calendar)[1],
            trailingDay: coverage.days(calendar: calendar)[2],
            fraction: 0.65,
            lowerPageStride: 330
        )
        var coordinator = TemporalCoupledScrollCoordinator()
        let epoch = try XCTUnwrap(coordinator.begin(.lowerUserDriven))
        XCTAssertTrue(
            coordinator.publish(
                progress,
                epoch: epoch,
                days: coverage.days(calendar: calendar),
                maximumDate: today,
                calendar: calendar
            )
        )
        coverage = try XCTUnwrap(
            coverage.extended(
                toward: .preceding,
                maximumDate: today,
                calendar: calendar,
                configuration: HistoryMotionConfiguration(initialRadius: 3, extensionLength: 4)
            )
        )
        XCTAssertTrue(
            coordinator.rebase(
                days: coverage.days(calendar: calendar),
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
                days: coverage.days(calendar: calendar),
                maximumDate: today,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            coordinator.rebase(
                days: Array(coverage.days(calendar: calendar).suffix(2)),
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
