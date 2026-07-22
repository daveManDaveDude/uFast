import Foundation
import SwiftData

// swiftlint:disable trailing_comma

enum HealthAuthorizationFixtureState: CaseIterable {
    case unavailable
    case notDetermined
    case denied
    case authorized
    case revoked
}

enum PreviewFixtures {
    private struct PreviewDrink {
        let type: HydrationDrinkType
        let name: String?
        let volume: Int
    }

    static let utc = TimeZone(secondsFromGMT: 0) ?? .current
    static let london = TimeZone(identifier: "Europe/London") ?? utc
    static let newYork = TimeZone(identifier: "America/New_York") ?? utc

    static let beforeLondonSpringClockChange = Date(
        timeIntervalSince1970: 1_774_742_200
    )
    static let afterLondonSpringClockChange = Date(
        timeIntervalSince1970: 1_774_749_400
    )
    static let todayTimelineNow = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    static var modelContainer: ModelContainer {
        do {
            let container = try PersistenceContainer.make(inMemory: true)
            container.mainContext.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            return container
        } catch {
            fatalError("Unable to create preview persistence: \(error)")
        }
    }

    @MainActor
    static var emptyModelContainer: ModelContainer {
        do {
            return try PersistenceContainer.make(inMemory: true)
        } catch {
            fatalError("Unable to create empty preview persistence: \(error)")
        }
    }

    @MainActor
    static var completedFastModelContainer: ModelContainer {
        do {
            let container = try PersistenceContainer.make(inMemory: true)
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            container.mainContext.insert(
                AppSettingsRecord(hasCompletedOnboarding: true)
            )
            container.mainContext.insert(
                FastRecord(
                    startDate: now.addingTimeInterval(-13 * 60 * 60),
                    endDate: now,
                    goalAtStart: .default
                )
            )
            let start = FoodEntryRecord(
                draft: .init(
                    description: "Dinner",
                    occurredAt: now.addingTimeInterval(-40 * 60 * 60)
                ),
                createdAt: now.addingTimeInterval(-40 * 60 * 60)
            )
            let end = FoodEntryRecord(
                draft: .init(
                    description: "Breakfast",
                    occurredAt: now.addingTimeInterval(-28 * 60 * 60)
                ),
                createdAt: now.addingTimeInterval(-28 * 60 * 60)
            )
            container.mainContext.insert(start)
            container.mainContext.insert(end)
            let pair = ReconstructionBoundaryPair(
                start: .init(kind: .food, id: start.id),
                end: .init(kind: .food, id: end.id)
            )
            let needsReview = FastRecord(
                reconstructedStart: start.occurredAt,
                endDate: end.occurredAt,
                boundaries: pair,
                adjustedByUser: true
            )
            needsReview.markNeedsReview()
            container.mainContext.insert(needsReview)
            container.mainContext.insert(
                UnknownPeriodRecord(
                    startDate: now.addingTimeInterval(-26 * 60 * 60),
                    endDate: now.addingTimeInterval(-18 * 60 * 60),
                    boundaries: .init(
                        start: .init(kind: .food, id: UUID()),
                        end: .init(kind: .hydration, id: UUID())
                    ),
                    reason: .userChoice,
                    createdAt: now
                )
            )
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Unable to create completed-fast preview persistence: \(error)")
        }
    }

    @MainActor
    static var todayTimelineModelContainer: ModelContainer {
        makeTodayTimelineModelContainer(foodCount: 2, drinkCount: 2)
    }

    @MainActor
    static var longTodayTimelineModelContainer: ModelContainer {
        makeTodayTimelineModelContainer(foodCount: 7, drinkCount: 6)
    }

    @MainActor
    static var activeFastTodayTimelineModelContainer: ModelContainer {
        makeTodayTimelineModelContainer(foodCount: 2, drinkCount: 2, hasActiveFast: true)
    }

    @MainActor
    private static func makeTodayTimelineModelContainer(
        foodCount: Int,
        drinkCount: Int,
        hasActiveFast: Bool = false
    ) -> ModelContainer {
        do {
            let container = try PersistenceContainer.make(inMemory: true)
            container.mainContext.insert(AppSettingsRecord(hasCompletedOnboarding: true))

            if hasActiveFast {
                container.mainContext.insert(
                    FastRecord(
                        startDate: todayTimelineNow.addingTimeInterval(-4 * 60 * 60),
                        goalAtStart: .default
                    )
                )
            }

            insertPreviewFoods(foodCount, into: container)
            insertPreviewDrinks(drinkCount, into: container)

            try container.mainContext.save()
            return container
        } catch {
            fatalError("Unable to create Today preview persistence: \(error)")
        }
    }

    @MainActor
    private static func insertPreviewFoods(_ count: Int, into container: ModelContainer) {
        let foods = [
            "Porridge and berries",
            "Vegetable soup and bread",
            "Apple and peanut butter",
            "Rice, tofu and greens",
            "Yoghurt with seeds",
            "Tomato pasta",
            "Banana",
        ]
        for index in 0 ..< count {
            let occurredAt = todayTimelineNow.addingTimeInterval(TimeInterval(-index * 37 * 60))
            container.mainContext.insert(
                FoodEntryRecord(
                    draft: FoodEntryDraft(
                        description: foods[index % foods.count],
                        occurredAt: occurredAt,
                        nutrition: FoodNutrition(energyKilocalories: Double(240 + index * 35))
                    ),
                    createdAt: occurredAt
                )
            )
        }
    }

    @MainActor
    private static func insertPreviewDrinks(_ count: Int, into container: ModelContainer) {
        let drinks = [
            PreviewDrink(type: .water, name: nil, volume: 500),
            PreviewDrink(type: .tea, name: nil, volume: 300),
            PreviewDrink(type: .custom, name: "Coconut water", volume: 330),
            PreviewDrink(type: .coffee, name: nil, volume: 300),
        ]
        for index in 0 ..< count {
            let drink = drinks[index % drinks.count]
            let occurredAt = todayTimelineNow.addingTimeInterval(TimeInterval(-(index * 41 + 12) * 60))
            container.mainContext.insert(
                HydrationEntryRecord(
                    type: drink.type,
                    customName: drink.name,
                    volumeMillilitres: drink.volume,
                    occurredAt: occurredAt,
                    isCaloric: drink.type == .custom,
                    createdAt: occurredAt
                )
            )
        }
    }
}
