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

enum CompletedFastError: Error, Equatable {
    case startTimeNotBeforeEndTime
    case futureStartTime
    case futureEndTime
    case conflict
    case noCompletedFast
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
