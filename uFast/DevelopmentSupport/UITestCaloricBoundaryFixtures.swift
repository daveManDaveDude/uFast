import Foundation
import SwiftData

extension UITestSeedFixtures {
    /// A repeatable ten-year store used by MNT-005 structural query tests and
    /// the optional device smoke launch. The two named boundaries are kept
    /// close to the fixed clock; every other row is deliberately unrelated.
    static func seedCaloricBoundaryMultiYear(in context: ModelContext, clock: any AppClock) {
        let now = clock.now
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let punctuationDate = now.addingTimeInterval(-4 * 60 * 60)
        context.insert(FoodEntryRecord(
            id: fixtureID(1),
            draft: .init(description: "Scale source", occurredAt: sourceDate),
            createdAt: sourceDate
        ))
        context.insert(HydrationEntryRecord(
            id: fixtureID(2),
            type: .custom,
            customName: "Scale punctuation",
            volumeMillilitres: 250,
            occurredAt: punctuationDate,
            isCaloric: true,
            createdAt: punctuationDate
        ))
        seedScaleFoods(in: context, now: now)
        seedScaleHydration(in: context, now: now)
    }

    private static func seedScaleFoods(in context: ModelContext, now: Date) {
        for index in 0 ..< 2000 {
            let day = index % 3650
            let date = now.addingTimeInterval(-Double(day + 30) * 86400 - 3600)
            context.insert(FoodEntryRecord(
                id: fixtureID(10000 + index),
                draft: .init(description: "Scale food (index)", occurredAt: date),
                createdAt: date
            ))
        }
    }

    private static func seedScaleHydration(in context: ModelContext, now: Date) {
        for index in 0 ..< 2000 {
            let day = (index * 7) % 3650
            let date = now.addingTimeInterval(-Double(day + 45) * 86400 - 7200)
            context.insert(HydrationEntryRecord(
                id: fixtureID(20000 + index),
                type: .custom,
                customName: "Scale drink (index)",
                volumeMillilitres: 250,
                occurredAt: date,
                isCaloric: index.isMultiple(of: 2),
                createdAt: date
            ))
        }
    }

    private static func fixtureID(_ value: Int) -> UUID {
        let suffix = String(value, radix: 16)
        let padded = String(repeating: "0", count: max(0, 12 - suffix.count)) + suffix
        guard let id = UUID(uuidString: "50000000-0000-0000-0000-\(padded)") else {
            preconditionFailure("Invalid deterministic fixture UUID")
        }
        return id
    }
}
