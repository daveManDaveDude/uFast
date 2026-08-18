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
    case confirmationRequired
    case confirmationRequiredWithImpact(CaloricEventConfirmationContext)
    case completedFastConfirmationRequired
    case completedConfirmationWithImpact(CaloricEventConfirmationContext)
    case inferredFastConfirmationRequired
    case inferredConfirmationWithImpact(CaloricEventConfirmationContext)
    case eventAtActiveFastStart
    case fastConflict

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.confirmationRequired, .confirmationRequired),
             (.confirmationRequiredWithImpact, .confirmationRequiredWithImpact),
             (.confirmationRequired, .confirmationRequiredWithImpact),
             (.confirmationRequiredWithImpact, .confirmationRequired):
            true
        case (.completedFastConfirmationRequired, .completedFastConfirmationRequired),
             (.completedConfirmationWithImpact, .completedConfirmationWithImpact),
             (.completedFastConfirmationRequired, .completedConfirmationWithImpact),
             (.completedConfirmationWithImpact, .completedFastConfirmationRequired):
            true
        case (.inferredFastConfirmationRequired, .inferredFastConfirmationRequired),
             (.inferredConfirmationWithImpact, .inferredConfirmationWithImpact),
             (.inferredFastConfirmationRequired, .inferredConfirmationWithImpact),
             (.inferredConfirmationWithImpact, .inferredFastConfirmationRequired):
            true
        case (.eventAtActiveFastStart, .eventAtActiveFastStart), (.fastConflict, .fastConflict):
            true
        default:
            false
        }
    }
}

@MainActor
final class FoodEntryService {
    private let repository: any FoodEntryRepository
    private let clock: any AppClock

    init(repository: any FoodEntryRepository, clock: any AppClock) {
        self.repository = repository
        self.clock = clock
    }

    func save(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool = false
    ) throws {
        if let boundaryAwareRepository = repository as? any CaloricBoundaryAwareFoodEntryRepository {
            try saveWithBoundaryAwareRepository(
                boundaryAwareRepository,
                draft,
                replacing: record,
                goal: goal,
                endingActiveFast: endingActiveFast
            )
            return
        }

        try saveWithBasicRepository(
            draft,
            replacing: record,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
    }

    private func saveWithBoundaryAwareRepository(
        _ repository: any CaloricBoundaryAwareFoodEntryRepository,
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        let impact = try repository.caloricEventImpact(for: draft, replacing: record)
        let activeFastStart = try self.repository.activeFast()?.startDate
        switch CaloricEventSavePolicy.decision(
            isCaloric: draft.isCaloric,
            occurredAt: draft.occurredAt,
            activeFastStart: activeFastStart
        ) {
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
        if impact.requiresConfirmation, !endingActiveFast {
            throw impact.affectsActiveFast
                ? FoodEntrySaveError.confirmationRequiredWithImpact(
                    CaloricEventConfirmationContext(
                        persistedImpact: impact,
                        fallbackKind: .active
                    )
                )
                : FoodEntrySaveError.completedConfirmationWithImpact(
                    CaloricEventConfirmationContext(persistedImpact: impact)
                )
        }
        try repository.saveCaloricEvent(draft, replacing: record, goal: goal)
    }

    private func saveWithBasicRepository(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        let activeFast = try repository.activeFast()
        let decision = CaloricEventSavePolicy.decision(
            isCaloric: draft.isCaloric,
            occurredAt: draft.occurredAt,
            activeFastStart: activeFast?.startDate
        )

        switch decision {
        case .saveWithoutEndingFast:
            try saveEvent(draft, replacing: record)
        case .invalidAtActiveFastStart:
            throw FoodEntrySaveError.eventAtActiveFastStart
        case .requiresEndingActiveFast:
            guard endingActiveFast, let activeFast else {
                throw FoodEntrySaveError.confirmationRequired
            }
            guard try !hasFastConflict(activeFast: activeFast, endDate: draft.occurredAt) else {
                throw FoodEntrySaveError.fastConflict
            }
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
                    goal: goal
                )
            }
        }
    }

    private func saveEvent(_ draft: FoodEntryDraft, replacing record: FoodEntryRecord?) throws {
        if let record {
            try repository.update(record, with: draft, at: clock.now)
        } else {
            _ = try repository.create(draft, at: clock.now)
        }
    }

    private func hasFastConflict(activeFast: FastRecord, endDate: Date) throws -> Bool {
        let intervals = try repository.recordedFasts().map(\.recordedInterval)
        return FastConflictChecker.hasConflict(
            proposedStart: activeFast.startDate,
            proposedEnd: endDate,
            excluding: activeFast.id,
            among: intervals
        )
    }
}
