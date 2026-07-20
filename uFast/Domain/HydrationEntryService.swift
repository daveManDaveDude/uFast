import Foundation

enum HydrationEntrySaveError: Error, Equatable {
    case confirmationRequired
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

    func save(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool = false
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
