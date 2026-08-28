import Foundation
import SwiftData

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma function_body_length type_body_length file_length
enum UITestSeedFixtures {
    static func seedNewFavouriteDefault(in context: ModelContext, clock: any AppClock) {
        guard let settings = try? context.fetch(FetchDescriptor<AppSettingsRecord>()),
              !settings.isEmpty,
              let records = try? context.fetch(FetchDescriptor<HydrationFavouriteRecord>()),
              records.isEmpty
        else {
            return
        }
        try? HydrationFavouriteMigration.seedNewStore(in: context, at: clock.now)
    }

    static func seedFavouritePopulated(in context: ModelContext, clock: any AppClock) {
        let createdAt = clock.now.addingTimeInterval(-120)
        guard let id = UUID(uuidString: "10100000-0000-0000-0000-000000000001") else { return }
        context.insert(HydrationFavouriteRecord(
            id: id,
            name: "Sparkling water",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: createdAt,
            creationOrder: 1
        ))
    }

    static func seedFavouriteDuplicateName(in context: ModelContext, clock: any AppClock) {
        context.insert(HydrationFavouriteRecord(
            name: "Water",
            volumeMillilitres: 250,
            isCaloric: false,
            createdAt: clock.now,
            creationOrder: 1
        ))
    }

    static func seedFavouriteValidation(in context: ModelContext, clock: any AppClock) {
        context.insert(HydrationFavouriteRecord(
            name: "",
            volumeMillilitres: 0,
            isCaloric: false,
            createdAt: clock.now,
            creationOrder: 2
        ))
    }

    static func seedCaloricFavouriteActiveFast(in context: ModelContext, clock: any AppClock) {
        let createdAt = clock.now.addingTimeInterval(-120)
        guard let id = UUID(uuidString: "10100000-0000-0000-0000-000000000002") else { return }
        context.insert(HydrationFavouriteRecord(
            id: id,
            name: "Juice",
            volumeMillilitres: 250,
            isCaloric: true,
            createdAt: createdAt
        ))
        context.insert(FastRecord(
            startDate: clock.now.addingTimeInterval(-3600),
            goalAtStart: .default
        ))
    }

    static func seedInferredFast(in context: ModelContext, clock: any AppClock) {
        guard let settings = try? context.fetch(FetchDescriptor<AppSettingsRecord>()).first,
              let firstID = UUID(uuidString: "10200000-0000-0000-0000-000000000001"),
              let secondID = UUID(uuidString: "10200000-0000-0000-0000-000000000002")
        else { return }
        settings.setInferredFastDetectionEnabled(true)
        let historicalDate = clock.now.addingTimeInterval(-20 * 60 * 60)
        let currentDate = clock.now.addingTimeInterval(-8 * 60 * 60)
        context.insert(FoodEntryRecord(
            id: firstID,
            draft: .init(description: "Inferred supper", occurredAt: historicalDate),
            createdAt: historicalDate
        ))
        context.insert(FoodEntryRecord(
            id: secondID,
            draft: .init(description: "Inferred breakfast", occurredAt: currentDate),
            createdAt: currentDate
        ))
    }

