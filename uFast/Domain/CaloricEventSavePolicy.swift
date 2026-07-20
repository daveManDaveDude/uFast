import Foundation

enum CaloricEventSaveDecision: Equatable {
    case saveWithoutEndingFast
    case requiresEndingActiveFast
    case invalidAtActiveFastStart
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

    func save(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        endingActiveFast: Bool = false
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
