import Foundation

enum CaloricEventSaveDecision: Equatable {
    case saveWithoutEndingFast
    case requiresEndingActiveFast
    case invalidAtActiveFastStart
}

enum CaloricEventConfirmationKind: Equatable, Sendable {
    case active
    case completed
    case inferred
}

struct CaloricEventConfirmationContext: Equatable, Sendable {
    let kind: CaloricEventConfirmationKind
    let affectedPersistedFastCount: Int
    let includesReconstructedReview: Bool
    let includesInferredInterval: Bool

    init(
        persistedImpact: CaloricEventImpact = .none,
        fallbackKind: CaloricEventConfirmationKind = .inferred,
        includesInferredInterval: Bool = false
    ) {
        kind = if persistedImpact.affectsActiveFast {
            .active
        } else if persistedImpact.requiresConfirmation {
            .completed
        } else {
            fallbackKind
        }
        affectedPersistedFastCount = persistedImpact.affectedPersistedFastCount
        includesReconstructedReview = !persistedImpact.reconstructedReviewIDs.isEmpty
        self.includesInferredInterval = includesInferredInterval
    }

    var isCombined: Bool {
        affectedPersistedFastCount > 0 && includesInferredInterval
    }

    func includingInferredInterval() -> Self {
        Self(
            kind: kind,
            affectedPersistedFastCount: affectedPersistedFastCount,
            includesReconstructedReview: includesReconstructedReview,
            includesInferredInterval: true
        )
    }

    private init(
        kind: CaloricEventConfirmationKind,
        affectedPersistedFastCount: Int,
        includesReconstructedReview: Bool,
        includesInferredInterval: Bool
    ) {
        self.kind = kind
        self.affectedPersistedFastCount = affectedPersistedFastCount
        self.includesReconstructedReview = includesReconstructedReview
        self.includesInferredInterval = includesInferredInterval
    }
}

enum CaloricEventSavePolicy {
    static func decision(
        isCaloric: Bool,
        occurredAt: Date,
        activeFastStart: Date?
    ) -> CaloricEventSaveDecision {
        guard isCaloric, let activeFastStart else {
            return .saveWithoutEndingFast
        }
        if occurredAt == activeFastStart {
            return .invalidAtActiveFastStart
        }
        if occurredAt > activeFastStart {
            return .requiresEndingActiveFast
        }
        return .saveWithoutEndingFast
    }
}

enum FoodEntrySaveError: Error, Equatable {
    case confirmationRequiredWithImpact(CaloricEventConfirmationContext)
    case completedConfirmationWithImpact(CaloricEventConfirmationContext)
    case inferredConfirmationWithImpact(CaloricEventConfirmationContext)
    case eventAtActiveFastStart
    case fastConflict
}

@MainActor
final class FoodEntryService {
    private let repository: any FoodEntryRepository
    private let clock: any AppClock

    init(repository: any FoodEntryRepository, clock: any AppClock) {
        self.repository = repository
        self.clock = clock
    }

    // swiftlint:disable:next function_body_length
    func save(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool = false,
        recordID: UUID? = nil
    ) throws {
        let impact = try repository.caloricEventImpact(
            for: draft,
            replacing: record,
            recordID: recordID
        )
        let activeFast = try repository.activeFast()
        let decision = CaloricEventSavePolicy.decision(
            isCaloric: draft.isCaloric,
            occurredAt: draft.occurredAt,
            activeFastStart: activeFast?.startDate
        )
        switch decision {
        case .invalidAtActiveFastStart:
            throw FoodEntrySaveError.eventAtActiveFastStart
        case .requiresEndingActiveFast where !endingActiveFast:
            throw FoodEntrySaveError.confirmationRequiredWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: impact,
                    fallbackKind: .active
                )
            )
        case .saveWithoutEndingFast where impact.requiresConfirmation && !endingActiveFast:
            throw FoodEntrySaveError.completedConfirmationWithImpact(
                CaloricEventConfirmationContext(persistedImpact: impact)
            )
        default:
            break
        }
        if let confirmationError = confirmationError(
            for: impact,
            endingActiveFast: endingActiveFast
        ) {
            throw confirmationError
        }
        if endingActiveFast, let activeFast, decision == .requiresEndingActiveFast {
            if let record {
                try repository.update(
                    record,
                    with: draft,
                    at: clock.now,
                    ending: activeFast,
                    goal: goal
                )
            } else {
                _ = try repository.create(
                    draft,
                    at: clock.now,
                    ending: activeFast,
                    goal: goal,
                    recordID: recordID
                )
            }
        } else {
            try repository.saveCaloricEvent(
                draft,
                replacing: record,
                goal: goal,
                recordID: recordID
            )
        }
    }

    private func confirmationError(
        for impact: CaloricEventImpact,
        endingActiveFast: Bool
    ) -> FoodEntrySaveError? {
        guard impact.requiresConfirmation, !endingActiveFast else { return nil }
        return impact.affectsActiveFast
            ? .confirmationRequiredWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: impact,
                    fallbackKind: .active
                )
            )
            : .completedConfirmationWithImpact(
                CaloricEventConfirmationContext(persistedImpact: impact)
            )
    }
}