    /// OW-412-only fixture for food and explicitly caloric hydration boundary
    /// transitions. The first suppression ends exactly at the default cap;
    /// the last is exactly at the eight-hour eligibility boundary.
    static func seedInferredFastEligibility(in context: ModelContext, clock: any AppClock) {
        guard let settings = try? context.fetch(FetchDescriptor<AppSettingsRecord>()).first,
              let capHydrationID = UUID(uuidString: "10400000-0000-0000-0000-000000000001"),
              let capFoodID = UUID(uuidString: "10400000-0000-0000-0000-000000000002"),
              let postFoodID = UUID(uuidString: "10400000-0000-0000-0000-000000000003"),
              let eligibilityHydrationID = UUID(uuidString: "10400000-0000-0000-0000-000000000004")
        else { return }

        settings.setInferredFastDetectionEnabled(true)
        let capHydrationDate = clock.now.addingTimeInterval(-60 * 60 * 60)
        let capFoodDate = clock.now.addingTimeInterval(-32 * 60 * 60)
        let postFoodDate = clock.now.addingTimeInterval(-20 * 60 * 60)
        let eligibilityHydrationDate = clock.now.addingTimeInterval(-8 * 60 * 60)

        context.insert(HydrationEntryRecord(
            id: capHydrationID,
            type: .coffee,
            volumeMillilitres: 250,
            occurredAt: capHydrationDate,
            isCaloric: true,
            createdAt: capHydrationDate
        ))
        context.insert(FoodEntryRecord(
            id: capFoodID,
            draft: .init(description: "Cap food", occurredAt: capFoodDate),
            createdAt: capFoodDate
        ))
        context.insert(FoodEntryRecord(
            id: postFoodID,
            draft: .init(description: "Post food", occurredAt: postFoodDate),
            createdAt: postFoodDate
        ))
        context.insert(HydrationEntryRecord(
            id: eligibilityHydrationID,
            type: .coffee,
            volumeMillilitres: 250,
            occurredAt: eligibilityHydrationDate,
            isCaloric: true,
            createdAt: eligibilityHydrationDate
        ))

        let candidates = [
            InferredFastInterval(
                sourceBoundaryReference: .init(kind: .hydration, id: capHydrationID),
                sourceDate: capHydrationDate,
                sourceDescription: "Coffee",
                nextBoundaryReference: .init(kind: .food, id: capFoodID),
                nextBoundaryDate: capFoodDate,
                startDate: capHydrationDate,
                endDate: capHydrationDate.addingTimeInterval(28 * 60 * 60),
                goal: settings.fastingGoal,
                state: .historical
            ),
            InferredFastInterval(
                sourceBoundaryReference: .init(kind: .food, id: capFoodID),
                sourceDate: capFoodDate,
                sourceDescription: "Cap food",
                nextBoundaryReference: .init(kind: .food, id: postFoodID),
                nextBoundaryDate: postFoodDate,
                startDate: capFoodDate,
                endDate: postFoodDate,
                goal: settings.fastingGoal,
                state: .historical
            ),
            InferredFastInterval(
                sourceBoundaryReference: .init(kind: .food, id: postFoodID),
                sourceDate: postFoodDate,
                sourceDescription: "Post food",
                nextBoundaryReference: .init(kind: .hydration, id: eligibilityHydrationID),
                nextBoundaryDate: eligibilityHydrationDate,
                startDate: postFoodDate,
                endDate: eligibilityHydrationDate,
                goal: settings.fastingGoal,
                state: .historical
            ),
            InferredFastInterval(
                sourceBoundaryReference: .init(kind: .hydration, id: eligibilityHydrationID),
                sourceDate: eligibilityHydrationDate,
                sourceDescription: "Coffee",
                nextBoundaryReference: nil,
                nextBoundaryDate: nil,
                startDate: eligibilityHydrationDate,
                endDate: clock.now,
                goal: settings.fastingGoal,
                state: .inProgress
            ),
        ]
        for candidate in candidates {
            context.insert(InferredFastSuppressionRecord(
                suppression: InferredFastSuppressionDecider.make(candidate: candidate, at: clock.now)
            ))
        }
    }

    static func seedSuppressedInferredFast(in context: ModelContext, clock: any AppClock) {
        let settings: AppSettingsRecord
        if let existing = try? context.fetch(FetchDescriptor<AppSettingsRecord>()).first {
            settings = existing
        } else {
            let created = AppSettingsRecord(hasCompletedOnboarding: true)
            context.insert(created)
            settings = created
        }
        guard let sourceID = UUID(uuidString: "10300000-0000-0000-0000-000000000001") else { return }
        settings.setInferredFastDetectionEnabled(true)
        let sourceDate = clock.now.addingTimeInterval(-20 * 60 * 60)
        context.insert(FoodEntryRecord(
            id: sourceID,
            draft: .init(description: "Hidden inferred supper", occurredAt: sourceDate),
            createdAt: sourceDate
        ))
        let candidate = InferredFastInterval(
            sourceBoundaryReference: .init(kind: .food, id: sourceID),
            sourceDate: sourceDate,
            sourceDescription: "Hidden inferred supper",
            nextBoundaryReference: nil,
            nextBoundaryDate: nil,
            startDate: sourceDate,
            endDate: clock.now,
            goal: settings.fastingGoal,
            state: .inProgress
        )
        context.insert(InferredFastSuppressionRecord(
            suppression: InferredFastSuppressionDecider.make(candidate: candidate, at: clock.now)
        ))
    }

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

