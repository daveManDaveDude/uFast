import Foundation
import SwiftData

struct HistoryFastSnapshot: Equatable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let capturedHistoricalGoal: FastingGoal?
    let origin: FastOrigin?
    let reviewState: FastReviewState?
    let presentationIntegrity: FastRecordPresentationIntegrity
    let boundaryPair: ReconstructionBoundaryPair?

    init(_ record: FastRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
        capturedHistoricalGoal = record.capturedHistoricalGoal
        origin = record.origin
        reviewState = record.reviewState
        presentationIntegrity = record.presentationIntegrity
        boundaryPair = record.boundaryPair
    }

    var recordedInterval: RecordedFastInterval {
        RecordedFastInterval(id: id, startDate: startDate, endDate: endDate)
    }
}

struct HistoryDataSlice: Equatable {
    let window: DateInterval
    let completedFasts: [HistoryFastSnapshot]
    let activeFast: HistoryFastSnapshot?
    let foods: [FoodEntrySnapshot]
    let drinks: [HydrationEntrySnapshot]
    let settings: AppSettingsSnapshot?

    var projectionInputCount: Int {
        completedFasts.count + (activeFast == nil ? 0 : 1) + foods.count + drinks.count
    }
}

enum HistoryMotionWindow {
    static let dayRadius = 7

    static func interval(
        centeredOn date: Date,
        maximumDate: Date,
        calendar: Calendar
    ) -> DateInterval? {
        let selectedDay = calendar.startOfDay(for: date)
        let maximumDay = calendar.startOfDay(for: maximumDate)
        guard let start = calendar.date(byAdding: .day, value: -dayRadius, to: selectedDay),
              let proposedLastDay = calendar.date(byAdding: .day, value: dayRadius, to: selectedDay),
              let end = calendar.date(
                  byAdding: .day,
                  value: 1,
                  to: min(proposedLastDay, maximumDay)
              ),
              start < end
        else { return nil }
        return DateInterval(start: start, end: end)
    }
}

@MainActor
final class SwiftDataHistoryDataProvider {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(window: DateInterval) throws -> HistoryDataSlice {
        let completed = try completedFasts(intersecting: window).map(HistoryFastSnapshot.init)
        let active = try ActiveFastAuthority.fetch(in: modelContext).map(HistoryFastSnapshot.init)
        let settings = try SwiftDataSettingsStore(modelContext: modelContext)
            .authoritativeRecord().map(AppSettingsSnapshot.init)
        let visibleFoods = try foods(in: window)
        let visibleDrinks = try drinks(in: window)
        let neighbours = try nearestCaloricNeighbours(outside: window)
        return HistoryDataSlice(
            window: window,
            completedFasts: completed,
            activeFast: active,
            foods: appendUnique(visibleFoods, neighbours.foods).map(FoodEntrySnapshot.init),
            drinks: appendUnique(visibleDrinks, neighbours.drinks).map(HydrationEntrySnapshot.init),
            settings: settings
        )
    }

    private func completedFasts(intersecting window: DateInterval) throws -> [FastRecord] {
        let lower = window.start
        let upper = window.end
        let distantPast = Date.distantPast
        let descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.endDate != nil
                    && $0.startDate < upper
                    && ($0.endDate ?? distantPast) > lower
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func foods(in window: DateInterval) throws -> [FoodEntryRecord] {
        let lower = window.start
        let upper = window.end
        return try modelContext.fetch(FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lower && $0.occurredAt < upper },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
    }

    private func drinks(in window: DateInterval) throws -> [HydrationEntryRecord] {
        let lower = window.start
        let upper = window.end
        return try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lower && $0.occurredAt < upper },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
    }

    private func nearestCaloricNeighbours(
        outside window: DateInterval
    ) throws -> (foods: [FoodEntryRecord], drinks: [HydrationEntryRecord]) {
        let beforeFoods = try caloricFoods(before: window.start, order: .reverse)
        let beforeDrinks = try caloricDrinks(before: window.start, order: .reverse)
        let afterFoods = try caloricFoods(after: window.end, order: .forward)
        let afterDrinks = try caloricDrinks(after: window.end, order: .forward)
        let before = nearestFoodOrDrink(foods: beforeFoods, drinks: beforeDrinks, latest: true)
        let after = nearestFoodOrDrink(foods: afterFoods, drinks: afterDrinks, latest: false)
        return (
            [before.food, after.food].compactMap(\.self),
            [before.drink, after.drink].compactMap(\.self)
        )
    }

    private func caloricFoods(before date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricFoods(after date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(before date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(after date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func nearestFoodOrDrink(
        foods: [FoodEntryRecord],
        drinks: [HydrationEntryRecord],
        latest: Bool
    ) -> (food: FoodEntryRecord?, drink: HydrationEntryRecord?) {
        guard let food = foods.first else { return (nil, drinks.first) }
        guard let drink = drinks.first else { return (food, nil) }
        let foodWins = latest ? food.occurredAt >= drink.occurredAt : food.occurredAt <= drink.occurredAt
        return foodWins ? (food, nil) : (nil, drink)
    }

    private func appendUnique<Record: Identifiable>(
        _ visible: [Record],
        _ neighbours: [Record]
    ) -> [Record] where Record.ID: Hashable {
        var identifiers = Set(visible.map(\.id))
        return visible + neighbours.filter { identifiers.insert($0.id).inserted }
    }
}
