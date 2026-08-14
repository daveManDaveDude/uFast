import Foundation
import SwiftData

struct HistoryFastSnapshot: Equatable {
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

/// Compact value returned for one visual runway chunk.  The SwiftData models
/// are converted to value snapshots before leaving the provider boundary.
/// `data` is intentionally the same projection input used by settled History;
/// the coordinator owns the compact, immutable presentation assembled from
/// these values and never retains model objects.
struct HistoryMotionChunk: Equatable, Sendable {
    let coverage: HistoryMotionCoverage
    let presentation: HistoryMotionPresentation
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

    /// Merge adjacent chunks by stable identity.  This is used before building
    /// a presentation so an event or fast crossing a seam is projected once,
    /// with recorded-fast precedence unchanged from the settled builder.
    nonisolated static func mergeMotionChunks(
        _ chunks: [HistoryMotionChunk],
        window: DateInterval
    ) -> HistoryMotionPresentation? {
        guard !chunks.isEmpty else { return nil }
        var intervals: [HistoryMotionIntervalPrimitive] = []
        var events: [HistoryMotionEventPrimitive] = []
        var intervalIDs = Set<UUID>()
        var eventIDs = Set<UUID>()
        for chunk in chunks {
            for interval in chunk.presentation.intervals where intervalIDs.insert(interval.id).inserted {
                intervals.append(interval)
            }
            for event in chunk.presentation.events where eventIDs.insert(event.id).inserted {
                events.append(event)
            }
        }
        return HistoryMotionPresentation(
            window: window,
            intervals: intervals.sorted { $0.start < $1.start },
            events: events.sorted { $0.occurredAt < $1.occurredAt }
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
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricFoods(after date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(before date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(after date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
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
        let foodBoundary = CaloricBoundary(
            reference: .init(kind: .food, id: food.id),
            occurredAt: food.occurredAt,
            description: ""
        )
        let drinkBoundary = CaloricBoundary(
            reference: .init(kind: .hydration, id: drink.id),
            occurredAt: drink.occurredAt,
            description: ""
        )
        let foodPrecedes = CaloricBoundaryOrdering.precedes(foodBoundary, drinkBoundary)
        let foodWins = latest ? !foodPrecedes : foodPrecedes
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

/// Motion-only provider. It avoids the settled fetch boundary, but shares the
/// pure `ActiveFastAuthority` resolver so the independent context applies the
/// same zero/one/many rule. It returns value snapshots only.
final class SwiftDataHistoryMotionDataProvider {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(window: DateInterval, calendar _: Calendar) throws -> HistoryDataSlice {
        let lower = window.start
        let upper = window.end
        let distantPast = Date.distantPast
        let completed = try modelContext.fetch(FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.endDate != nil
                    && $0.startDate < upper
                    && ($0.endDate ?? distantPast) > lower
            },
            sortBy: [SortDescriptor(\.startDate)]
        )).map(HistoryFastSnapshot.init)
        let activeCandidates = try modelContext.fetch(FetchDescriptor<FastRecord>(
            predicate: #Predicate { $0.endDate == nil }
        ))
        let active = try ActiveFastAuthority.resolve(activeCandidates)
            .map(HistoryFastSnapshot.init)
        let foods = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lower && $0.occurredAt < upper },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
        let drinks = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lower && $0.occurredAt < upper },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
        let neighbours = try nearestCaloricNeighbours(outside: window)
        return HistoryDataSlice(
            window: window,
            completedFasts: completed,
            activeFast: active,
            foods: appendUnique(foods, neighbours.foods).map(FoodEntrySnapshot.init),
            drinks: appendUnique(drinks, neighbours.drinks).map(HydrationEntrySnapshot.init),
            settings: nil
        )
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
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricFoods(after date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(before date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func caloricDrinks(after date: Date, order: SortOrder) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt >= date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
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
        let foodBoundary = CaloricBoundary(
            reference: .init(kind: .food, id: food.id),
            occurredAt: food.occurredAt,
            description: ""
        )
        let drinkBoundary = CaloricBoundary(
            reference: .init(kind: .hydration, id: drink.id),
            occurredAt: drink.occurredAt,
            description: ""
        )
        let foodPrecedes = CaloricBoundaryOrdering.precedes(foodBoundary, drinkBoundary)
        let foodWins = latest ? !foodPrecedes : foodPrecedes
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

enum HistoryMotionChunkError: Error, Equatable, Sendable {
    case invalidCoverage
}

/// Background-safe range loader. The actor creates its own ModelContext from
/// the container and returns only Sendable value snapshots; SwiftData model
/// objects never cross into the History view.
actor SwiftDataHistoryMotionRangeLoader {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func merge(
        _ chunks: [HistoryMotionChunk],
        window: DateInterval
    ) -> HistoryMotionPresentation? {
        SwiftDataHistoryDataProvider.mergeMotionChunks(chunks, window: window)
    }

    func load(
        coverage: HistoryMotionCoverage,
        calendar: Calendar,
        referenceNow: Date
    ) async throws -> HistoryMotionChunk {
        let context = ModelContext(container)
        guard let window = coverage.visualWindow(calendar: calendar) else {
            throw HistoryMotionChunkError.invalidCoverage
        }
        let data = try SwiftDataHistoryMotionDataProvider(modelContext: context)
            .fetch(window: window, calendar: calendar)
        let exact = HistoryPresentationBuilder.build(
            data: data,
            locale: calendar.locale ?? Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: calendar.timeZone,
            referenceNow: referenceNow
        )
        return HistoryMotionChunk(coverage: coverage, presentation: HistoryMotionPresentation(exact))
    }
}
