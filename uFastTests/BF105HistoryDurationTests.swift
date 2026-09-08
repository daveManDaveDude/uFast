import Foundation
@testable import uFast
import XCTest

@MainActor
final class BF105HistoryDurationTests: XCTestCase {
    func testCurrentDurationUsesCompletedSecondsAndNeverRoundsFutureOrNegativeTime() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let spec = HistoryDurationSpec.current(
            startDate: start,
            capDate: start.addingTimeInterval(4 * 60 * 60)
        )

        XCTAssertEqual(spec.completedSeconds(at: start.addingTimeInterval(-1)), 0)
        XCTAssertEqual(spec.completedSeconds(at: start.addingTimeInterval(3661.9)), 3661)
        XCTAssertEqual(spec.completedSeconds(at: start.addingTimeInterval(5 * 60 * 60)), 4 * 60 * 60)
    }

    func testOnlyCurrentDurationSpecsObserveTheInjectedClock() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let completed = HistoryDurationSpec.completed(
            startDate: start,
            endDate: start.addingTimeInterval(90)
        )
        let current = HistoryDurationSpec.current(startDate: start)

        XCTAssertFalse(completed.observesClock)
        XCTAssertTrue(current.observesClock)
        XCTAssertEqual(
            completed.value(at: start),
            completed.value(at: start.addingTimeInterval(3600))
        )
    }

    func testCompletedDurationIsStaticAcrossClockAndDSTUsesAbsoluteElapsedTime() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 24, hour: 12)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)
        ))
        let spec = HistoryDurationSpec.completed(startDate: start, endDate: end)

        XCTAssertEqual(spec.completedSeconds(at: end.addingTimeInterval(9999)), 25 * 60 * 60)
        XCTAssertEqual(
            HistoryTextFormatting.compactDuration(
                spec, at: start, resolver: AppTextResolver()
            ),
            "1 d 1 h"
        )
    }

    func testCompletedCompactDurationFloorsToWholeLocalizedMinutes() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let spec = HistoryDurationSpec.completed(
            startDate: start,
            endDate: start.addingTimeInterval(21 * 60 * 60 + 13 * 60 + 59)
        )

        XCTAssertEqual(
            HistoryTextFormatting.compactDuration(
                spec,
                at: start.addingTimeInterval(90 * 60 * 60),
                resolver: AppTextResolver()
            ),
            "21 h 13 min"
        )
        XCTAssertEqual(
            HistoryTextFormatting.compactDuration(
                .completed(startDate: start, endDate: start.addingTimeInterval(59)),
                at: start.addingTimeInterval(1),
                resolver: AppTextResolver()
            ),
            "Less than 1 minute"
        )
    }

    func testCompletedMultiDayTemplateMatchesRenderedSpacing() {
        XCTAssertEqual(
            HistoryTextFormatting.compactCompletedTemplate(
                dayDigits: 2,
                resolver: AppTextResolver()
            ),
            "88 d 88 h 88 min"
        )
    }

    func testDurationValueUsesAbsoluteSecondsAcrossBothLondonDSTTransitions() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let springStart = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 28, hour: 12)
        ))
        let springEnd = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 29, hour: 12)
        ))
        XCTAssertEqual(
            HistoryDurationSpec.completed(startDate: springStart, endDate: springEnd)
                .value(at: springEnd),
            HistoryDurationValue(totalSeconds: 23 * 60 * 60)
        )

        let autumnStart = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 24, hour: 12)
        ))
        let autumnEnd = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)
        ))
        XCTAssertEqual(
            HistoryDurationSpec.completed(startDate: autumnStart, endDate: autumnEnd)
                .value(at: autumnEnd),
            HistoryDurationValue(totalSeconds: 25 * 60 * 60)
        )
    }

    func testCurrentFormatAndLocalizedTemplateBoundaries() {
        let resolver = AppTextResolver()
        XCTAssertEqual(
            HistoryTextFormatting.compactDuration(
                .current(startDate: .init(timeIntervalSince1970: 0)),
                at: Date(timeIntervalSince1970: 86399),
                resolver: resolver
            ),
            "23:59:59"
        )
        XCTAssertEqual(
            HistoryTextFormatting.compactDuration(
                .current(startDate: .init(timeIntervalSince1970: 0)),
                at: Date(timeIntervalSince1970: 86400),
                resolver: resolver
            ),
            "1d 00:00:00"
        )
        XCTAssertEqual(HistoryTextFormatting.activeTemplate(dayDigits: 2, resolver: resolver), "88d 88:88:88")
        XCTAssertEqual(HistoryTextFormatting.activeTemplate(dayDigits: 3, resolver: resolver), "888d 88:88:88")
    }

    func testOneSharedCadenceCoalescesDelayedPulsesAndStopsAndResumes() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = MutableAppClock(now: start)
        let driver = ManualHistoryDurationCadence()
        let pulse = HistoryDurationPulse(clock: clock, driver: driver)

        pulse.start()
        clock.advance(by: 7)
        driver.emitPulse()
        XCTAssertEqual(pulse.now, start.addingTimeInterval(7))
        XCTAssertEqual(pulse.pulseCount, 1)
        driver.emitPulse()
        XCTAssertEqual(pulse.pulseCount, 1)

        pulse.stop()
        clock.advance(by: 2)
        driver.emitPulse()
        XCTAssertEqual(pulse.pulseCount, 1)

        pulse.start()
        clock.advance(by: 1)
        driver.emitPulse()
        XCTAssertEqual(pulse.now, start.addingTimeInterval(10))
        XCTAssertEqual(pulse.pulseCount, 2)
    }

    func testCapDeadlineIsOneShotAndCannotRearmAfterFiring() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = MutableAppClock(now: start)
        let cadence = ManualHistoryDurationCadence()
        let deadline = ManualHistoryDurationDeadline()
        let pulse = HistoryDurationPulse(
            clock: clock,
            driver: cadence,
            deadlineDriver: deadline
        )
        let cap = start.addingTimeInterval(3)

        pulse.start()
        pulse.armCapDeadline(at: cap)
        pulse.advanceTestClock(by: 4)
        XCTAssertEqual(pulse.capDeadlineGeneration, 1)

        pulse.armCapDeadline(at: cap)
        pulse.advanceTestClock(by: 4)
        XCTAssertEqual(pulse.capDeadlineGeneration, 1)

        pulse.stop()
        pulse.start()
        pulse.armCapDeadline(at: cap)
        XCTAssertEqual(pulse.capDeadlineGeneration, 1)
    }

    func testCapDeadlineRefreshesCachedPulseBeforeReclassificationAndRemainsOneShot() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = FastingGoal.default
        let cap = start.addingTimeInterval(InferredFastProjector.maximumDuration(for: goal))
        let clock = MutableAppClock(now: start)
        let cadence = ManualHistoryDurationCadence()
        let deadline = ManualHistoryDurationDeadline()
        let pulse = HistoryDurationPulse(
            clock: clock,
            driver: cadence,
            deadlineDriver: deadline
        )
        let current = HistoryVisibleFastItem.inferred(InferredFastInterval(
            sourceBoundaryReference: .init(kind: .food, id: UUID()),
            sourceDate: start,
            sourceDescription: "Dinner",
            nextBoundaryReference: nil,
            nextBoundaryDate: nil,
            startDate: start,
            endDate: cap,
            goal: goal,
            state: .inProgress
        ))

        pulse.start()
        pulse.armCapDeadline(at: cap)
        clock.advance(by: cap.timeIntervalSince(start) + 1)
        XCTAssertEqual(pulse.now, start)

        // Fire the deadline without delivering the ordinary cadence pulse.
        deadline.advance(to: clock.now)

        XCTAssertEqual(pulse.now, clock.now)
        let reclassified = current.reclassifiedIfCapped(at: pulse.now)
        XCTAssertEqual(reclassified.inferredInterval?.state, .historical)
        XCTAssertEqual(reclassified.endDate, cap)
        XCTAssertFalse(reclassified.inferredInterval?.offersStart ?? true)
        XCTAssertTrue(reclassified.inferredInterval?.offersSave ?? false)

        pulse.armCapDeadline(at: cap)
        clock.advance(by: 4)
        deadline.advance(to: clock.now)
        XCTAssertEqual(pulse.capDeadlineGeneration, 1)
    }
}

