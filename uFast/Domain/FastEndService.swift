import Foundation

enum FastEndError: Error, Equatable {
    case endTimeNotAfterStart
    case futureEndTime
}

@MainActor
final class FastEndService {
    private let repository: any ActiveFastRepository
    private let clock: any AppClock

    init(
        repository: any ActiveFastRepository,
        clock: any AppClock
    ) {
        self.repository = repository
        self.clock = clock
    }

    @discardableResult
    func endFast(goal: FastingGoal) throws -> FastRecord? {
        let confirmationTime = clock.now
        return try endFast(
            at: confirmationTime,
            goal: goal,
            currentTime: confirmationTime
        )
    }

    @discardableResult
    func endFast(at endDate: Date, goal: FastingGoal) throws -> FastRecord? {
        try endFast(
            at: endDate,
            goal: goal,
            currentTime: clock.now
        )
    }

    private func endFast(
        at endDate: Date,
        goal: FastingGoal,
        currentTime: Date
    ) throws -> FastRecord? {
        guard let activeFast = try repository.activeFast() else {
            return nil
        }
        guard endDate > activeFast.startDate else {
            throw FastEndError.endTimeNotAfterStart
        }
        guard endDate <= currentTime else {
            throw FastEndError.futureEndTime
        }

        try repository.complete(activeFast, at: endDate, goal: goal)
        return activeFast
    }
}
