import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_body_length

enum CaloricBoundaryKind: String, CaseIterable, Hashable, Sendable {
    case food
    case hydration
}

struct CaloricBoundaryReference: Hashable, Sendable {
    let kind: CaloricBoundaryKind
    let id: UUID
}

struct CaloricBoundary: Equatable, Hashable, Sendable {
    let reference: CaloricBoundaryReference
    let occurredAt: Date
    let description: String
}

struct FoodBoundarySnapshot: Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let description: String
    let isCaloric: Bool
}

struct HydrationBoundarySnapshot: Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let description: String
    let isCaloric: Bool
}

enum CaloricBoundaryExtractor {
    static func boundaries(
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
        return ReconstructionProposalGenerator.sortedBoundaries(
            foodBoundaries + hydrationBoundaries
        )
    }
}

struct ReconstructionBoundaryPair: Equatable, Hashable, Sendable {
    let start: CaloricBoundaryReference
    let end: CaloricBoundaryReference
}

struct ReconstructionCandidate: Equatable, Hashable, Sendable {
    let pair: ReconstructionBoundaryPair
    let startBoundary: CaloricBoundary
    let endBoundary: CaloricBoundary

    var startDate: Date {
        startBoundary.occurredAt
    }

    var endDate: Date {
        endBoundary.occurredAt
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

enum ReconstructionBlockedReason: String, Equatable, Hashable, Sendable {
    case savedHistoryConflict
}

enum ReconstructionRangeEdge: String, Equatable, Hashable, Sendable {
    case start
    case end
}

enum ReconstructionResult: Equatable, Hashable, Sendable {
    case proposal(ReconstructionCandidate)
    case blocked(ReconstructionCandidate, reason: ReconstructionBlockedReason)
    case insufficientEdge(ReconstructionRangeEdge)

    var candidate: ReconstructionCandidate? {
        switch self {
        case let .proposal(candidate), let .blocked(candidate, _): candidate
        case .insufficientEdge: nil
        }
    }
}

struct ReconstructionGeneration: Equatable, Sendable {
    let results: [ReconstructionResult]
    let caloricBoundaryCount: Int
    let qualifyingPairCount: Int
    let suppressedPairCount: Int
}

enum ReconstructionProposalGenerator {
    static let minimumDuration: TimeInterval = 8 * 60 * 60

    static func generate(
        range: Range<Date>,
        boundaries: [CaloricBoundary],
        savedFasts: [RecordedFastInterval],
        representedPairs: Set<ReconstructionBoundaryPair> = []
    ) -> ReconstructionGeneration {
        let sorted = sortedBoundaries(boundaries)
        var relevant = sorted.filter { range.contains($0.occurredAt) }
        if let before = sorted.last(where: { $0.occurredAt < range.lowerBound }) {
            relevant.insert(before, at: 0)
        }
        if let after = sorted.first(where: { $0.occurredAt >= range.upperBound }) {
            relevant.append(after)
        }

        var results: [ReconstructionResult] = []
        var qualifyingPairCount = 0
        var suppressedPairCount = 0

        for (start, end) in zip(relevant, relevant.dropFirst()) {
            guard start.reference != end.reference,
                  start.occurredAt < end.occurredAt,
                  start.occurredAt < range.upperBound,
                  end.occurredAt > range.lowerBound
            else { continue }

            let candidate = ReconstructionCandidate(
                pair: ReconstructionBoundaryPair(
                    start: start.reference,
                    end: end.reference
                ),
                startBoundary: start,
                endBoundary: end
            )
            guard candidate.duration >= minimumDuration else { continue }
            qualifyingPairCount += 1

            if representedPairs.contains(candidate.pair) {
                suppressedPairCount += 1
                continue
            }

            if FastConflictChecker.hasConflict(
                proposedStart: candidate.startDate,
                proposedEnd: candidate.endDate,
                among: savedFasts
            ) {
                results.append(.blocked(candidate, reason: .savedHistoryConflict))
            } else {
                results.append(.proposal(candidate))
            }
        }

        if !sorted.contains(where: { $0.occurredAt < range.lowerBound }) {
            results.insert(.insufficientEdge(.start), at: 0)
        }
        if !sorted.contains(where: { $0.occurredAt >= range.upperBound }) {
            results.append(.insufficientEdge(.end))
        }

        return ReconstructionGeneration(
            results: results,
            caloricBoundaryCount: sorted.count,
            qualifyingPairCount: qualifyingPairCount,
            suppressedPairCount: suppressedPairCount
        )
    }

    static func sortedBoundaries(_ boundaries: [CaloricBoundary]) -> [CaloricBoundary] {
        boundaries.sorted {
            if $0.occurredAt != $1.occurredAt {
                return $0.occurredAt < $1.occurredAt
            }
            if $0.reference.kind != $1.reference.kind {
                return $0.reference.kind.rawValue < $1.reference.kind.rawValue
            }
            return $0.reference.id.uuidString < $1.reference.id.uuidString
        }
    }
}
