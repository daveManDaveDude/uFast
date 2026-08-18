import Foundation

public enum CaloricBoundaryKind: String, CaseIterable, Hashable, Sendable {
    case food
    case hydration
}

public struct CaloricBoundaryReference: Hashable, Sendable {
    public let kind: CaloricBoundaryKind
    public let id: UUID

    public init(kind: CaloricBoundaryKind, id: UUID) {
        self.kind = kind
        self.id = id
    }
}

public struct CaloricBoundary: Equatable, Hashable, Sendable {
    public let reference: CaloricBoundaryReference
    public let occurredAt: Date
    public let description: String

    public init(reference: CaloricBoundaryReference, occurredAt: Date, description: String) {
        self.reference = reference
        self.occurredAt = occurredAt
        self.description = description
    }
}

public struct FoodBoundarySnapshot: Equatable, Sendable {
    public let id: UUID
    public let occurredAt: Date
    public let description: String
    public let isCaloric: Bool

    public init(id: UUID, occurredAt: Date, description: String, isCaloric: Bool) {
        self.id = id
        self.occurredAt = occurredAt
        self.description = description
        self.isCaloric = isCaloric
    }
}

public struct HydrationBoundarySnapshot: Equatable, Sendable {
    public let id: UUID
    public let occurredAt: Date
    public let description: String
    public let isCaloric: Bool

    public init(id: UUID, occurredAt: Date, description: String, isCaloric: Bool) {
        self.id = id
        self.occurredAt = occurredAt
        self.description = description
        self.isCaloric = isCaloric
    }
}

public enum CaloricBoundaryOrdering {
    public static func precedes(_ lhs: CaloricBoundary, _ rhs: CaloricBoundary) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }
        if lhs.reference.kind != rhs.reference.kind {
            return lhs.reference.kind.rawValue < rhs.reference.kind.rawValue
        }
        return lhs.reference.id.uuidString < rhs.reference.id.uuidString
    }

    public static func sorted(_ boundaries: [CaloricBoundary]) -> [CaloricBoundary] {
        boundaries.sorted(by: precedes)
    }
}

public enum CaloricBoundaryExtractor {
    public static func boundaries(
        food: [FoodBoundarySnapshot],
        hydration: [HydrationBoundarySnapshot]
    ) -> [CaloricBoundary] {
        let foodBoundaries = food.filter(\.isCaloric).map {
            CaloricBoundary(
                reference: CaloricBoundaryReference(kind: .food, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.description
            )
        }
        let hydrationBoundaries = hydration.filter(\.isCaloric).map {
            CaloricBoundary(
                reference: CaloricBoundaryReference(kind: .hydration, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.description
            )
        }
        return CaloricBoundaryOrdering.sorted(foodBoundaries + hydrationBoundaries)
    }
}

public struct CaloricBoundaryPair: Equatable, Hashable, Sendable {
    public let start: CaloricBoundaryReference
    public let end: CaloricBoundaryReference

    public init(start: CaloricBoundaryReference, end: CaloricBoundaryReference) {
        self.start = start
        self.end = end
    }
}

public struct RecordedFastInterval: Equatable, Sendable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?

    public init(id: UUID, startDate: Date, endDate: Date?) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// Shared absolute-time boundary queries used by inferred presentation,
/// persisted-fast reconciliation and fast-side validation.
public enum CaloricBoundaryQuery {
    public static func earliestBoundary(
        after startDate: Date,
        in boundaries: [CaloricBoundary]
    ) -> CaloricBoundary? {
        CaloricBoundaryOrdering.sorted(boundaries).first {
            $0.occurredAt > startDate
        }
    }

    public static func earliestBoundary(
        after startDate: Date,
        before endDate: Date,
        in boundaries: [CaloricBoundary]
    ) -> CaloricBoundary? {
        earliestBoundary(after: startDate, in: boundaries).flatMap {
            $0.occurredAt < endDate ? $0 : nil
        }
    }

    public static func firstBlockingOpenBoundary(
        after startDate: Date,
        in boundaries: [CaloricBoundary]
    ) -> CaloricBoundary? {
        earliestBoundary(after: startDate, in: boundaries)
    }

    public static func firstBlockingEndBoundary(
        after startDate: Date,
        proposedEndDate: Date,
        in boundaries: [CaloricBoundary]
    ) -> CaloricBoundary? {
        guard let boundary = earliestBoundary(after: startDate, in: boundaries),
              proposedEndDate > boundary.occurredAt
        else { return nil }
        return boundary
    }
}

public enum FastConflictChecker {
    public static func hasConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID? = nil,
        among intervals: [RecordedFastInterval]
    ) -> Bool {
        intervals.contains { interval in
            guard interval.id != excludedID else { return false }
            let startsBeforeExistingEnd = interval.endDate.map { proposedStart < $0 } ?? true
            let existingStartsBeforeEnd = proposedEnd.map { interval.startDate < $0 } ?? true
            return startsBeforeExistingEnd && existingStartsBeforeEnd
        }
    }
}

public struct AutomaticFastIdentity: Hashable, Sendable {
    public let boundaries: CaloricBoundaryPair

    public init(boundaries: CaloricBoundaryPair) {
        self.boundaries = boundaries
    }
}

public struct AutomaticFastInterval: Equatable, Sendable {
    public let identity: AutomaticFastIdentity
    public let startDate: Date
    public let endDate: Date
    public var interval: Range<Date> {
        startDate ..< endDate
    }

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public init(identity: AutomaticFastIdentity, startDate: Date, endDate: Date) {
        self.identity = identity
        self.startDate = startDate
        self.endDate = endDate
    }
}

public enum AutomaticFastProjector {
    public static let minimumDuration: TimeInterval = 8 * 60 * 60

    public static func project(
        boundaries: [CaloricBoundary],
        visibleInterval: Range<Date>,
        excluding recordedFasts: [RecordedFastInterval] = []
    ) -> [AutomaticFastInterval] {
        let ordered = CaloricBoundaryOrdering.sorted(boundaries)
        return zip(ordered, ordered.dropFirst()).compactMap { start, end in
            guard start.occurredAt < end.occurredAt else { return nil }
            let interval = start.occurredAt ..< end.occurredAt
            guard end.occurredAt.timeIntervalSince(start.occurredAt) > minimumDuration,
                  intersects(interval, visibleInterval),
                  !recordedFasts.contains(where: { overlaps(interval, $0) })
            else { return nil }
            return AutomaticFastInterval(
                identity: AutomaticFastIdentity(
                    boundaries: CaloricBoundaryPair(start: start.reference, end: end.reference)
                ),
                startDate: start.occurredAt,
                endDate: end.occurredAt
            )
        }
    }

    public static func isExactProjection(
        startDate: Date,
        endDate: Date,
        boundaries pair: CaloricBoundaryPair?,
        caloricBoundaries: [CaloricBoundary]
    ) -> Bool {
        guard let pair else { return false }
        return project(
            boundaries: caloricBoundaries,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        ).contains {
            $0.identity.boundaries == pair && $0.startDate == startDate && $0.endDate == endDate
        }
    }

    public static func intersects(_ lhs: Range<Date>, _ rhs: Range<Date>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func overlaps(_ interval: Range<Date>, _ fast: RecordedFastInterval) -> Bool {
        let endsAfterStart = fast.endDate.map { interval.lowerBound < $0 } ?? true
        return endsAfterStart && fast.startDate < interval.upperBound
    }
}
