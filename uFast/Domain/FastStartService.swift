import Foundation

@MainActor
protocol ActiveFastRepository: CaloricBoundaryQuerying {
    func activeFast() throws -> FastRecord?
    func recordedFasts() throws -> [FastRecord]
    func hasRecordedFastConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID?
    ) throws -> Bool
    func saveNewActiveFast(_ fast: FastRecord) throws
    func updateStartDate(of fast: FastRecord, to startDate: Date) throws
    func complete(_ fast: FastRecord, at endDate: Date, goal: FastingGoal) throws
}

extension ActiveFastRepository {
    func hasRecordedFastConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID?
    ) throws -> Bool {
        try FastConflictChecker.hasConflict(
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            excluding: excludedID,
            among: recordedFasts().map(\.recordedInterval)
        )
    }
}

enum FastStartError: Error, Equatable {
    case futureStartTime
    case noActiveFast
    case startTimeBeyondMaximumAge
    case conflict
    case crossesCaloricBoundary(Date)
}

@MainActor
final class FastStartService {
    /// The inclusive elapsed-time window for both manual starts and active-start corrections.
    static let maximumStartAge: TimeInterval = 36 * 60 * 60

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
        try validate(startDate: startDate)
        try validateCaloricBoundary(startDate: startDate)

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
        try validate(startDate: startDate)
        try validateCaloricBoundary(startDate: startDate)
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
        try repository.hasRecordedFastConflict(
            proposedStart: startDate,
            proposedEnd: nil,
            excluding: excludedID
        )
    }

    private func validate(startDate: Date) throws {
        let now = clock.now
        guard startDate <= now else {
            throw FastStartError.futureStartTime
        }
        guard startDate >= now.addingTimeInterval(-Self.maximumStartAge) else {
            throw FastStartError.startTimeBeyondMaximumAge
        }
    }

    private func validateCaloricBoundary(startDate: Date) throws {
        guard let boundary = try repository.earliestCaloricBoundary(after: startDate) else { return }
        throw FastStartError.crossesCaloricBoundary(boundary.occurredAt)
    }
}
