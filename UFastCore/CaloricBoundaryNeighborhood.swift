import Foundation

/// The persistence-independent description of one bounded boundary request.
/// It is deliberately semantic: SwiftData adapters translate these bounds into
/// predicates, while pure tests can use the same request description against a
/// full-history oracle.
public enum BoundaryQueryEntity: String, Equatable, Sendable {
    case food
    case hydration
    case fast
    case reconstructedFast
}

public struct BoundaryQueryObservation: Equatable, Sendable {
    public let entity: BoundaryQueryEntity
    public let lowerBound: Date?
    public let upperBound: Date?
    public let lowerInclusive: Bool
    public let upperInclusive: Bool
    public let sortKeys: [String]
    public let fetchLimit: Int?
    public let returnedCount: Int

    public init(
        entity: BoundaryQueryEntity,
        lowerBound: Date? = nil,
        upperBound: Date? = nil,
        lowerInclusive: Bool = false,
        upperInclusive: Bool = false,
        sortKeys: [String] = [],
        fetchLimit: Int? = nil,
        returnedCount: Int
    ) {
        self.entity = entity
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.lowerInclusive = lowerInclusive
        self.upperInclusive = upperInclusive
        self.sortKeys = sortKeys
        self.fetchLimit = fetchLimit
        self.returnedCount = returnedCount
    }
}

public protocol BoundaryQueryObservationSink: AnyObject {
    func record(_ observation: BoundaryQueryObservation)
}

public final class NoOpBoundaryQueryObservationSink: BoundaryQueryObservationSink {
    public init() {}

    public func record(_: BoundaryQueryObservation) {}
}

public final class RecordingBoundaryQueryObservationSink: BoundaryQueryObservationSink {
    public private(set) var observations: [BoundaryQueryObservation] = []

    public init() {}

    public func record(_ observation: BoundaryQueryObservation) {
        observations.append(observation)
    }
}

/// A persisted-fast value used by the pure neighbourhood selector. The
/// optional end reference is enough to model reconstructed review lookups;
/// no SwiftData model or app presentation type crosses this boundary.
public struct BoundaryFastSnapshot: Equatable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let isReconstructed: Bool
    public let endReference: CaloricBoundaryReference?

    public init(
        id: UUID,
        startDate: Date,
        endDate: Date?,
        isReconstructed: Bool = false,
        endReference: CaloricBoundaryReference? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.isReconstructed = isReconstructed
        self.endReference = endReference
    }
}

public struct CaloricBoundaryNeighborhood: Equatable, Sendable {
    public let boundaries: [CaloricBoundary]
    public let fasts: [BoundaryFastSnapshot]

