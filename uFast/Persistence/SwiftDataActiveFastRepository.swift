import Foundation
import SwiftData

enum ActiveFastPersistenceError: Error {
    case simulatedSaveFailure
    case completedFastNotFound
}

@MainActor
final class SwiftDataActiveFastRepository: ActiveFastRepository {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false
    ) {
        self.modelContext = modelContext
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw ActiveFastPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func activeFast() throws -> FastRecord? {
        try ActiveFastAuthority.fetch(in: modelContext)
    }

    func recordedFasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        modelContext.insert(fast)
        try transaction.save()
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        let originalStartDate = fast.startDate
        fast.correctStartDate(to: startDate)
        try transaction.save {
            fast.correctStartDate(to: originalStartDate)
        }
    }

    func complete(_ fast: FastRecord, at endDate: Date, goal: FastingGoal) throws {
        guard fast.isActive else {
            return
        }

        guard let originalGoal = fast.historicalGoal else {
            throw FastRecordIntegrityError.invalidHistoricalGoal(rawHours: fast.goalHoursAtStart)
        }
        fast.complete(at: endDate, goal: goal)
        try transaction.save {
            fast.restoreActive(goal: originalGoal)
        }
    }
}

extension SwiftDataActiveFastRepository: CompletedFastRepository {
    func updateCompletedFast(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> FastRecord {
        guard let fast = try recordedFasts().first(where: { $0.id == id && !$0.isActive }) else {
            throw ActiveFastPersistenceError.completedFastNotFound
        }

        let originalStartDate = fast.startDate
        guard let originalEndDate = fast.endDate else {
            throw ActiveFastPersistenceError.completedFastNotFound
        }
        fast.correctBoundaries(startDate: startDate, endDate: endDate)
        try transaction.save {
            fast.correctBoundaries(startDate: originalStartDate, endDate: originalEndDate)
        }
        return fast
    }

    func deleteCompletedFast(id: UUID) throws {
        guard let fast = try recordedFasts().first(where: { $0.id == id && !$0.isActive }) else {
            throw ActiveFastPersistenceError.completedFastNotFound
        }

        modelContext.delete(fast)
        try transaction.save()
    }
}

extension SwiftDataActiveFastRepository: CompletedFastCreationRepository {
    func saveCompletedFast(_ fast: FastRecord) throws {
        modelContext.insert(fast)
        try transaction.save()
    }
}
