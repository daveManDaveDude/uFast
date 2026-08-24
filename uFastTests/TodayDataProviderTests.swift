import SwiftData
@testable import uFast
import XCTest

@MainActor
final class TodayDataProviderTests: XCTestCase {
    func testProviderUsesHalfOpenCalendarDayAndPreservesSameDayOrdering() throws {
        let calendar = try utcCalendar()
        let now = try date(2026, 8, 20, 12, calendar: calendar)
        let start = calendar.startOfDay(for: now)
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))

        let tieDate = now.addingTimeInterval(-60)
        let firstID = try XCTUnwrap(UUID(uuidString: "10400000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "10400000-0000-0000-0000-000000000002"))
        context.insert(FoodEntryRecord(
            id: secondID,
            draft: .init(description: "Later tie", occurredAt: tieDate),
            createdAt: tieDate
        ))
        context.insert(FoodEntryRecord(
            id: firstID,
            draft: .init(description: "Earlier tie", occurredAt: tieDate),
            createdAt: tieDate
        ))
        context.insert(FoodEntryRecord(
            draft: .init(description: "At next midnight", occurredAt: end),
            createdAt: end
        ))
        context.insert(FoodEntryRecord(
            draft: .init(description: "Before today", occurredAt: start.addingTimeInterval(-1)),
            createdAt: start.addingTimeInterval(-1)
        ))
        context.insert(HydrationEntryRecord(
            type: .water,
            volumeMillilitres: 500,
            occurredAt: now,
            isCaloric: false,
            createdAt: now
        ))
        try context.save()

        let provider = SwiftDataTodayDataProvider(
            modelContext: context,
            clock: FixedAppClock(now: now),
            calendar: calendar
        )

        XCTAssertEqual(provider.dayInterval.start, start)
        XCTAssertEqual(provider.dayInterval.end, end)
        XCTAssertEqual(provider.snapshot.foodEntries.map(\.id), [firstID, secondID])
        XCTAssertEqual(provider.snapshot.hydrationEntries.count, 1)
        XCTAssertTrue(provider.snapshot.foodEntries.allSatisfy {
            $0.occurredAt >= start && $0.occurredAt < end
        })
    }

    func testProviderSelectsCorrectAbsoluteIntervalAcrossDSTAndTimeZoneChanges() throws {
        let london = try calendar(timeZone: "Europe/London")
        let spring = try date(2026, 3, 29, 12, calendar: london)
        let springInterval = TodayCalendarInterval(now: spring, calendar: london)
        XCTAssertEqual(springInterval.end.timeIntervalSince(springInterval.start), 23 * 60 * 60)

        let autumn = try date(2026, 10, 25, 12, calendar: london)
        let autumnInterval = TodayCalendarInterval(now: autumn, calendar: london)
        XCTAssertEqual(autumnInterval.end.timeIntervalSince(autumnInterval.start), 25 * 60 * 60)

        let utc = try calendar(timeZone: "UTC")
        let newYork = try calendar(timeZone: "America/New_York")
        let now = try date(2026, 1, 2, 0, 30, calendar: utc)
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let boundary = try date(2026, 1, 1, 23, 45, calendar: utc)
        context.insert(FoodEntryRecord(
            draft: .init(description: "Time-zone seam", occurredAt: boundary),
            createdAt: boundary
        ))
        try context.save()
        let provider = SwiftDataTodayDataProvider(
            modelContext: context,
            clock: FixedAppClock(now: now),
            calendar: utc
        )

        XCTAssertTrue(provider.snapshot.foodEntries.isEmpty)
        provider.refresh(now: now, calendar: newYork)
        XCTAssertEqual(provider.snapshot.foodEntries.map(\.foodDescription), ["Time-zone seam"])
    }

    func testHostEffectiveCalendarPropagatesEnvironmentTimeZoneToTimeline() throws {
        let environmentCalendar = try calendar(timeZone: "UTC")
        let environmentTimeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let effectiveCalendar = TodayFeatureHost.effectiveCalendar(
            environmentCalendar: environmentCalendar,
            environmentTimeZone: environmentTimeZone
        )
        let now = try date(2026, 1, 2, 0, 30, calendar: environmentCalendar)
        let eventDate = try date(2026, 1, 1, 23, 45, calendar: environmentCalendar)
        let event = FoodEntrySnapshot(
            FoodEntryRecord(
                draft: .init(
                    description: "New York calendar day",
                    occurredAt: eventDate
                ),
                createdAt: eventDate
            )
        )

        XCTAssertEqual(effectiveCalendar.timeZone.identifier, "America/New_York")
        XCTAssertEqual(
            TodayTimeline.entries(food: [event], drinks: [], now: now, calendar: effectiveCalendar).count,
            1
        )
    }

    func testMutableClockRefreshesOnBackgroundActivationAndReschedulesRollover() throws {
        let calendar = try utcCalendar()
        let start = try date(2026, 8, 20, 23, 59, calendar: calendar)
        let clock = MutableTodayClock(now: start)
        let container = try PersistenceContainer.make(inMemory: true)
        let provider = SwiftDataTodayDataProvider(
            modelContext: container.mainContext,
            clock: clock,
            calendar: calendar
        )
        let firstSchedule = TodayRolloverSchedule(interval: provider.dayInterval)

        clock.now = try date(2026, 8, 21, 0, 1, calendar: calendar)
        XCTAssertTrue(firstSchedule.shouldRefresh(now: clock.now, taskIsCancelled: false))
        provider.refresh()
        let secondSchedule = TodayRolloverSchedule(interval: provider.dayInterval)

        XCTAssertNotEqual(firstSchedule, secondSchedule)
        XCTAssertEqual(provider.dayInterval.start, calendar.startOfDay(for: clock.now))
        XCTAssertFalse(secondSchedule.shouldRefresh(now: clock.now, taskIsCancelled: false))
    }

    func testRolloverCancellationIsDeterministicAndDoesNotApplyStaleTask() throws {
        let calendar = try utcCalendar()
        let now = try date(2026, 8, 21, 0, 1, calendar: calendar)
        let priorNow = try date(2026, 8, 20, 23, 59, calendar: calendar)
        let interval = TodayCalendarInterval(
            now: priorNow,
            calendar: calendar
        )
        let schedule = TodayRolloverSchedule(interval: interval)

        XCTAssertEqual(schedule.nanosecondsUntil(now: now), 0)
        XCTAssertFalse(schedule.shouldRefresh(now: now, taskIsCancelled: true))
    }

    func testCommittedSaveAndDeleteRefreshTheImmutableSnapshot() throws {
        let calendar = try utcCalendar()
        let now = try date(2026, 8, 20, 12, calendar: calendar)
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let provider = SwiftDataTodayDataProvider(
            modelContext: context,
            clock: FixedAppClock(now: now),
            calendar: calendar
        )
        let record = FoodEntryRecord(
            draft: .init(description: "Committed meal", occurredAt: now),
            createdAt: now
        )

        context.insert(record)
        try context.save()
        XCTAssertEqual(provider.snapshot.foodEntries.map(\.foodDescription), ["Committed meal"])

        context.delete(record)
        try context.save()
        XCTAssertTrue(provider.snapshot.foodEntries.isEmpty)
    }

    func testFailedRefreshAdoptsRequestedDayAndRecoversTimelineWithNewCalendar() throws {
        let utc = try utcCalendar()
        let london = try calendar(timeZone: "Europe/London")
        let now = try date(2026, 8, 20, 23, 30, calendar: utc)
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let authorities = seedFailedRefreshAuthority(in: context, now: now)
        let londonOnlyMeal = FoodEntryRecord(
            draft: .init(
                description: "London recovery meal",
                occurredAt: now.addingTimeInterval(45 * 60)
            ),
            createdAt: now
        )
        context.insert(londonOnlyMeal)
        try context.save()
        let provider = SwiftDataTodayDataProvider(
            modelContext: context,
            clock: FixedAppClock(now: now),
            calendar: utc
        )
        let expectedLondonInterval = TodayCalendarInterval(now: now, calendar: london)

        provider.refresh(
            now: now,
            calendar: london,
            using: { _ in throw TodaySnapshotLoadFailure.unavailable }
        )

        XCTAssertEqual(provider.calendar.timeZone.identifier, london.timeZone.identifier)
        XCTAssertEqual(provider.dayInterval, expectedLondonInterval)
        XCTAssertTrue(provider.snapshot.foodEntries.isEmpty)
        XCTAssertTrue(provider.snapshot.hydrationEntries.isEmpty)
        XCTAssertEqual(provider.snapshot.settings.map(\.id), [authorities.settingsID])
        XCTAssertEqual(provider.snapshot.activeFasts.map(\.id), [authorities.activeFastID])
        XCTAssertEqual(provider.snapshot.hydrationFavourites.map(\.id), [authorities.favouriteID])
        XCTAssertEqual(provider.failure, .snapshotUnavailable)

        provider.refresh()

        XCTAssertEqual(
            provider.snapshot.foodEntries.map(\.foodDescription),
            ["London recovery meal", "Existing meal"]
        )
        XCTAssertEqual(provider.snapshot.hydrationEntries.count, 1)
        XCTAssertNil(provider.failure)
    }

    func testMultiYearFixtureContainsOnlyTodayRecordsInProviderSnapshot() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = try utcCalendar()
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        UITestSeedFixtures.seedTodayMultiYear(in: context, clock: FixedAppClock(now: now))
        try context.save()

        let provider = SwiftDataTodayDataProvider(
            modelContext: context,
            clock: FixedAppClock(now: now),
            calendar: calendar
        )
        XCTAssertEqual(provider.snapshot.foodEntries.map(\.foodDescription), ["Today breakfast"])
        XCTAssertEqual(provider.snapshot.hydrationEntries.count, 1)
    }

    private func utcCalendar() throws -> Calendar {
        try calendar(timeZone: "UTC")
    }

    private func calendar(timeZone identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
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
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }

    private func seedFailedRefreshAuthority(
        in context: ModelContext,
        now: Date
    ) -> FailedRefreshAuthorityIDs {
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        let activeFast = FastRecord(
            startDate: now.addingTimeInterval(-60 * 60),
            goalAtStart: .default
        )
        let favourite = HydrationFavouriteRecord(
            name: "Sparkling water",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: now
        )
        context.insert(settings)
        context.insert(activeFast)
        context.insert(favourite)
        context.insert(FoodEntryRecord(
            draft: .init(description: "Existing meal", occurredAt: now),
            createdAt: now
        ))
        context.insert(HydrationEntryRecord(
            type: .water,
            volumeMillilitres: 500,
            occurredAt: now,
            isCaloric: false,
            createdAt: now
        ))
        return FailedRefreshAuthorityIDs(
            settingsID: settings.id,
            activeFastID: activeFast.id,
            favouriteID: favourite.id
        )
    }
}

private enum TodaySnapshotLoadFailure: Error {
    case unavailable
}

private struct FailedRefreshAuthorityIDs {
    let settingsID: UUID
    let activeFastID: UUID
    let favouriteID: UUID
}

private final class MutableTodayClock: AppClock, @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
