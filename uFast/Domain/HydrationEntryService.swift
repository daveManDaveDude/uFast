import Foundation

enum HydrationEntrySaveError: Error, Equatable {
    case confirmationRequiredWithImpact(CaloricEventConfirmationContext)
    case completedConfirmationWithImpact(CaloricEventConfirmationContext)
    case inferredConfirmationWithImpact(CaloricEventConfirmationContext)
    case eventAtActiveFastStart
    case fastConflict
}

@MainActor
final class HydrationEntryService {
    private let repository: any HydrationEntryRepository
    private let clock: any AppClock

    init(repository: any HydrationEntryRepository, clock: any AppClock) {
        self.repository = repository
        self.clock = clock
    }

    // swiftlint:disable:next function_body_length
    func save(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
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
    ) -> HydrationEntrySaveError? {
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
