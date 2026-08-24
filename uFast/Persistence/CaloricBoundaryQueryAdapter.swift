import Foundation
import SwiftData

/// The only SwiftData-facing part of the bounded boundary contract. Each
/// method records the semantic request after applying its storage predicate;
/// callers can inject a recorder in tests and production uses the no-op sink.
@MainActor
// swiftlint:disable:next type_body_length
final class SwiftDataCaloricBoundaryQueryAdapter {
    private let modelContext: ModelContext
    private let observationSink: BoundaryQueryObservationSink

    init(
        modelContext: ModelContext,
        observationSink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) {
        self.modelContext = modelContext
        self.observationSink = observationSink
    }

    func food(id: UUID) throws -> FoodEntryRecordResolution {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 2
        let records = try modelContext.fetch(descriptor)
        observe(entity: .food, sortKeys: ["id"], fetchLimit: 2, returnedCount: records.count)
        switch records.count {
        case 0: return .missing
        case 1: return .unique(records[0])
        default: return .duplicate
        }
    }

    func hydration(id: UUID) throws -> HydrationEntryRecordResolution {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 2
        let records = try modelContext.fetch(descriptor)
        observe(entity: .hydration, sortKeys: ["id"], fetchLimit: 2, returnedCount: records.count)
        switch records.count {
        case 0: return .missing
        case 1: return .unique(records[0])
        default: return .duplicate
        }
    }

    func fast(id: UUID) throws -> FastRecordResolution {
        var descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 2
        let records = try modelContext.fetch(descriptor)
        observe(entity: .fast, sortKeys: ["id"], fetchLimit: 2, returnedCount: records.count)
        switch records.count {
        case 0: return .missing
        case 1: return .unique(records[0])
        default: return .duplicate
        }
    }

