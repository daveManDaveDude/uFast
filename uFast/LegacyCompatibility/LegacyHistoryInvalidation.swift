import Foundation
import SwiftData

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

@MainActor
struct LegacyHistoryInvalidator {
    let modelContext: ModelContext

    func invalidate(for mutation: CaloricEventMutation) throws -> [InvalidatedLegacyFast] {
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        let reconstructed = fasts.compactMap { fast -> ReconstructedHistorySnapshot? in
            guard fast.origin == .reconstructed,
                  let endDate = fast.endDate,
                  let boundaries = fast.boundaryPair
            else { return nil }
            return ReconstructedHistorySnapshot(
                id: fast.id,
                interval: fast.startDate ..< endDate,
                boundaries: boundaries
            )
        }
        let affected = AffectedHistoryDetector.affectedIDs(
            mutation: mutation,
            reconstructed: reconstructed
        )
        return fasts.compactMap { fast in
            guard affected.contains(fast.id), fast.reviewState != .needsReview else { return nil }
            let invalidated = InvalidatedLegacyFast(fast: fast, snapshot: fast.provenanceSnapshot)
            fast.markNeedsReview()
            return invalidated
        }
    }

    func restore(_ invalidated: [InvalidatedLegacyFast]) {
        invalidated.forEach { $0.fast.restoreProvenance($0.snapshot) }
    }
}

struct InvalidatedLegacyFast {
    let fast: FastRecord
    let snapshot: FastRecordProvenanceSnapshot
}
