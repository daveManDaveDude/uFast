@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

final class TemporalEventGroupingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }

    func testTwoTeaEventsProjectToOneStableHydrationGroup() throws {
        let day = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10))
        let window = DateInterval(start: day.addingTimeInterval(-3600), duration: 26 * 3600)
        let inputs = [
            input("00000000-0000-0000-0000-000000000001", at: 10, minute: 42),
            input("00000000-0000-0000-0000-000000000002", at: 11, minute: 30),
        ]

        let first = TemporalEventGrouping.project(inputs, in: window, calendar: calendar)
        let second = TemporalEventGrouping.project(inputs, in: window, calendar: calendar)

        XCTAssertEqual(first, second)
        guard case let .group(group) = try XCTUnwrap(first.first) else {
            return XCTFail("Expected a group")
        }
        XCTAssertEqual(group.family, .hydration)
        XCTAssertEqual(group.count, 2)
        XCTAssertEqual(calendar.component(.hour, from: group.bucket.start), 10)
        XCTAssertEqual(calendar.component(.hour, from: group.bucket.end), 12)
        XCTAssertEqual(group.members.map(\.reference.id.uuidString), [
            "00000000-0000-0000-0000-000000000001",
            "00000000-0000-0000-0000-000000000002",
        ])
        XCTAssertEqual(group.visualCountText, "2")
    }

    func testBucketMembershipIsHalfOpenAtTwoHourBoundary() throws {
        let windowStart = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 0))
        let window = DateInterval(start: windowStart, duration: 24 * 3600)
        let before = input(
            "00000000-0000-0000-0000-000000000010",
            at: 9,
            minute: 59,
            second: 59
        )
        let after = input(
            "00000000-0000-0000-0000-000000000011",
            at: 10,
            minute: 0
        )

        let result = TemporalEventGrouping.project([before, after], in: window, calendar: calendar)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map { calendar.component(.hour, from: $0.bucket.start) }, [8, 10])
    }

    func testFoodAndHydrationAtSameInstantRemainSeparate() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10, minute: 42))
        let window = DateInterval(start: instant.addingTimeInterval(-3600), duration: 3 * 3600)
        let food = input(
            "00000000-0000-0000-0000-000000000020",
            at: 10,
            minute: 42,
            family: .food,
            title: "Lunch"
        )
        let drink = input(
            "00000000-0000-0000-0000-000000000021",
            at: 10,
            minute: 42,
            family: .hydration,
            title: "Tea"
        )

        let result = TemporalEventGrouping.project([food, drink], in: window, calendar: calendar)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.family), [.food, .hydration])
    }

    func testEqualTimeMembersUseTypedUUIDOrdering() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10, minute: 42))
        let window = DateInterval(start: instant.addingTimeInterval(-3600), duration: 3 * 3600)
        let inputs = [
            input("00000000-0000-0000-0000-0000000000ff", at: 10, minute: 42),
            input("00000000-0000-0000-0000-000000000001", at: 10, minute: 42),
        ]

        let result = TemporalEventGrouping.project(inputs, in: window, calendar: calendar)

        guard case let .group(group) = result.first else {
            return XCTFail("Expected a group")
        }
        XCTAssertEqual(group.members.map(\.reference.id.uuidString), [
            "00000000-0000-0000-0000-000000000001",
            "00000000-0000-0000-0000-0000000000FF",
        ])
    }

    func testSingleEventHasNoGroupOrBadge() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10, minute: 42))
        let window = DateInterval(start: instant.addingTimeInterval(-3600), duration: 3 * 3600)
        let result = TemporalEventGrouping.project(
            [input("00000000-0000-0000-0000-000000000030", at: 10, minute: 42)],
            in: window,
            calendar: calendar
        )

        guard case let .single(_, member) = result.first else {
            return XCTFail("Expected a single item")
        }
        XCTAssertEqual(member.title, "Tea")
        XCTAssertNil(result.first?.group)
    }

    func testVisualCountCapsAbove99ButGroupCountRemainsExact() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10, minute: 42))
        let window = DateInterval(start: instant.addingTimeInterval(-3600), duration: 3 * 3600)
        let inputs = (0 ..< 100).map { index in
            input(
                String(format: "00000000-0000-0000-0000-%012d", index + 1),
                at: 10,
                minute: 42
            )
        }

        guard case let .group(group) = try XCTUnwrap(
            TemporalEventGrouping.project(inputs, in: window, calendar: calendar).first
        ) else {
            return XCTFail("Expected a group")
        }
        XCTAssertEqual(group.count, 100)
        XCTAssertEqual(group.visualCountText, "99+")
    }

    func testDSTBucketsUseCalendarLocalBoundariesAndKeepEvents() throws {
        let springDay = try XCTUnwrap(date(year: 2027, month: 3, day: 28, hour: 0))
        let autumnDay = try XCTUnwrap(date(year: 2027, month: 10, day: 31, hour: 0))

        let springBuckets = try TemporalEventGrouping.makeBuckets(
            intersecting: DateInterval(
                start: springDay,
                end: XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: springDay))
            ),
            calendar: calendar
        )
        let autumnBuckets = try TemporalEventGrouping.makeBuckets(
            intersecting: DateInterval(
                start: autumnDay,
                end: XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: autumnDay))
            ),
            calendar: calendar
        )

        XCTAssertEqual(springBuckets.first?.interval.duration, 3600)
        XCTAssertEqual(autumnBuckets.first?.interval.duration, 3 * 3600)
        XCTAssertEqual(springBuckets.count, 12)
        XCTAssertEqual(autumnBuckets.count, 12)
        XCTAssertEqual(
            springBuckets.map(\.start).count,
            Set(springBuckets.map(\.start)).count
        )
        XCTAssertEqual(
            autumnBuckets.map(\.start).count,
            Set(autumnBuckets.map(\.start)).count
        )
    }

    func testGroupLayoutCentersOnBucketMidpointAndUses82PercentWidth() {
        let layout = TemporalEventGroupLayout.make(
            bucketStartFraction: 0.25,
            bucketEndFraction: 0.5,
            ribbonWidth: 1000
        )

        XCTAssertEqual(layout?.centerFraction, 0.375)
        XCTAssertEqual(layout?.visibleWidth, 205)
        XCTAssertGreaterThanOrEqual(layout?.interactiveWidth ?? 0, 44)
        XCTAssertEqual(
            (layout?.centerFraction ?? 0) - (layout?.visibleWidth ?? 0) / 1000 / 2,
            0.2725,
            accuracy: 0.0001
        )
        XCTAssertTrue((layout?.visibleBounds.lowerBound ?? 0) >= 0.25)
        XCTAssertTrue((layout?.visibleBounds.upperBound ?? 1) <= 0.5)
    }

    func testGroupLayoutClipsVisibleContentAtWindowEdges() {
        let leftEdge = TemporalEventGroupLayout.make(
            bucketStartFraction: -0.25,
            bucketEndFraction: 0.1,
            ribbonWidth: 1000
        )
        let rightEdge = TemporalEventGroupLayout.make(
            bucketStartFraction: 0.9,
            bucketEndFraction: 1.25,
            ribbonWidth: 1000
        )

        XCTAssertGreaterThanOrEqual(leftEdge?.visibleBounds.lowerBound ?? -1, 0)
        XCTAssertLessThanOrEqual(leftEdge?.visibleBounds.upperBound ?? 2, 0.1)
        XCTAssertGreaterThanOrEqual(rightEdge?.visibleBounds.lowerBound ?? -1, 0.9)
        XCTAssertLessThanOrEqual(rightEdge?.visibleBounds.upperBound ?? 2, 1)
        XCTAssertLessThanOrEqual(leftEdge?.visibleContentWidth ?? 0, 44)
        XCTAssertLessThanOrEqual(rightEdge?.visibleContentWidth ?? 0, 44)
    }

    func testRTLCalendarContextDoesNotChangeChronologicalGrouping() throws {
        var rtlCalendar = calendar
        rtlCalendar.locale = Locale(identifier: "ar_SA")
        let day = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 0))
        let window = DateInterval(start: day, duration: 24 * 3600)
        let input = input(
            "00000000-0000-0000-0000-000000000040",
            at: 10,
            minute: 42
        )

        let result = TemporalEventGrouping.project([input], in: window, calendar: rtlCalendar)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(rtlCalendar.component(.hour, from: result[0].bucket.start), 10)
    }

    private func input(
        _ id: String,
        at hour: Int,
        minute: Int,
        second: Int = 0,
        family: TemporalEventFamily = .hydration,
        title: String = "Tea",
        isCaloric: Bool = false,
        presentationCategory: TemporalEventPresentationCategory? = nil
    ) -> TemporalEventGroupingInput {
        TemporalEventGroupingInput(
            reference: TemporalEventReference(family: family, id: UUID(uuidString: id) ?? UUID()),
            occurredAt: date(
                year: 2027,
                month: 1,
                day: 15,
                hour: hour,
                minute: minute,
                second: second
            ) ?? .distantPast,
            title: title,
            detail: "300 ml",
            accessibilityLabel: "\(title), \(family.rawValue)",
            isCaloric: family == .food ? true : isCaloric,
            presentationCategory: presentationCategory
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))
    }
}

