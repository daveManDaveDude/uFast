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

private func historyFastContextWindow(
    for window: DateInterval,
    goal: FastingGoal?
) -> DateInterval {
    // A candidate can begin one maximum-duration before the visible window and
    // can extend one maximum-duration beyond it. Keep those recorded fasts as
    // projection context while the settled builder still filters by `window`.
    guard let goal else { return window }
    let candidateExtent = InferredFastProjector.maximumDuration(for: goal)
    return DateInterval(
        start: window.start.addingTimeInterval(-candidateExtent),
        end: window.end.addingTimeInterval(candidateExtent)
    )
}

@MainActor
final class SwiftDataHistoryDataProvider {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetch(window: DateInterval) throws -> HistoryDataSlice {
        let active = try ActiveFastAuthority.fetch(in: modelContext).map(HistoryFastSnapshot.init)
        let settings = try SwiftDataSettingsStore(modelContext: modelContext)
            .authoritativeRecord().map(AppSettingsSnapshot.init)
        let completed = try completedFasts(
            intersecting: historyFastContextWindow(for: window, goal: settings?.fastingGoal)
        ).map(HistoryFastSnapshot.init)
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
        let inferredContexts = chunks.compactMap(\.presentation.inferredContext)
        let inferredContext = inferredContexts.first.map { first in
            HistoryMotionInferredContext(
                foodEvents: inferredContexts
                    .flatMap(\.foodEvents)
                    .reduce(into: [UUID: FoodBoundarySnapshot]()) { result, event in
                        result[event.id] = event
                    }
                    .values
                    .sorted { $0.occurredAt < $1.occurredAt },
                recordedFasts: inferredContexts
                    .flatMap(\.recordedFasts)
                    .reduce(into: [UUID: RecordedFastInterval]()) { result, fast in
                        result[fast.id] = fast
                    }
                    .values
                    .sorted { $0.startDate < $1.startDate },
                currentGoal: first.currentGoal,
                enabled: first.enabled
            )
        }
        return HistoryMotionPresentation(
            window: window,
            intervals: intervals.sorted { $0.start < $1.start },
            events: events.sorted { $0.occurredAt < $1.occurredAt },
            inferredContext: inferredContext
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
        let beforeFoods = try foodEvents(before: window.start, order: .reverse)
        let beforeDrinks = try caloricDrinks(before: window.start, order: .reverse)
        let afterFoods = try foodEvents(after: window.end, order: .forward)
        let afterDrinks = try caloricDrinks(after: window.end, order: .forward)
        return (
            [beforeFoods.first, afterFoods.first].compactMap(\.self),
            [beforeDrinks.first, afterDrinks.first].compactMap(\.self)
        )
    }

    private func foodEvents(before date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func foodEvents(after date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= date },
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
        let settingsRecords = try modelContext.fetch(FetchDescriptor<AppSettingsRecord>())
        let settings = settingsRecords.count == 1
            ? settingsRecords.first.map(AppSettingsSnapshot.init)
            : nil
        let fastContextWindow = historyFastContextWindow(for: window, goal: settings?.fastingGoal)
        let fastContextLower = fastContextWindow.start
        let fastContextUpper = fastContextWindow.end
        let completed = try modelContext.fetch(FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.endDate != nil
                    && $0.startDate < fastContextUpper
                    && ($0.endDate ?? distantPast) > fastContextLower
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
            settings: settings
        )
    }

    private func nearestCaloricNeighbours(
        outside window: DateInterval
    ) throws -> (foods: [FoodEntryRecord], drinks: [HydrationEntryRecord]) {
        let beforeFoods = try foodEvents(before: window.start, order: .reverse)
        let beforeDrinks = try caloricDrinks(before: window.start, order: .reverse)
        let afterFoods = try foodEvents(after: window.end, order: .forward)
        let afterDrinks = try caloricDrinks(after: window.end, order: .forward)
        return (
            [beforeFoods.first, afterFoods.first].compactMap(\.self),
            [beforeDrinks.first, afterDrinks.first].compactMap(\.self)
        )
    }

    private func foodEvents(before date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: order), SortDescriptor(\.id, order: order)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func foodEvents(after date: Date, order: SortOrder) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= date },
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
        return HistoryMotionChunk(
            coverage: coverage,
            presentation: HistoryMotionPresentation(
                exact,
                inferredContext: HistoryMotionInferredContext(data: data)
            )
        )
    }
}
