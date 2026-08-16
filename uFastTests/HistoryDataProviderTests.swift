import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class HistoryDataProviderTests: XCTestCase {
    func testCarouselUsesExactSourceOnlyForSelectedSettledPage() {
        XCTAssertEqual(
            TemporalHistoryCarousel.presentationSource(
                isSelectedPage: true,
                movementPhase: .settled
            ),
            .settled
        )
        for phase: TemporalCarouselMovementPhase in [.userDriven, .decelerating, .aligning, .programmatic] {
            XCTAssertEqual(
                TemporalHistoryCarousel.presentationSource(
                    isSelectedPage: true,
                    movementPhase: phase
                ),
                .motion
            )
        }
        XCTAssertEqual(
            TemporalHistoryCarousel.presentationSource(
                isSelectedPage: false,
                movementPhase: .settled
            ),
            .motion
        )
    }

    @MainActor
    private struct LegacyFixture {
        let container: ModelContainer
        let window: DateInterval
        let unknownID: UUID

        var context: ModelContext {
            container.mainContext
        }
    }

    func testTenYearStoreSuppliesOnlyVisibleRecordsAndNearestCaloricNeighbours() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = utcCalendar
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2016, month: 1, day: 1)))

        for offset in 0 ..< 3653 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: firstDay))
            let meal = try XCTUnwrap(calendar.date(byAdding: .hour, value: 8, to: day))
            let water = try XCTUnwrap(calendar.date(byAdding: .hour, value: 12, to: day))
            context.insert(FoodEntryRecord(
                draft: .init(description: "Meal \(offset)", occurredAt: meal),
                createdAt: meal
            ))
            context.insert(HydrationEntryRecord(
                type: .water,
                volumeMillilitres: 500,
                occurredAt: water,
                isCaloric: false,
                createdAt: water
            ))
        }
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.save()

        let selectedDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2000, to: firstDay))
        let selectedEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: selectedDay))
        let result = try SwiftDataHistoryDataProvider(modelContext: context).fetch(
            window: DateInterval(start: selectedDay, end: selectedEnd)
        )

        XCTAssertEqual(result.foods.count, 3)
        XCTAssertEqual(result.drinks.count, 1)
        XCTAssertEqual(result.projectionInputCount, 4)
        XCTAssertEqual(result.foods.map(\.occurredAt).sorted(), [
            selectedDay.addingTimeInterval(-16 * 60 * 60),
            selectedDay.addingTimeInterval(8 * 60 * 60),
            selectedEnd.addingTimeInterval(8 * 60 * 60),
        ])
        XCTAssertEqual(result.window, DateInterval(start: selectedDay, end: selectedEnd))
    }

    func testProviderReturnsOnlyCompletedFastsIntersectingRequestedWindow() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let window = DateInterval(
            start: Date(timeIntervalSince1970: 2_000_000_000),
            duration: 24 * 60 * 60
        )
        context.insert(FastRecord(
            startDate: window.start.addingTimeInterval(-60),
            endDate: window.start.addingTimeInterval(60),
            goalAtStart: .default
        ))
        context.insert(FastRecord(
            startDate: window.end,
            endDate: window.end.addingTimeInterval(60),
            goalAtStart: .default
        ))
        try context.save()

        let result = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)

        XCTAssertEqual(result.completedFasts.count, 1)
        XCTAssertLessThan(result.completedFasts[0].startDate, window.start)
    }

    func testBoundedMotionSliceRetainsEventsAcrossAdjacentCalendarPages() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = utcCalendar
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2027, month: 3, day: 15))
        )
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: selectedDay))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: selectedDay))
        let afterNextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: selectedDay))
        let previousMeal = food("Previous dinner", on: previousDay, hour: 18)
        let selectedMeal = food("Selected lunch", on: selectedDay, hour: 12)
        let nextBreakfast = food("Next breakfast", on: nextDay, hour: 8)
        let nextDinner = food("Next dinner", on: nextDay, hour: 18)
        [previousMeal, selectedMeal, nextBreakfast, nextDinner].forEach(context.insert)
        try context.save()

        let settled = try SwiftDataHistoryDataProvider(modelContext: context).fetch(
            window: DateInterval(start: selectedDay, end: nextDay)
        )
        let motion = try SwiftDataHistoryDataProvider(modelContext: context).fetch(
            window: DateInterval(start: previousDay, end: afterNextDay)
        )

        XCTAssertEqual(
            settled.foods.filter { $0.occurredAt >= nextDay && $0.occurredAt < afterNextDay }.count,
            1,
            "The exact settled slice intentionally retains only the nearest outside boundary."
        )
        XCTAssertEqual(
            motion.foods.filter { $0.occurredAt >= nextDay && $0.occurredAt < afterNextDay }.count,
            2,
            "A bounded motion slice can keep every event on an incoming calendar page visible."
        )
    }

    func testInferredProjectionUsesNearestFoodEvenWhenHydrationIsCloser() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 2_200_000_000)
        let window = DateInterval(
            start: start.addingTimeInterval(9 * 60 * 60),
            duration: 60 * 60
        )
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        context.insert(source)
        context.insert(HydrationEntryRecord(
            type: .water,
            volumeMillilitres: 500,
            occurredAt: start.addingTimeInterval(8.5 * 60 * 60),
            isCaloric: false,
            createdAt: start
        ))
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let data = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: window.end
        )
        let inferred = try XCTUnwrap(presentation.fastItems.first(where: { $0.kind == .inferred }))
        XCTAssertEqual(inferred.id, source.id)
        XCTAssertEqual(inferred.startDate, start)
    }

    func testMotionCoverageIsCalendarBoundedAcrossDaylightSavingAndMaximumDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2027, month: 3, day: 28))
        )
        let maximumDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: selectedDay))
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: selectedDay,
            maximumDate: maximumDay,
            calendar: calendar
        )
        XCTAssertEqual(coverage.lastDay, maximumDay)
        XCTAssertEqual(coverage.days(calendar: calendar).count, 124)
        let visualWindow = try XCTUnwrap(coverage.visualWindow(calendar: calendar))
        let visualDuration: TimeInterval = visualWindow.duration
        let elapsedDayDuration: TimeInterval = 124 * 24 * 60 * 60 + 2 * 60 * 60
        XCTAssertNotEqual(
            visualDuration,
            elapsedDayDuration,
            "Calendar-day preloading must remain correct across the spring DST transition."
        )
    }

    func testExactLegacyFastIsProjectedOnceAndUnknownRecordRemainsStoredButHidden() throws {
        let fixture = try legacyFixture(adjusted: false)
        let data = try SwiftDataHistoryDataProvider(modelContext: fixture.context).fetch(
            window: fixture.window
        )
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: fixture.window.end
        )

        XCTAssertEqual(presentation.fastItems.map(\.kind), [.automatic])
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).map(\.id),
            [fixture.unknownID]
        )
    }

    func testNonReproducibleLegacyFastRemainsReadOnlyWithoutAutomaticDuplicate() throws {
        let fixture = try legacyFixture(adjusted: true)
        let data = try SwiftDataHistoryDataProvider(modelContext: fixture.context).fetch(
            window: fixture.window
        )
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: fixture.window.end
        )

        XCTAssertEqual(presentation.fastItems.map(\.kind), [.previouslySaved])
        XCTAssertEqual(presentation.fastItems.first?.title, "Previously saved fast")
    }

    private func legacyFixture(
        adjusted: Bool
    ) throws -> LegacyFixture {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 2_100_000_000)
        let end = start.addingTimeInterval(12 * 60 * 60)
        let first = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        let second = FoodEntryRecord(
            draft: .init(description: "Breakfast", occurredAt: end),
            createdAt: end
        )
        let pair = ReconstructionBoundaryPair(
            start: .init(kind: .food, id: first.id),
            end: .init(kind: .food, id: second.id)
        )
        let storedStart = adjusted ? start.addingTimeInterval(60) : start
        let storedEnd = adjusted ? end.addingTimeInterval(-60) : end
        let fast = FastRecord(
            reconstructedStart: storedStart,
            endDate: storedEnd,
            boundaries: pair,
            adjustedByUser: adjusted
        )
        let unknownID = UUID()
        let unknown = UnknownPeriodRecord(
            id: unknownID,
            startDate: start,
            endDate: end,
            boundaries: pair,
            reason: .userChoice,
            createdAt: end
        )
        context.insert(first)
        context.insert(second)
        context.insert(fast)
        context.insert(unknown)
        try context.save()
        return LegacyFixture(
            container: container,
            window: DateInterval(
                start: start.addingTimeInterval(-60),
                end: end.addingTimeInterval(60)
            ),
            unknownID: unknownID
        )
    }

    private func food(_ description: String, on day: Date, hour: Int) -> FoodEntryRecord {
        let occurredAt = day.addingTimeInterval(TimeInterval(hour) * 60 * 60)
        return FoodEntryRecord(
            draft: .init(description: description, occurredAt: occurredAt),
            createdAt: day
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