    static func seedHistoryMidnightSeam(
        in context: ModelContext,
        clock: any AppClock,
        extendsActiveFast: Bool = false
    ) throws {
        if try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        guard let london = TimeZone(identifier: "Europe/London") else { return }
        calendar.timeZone = london
        let currentDay = calendar.startOfDay(for: clock.now)
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay)
        else { return }
        let activeStartDay: Date
        if extendsActiveFast {
            guard let extendedStartDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: previousDay
            ) else { return }
            activeStartDay = extendedStartDay
        } else {
            activeStartDay = previousDay
        }
        let completedDay = extendsActiveFast ? activeStartDay : previousDay
        guard let completedStart = calendar.date(
            bySettingHour: 10,
            minute: 6,
            second: 0,
            of: completedDay
        ),
            let completedEnd = calendar.date(
                bySettingHour: 18,
                minute: 0,
                second: 0,
                of: completedDay
            ),
            let activeStart = calendar.date(
                bySettingHour: 19,
                minute: 6,
                second: 0,
                of: activeStartDay
            ),
            let completedID = UUID(uuidString: "10200000-0000-0000-0000-000000000001"),
            let activeID = UUID(uuidString: "10200000-0000-0000-0000-000000000002")
        else { return }

        context.insert(FastRecord(
            id: completedID,
            startDate: completedStart,
            endDate: completedEnd,
            goalAtStart: .default
        ))
        context.insert(FastRecord(
            id: activeID,
            startDate: activeStart,
            goalAtStart: .default
        ))

        let markers = [
            (previousDay, 18, 42, "10200000-0000-0000-0000-000000000010"),
            (previousDay, 23, 48, "10200000-0000-0000-0000-000000000011"),
            (currentDay, 0, 12, "10200000-0000-0000-0000-000000000012"),
            (currentDay, 12, 0, "10200000-0000-0000-0000-000000000013"),
        ]
        for (day, hour, minute, rawID) in markers {
            guard let occurredAt = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: day
            ), let id = UUID(uuidString: rawID)
            else { continue }
            context.insert(HydrationEntryRecord(
                id: id,
                type: .tea,
                volumeMillilitres: 300,
                occurredAt: occurredAt,
                isCaloric: false,
                createdAt: occurredAt
            ))
        }
    }

    private static func seedGroupingFast(in context: ModelContext, day: Date, calendar: Calendar) {
        guard let fastStart = calendar.date(byAdding: .day, value: -1, to: day),
              let start = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: fastStart),
              let end = calendar.date(bySettingHour: 10, minute: 8, second: 0, of: day),
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

extension UITestSeedFixtures {
    static func seedHistoryFastLabelLayout(
        in context: ModelContext,
        clock: any AppClock
    ) throws {
        if try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        guard let london = TimeZone(identifier: "Europe/London") else { return }
        calendar.timeZone = london
        guard let recordedStart = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 25, hour: 20, minute: 42)
        ), let recordedEnd = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 26, hour: 17, minute: 55)
        ), let activeStart = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 26, hour: 20, minute: 26)
        ), let foodAtEnd = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 26, hour: 17, minute: 55)
        ), let drinkAt = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 26, hour: 19, minute: 54)
        ), let recordedID = UUID(uuidString: "10400000-0000-0000-0000-000000000001"),
        let activeID = UUID(uuidString: "10400000-0000-0000-0000-000000000002"),
        let foodID = UUID(uuidString: "10400000-0000-0000-0000-000000000010"),
        let drinkID = UUID(uuidString: "10400000-0000-0000-0000-000000000011")
        else { return }

        context.insert(FastRecord(
            id: recordedID,
            startDate: recordedStart,
            endDate: recordedEnd,
            goalAtStart: .default
        ))
        context.insert(FastRecord(id: activeID, startDate: activeStart, goalAtStart: .default))
        context.insert(FoodEntryRecord(
            id: foodID,
            draft: .init(description: "Label fixture food", occurredAt: foodAtEnd),
            createdAt: foodAtEnd
        ))
        context.insert(HydrationEntryRecord(
            id: drinkID,
            type: .custom,
            customName: "Label fixture drink",
            volumeMillilitres: 250,
            occurredAt: drinkAt,
            isCaloric: true,
            createdAt: drinkAt
        ))
        _ = clock
    }

    static func seedFoodFavouritePopulated(in context: ModelContext, clock: any AppClock) {
        guard let id = UUID(uuidString: "10300000-0000-0000-0000-000000000001") else { return }
        context.insert(FoodFavouriteRecord(
            id: id,
            description: "Overnight oats",
            nutrition: FoodNutrition(
                energyKilocalories: 420,
                proteinGrams: 20,
                carbohydrateGrams: 50,
                fatGrams: 12,
                fibreGrams: 8,
                sugarGrams: 0,
                saltGrams: 0
            ),
            createdAt: clock.now.addingTimeInterval(-120),
            creationOrder: 1
        ))
    }

    static func seedFoodFavouriteDuplicateName(in context: ModelContext, clock: any AppClock) {
        context.insert(FoodFavouriteRecord(
            description: "Café",
            nutrition: FoodNutrition(energyKilocalories: 2),
            createdAt: clock.now.addingTimeInterval(-60),
            creationOrder: 1
        ))
        context.insert(FoodFavouriteRecord(
            description: "CAFE",
            nutrition: FoodNutrition(energyKilocalories: 2),
            createdAt: clock.now,
            creationOrder: 2
        ))
    }

    static func seedFoodFavouriteValidation(in context: ModelContext, clock: any AppClock) {
        context.insert(FoodFavouriteRecord(
            description: " ",
            nutrition: FoodNutrition(energyKilocalories: -.infinity),
            createdAt: clock.now,
            creationOrder: 1
        ))
    }

    static func seedFoodFavouriteActiveFast(in context: ModelContext, clock: any AppClock) {
        seedFoodFavouritePopulated(in: context, clock: clock)
        context.insert(FastRecord(startDate: clock.now.addingTimeInterval(-3600), goalAtStart: .default))
    }
}
