import Foundation

enum CompletedFastOrdering {
    static func newestEndedFirst(_ fasts: [FastRecord]) -> [FastRecord] {
        fasts.sorted { first, second in
            guard first.endDate == second.endDate else {
                return (first.endDate ?? .distantPast) > (second.endDate ?? .distantPast)
            }
            return first.id.uuidString < second.id.uuidString
        }
    }
}

@MainActor
protocol CompletedFastRepository {
    func recordedFasts() throws -> [FastRecord]
    func updateCompletedFast(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> FastRecord
    func deleteCompletedFast(id: UUID) throws
}

@MainActor
protocol CompletedFastCreationRepository: CompletedFastRepository {
    func saveCompletedFast(_ fast: FastRecord) throws
}

enum CompletedFastError: Error, Equatable {
    case startTimeNotBeforeEndTime
    case futureStartTime
    case futureEndTime
    case conflict
    case noCompletedFast
    case crossesCaloricBoundary(Date)
}

@MainActor
final class CompletedFastService {
    private let repository: any CompletedFastRepository
    private let clock: any AppClock

    init(
        repository: any CompletedFastRepository,
        clock: any AppClock
    ) {
        self.repository = repository
        self.clock = clock
    }

    func validationError(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> CompletedFastError? {
        guard startDate < endDate else {
            return .startTimeNotBeforeEndTime
        }
        guard startDate <= clock.now else {
            return .futureStartTime
        }
        guard endDate <= clock.now else {
            return .futureEndTime
        }

        if let boundary = try crossingBoundary(startDate: startDate, endDate: endDate) {
            return .crossesCaloricBoundary(boundary.occurredAt)
        }

        let intervals = try repository.recordedFasts().map(\.recordedInterval)
        guard !FastConflictChecker.hasConflict(
            proposedStart: startDate,
            proposedEnd: endDate,
            excluding: id,
            among: intervals
        ) else {
            return .conflict
        }

        return nil
    }

    private func crossingBoundary(startDate: Date, endDate: Date) throws -> CaloricBoundary? {
        guard let query = repository as? any CaloricBoundaryQuerying else { return nil }
        return try query.savedCaloricBoundaries().first {
            $0.occurredAt > startDate && endDate > $0.occurredAt
        }
    }

    @discardableResult
    func update(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> FastRecord {
        if let error = try validationError(
            id: id,
            startDate: startDate,
            endDate: endDate
        ) {
            throw error
        }

        return try repository.updateCompletedFast(
            id: id,
            startDate: startDate,
            endDate: endDate
        )
    }

    func delete(id: UUID) throws {
        try repository.deleteCompletedFast(id: id)
    }
}

@MainActor
final class CompletedFastCreationService {
    private let repository: any CompletedFastCreationRepository
    private let clock: any AppClock

    init(
        repository: any CompletedFastCreationRepository,
        clock: any AppClock
    ) {
        self.repository = repository
        self.clock = clock
    }

    func save(
        startDate: Date,
        endDate: Date,
        goal: FastingGoal
    ) throws -> FastRecord {
        guard startDate < endDate else {
            throw CompletedFastError.startTimeNotBeforeEndTime
        }
        guard startDate <= clock.now else {
            throw CompletedFastError.futureStartTime
        }
        guard endDate <= clock.now else {
            throw CompletedFastError.futureEndTime
        }
        if let boundary = try crossingBoundary(startDate: startDate, endDate: endDate) {
            throw CompletedFastError.crossesCaloricBoundary(boundary.occurredAt)
        }
        let intervals = try repository.recordedFasts().map(\.recordedInterval)
        guard !FastConflictChecker.hasConflict(
            proposedStart: startDate,
            proposedEnd: endDate,
            among: intervals
        ) else {
            throw CompletedFastError.conflict
        }

        let fast = FastRecord(startDate: startDate, endDate: endDate, goalAtStart: goal)
        try repository.saveCompletedFast(fast)
        return fast
    }

    private func crossingBoundary(startDate: Date, endDate: Date) throws -> CaloricBoundary? {
        guard let query = repository as? any CaloricBoundaryQuerying else { return nil }
        return try query.savedCaloricBoundaries().first {
            $0.occurredAt > startDate && endDate > $0.occurredAt
        }
    }
}
