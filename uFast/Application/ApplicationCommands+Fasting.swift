import Foundation

extension ApplicationCommands {
    func startFast(
        at startDate: Date? = nil,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) throws -> ApplicationCommandOutcome {
        let repository = activeFastRepository()
        let existingID = try repository.activeFast()?.id
        let service = FastStartService(repository: repository, clock: clock)
        let fast = try startDate.map { try service.startFast(at: $0, goal: goal) }
            ?? service.startFast(goal: goal)
        guard existingID == nil else {
            return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: false)
        }
        projectionCoordinator.enqueue(
            .activeFastStarted(fast: fast, goal: goal, now: clock.now),
            completion: completion
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func correctActiveFastStart(
        to startDate: Date,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) throws -> ApplicationCommandOutcome {
        let fast = try FastStartService(
            repository: activeFastRepository(),
            clock: clock
        ).correctActiveFastStart(to: startDate)
        projectionCoordinator.enqueue(
            .activeFastChanged(fast: fast, goal: goal, now: clock.now),
            completion: completion
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func hasStartConflict(startDate: Date, excluding excludedID: UUID?) throws -> Bool {
        try FastStartService(repository: activeFastRepository(), clock: clock)
            .hasConflict(startDate: startDate, excluding: excludedID)
    }

    func endFast(at endDate: Date? = nil, goal: FastingGoal) throws -> ApplicationCommandOutcome {
        let service = FastEndService(repository: activeFastRepository(), clock: clock)
        let fast = try endDate.map { try service.endFast(at: $0, goal: goal) }
            ?? service.endFast(goal: goal)
        guard let fast else {
            return ApplicationCommandOutcome(recordID: nil, projectionEnqueued: false)
        }
        projectionCoordinator.enqueue(.fastEndedOrDeleted)
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func updateCompletedFast(id: UUID, startDate: Date, endDate: Date) throws {
        _ = try CompletedFastService(
            repository: completedFastRepository(),
            clock: clock
        ).update(id: id, startDate: startDate, endDate: endDate)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func completedFastValidationError(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> CompletedFastError? {
        try CompletedFastService(
            repository: completedFastRepository(),
            clock: clock
        ).validationError(id: id, startDate: startDate, endDate: endDate)
    }

    func deleteCompletedFast(id: UUID) throws {
        try CompletedFastService(repository: completedFastRepository(), clock: clock).delete(id: id)
        projectionCoordinator.publishHistoryInvalidation()
    }
}
