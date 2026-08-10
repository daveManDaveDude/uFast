import Foundation
import SwiftData

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma
enum UITestSeedFixtures {
    static func seedSlice3History(in context: ModelContext, clock: any AppClock) throws {
        if try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        let now = clock.now
        let dates = [-60, -48, -36, -24].map {
            now.addingTimeInterval(TimeInterval($0 * 60 * 60))
        }
        let entries = [
            FoodEntryRecord(draft: .init(description: "Late dinner", occurredAt: dates[0]), createdAt: dates[0]),
            FoodEntryRecord(draft: .init(description: "Breakfast", occurredAt: dates[1]), createdAt: dates[1]),
            FoodEntryRecord(draft: .init(description: "Supper", occurredAt: dates[2]), createdAt: dates[2]),
            FoodEntryRecord(draft: .init(description: "Morning meal", occurredAt: dates[3]), createdAt: dates[3]),
        ]
        entries.forEach(context.insert)
        let confirmed = FastRecord(
            reconstructedStart: dates[0],
            endDate: dates[1],
            boundaries: .init(
                start: .init(kind: .food, id: entries[0].id),
                end: .init(kind: .food, id: entries[1].id)
            ),
            adjustedByUser: false
        )
        let needsReview = FastRecord(
            reconstructedStart: dates[2],
            endDate: dates[3],
            boundaries: .init(
                start: .init(kind: .food, id: entries[2].id),
                end: .init(kind: .food, id: entries[3].id)
            ),
            adjustedByUser: true
        )
        needsReview.markNeedsReview()
        context.insert(confirmed)
        context.insert(needsReview)
        context.insert(
            UnknownPeriodRecord(
                startDate: now.addingTimeInterval(-18 * 60 * 60),
                endDate: now.addingTimeInterval(-10 * 60 * 60),
                boundaries: .init(
                    start: .init(kind: .food, id: UUID()),
                    end: .init(kind: .hydration, id: UUID())
                ),
                reason: .userChoice,
                createdAt: now
            )
        )
    }

    static func seedHistoryEventGrouping(in context: ModelContext, clock: any AppClock) throws {
        if try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        guard let london = TimeZone(identifier: "Europe/London") else { return }
        calendar.timeZone = london
        let day = calendar.startOfDay(for: clock.now)
        seedGroupingFast(in: context, day: day, calendar: calendar)
        seedGroupingTea(in: context, day: day, calendar: calendar)
        seedGroupingFood(in: context, day: day, calendar: calendar)
        seedGroupingMixedHydration(in: context, day: day, calendar: calendar)
    }

    private static func seedGroupingFast(in context: ModelContext, day: Date, calendar: Calendar) {
        guard let fastStart = calendar.date(byAdding: .day, value: -1, to: day),
              let start = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: fastStart),
              let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day),
              let id = UUID(uuidString: "39700000-0000-0000-0000-000000000001")
        else { return }
        context.insert(FastRecord(id: id, startDate: start, endDate: end, goalAtStart: .default))
    }

    private static func seedGroupingTea(in context: ModelContext, day: Date, calendar: Calendar) {
        let values = [
            (8, 46, "39700000-0000-0000-0000-000000000010"),
            (10, 42, "39700000-0000-0000-0000-000000000011"),
            (11, 30, "39700000-0000-0000-0000-000000000012"),
            (16, 2, "39700000-0000-0000-0000-000000000013"),
        ]
        for (hour, minute, rawID) in values {
            guard let occurredAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  let id = UUID(uuidString: rawID)
            else { continue }
            context.insert(HydrationEntryRecord(
                id: id, type: .tea, volumeMillilitres: 300,
                occurredAt: occurredAt, isCaloric: false, createdAt: occurredAt
            ))
        }
    }

    private static func seedGroupingFood(in context: ModelContext, day: Date, calendar: Calendar) {
        let values = [
            (10, 8, "39700000-0000-0000-0000-000000000020"),
            (10, 20, "39700000-0000-0000-0000-000000000021"),
            (17, 14, "39700000-0000-0000-0000-000000000022"),
        ]
        for (hour, minute, rawID) in values {
            guard let occurredAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  let id = UUID(uuidString: rawID)
            else { continue }
            context.insert(FoodEntryRecord(
                id: id,
                draft: .init(description: hour == 17 ? "Snack" : "Lunch", occurredAt: occurredAt),
                createdAt: occurredAt
            ))
        }
    }

    private static func seedGroupingMixedHydration(
        in context: ModelContext,
        day: Date,
        calendar: Calendar
    ) {
        let values = [
            (10, 28, true, "Juice", "39700000-0000-0000-0000-000000000030"),
            (10, 40, true, "Soda", "39700000-0000-0000-0000-000000000031"),
        ]
        for (hour, minute, isCaloric, name, rawID) in values {
            guard let occurredAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  let id = UUID(uuidString: rawID)
            else { continue }
            context.insert(HydrationEntryRecord(
                id: id, type: .custom, customName: name, volumeMillilitres: 250,
                occurredAt: occurredAt, isCaloric: isCaloric, createdAt: occurredAt
            ))
        }
    }
}
