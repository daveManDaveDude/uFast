import Foundation

@MainActor
protocol ActiveFastRepository {
    func activeFast() throws -> FastRecord?
    func saveNewActiveFast(_ fast: FastRecord) throws
}

@MainActor
final class FastStartService {
    private let repository: any ActiveFastRepository
    private let clock: any AppClock

    init(
        repository: any ActiveFastRepository,
        clock: any AppClock
    ) {
        self.repository = repository
        self.clock = clock
    }

    func startFast(goal: FastingGoal) throws -> FastRecord {
        if let activeFast = try repository.activeFast() {
            return activeFast
        }

        let fast = FastRecord(
            startDate: clock.now,
            goalAtStart: goal
        )
        try repository.saveNewActiveFast(fast)
        return fast
    }
}
