import Foundation
import SwiftData

@MainActor
struct SwiftDataHistoryInvalidator {
    let modelContext: ModelContext

    func invalidate(for mutation: CaloricEventMutation) throws -> [InvalidatedFast] {
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
            let invalidated = InvalidatedFast(fast: fast, snapshot: fast.provenanceSnapshot)
            fast.markNeedsReview()
            return invalidated
        }
    }

    func restore(_ invalidated: [InvalidatedFast]) {
        invalidated.forEach { $0.fast.restoreProvenance($0.snapshot) }
    }
}

struct InvalidatedFast {
    let fast: FastRecord
    let snapshot: FastRecordProvenanceSnapshot
}
