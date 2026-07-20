import Foundation

@MainActor
protocol ActiveFastRepository {
    func activeFast() throws -> FastRecord?
    func recordedFasts() throws -> [FastRecord]
    func saveNewActiveFast(_ fast: FastRecord) throws
    func updateStartDate(of fast: FastRecord, to startDate: Date) throws
    func complete(_ fast: FastRecord, at endDate: Date, goal: FastingGoal) throws
}

enum FastStartError: Error, Equatable {
    case futureStartTime
    case noActiveFast
    case startTimeBeyondCorrectionLimit
    case conflict
}

@MainActor
final class FastStartService {
    static let maximumCorrectionAge: TimeInterval = 24 * 60 * 60

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
        try startFast(at: clock.now, goal: goal)
    }

    func startFast(at startDate: Date, goal: FastingGoal) throws -> FastRecord {
        guard startDate <= clock.now else {
            throw FastStartError.futureStartTime
        }

        if let activeFast = try repository.activeFast() {
            return activeFast
        }

        guard try !hasConflict(startDate: startDate) else {
            throw FastStartError.conflict
        }

        let fast = FastRecord(
            startDate: startDate,
            goalAtStart: goal
        )
        try repository.saveNewActiveFast(fast)
        return fast
    }

    func correctActiveFastStart(to startDate: Date) throws -> FastRecord {
        guard startDate <= clock.now else {
            throw FastStartError.futureStartTime
        }
        guard startDate >= clock.now.addingTimeInterval(-Self.maximumCorrectionAge) else {
            throw FastStartError.startTimeBeyondCorrectionLimit
        }
        guard let activeFast = try repository.activeFast() else {
            throw FastStartError.noActiveFast
        }
        guard try !hasConflict(startDate: startDate, excluding: activeFast.id) else {
            throw FastStartError.conflict
        }

        try repository.updateStartDate(of: activeFast, to: startDate)
        return activeFast
    }

    func hasConflict(
        startDate: Date,
        excluding excludedID: UUID? = nil
    ) throws -> Bool {
        let intervals = try repository.recordedFasts().map(\.recordedInterval)
        return FastConflictChecker.hasConflict(
            proposedStart: startDate,
            proposedEnd: nil,
            excluding: excludedID,
            among: intervals
        )
    }
}
