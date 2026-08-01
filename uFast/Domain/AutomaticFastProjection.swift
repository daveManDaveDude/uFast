import Foundation

/// Stable identity for a derived interval. It deliberately retains the two
/// saved event references instead of inventing a persisted fast identifier.
struct AutomaticFastIdentity: Hashable, Sendable {
    let boundaries: ReconstructionBoundaryPair
}

struct AutomaticFastInterval: Equatable, Sendable {
    let identity: AutomaticFastIdentity
    let startDate: Date
    let endDate: Date

    var interval: Range<Date> {
        startDate ..< endDate
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

enum AutomaticFastProjector {
    static let minimumDuration: TimeInterval = 8 * 60 * 60

    /// Projects only intervals that intersect `visibleInterval`. `boundaries`
    /// is the complete caloric ordering (including neighbours outside the
    /// viewport), so an edge never becomes an invented fasting boundary.
    static func project(
        boundaries: [CaloricBoundary],
        visibleInterval: Range<Date>,
        excluding recordedFasts: [RecordedFastInterval] = []
    ) -> [AutomaticFastInterval] {
        let ordered = ReconstructionProposalGenerator.sortedBoundaries(boundaries)
        return zip(ordered, ordered.dropFirst()).compactMap { start, end -> AutomaticFastInterval? in
            guard start.occurredAt < end.occurredAt else { return nil }
            let interval = start.occurredAt ..< end.occurredAt
            guard end.occurredAt.timeIntervalSince(start.occurredAt) > minimumDuration,
                  intersects(interval, visibleInterval),
                  !recordedFasts.contains(where: { overlaps(interval, $0) })
            else { return nil }
            return AutomaticFastInterval(
                identity: AutomaticFastIdentity(
                    boundaries: ReconstructionBoundaryPair(
                        start: start.reference,
                        end: end.reference
                    )
                ),
                startDate: start.occurredAt,
                endDate: end.occurredAt
            )
        }
    }

    static func isReproducibleLegacy(
        startDate: Date,
        endDate: Date,
        boundaries pair: ReconstructionBoundaryPair?,
        caloricBoundaries: [CaloricBoundary]
    ) -> Bool {
        guard let pair else { return false }
        return project(
            boundaries: caloricBoundaries,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        ).contains {
            $0.identity.boundaries == pair
                && $0.startDate == startDate
                && $0.endDate == endDate
        }
    }

    static func intersects(_ lhs: Range<Date>, _ rhs: Range<Date>) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private static func overlaps(_ interval: Range<Date>, _ fast: RecordedFastInterval) -> Bool {
        let endsAfterStart = fast.endDate.map { interval.lowerBound < $0 } ?? true
        return endsAfterStart && fast.startDate < interval.upperBound
    }
}
