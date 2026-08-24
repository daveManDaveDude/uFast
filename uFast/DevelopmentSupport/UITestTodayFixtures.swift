import Foundation
import SwiftData

// swiftlint:disable trailing_comma

private struct TodayMultiYearFoodSeed {
    let id: UUID
    let description: String
    let occurredAt: Date
}

extension UITestSeedFixtures {
    static func seedTodayMultiYear(in context: ModelContext, clock: any AppClock) {
        let now = clock.now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let older = calendar.date(byAdding: .year, value: -1, to: now)
            ?? now.addingTimeInterval(-365 * 24 * 60 * 60)
        let newer = calendar.date(byAdding: .year, value: 1, to: now)
            ?? now.addingTimeInterval(365 * 24 * 60 * 60)
        seedNamedFoods(in: context, now: now, older: older, newer: newer)
        seedHydrationEntries(in: context, now: now, older: older)
        seedUnrelatedHistory(in: context, older: older, newer: newer)
    }

    private static func seedNamedFoods(
        in context: ModelContext,
        now: Date,
        older: Date,
        newer: Date
    ) {
        let foods = [
            TodayMultiYearFoodSeed(
                id: stableID(1),
                description: "Today breakfast",
                occurredAt: now.addingTimeInterval(-45 * 60)
            ),
            TodayMultiYearFoodSeed(
                id: stableID(2),
                description: "Older breakfast",
                occurredAt: older
            ),
            TodayMultiYearFoodSeed(
                id: stableID(3),
                description: "Future breakfast",
                occurredAt: newer
            ),
        ]
        for food in foods {
            context.insert(FoodEntryRecord(
                id: food.id,
                draft: .init(description: food.description, occurredAt: food.occurredAt),
                createdAt: food.occurredAt
            ))
        }
    }

    private static func seedHydrationEntries(in context: ModelContext, now: Date, older: Date) {
        let todayDrinkDate = now.addingTimeInterval(-30 * 60)
        context.insert(HydrationEntryRecord(
            id: stableID(11),
            type: .water,
            volumeMillilitres: 500,
            occurredAt: todayDrinkDate,
            isCaloric: false,
            createdAt: todayDrinkDate
        ))
        context.insert(HydrationEntryRecord(
            id: stableID(12),
            type: .water,
            volumeMillilitres: 500,
            occurredAt: older,
            isCaloric: false,
            createdAt: older
        ))
    }

    private static func seedUnrelatedHistory(in context: ModelContext, older: Date, newer: Date) {
        // Keep the fixture substantial enough to exercise the bounded query
        // against a long-lived local store without random or wall-clock data.
        for index in 0 ..< 1000 {
            let offset = TimeInterval(index * 60)
            let oldFoodDate = older.addingTimeInterval(offset)
            let futureFoodDate = newer.addingTimeInterval(offset)
            context.insert(FoodEntryRecord(
                id: stableID(1000 + index),
                draft: .init(description: "Historical food \(index)", occurredAt: oldFoodDate),
                createdAt: oldFoodDate
            ))
            context.insert(FoodEntryRecord(
                id: stableID(2000 + index),
                draft: .init(description: "Future food \(index)", occurredAt: futureFoodDate),
                createdAt: futureFoodDate
            ))
            context.insert(HydrationEntryRecord(
                id: stableID(3000 + index),
                type: .water,
                volumeMillilitres: 500,
                occurredAt: oldFoodDate,
                isCaloric: false,
                createdAt: oldFoodDate
            ))
            context.insert(HydrationEntryRecord(
                id: stableID(4000 + index),
                type: .water,
                volumeMillilitres: 500,
                occurredAt: futureFoodDate,
                isCaloric: false,
                createdAt: futureFoodDate
            ))
        }
    }

    private static func stableID(_ value: Int) -> UUID {
        let suffix = String(format: "%012llX", UInt64(value))
        return UUID(uuidString: "10300000-0000-0000-0000-\(suffix)") ?? UUID()
    }
}