    public init(boundaries: [CaloricBoundary], fasts: [BoundaryFastSnapshot]) {
        self.boundaries = CaloricBoundaryOrdering.sorted(boundaries)
        self.fasts = fasts.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

/// Pure implementation of the settled mutation neighbourhood contract. The
/// SwiftData adapter uses the same selection rules, but executes each request
/// in storage rather than materialising the complete lifetime history.
public enum CaloricBoundaryNeighborhoodSelector {
    // The explicit parameter surface keeps the pure oracle independent of
    // SwiftData; callers inject the observation sink rather than a framework
    // context.
    // swiftlint:disable:next function_body_length function_parameter_count
    public static func eventNeighborhood(
        oldReference: CaloricBoundaryReference?,
        oldOccurredAt: Date?,
        newBoundary: CaloricBoundary?,
        goal: FastingGoal,
        food: [FoodBoundarySnapshot],
        hydration: [HydrationBoundarySnapshot],
        fasts: [BoundaryFastSnapshot],
        sink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) -> CaloricBoundaryNeighborhood {
        let dates = [oldOccurredAt, newBoundary?.occurredAt].compactMap(\.self)
        let allBoundaries = CaloricBoundaryExtractor.boundaries(food: food, hydration: hydration)
        var selected: [CaloricBoundary] = []

        for date in dates {
            let exact = allBoundaries.filter { $0.occurredAt == date }
            let predecessorLowerBound = date.addingTimeInterval(
                -InferredFastProjector.maximumDuration(for: goal)
            )
            record(
                sink,
                entity: .food,
                lower: date,
                upper: date,
                lowerInclusive: true,
                upperInclusive: true,
                sortKeys: ["occurredAt", "kind", "id"],
                fetchLimit: nil,
                returnedCount: exact.filter { $0.reference.kind == .food }.count
            )
            record(
                sink,
                entity: .hydration,
                lower: date,
                upper: date,
                lowerInclusive: true,
                upperInclusive: true,
                sortKeys: ["occurredAt", "kind", "id"],
                fetchLimit: nil,
                returnedCount: exact.filter { $0.reference.kind == .hydration }.count
            )
            selected.append(contentsOf: exact)

            for kind in CaloricBoundaryKind.allCases {
                let candidates = allBoundaries.filter {
                    $0.reference.kind == kind
                        && $0.occurredAt >= predecessorLowerBound
                        && $0.occurredAt < date
                }
                let nearest = candidates.max(by: CaloricBoundaryOrdering.precedes)
                record(
                    sink,
                    entity: kind == .food ? .food : .hydration,
                    lower: predecessorLowerBound,
                    upper: date,
                    lowerInclusive: true,
                    sortKeys: ["occurredAt.desc", "id"],
                    fetchLimit: 1,
                    returnedCount: nearest == nil ? 0 : 1
                )
                if let nearest {
                    selected.append(nearest)
                }
            }
        }

        selected.removeAll { $0.reference == oldReference }
        if let newBoundary {
            selected.append(newBoundary)
        }

        let predecessorLocations = selected
            .filter { boundary in
                dates.contains { date in boundary.occurredAt < date }
            }
            .map(\.occurredAt)
        let locations = Array(Set(dates + predecessorLocations)).sorted()
        let selectedFasts = fasts.filter { fast in
            let overlapsLocation = locations.contains { location in
                guard fast.startDate < location else { return false }
                return fast.endDate.map { $0 > location } ?? true
            }
            let referencesRemovedEnd = oldReference != nil
                && fast.isReconstructed
                && fast.endReference == oldReference
            return overlapsLocation || referencesRemovedEnd
        }
        for location in locations {
            let count = selectedFasts.filter {
                guard $0.startDate < location else { return false }
                return $0.endDate.map { $0 > location } ?? true
            }.count
            record(
                sink,
                entity: .fast,
                upper: location,
                lowerInclusive: false,
                upperInclusive: false,
                sortKeys: ["startDate", "id"],
                fetchLimit: nil,
                returnedCount: count
            )
        }
        if let oldReference {
            let count = selectedFasts.filter {
                $0.isReconstructed && $0.endReference == oldReference
            }.count
            record(
                sink,
                entity: .reconstructedFast,
                sortKeys: ["id"],
                fetchLimit: nil,
                returnedCount: count
            )
        }

        _ = goal // The goal bounds the inferred predecessor query in the storage adapter.
        return CaloricBoundaryNeighborhood(boundaries: selected, fasts: selectedFasts)
    }

    public static func earliestBoundary(
        after startDate: Date,
        food: [FoodBoundarySnapshot],
        hydration: [HydrationBoundarySnapshot],
        sink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) -> CaloricBoundary? {
        let boundaries = CaloricBoundaryExtractor.boundaries(food: food, hydration: hydration)
            .filter { $0.occurredAt > startDate }
        let result = boundaries.first
        record(
            sink,
            entity: .food,
            lower: startDate,
            lowerInclusive: false,
            sortKeys: ["occurredAt", "kind", "id"],
            fetchLimit: 1,
            returnedCount: boundaries.filter { $0.reference.kind == .food }.prefix(1).count
        )
        record(
            sink,
            entity: .hydration,
            lower: startDate,
            lowerInclusive: false,
            sortKeys: ["occurredAt", "kind", "id"],
            fetchLimit: 1,
            returnedCount: boundaries.filter { $0.reference.kind == .hydration }.prefix(1).count
        )
        return result
    }

    public static func firstBoundary(
        inside interval: Range<Date>,
        food: [FoodBoundarySnapshot],
        hydration: [HydrationBoundarySnapshot],
        sink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) -> CaloricBoundary? {
        let boundaries = CaloricBoundaryExtractor.boundaries(food: food, hydration: hydration)
            .filter { $0.occurredAt > interval.lowerBound && $0.occurredAt < interval.upperBound }
        let result = boundaries.first
        record(
            sink,
            entity: .food,
            lower: interval.lowerBound,
            upper: interval.upperBound,
            sortKeys: ["occurredAt", "kind", "id"],
            fetchLimit: 1,
            returnedCount: boundaries.filter { $0.reference.kind == .food }.prefix(1).count
        )
        record(
            sink,
            entity: .hydration,
            lower: interval.lowerBound,
            upper: interval.upperBound,
            sortKeys: ["occurredAt", "kind", "id"],
            fetchLimit: 1,
            returnedCount: boundaries.filter { $0.reference.kind == .hydration }.prefix(1).count
        )
        return result
    }

    public static func hasFastConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID? = nil,
        fasts: [BoundaryFastSnapshot],
        sink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) -> Bool {
        let conflict = fasts.first { fast in
            guard fast.id != excludedID else { return false }
            let startsBeforeExistingEnd = fast.endDate.map { proposedStart < $0 } ?? true
            let existingStartsBeforeEnd = proposedEnd.map { fast.startDate < $0 } ?? true
            return startsBeforeExistingEnd && existingStartsBeforeEnd
        }
        record(
            sink,
            entity: .fast,
            lower: proposedStart,
            upper: proposedEnd,
            sortKeys: ["startDate", "id"],
            fetchLimit: 1,
            returnedCount: conflict == nil ? 0 : 1
        )
        return conflict != nil
    }

    private static func record(
        _ sink: BoundaryQueryObservationSink,
        entity: BoundaryQueryEntity,
        lower: Date? = nil,
        upper: Date? = nil,
        lowerInclusive: Bool = false,
        upperInclusive: Bool = false,
        sortKeys: [String],
        fetchLimit: Int?,
        returnedCount: Int
    ) {
        sink.record(
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
