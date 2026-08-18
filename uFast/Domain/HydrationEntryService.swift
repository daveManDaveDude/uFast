import Foundation

enum HydrationEntrySaveError: Error, Equatable {
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
final class HydrationEntryService {
    private let repository: any HydrationEntryRepository
    private let clock: any AppClock

    init(repository: any HydrationEntryRepository, clock: any AppClock) {
        self.repository = repository
        self.clock = clock
    }

    func save(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool = false
    ) throws {
        if let boundaryAwareRepository = repository as? any CaloricHydrationRepository {
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
        _ repository: any CaloricHydrationRepository,
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
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
            throw HydrationEntrySaveError.eventAtActiveFastStart
        case .requiresEndingActiveFast where !endingActiveFast:
            throw HydrationEntrySaveError.confirmationRequiredWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: impact,
                    fallbackKind: .active
                )
            )
        case .saveWithoutEndingFast where impact.requiresConfirmation && !endingActiveFast:
            throw HydrationEntrySaveError.completedConfirmationWithImpact(
                CaloricEventConfirmationContext(persistedImpact: impact)
            )
        default:
            break
        }
        if impact.requiresConfirmation, !endingActiveFast {
            throw impact.affectsActiveFast
                ? HydrationEntrySaveError.confirmationRequiredWithImpact(
                    CaloricEventConfirmationContext(
                        persistedImpact: impact,
                        fallbackKind: .active
                    )
                )
                : HydrationEntrySaveError.completedConfirmationWithImpact(
                    CaloricEventConfirmationContext(persistedImpact: impact)
                )
        }
        try repository.saveCaloricEvent(draft, replacing: record, goal: goal)
    }

    private func saveWithBasicRepository(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        let activeFast = try repository.activeFast()
        switch CaloricEventSavePolicy.decision(
            isCaloric: draft.isCaloric,
            occurredAt: draft.occurredAt,
            activeFastStart: activeFast?.startDate
        ) {
        case .saveWithoutEndingFast:
            if let record {
                try repository.update(record, with: draft, at: clock.now)
            } else {
                _ = try repository.create(draft, at: clock.now)
            }
        case .invalidAtActiveFastStart:
            throw HydrationEntrySaveError.eventAtActiveFastStart
        case .requiresEndingActiveFast:
            guard endingActiveFast, let activeFast else {
                throw HydrationEntrySaveError.confirmationRequired
            }
            let intervals = try repository.recordedFasts().map(\.recordedInterval)
            guard !FastConflictChecker.hasConflict(
                proposedStart: activeFast.startDate,
                proposedEnd: draft.occurredAt,
                excluding: activeFast.id,
                among: intervals
            ) else { throw HydrationEntrySaveError.fastConflict }
            if let record {
                try repository.update(record, with: draft, at: clock.now, ending: activeFast, goal: goal)
            } else {
                _ = try repository.create(draft, at: clock.now, ending: activeFast, goal: goal)
            }
        }
    }
}