extension TemporalEventGroupingTests {
    func testCaloricAndNonCaloricDrinksFormIndependentGroupsInOneBucket() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10))
        let window = DateInterval(start: instant, duration: 2 * 3600)
        let inputs = [
            input(
                "00000000-0000-0000-0000-000000000050",
                at: 10,
                minute: 10,
                isCaloric: true,
                presentationCategory: .caloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000051",
                at: 10,
                minute: 20,
                isCaloric: true,
                presentationCategory: .caloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000052",
                at: 10,
                minute: 30,
                presentationCategory: .nonCaloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000053",
                at: 10,
                minute: 40,
                presentationCategory: .nonCaloricDrink
            ),
        ]

        let result = TemporalEventGrouping.project(inputs, in: window, calendar: calendar)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.presentationCategory), [.caloricDrink, .nonCaloricDrink])
        XCTAssertEqual(result.compactMap(\.group).map(\.count), [2, 2])
        XCTAssertEqual(Set(result.map(\.id)).count, 2)
    }

    func testFoodAndBothDrinkCategoriesProduceThreeOrderedGroups() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10))
        let window = DateInterval(start: instant, duration: 2 * 3600)
        let inputs = [
            input(
                "00000000-0000-0000-0000-000000000060",
                at: 10,
                minute: 5,
                family: .food,
                title: "Lunch"
            ),
            input(
                "00000000-0000-0000-0000-000000000061",
                at: 10,
                minute: 15,
                family: .food,
                title: "Lunch"
            ),
            input(
                "00000000-0000-0000-0000-000000000062",
                at: 10,
                minute: 25,
                isCaloric: true,
                presentationCategory: .caloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000063",
                at: 10,
                minute: 35,
                isCaloric: true,
                presentationCategory: .caloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000064",
                at: 10,
                minute: 45,
                presentationCategory: .nonCaloricDrink
            ),
            input(
                "00000000-0000-0000-0000-000000000065",
                at: 10,
                minute: 55,
                presentationCategory: .nonCaloricDrink
            ),
        ]

        let result = TemporalEventGrouping.project(inputs, in: window, calendar: calendar)

        XCTAssertEqual(result.map(\.presentationCategory), [.food, .caloricDrink, .nonCaloricDrink])
        XCTAssertEqual(result.compactMap(\.group).map(\.count), [2, 2, 2])
        XCTAssertEqual(Set(result.map(\.id)).count, 3)
    }

    func testHydrationReclassificationChangesPresentationCategoryButKeepsTypedReference() throws {
        let instant = try XCTUnwrap(date(year: 2027, month: 1, day: 15, hour: 10))
        let window = DateInterval(start: instant, duration: 2 * 3600)
        let id = "00000000-0000-0000-0000-000000000070"
        let caloric = input(
            id,
            at: 10,
            minute: 10,
            isCaloric: true,
            presentationCategory: .caloricDrink
        )
        let nonCaloric = input(
            id,
            at: 10,
            minute: 10,
            presentationCategory: .nonCaloricDrink
        )

        let before = try XCTUnwrap(
            TemporalEventGrouping.project([caloric], in: window, calendar: calendar).first
        )
        let after = try XCTUnwrap(
            TemporalEventGrouping.project([nonCaloric], in: window, calendar: calendar).first
        )

        XCTAssertEqual(before.family, .hydration)
        XCTAssertEqual(after.family, .hydration)
        XCTAssertEqual(before.memberReferences, after.memberReferences)
        XCTAssertEqual(before.presentationCategory, .caloricDrink)
        XCTAssertEqual(after.presentationCategory, .nonCaloricDrink)
    }

    func testMarkerMetricsProvideThreeNonOverlappingRowsAndTouchTargets() {
        let categories: [TemporalEventPresentationCategory] = [.food, .caloricDrink, .nonCaloricDrink]
        let metrics = categories.map {
            TemporalEventMarkerMetrics.make(category: $0, accessibilitySize: false)
        }

        XCTAssertEqual(metrics.map(\.rowTop), [122, 174, 226])
        XCTAssertEqual(metrics.map(\.tileSize), [26, 26, 26])
        XCTAssertTrue(metrics.allSatisfy { $0.hitHeight >= 44 && $0.cellHeight <= $0.rowHeight })
        XCTAssertLessThanOrEqual(
            (metrics.last?.rowTop ?? 0) + (metrics.last?.cellHeight ?? 0),
            268
        )

        let accessibilityMetrics = categories.map {
            TemporalEventMarkerMetrics.make(category: $0, accessibilitySize: true)
        }
        XCTAssertTrue(accessibilityMetrics.allSatisfy { $0.hitHeight >= 44 && $0.cellHeight <= $0.rowHeight })
        XCTAssertLessThanOrEqual(
            (accessibilityMetrics.last?.rowTop ?? 0) + (accessibilityMetrics.last?.cellHeight ?? 0),
            320
        )
    }

    func testGridRulesUseSurfaceHeightAfterLabelClearance() {
        XCTAssertEqual(TemporalRibbonSurfaceMetrics.gridRuleHeight(surfaceHeight: 260), 228)
        XCTAssertEqual(TemporalRibbonSurfaceMetrics.gridRuleHeight(surfaceHeight: 320), 288)
    }
}
