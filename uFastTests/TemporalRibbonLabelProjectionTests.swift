import Foundation
@testable import uFast
import XCTest

// swiftformat:disable trailingCommas
// swiftlint:disable type_body_length large_tuple trailing_comma

final class TemporalRibbonLabelProjectionTests: XCTestCase {
    func testResolverUsesLocalCalendarMidnightRolesAndTerminalEnd() throws {
        let calendar = try londonCalendar()
        let first = date(2026, 8, 25, 0, calendar: calendar)
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: first))
        let third = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: second))
        let resolver = TemporalContinuousDaySpaceResolver(
            days: [first, second], contentWidth: 520, calendar: calendar
        )

        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: first, role: .start)), 0, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: second, role: .start)), 260, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: second, role: .end)), 260, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: third, role: .end)), 520, accuracy: 0.000_001)
        XCTAssertNil(resolver.coordinate(for: first, role: .end))
        XCTAssertNil(resolver.coordinate(for: third, role: .start))
    }

    func testResolverUsesActualLondonDSTDurationsAndMirrorsOnlyFinalCoordinate() throws {
        let calendar = try londonCalendar()
        let spring = date(2026, 3, 29, 0, calendar: calendar)
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: spring))
        let resolver = TemporalContinuousDaySpaceResolver(
            days: [spring], contentWidth: 250, calendar: calendar
        )
        let noon = date(2026, 3, 29, 12, calendar: calendar)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: noon, role: .start)), 250 * 11 / 23, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: spring, role: .start)), 0, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(resolver.coordinate(for: next, role: .end)), 250, accuracy: 0.000_001)
    }

    func testProjectorDeduplicatesFragmentsUsesSharedLaneAndCalmFitPolicy() throws {
        let calendar = try londonCalendar()
        let first = date(2026, 8, 25, 0, calendar: calendar)
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: first))
        let id = try XCTUnwrap(UUID(uuidString: "10400000-0000-0000-0000-000000000001"))
        let input = TemporalRibbonLabelInput(
            id: id,
            start: date(2026, 8, 25, 20, calendar: calendar),
            end: date(2026, 8, 26, 8, calendar: calendar),
            kind: .recorded,
            title: "Fast",
            glyphName: "moon.stars.fill"
        )
        let duplicate = TemporalRibbonLabelInput(
            id: id,
            start: input.start,
            end: input.end,
            kind: .recorded,
            title: "Fast",
            glyphName: "moon.stars.fill"
        )

        let labels = TemporalRibbonLabelProjector.project(
            [input, duplicate],
            days: [first, second],
            contentWidth: 520,
            calendar: calendar,
            metrics: ["Fast": TemporalRibbonLabelMetrics(title: "Fast", glyphWidth: 16, textWidth: 30)]
        )
        let label = try XCTUnwrap(labels.first)
        XCTAssertEqual(labels.count, 1)
        XCTAssertEqual(label.id, id)
        XCTAssertEqual(label.lane, 0)
        XCTAssertTrue(label.showsText)
        XCTAssertTrue(label.showsGlyph)
        XCTAssertEqual(label.labelCenterX, (label.projectedStartX + label.projectedEndX) / 2, accuracy: 0.000_001)
    }

    func testProjectorOmitsTextThenDecorationWhenBarIsTooNarrow() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let id = UUID()
        let input = TemporalRibbonLabelInput(
            id: id,
            start: date(2026, 8, 25, 1, calendar: calendar),
            end: date(2026, 8, 25, 1, 30, calendar: calendar),
            kind: .active,
            title: "Active fast",
            glyphName: "moon.stars.fill"
        )
        let labels = TemporalRibbonLabelProjector.project(
            [input],
            days: [day],
            contentWidth: 100,
            calendar: calendar,
            metrics: [
                "Active fast": TemporalRibbonLabelMetrics(
                    title: "Active fast", glyphWidth: 16, textWidth: 80
                )
            ]
        )
        let label = try XCTUnwrap(labels.first)
        XCTAssertFalse(label.showsText)
        XCTAssertFalse(label.showsGlyph)
        XCTAssertNil(label.title)
        XCTAssertNil(label.glyphName)
        XCTAssertEqual(label.labelWidth, 0)
    }

    func testProjectorKeepsUnknownGlyphWithoutFastingText() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let id = UUID()
        let input = TemporalRibbonLabelInput(
            id: id,
            start: date(2026, 8, 25, 8, calendar: calendar),
            end: date(2026, 8, 25, 16, calendar: calendar),
            kind: .unknown,
            title: "",
            glyphName: "questionmark.circle"
        )
        let labels = TemporalRibbonLabelProjector.project(
            [input],
            days: [day],
            contentWidth: 400,
            calendar: calendar,
            metrics: ["": TemporalRibbonLabelMetrics(title: "", glyphWidth: 16, textWidth: 0)]
        )
        let label = try XCTUnwrap(labels.first)
        XCTAssertEqual(label.id, id)
        XCTAssertFalse(label.showsText)
        XCTAssertTrue(label.showsGlyph)
        XCTAssertNil(label.title)
        XCTAssertEqual(label.glyphName, "questionmark.circle")
    }

    func testProjectorIsInvariantToPagePartitionAndRTLMirrorsCenter() throws {
        let calendar = try londonCalendar()
        let first = date(2026, 8, 25, 0, calendar: calendar)
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: first))
        let third = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: second))
        let start = date(2026, 8, 25, 20, calendar: calendar)
        let end = date(2026, 8, 26, 8, calendar: calendar)
        let input = TemporalRibbonLabelInput(
            id: UUID(), start: start, end: end, kind: .inferred,
            title: "Inferred fast", glyphName: "moon.fill"
        )
        let metrics = [
            "Inferred fast": TemporalRibbonLabelMetrics(
                title: "Inferred fast", glyphWidth: 16, textWidth: 80
            )
        ]
        let ltr = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [first, second, third], contentWidth: 780,
                calendar: calendar, metrics: metrics
            ).first
        )
        let rtl = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [first, second, third], contentWidth: 780,
                calendar: calendar, layoutDirection: .rightToLeft, metrics: metrics
            ).first
        )
        XCTAssertEqual(ltr.labelCenterX + rtl.labelCenterX, 780, accuracy: 0.000_001)
        XCTAssertEqual(
            abs(ltr.projectedEndX - ltr.projectedStartX),
            abs(rtl.projectedEndX - rtl.projectedStartX),
            accuracy: 0.000_001
        )
        XCTAssertEqual(ltr.lane, rtl.lane)
    }

    func testProjectorMapsEveryRibbonKindToItsExhaustiveVisualTreatment() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let start = date(2026, 8, 25, 4, calendar: calendar)
        let end = date(2026, 8, 25, 20, calendar: calendar)
        let values: [(TemporalRibbonIntervalItem.Kind, String?, String)] = [
            (.recorded, "Fast", "moon.stars.fill"),
            (.active, "Active fast", "moon.stars.fill"),
            (.automatic, "Inferred fast", "moon.fill"),
            (.inferred, "Inferred fast", "moon.fill"),
            (.previouslySaved, "Fast", "archivebox"),
            (.reconstructed, "Fast", "wand.and.stars"),
            (.needsReview, "Fast", "exclamationmark.triangle"),
            (.unknown, nil, "questionmark.circle")
        ]

        for (index, value) in values.enumerated() {
            let id = UUID()
            let input = TemporalRibbonLabelInput(
                id: id,
                start: start,
                end: end,
                kind: value.0,
                title: value.1 ?? "",
                glyphName: value.2
            )
            let title = value.1 ?? ""
            let label = try XCTUnwrap(
                TemporalRibbonLabelProjector.project(
                    [input],
                    days: [day],
                    contentWidth: 400,
                    calendar: calendar,
                    metrics: [title: .init(title: title, glyphWidth: 16, textWidth: 90)]
                ).first,
                "Missing label for kind index \(index)"
            )
            XCTAssertEqual(label.title, value.1)
            XCTAssertEqual(label.glyphName, value.2)
        }
    }

    func testResolverRejectsInvalidNonfiniteAndOutOfRunwayInputs() throws {
        let calendar = try londonCalendar()
        let first = date(2026, 8, 25, 0, calendar: calendar)
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: first))
        let resolver = TemporalContinuousDaySpaceResolver(
            days: [first, second], contentWidth: 520, calendar: calendar
        )
        let before = first.addingTimeInterval(-1)
        let terminal = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: second))
        let after = terminal.addingTimeInterval(1)
        let nonfinite = Date(timeIntervalSince1970: .nan)

        XCTAssertNil(resolver.coordinate(for: before, role: .start))
        XCTAssertNil(resolver.coordinate(for: after, role: .end))
        XCTAssertNil(resolver.coordinate(for: terminal, role: .start))
        XCTAssertNil(resolver.coordinate(for: nonfinite, role: .start))
        XCTAssertNil(
            TemporalContinuousDaySpaceResolver(
                days: [first], contentWidth: .nan, calendar: calendar
            ).coordinate(for: first, role: .start)
        )
        XCTAssertNil(
            TemporalContinuousDaySpaceResolver(
                days: [first, terminal], contentWidth: 520, calendar: calendar
            ).coordinate(for: first, role: .start)
        )
    }

    func testAutumnFallbackUsesActualLondonDayDuration() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 10, 25, 0, calendar: calendar)
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let resolver = TemporalContinuousDaySpaceResolver(
            days: [day], contentWidth: 270, calendar: calendar
        )

        XCTAssertEqual(
            try XCTUnwrap(resolver.coordinate(for: date(2026, 10, 25, 13, calendar: calendar), role: .start)),
            270 * 14 / 25,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(resolver.coordinate(for: next, role: .end)),
            270,
            accuracy: 0.000_001
        )
    }

    func testLabelLaneMatchesEveryArbitraryPagePartition() throws {
        let calendar = try londonCalendar()
        let first = date(2026, 8, 25, 0, calendar: calendar)
        let days = try (0 ..< 4).map {
            try XCTUnwrap(calendar.date(byAdding: .day, value: $0, to: first))
        }
        let id = UUID()
        let start = date(2026, 8, 25, 19, calendar: calendar)
        let end = date(2026, 8, 28, 5, calendar: calendar)
        let input = TemporalIntervalInput(id: id, start: start, end: end)
        let labelInput = TemporalRibbonLabelInput(
            id: id,
            start: start,
            end: end,
            kind: .recorded,
            title: "Fast",
            glyphName: "moon.stars.fill"
        )
        let descriptor = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [labelInput], days: days, contentWidth: 1040, calendar: calendar,
                metrics: ["Fast": .init(title: "Fast", glyphWidth: 16, textWidth: 30)]
            ).first
        )

        let partitions = [[0, 1], [2, 3], [1, 3], [0, 2, 3]]
        for partition in partitions {
            let fragments = partition.compactMap { index in
                TemporalHistoryPresentation.calendarDayWindow(
                    containing: days[index], calendar: calendar
                ).flatMap {
                    TemporalHistoryPresentation.pageGeometry([input], in: $0, surfaceWidth: 260).first
                }
            }
            XCTAssertFalse(fragments.isEmpty)
            XCTAssertTrue(fragments.allSatisfy { $0.id == descriptor.id && $0.lane == descriptor.lane })
        }
        XCTAssertEqual(
            descriptor.labelCenterX,
            (descriptor.projectedStartX + descriptor.projectedEndX) / 2,
            accuracy: 0.000_001
        )
    }

    func testVisualDescriptorsUseOneCompactSourceAcrossMovementPhases() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let start = date(2026, 8, 25, 20, calendar: calendar)
        let end = date(2026, 8, 26, 8, calendar: calendar)
        let id = UUID()
        let motion = TemporalRibbonLabelInput(
            id: id, start: start, end: end, kind: .active,
            title: "Active fast", glyphName: "moon.stars.fill"
        )
        let exact = TemporalRibbonLabelInput(
            id: id, start: start, end: end.addingTimeInterval(-60), kind: .active,
            title: "Active fast", glyphName: "moon.stars.fill"
        )
        let metrics: [String: TemporalRibbonLabelMetrics] = [
            "Active fast": .init(title: "Active fast", glyphWidth: 16, textWidth: 80)
        ]
        let baseline = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [motion], days: [day, day.addingTimeInterval(86400)], contentWidth: 520,
                calendar: calendar, metrics: metrics
            ).first
        )
        let phases: [TemporalCarouselMovementPhase] = [
            .userDriven, .decelerating, .aligning, .programmatic, .settled
        ]
        for phase in phases {
            _ = phase
            let visualSource = [motion]
            let visual = try XCTUnwrap(
                TemporalRibbonLabelProjector.project(
                    visualSource, days: [day, day.addingTimeInterval(86400)], contentWidth: 520,
                    calendar: calendar, metrics: metrics
                ).first
            )
            XCTAssertEqual(visual, baseline)
        }
        let exactDescriptor = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [exact], days: [day, day.addingTimeInterval(86400)], contentWidth: 520,
                calendar: calendar, metrics: metrics
            ).first
        )
        XCTAssertNotEqual(exactDescriptor.projectedEndX, baseline.projectedEndX)
    }

    // swiftlint:disable:next function_body_length
    func testOverlappingIntervalsUseExactSharedLaneOneVerticalContainment() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let firstID = try XCTUnwrap(UUID(uuidString: "10400000-0000-0000-0000-000000000021"))
        let secondID = try XCTUnwrap(UUID(uuidString: "10400000-0000-0000-0000-000000000022"))
        let first = TemporalRibbonLabelInput(
            id: firstID,
            start: date(2026, 8, 25, 2, calendar: calendar),
            end: date(2026, 8, 25, 18, calendar: calendar),
            kind: .recorded,
            title: "Fast",
            glyphName: "moon.stars.fill"
        )
        let second = TemporalRibbonLabelInput(
            id: secondID,
            start: date(2026, 8, 25, 4, calendar: calendar),
            end: date(2026, 8, 25, 14, calendar: calendar),
            kind: .active,
            title: "Active fast",
            glyphName: "moon.stars.fill"
        )
        let metrics: [String: TemporalRibbonLabelMetrics] = [
            "Fast": .init(title: "Fast", glyphWidth: 16, textWidth: 30),
            "Active fast": .init(title: "Active fast", glyphWidth: 16, textWidth: 80)
        ]
        let labels = TemporalRibbonLabelProjector.project(
            [first, second],
            days: [day],
            contentWidth: 400,
            calendar: calendar,
            metrics: metrics
        )
        let laneOne = try XCTUnwrap(labels.first { $0.id == secondID })
        XCTAssertEqual(laneOne.lane, 1)

        let policy = TemporalRibbonGeometry.pagePolicy(
            for: 400,
            accessibilitySize: false
        )
        let contentTop = policy.intervalLaneTop + Double(UFastTheme.Spacing.standard)
        let existingBarLaneStep = policy.intervalLaneHeight + policy.intervalLaneSpacing
        let laneTop = contentTop
            + Double(laneOne.lane) * existingBarLaneStep
        let barFrame = CGRect(
            x: laneOne.projectedStartX,
            y: laneTop,
            width: laneOne.projectedEndX - laneOne.projectedStartX,
            height: policy.intervalMarkHeight
        )
        let labelLayout = TemporalRibbonLabelLayout(
            contentWidth: 400,
            layerHeight: 268,
            laneHeight: policy.intervalMarkHeight,
            labelTop: contentTop,
            laneSpacing: policy.intervalLabelLaneSpacing
        )
        let labelFrame = CGRect(
            x: laneOne.labelCenterX - laneOne.labelWidth / 2,
            y: labelLayout.labelTop
                + Double(laneOne.lane) * (labelLayout.laneHeight + labelLayout.laneSpacing),
            width: laneOne.labelWidth,
            height: labelLayout.laneHeight
        )
        XCTAssertEqual(labelFrame.minY, barFrame.minY, accuracy: 0.000_001)
        XCTAssertEqual(labelFrame.maxY, barFrame.maxY, accuracy: 0.000_001)
        XCTAssertEqual(policy.intervalLaneStride, existingBarLaneStep, accuracy: 0.000_001)
        XCTAssertEqual(policy.intervalLaneStride, 46, accuracy: 0.000_001)
        XCTAssertEqual(policy.intervalLabelLaneSpacing, 2, accuracy: 0.000_001)

        let accessibilityPolicy = TemporalRibbonGeometry.pagePolicy(
            for: 400,
            accessibilitySize: true
        )
        XCTAssertEqual(accessibilityPolicy.intervalLaneStride, 52, accuracy: 0.000_001)
        XCTAssertEqual(
            accessibilityPolicy.intervalLabelLaneSpacing,
            accessibilityPolicy.intervalLaneStride - accessibilityPolicy.intervalMarkHeight,
            accuracy: 0.000_001
        )
    }

    func testMetricKeyIncludesLocalizedTitleLocaleDirectionDynamicTypeAndFont() {
        let base = TemporalRibbonLabelMetricKey(
            title: "Fast", localeIdentifier: "en_GB", layoutDirection: .leftToRight,
            dynamicTypeCategory: "accessibility3", font: "caption.semibold"
        )
        XCTAssertEqual(base, base)
        XCTAssertNotEqual(base, .init(
            title: "Inferred fast", localeIdentifier: "en_GB", layoutDirection: .leftToRight,
            dynamicTypeCategory: "accessibility3", font: "caption.semibold"
        ))
        XCTAssertNotEqual(base, .init(
            title: "Fast", localeIdentifier: "fr_FR", layoutDirection: .leftToRight,
            dynamicTypeCategory: "accessibility3", font: "caption.semibold"
        ))
        XCTAssertNotEqual(base, .init(
            title: "Fast", localeIdentifier: "en_GB", layoutDirection: .rightToLeft,
            dynamicTypeCategory: "accessibility3", font: "caption.semibold"
        ))
        XCTAssertNotEqual(base, .init(
            title: "Fast", localeIdentifier: "en_GB", layoutDirection: .leftToRight,
            dynamicTypeCategory: "xxxLarge", font: "caption.semibold"
        ))
        XCTAssertNotEqual(base, .init(
            title: "Fast", localeIdentifier: "en_GB", layoutDirection: .leftToRight,
            dynamicTypeCategory: "accessibility3", font: "caption.regular"
        ))
    }

    func testFitPolicyUsesFourPointSpacingAndSymmetricTwelvePointPadding() throws {
        let calendar = try londonCalendar()
        let day = date(2026, 8, 25, 0, calendar: calendar)
        let input = TemporalRibbonLabelInput(
            id: UUID(), start: date(2026, 8, 25, 8, calendar: calendar),
            end: date(2026, 8, 25, 16, calendar: calendar), kind: .recorded,
            title: "Fast", glyphName: "moon.stars.fill"
        )
        let metrics = TemporalRibbonLabelMetrics(title: "Fast", glyphWidth: 15, textWidth: 28)
        let label = try XCTUnwrap(
            TemporalRibbonLabelProjector.project(
                [input], days: [day], contentWidth: 400, calendar: calendar,
                metrics: ["Fast": metrics]
            ).first
        )
        XCTAssertEqual(label.labelWidth, 15 + 4 + 28 + 12, accuracy: 0.000_001)
        XCTAssertEqual(metrics.glyphOnlyWidth, 27, accuracy: 0.000_001)
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
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ) ?? .distantPast
    }
}