final class BF105DurationProjectionTests: XCTestCase {
    func testCompletedDurationFitPriorityAndFixedDescriptorFrameAcrossDigitBoundaries() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let duration = try HistoryDurationSpec.completed(
            startDate: start,
            endDate: XCTUnwrap(calendar.date(byAdding: .day, value: 100, to: start))
        )
        let input = try TemporalRibbonLabelInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000105")),
            start: start,
            end: end,
            kind: .active,
            title: "Active fast",
            glyphName: "moon.stars.fill",
            duration: duration
        )
        let metrics = TemporalRibbonLabelMetrics(
            title: "Active fast",
            glyphWidth: 16,
            textWidth: 40,
            durationTemplateWidths: [0: 58, 1: 70, 2: 78, 3: 90]
        )
        let project = { width in
            TemporalRibbonLabelProjector.project(
                [input], days: [start], contentWidth: width, calendar: calendar,
                metrics: ["Active fast": metrics]
            )
        }

        let descriptor = try XCTUnwrap(project(180).first)
        XCTAssertTrue(descriptor.showsText)
        XCTAssertTrue(descriptor.showsDuration)
        XCTAssertFalse(descriptor.duration?.isCurrent ?? true)
        XCTAssertEqual(descriptor.durationTemplateDayDigits, 3)
        XCTAssertEqual(
            descriptor.labelWidth,
            metrics.fullLabelWidth(durationWidth: 90),
            accuracy: 0.001
        )

        let unchanged = try XCTUnwrap(project(180).first)
        XCTAssertEqual(descriptor, unchanged)
        XCTAssertEqual(descriptor.projectedStartX, unchanged.projectedStartX, accuracy: 0.001)
        XCTAssertEqual(descriptor.labelCenterX, unchanged.labelCenterX, accuracy: 0.001)
    }

    func testFirstNonFittingDurationOmitsOnlyDurationBeforeGlyphFallback() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)))
        let input = try TemporalRibbonLabelInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000106")),
            start: start,
            end: XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start)),
            kind: .recorded,
            title: "Fast",
            glyphName: "moon.stars.fill",
            duration: .completed(
                startDate: start,
                endDate: XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
            )
        )
        let metrics = TemporalRibbonLabelMetrics(
            title: "Fast", glyphWidth: 16, textWidth: 20,
            durationTemplateWidths: [0: 80, 1: 90, 2: 100, 3: 110]
        )
        let descriptor = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [start], contentWidth: 70, calendar: calendar,
                metrics: ["Fast": metrics]
            ).first
        )
        XCTAssertFalse(descriptor.showsText)
        XCTAssertFalse(descriptor.showsDuration)
        XCTAssertTrue(descriptor.showsGlyph)

        let noDecorationDescriptor = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [start], contentWidth: 15, calendar: calendar,
                metrics: ["Fast": metrics]
            ).first
        )
        XCTAssertFalse(noDecorationDescriptor.showsText)
        XCTAssertFalse(noDecorationDescriptor.showsDuration)
        XCTAssertFalse(noDecorationDescriptor.showsGlyph)
        XCTAssertEqual(noDecorationDescriptor.labelWidth, 0, accuracy: 0.001)
    }

    func testDurationOnlyFitDropsGlyphAndUsesLargestSuccessiveTemplate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let input = try TemporalRibbonLabelInput(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000107")),
            start: start,
            end: end,
            kind: .active,
            title: "Active fast",
            glyphName: "moon.stars.fill",
            duration: .current(startDate: start)
        )
        let metrics = TemporalRibbonLabelMetrics(
            title: "Active fast",
            glyphWidth: 16,
            textWidth: 100,
            durationTemplateWidths: [0: 30, 1: 40, 2: 60]
        )

        let descriptor = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [start], contentWidth: 52, calendar: calendar,
                metrics: ["Active fast": metrics]
            ).first
        )
        XCTAssertFalse(descriptor.showsText)
        XCTAssertFalse(descriptor.showsGlyph)
        XCTAssertTrue(descriptor.showsDuration)
        XCTAssertEqual(descriptor.durationTemplateDayDigits, 1)
        XCTAssertEqual(try XCTUnwrap(descriptor.durationSlotWidth), 40, accuracy: 0.001)
        XCTAssertEqual(descriptor.labelWidth, 52, accuracy: 0.001)
    }

    func testDurationValueSelectsThreeAndFourDigitDayBoundariesWithoutCalendarMath() {
        XCTAssertEqual(HistoryDurationValue(totalSeconds: 99 * 24 * 60 * 60).dayDigits, 2)
        XCTAssertEqual(HistoryDurationValue(totalSeconds: 100 * 24 * 60 * 60).dayDigits, 3)
        XCTAssertEqual(HistoryDurationValue(totalSeconds: 999 * 24 * 60 * 60).dayDigits, 3)
        XCTAssertEqual(HistoryDurationValue(totalSeconds: 1000 * 24 * 60 * 60).dayDigits, 4)
    }
}
