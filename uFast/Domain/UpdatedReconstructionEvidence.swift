import Foundation

enum UpdatedEvidenceUnavailableReason: Equatable, Sendable {
    case missingSupportingEntry
    case noQualifyingInterval
    case conflictingHistory
    case ambiguousEvidence

    var explanation: String {
        switch self {
        case .missingSupportingEntry:
            "A supporting entry is no longer caloric or available."
        case .noQualifyingInterval:
            "The changed entries no longer support an eight-hour reconstructed fast."
        case .conflictingHistory:
            "The updated evidence overlaps another saved or active fast."
        case .ambiguousEvidence:
            "The changed entries support more than one possible interval."
        }
    }
}

enum UpdatedReconstructionEvidence: Equatable, Sendable {
    case available(ReconstructionCandidate)
    case unavailable(UpdatedEvidenceUnavailableReason)
}

enum UpdatedReconstructionEvidenceResolver {
    static func resolve(
        savedInterval: Range<Date>,
        originalPair: ReconstructionBoundaryPair,
        boundaries: [CaloricBoundary],
        otherFasts: [RecordedFastInterval]
    ) -> UpdatedReconstructionEvidence {
        let sorted = ReconstructionProposalGenerator.sortedBoundaries(boundaries)
        let originalReferences = Set([originalPair.start, originalPair.end])
        let related = zip(sorted, sorted.dropFirst()).compactMap { start, end -> ReconstructionCandidate? in
            guard start.occurredAt < end.occurredAt,
                  originalReferences.contains(start.reference) || originalReferences.contains(end.reference),
                  start.occurredAt < savedInterval.upperBound,
                  end.occurredAt > savedInterval.lowerBound
            else { return nil }
            return ReconstructionCandidate(
                pair: .init(start: start.reference, end: end.reference),
                startBoundary: start,
                endBoundary: end
            )
        }
        let qualifying = related.filter {
            $0.duration >= ReconstructionProposalGenerator.minimumDuration
        }
        let valid = qualifying.filter {
            !FastConflictChecker.hasConflict(
                proposedStart: $0.startDate,
                proposedEnd: $0.endDate,
                among: otherFasts
            )
        }

        if valid.count == 1, let candidate = valid.first {
            return .available(candidate)
        }
        if valid.count > 1 {
            return .unavailable(.ambiguousEvidence)
        }
        if !qualifying.isEmpty {
            return .unavailable(.conflictingHistory)
        }
        if related.isEmpty {
            return .unavailable(.missingSupportingEntry)
        }
        return .unavailable(.noQualifyingInterval)
    }
}
