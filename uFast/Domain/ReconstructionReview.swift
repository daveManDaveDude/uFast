import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_body_length function_parameter_count

enum ReconstructionReviewChoice: Equatable, Sendable {
    case accept
    case adjust(startDate: Date, endDate: Date)
    case leaveUnknown
}

struct ReviewedReconstruction: Equatable, Sendable {
    let result: ReconstructionResult
    let choice: ReconstructionReviewChoice
}

enum ReconstructionReviewValidationError: Error, Equatable {
    case unavailableChoice
    case outsideSupportingBoundaries
    case nonPositiveDuration
    case savedHistoryConflict
    case incompleteReview
}

struct ValidatedReconstructionOutcome: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case fast(startDate: Date, endDate: Date, adjusted: Bool)
        case unknown(reason: UnknownPeriodReason)
    }

    let candidate: ReconstructionCandidate
    let kind: Kind
}

enum ReconstructionReviewValidator {
    static func validate(
        reviewed: [ReviewedReconstruction],
        expectedResults: [ReconstructionResult],
        savedFasts: [RecordedFastInterval]
    ) throws -> [ValidatedReconstructionOutcome] {
        let expectedCandidates = expectedResults.compactMap(\.candidate)
        guard reviewed.count == expectedCandidates.count else {
            throw ReconstructionReviewValidationError.incompleteReview
        }

        var outcomes: [ValidatedReconstructionOutcome] = []
        var intervals = savedFasts
        for item in reviewed {
            guard let candidate = item.result.candidate,
                  expectedCandidates.contains(candidate)
            else {
                throw ReconstructionReviewValidationError.incompleteReview
            }

            switch (item.result, item.choice) {
            case (.proposal, .accept):
                try appendFast(
                    candidate: candidate,
                    startDate: candidate.startDate,
                    endDate: candidate.endDate,
                    adjusted: false,
                    intervals: &intervals,
                    outcomes: &outcomes
                )
            case let (.proposal, .adjust(startDate, endDate)):
                guard startDate >= candidate.startDate, endDate <= candidate.endDate else {
                    throw ReconstructionReviewValidationError.outsideSupportingBoundaries
                }
                try appendFast(
                    candidate: candidate,
                    startDate: startDate,
                    endDate: endDate,
                    adjusted: true,
                    intervals: &intervals,
                    outcomes: &outcomes
                )
            case (.proposal, .leaveUnknown):
                outcomes.append(
                    ValidatedReconstructionOutcome(
                        candidate: candidate,
                        kind: .unknown(reason: .userChoice)
                    )
                )
            case (.blocked(_, .savedHistoryConflict), .leaveUnknown):
                outcomes.append(
                    ValidatedReconstructionOutcome(
                        candidate: candidate,
                        kind: .unknown(reason: .savedHistoryConflict)
                    )
                )
            default:
                throw ReconstructionReviewValidationError.unavailableChoice
            }
        }
        return outcomes
    }

    private static func appendFast(
        candidate: ReconstructionCandidate,
        startDate: Date,
        endDate: Date,
        adjusted: Bool,
        intervals: inout [RecordedFastInterval],
        outcomes: inout [ValidatedReconstructionOutcome]
    ) throws {
        guard startDate < endDate else {
            throw ReconstructionReviewValidationError.nonPositiveDuration
        }
        guard !FastConflictChecker.hasConflict(
            proposedStart: startDate,
            proposedEnd: endDate,
            among: intervals
        ) else {
            throw ReconstructionReviewValidationError.savedHistoryConflict
        }
        let id = UUID()
        intervals.append(RecordedFastInterval(id: id, startDate: startDate, endDate: endDate))
        outcomes.append(
            ValidatedReconstructionOutcome(
                candidate: candidate,
                kind: .fast(startDate: startDate, endDate: endDate, adjusted: adjusted)
            )
        )
    }
}
