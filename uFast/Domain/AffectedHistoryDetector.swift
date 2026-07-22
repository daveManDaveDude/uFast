import Foundation

struct CaloricEventMutation: Equatable, Sendable {
    let reference: CaloricBoundaryReference
    let resultingOccurredAt: Date?
    let resultingIsCaloric: Bool

    static func deletion(_ reference: CaloricBoundaryReference) -> Self {
        Self(reference: reference, resultingOccurredAt: nil, resultingIsCaloric: false)
    }
}

struct ReconstructedHistorySnapshot: Equatable, Sendable {
    let id: UUID
    let interval: Range<Date>
    let boundaries: ReconstructionBoundaryPair
}

enum AffectedHistoryDetector {
    static func affectedIDs(
        mutation: CaloricEventMutation,
        reconstructed: [ReconstructedHistorySnapshot]
    ) -> Set<UUID> {
        Set(reconstructed.compactMap { fast in
            let directlyReferenced = fast.boundaries.start == mutation.reference ||
                fast.boundaries.end == mutation.reference
            let liesStrictlyInside = mutation.resultingIsCaloric &&
                mutation.resultingOccurredAt.map {
                    $0 > fast.interval.lowerBound && $0 < fast.interval.upperBound
                } == true
            return directlyReferenced || liesStrictlyInside ? fast.id : nil
        })
    }
}