    func earliestFood(after date: Date) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt > date },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .food,
            lower: date,
            lowerInclusive: false,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: 1
        )
    }

    func earliestCaloricHydration(after date: Date) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt > date },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .hydration,
            lower: date,
            lowerInclusive: false,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: 1
        )
    }

    func firstFood(in interval: Range<Date>) throws -> [FoodEntryRecord] {
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate {
                $0.occurredAt > interval.lowerBound && $0.occurredAt < interval.upperBound
            },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .food,
            lower: interval.lowerBound,
            upper: interval.upperBound,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: 1
        )
    }

    func firstCaloricHydration(in interval: Range<Date>) throws -> [HydrationEntryRecord] {
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate {
                $0.isCaloric
                    && $0.occurredAt > interval.lowerBound
                    && $0.occurredAt < interval.upperBound
            },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .hydration,
            lower: interval.lowerBound,
            upper: interval.upperBound,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: 1
        )
    }

    func exactFood(at date: Date) throws -> [FoodEntryRecord] {
        let descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt == date },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        return try fetch(
            descriptor,
            entity: .food,
            lower: date,
            upper: date,
            lowerInclusive: true,
            upperInclusive: true,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: nil
        )
    }

    func exactCaloricHydration(at date: Date) throws -> [HydrationEntryRecord] {
        let descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt == date },
            sortBy: [SortDescriptor(\.occurredAt), SortDescriptor(\.id)]
        )
        return try fetch(
            descriptor,
            entity: .hydration,
            lower: date,
            upper: date,
            lowerInclusive: true,
            upperInclusive: true,
            sortKeys: ["occurredAt", "id"],
            fetchLimit: nil
        )
    }

    func nearestFood(before date: Date, notBefore lowerBound: Date? = nil) throws -> [FoodEntryRecord] {
        if let lowerBound {
            var descriptor = FetchDescriptor<FoodEntryRecord>(
                predicate: #Predicate {
                    $0.occurredAt >= lowerBound && $0.occurredAt < date
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.id)]
            )
            descriptor.fetchLimit = 1
            return try fetch(
                descriptor,
                entity: .food,
                lower: lowerBound,
                upper: date,
                lowerInclusive: true,
                sortKeys: ["occurredAt.desc", "id"],
                fetchLimit: 1
            )
        }
        var descriptor = FetchDescriptor<FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .food,
            upper: date,
            sortKeys: ["occurredAt.desc", "id"],
            fetchLimit: 1
        )
    }

    func nearestCaloricHydration(
        before date: Date,
        notBefore lowerBound: Date? = nil
    ) throws -> [HydrationEntryRecord] {
        if let lowerBound {
            var descriptor = FetchDescriptor<HydrationEntryRecord>(
                predicate: #Predicate {
                    $0.isCaloric
                        && $0.occurredAt >= lowerBound
                        && $0.occurredAt < date
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.id)]
            )
            descriptor.fetchLimit = 1
            return try fetch(
                descriptor,
                entity: .hydration,
                lower: lowerBound,
                upper: date,
                lowerInclusive: true,
                sortKeys: ["occurredAt.desc", "id"],
                fetchLimit: 1
            )
        }
        var descriptor = FetchDescriptor<HydrationEntryRecord>(
            predicate: #Predicate { $0.isCaloric && $0.occurredAt < date },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = 1
        return try fetch(
            descriptor,
            entity: .hydration,
            upper: date,
            sortKeys: ["occurredAt.desc", "id"],
            fetchLimit: 1
        )
    }

    func fasts(overlapping date: Date) throws -> [FastRecord] {
        let distantPast = Date.distantPast
        let descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.startDate < date
                    && ($0.endDate == nil || ($0.endDate ?? distantPast) > date)
            },
            sortBy: [SortDescriptor(\.startDate), SortDescriptor(\.id)]
        )
        return try fetch(
            descriptor,
            entity: .fast,
            upper: date,
            sortKeys: ["startDate", "id"],
            fetchLimit: nil
        )
    }

    func fasts(overlapping interval: Range<Date>) throws -> [FastRecord] {
        let distantPast = Date.distantPast
        let descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.startDate < interval.upperBound
                    && ($0.endDate == nil || ($0.endDate ?? distantPast) > interval.lowerBound)
            },
            sortBy: [SortDescriptor(\.startDate), SortDescriptor(\.id)]
        )
        return try fetch(
            descriptor,
            entity: .fast,
            lower: interval.lowerBound,
            upper: interval.upperBound,
            sortKeys: ["startDate", "id"],
            fetchLimit: nil
        )
    }

    func reconstructedFasts(endingWith reference: CaloricBoundaryReference) throws -> [FastRecord] {
        let kind = reference.kind.rawValue
        let id = reference.id
        let descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.originRaw == "reconstructed"
                    && $0.endBoundaryKindRaw == kind
                    && $0.endBoundaryID == id
            },
            sortBy: [SortDescriptor(\.id)]
        )
        return try fetch(
            descriptor,
            entity: .reconstructedFast,
            sortKeys: ["id"],
            fetchLimit: nil
        )
    }

    func hasFastConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID?
    ) throws -> Bool {
        let distantPast = Date.distantPast
        let excluded = excludedID ?? UUID()
        let end = proposedEnd ?? Date.distantFuture
        let descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate {
                $0.id != excluded
                    && $0.startDate < end
                    && ($0.endDate == nil || ($0.endDate ?? distantPast) > proposedStart)
            },
            sortBy: [SortDescriptor(\.startDate), SortDescriptor(\.id)]
        )
        var limited = descriptor
        limited.fetchLimit = 1
        let records = try modelContext.fetch(limited)
        observe(
            entity: .fast,
            lower: proposedStart,
            upper: proposedEnd,
            sortKeys: ["startDate", "id"],
            fetchLimit: 1,
            returnedCount: records.count
        )
        return !records.isEmpty
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        entity: BoundaryQueryEntity,
        lower: Date? = nil,
        upper: Date? = nil,
        lowerInclusive: Bool = false,
        upperInclusive: Bool = false,
        sortKeys: [String],
        fetchLimit: Int?
    ) throws -> [T] {
        let records = try modelContext.fetch(descriptor)
        observe(
            entity: entity,
            lower: lower,
            upper: upper,
            lowerInclusive: lowerInclusive,
            upperInclusive: upperInclusive,
            sortKeys: sortKeys,
            fetchLimit: fetchLimit,
            returnedCount: records.count
        )
        return records
    }

    private func observe(
        entity: BoundaryQueryEntity,
        lower: Date? = nil,
        upper: Date? = nil,
        lowerInclusive: Bool = false,
        upperInclusive: Bool = false,
        sortKeys: [String],
        fetchLimit: Int?,
        returnedCount: Int
    ) {
        observationSink.record(
            BoundaryQueryObservation(
                entity: entity,
                lowerBound: lower,
                upperBound: upper,
                lowerInclusive: lowerInclusive,
                upperInclusive: upperInclusive,
                sortKeys: sortKeys,
                fetchLimit: fetchLimit,
                returnedCount: returnedCount
            )
        )
    }
}

enum FoodEntryRecordResolution {
    case missing
    case unique(FoodEntryRecord)
    case duplicate
}

enum HydrationEntryRecordResolution {
    case missing
    case unique(HydrationEntryRecord)
    case duplicate
}

enum FastRecordResolution {
    case missing
    case unique(FastRecord)
    case duplicate
}
