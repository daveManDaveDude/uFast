import Foundation
import SwiftData

enum ActiveFastPersistenceError: Error {
    case simulatedSaveFailure
    case completedFastNotFound
}

@MainActor
final class SwiftDataActiveFastRepository: ActiveFastRepository {
    private let modelContext: ModelContext
    private let simulateSaveFailure: Bool

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false
    ) {
        self.modelContext = modelContext
        self.simulateSaveFailure = simulateSaveFailure
    }

    func activeFast() throws -> FastRecord? {
        var descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate { $0.endDate == nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func recordedFasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        modelContext.insert(fast)

        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            modelContext.delete(fast)
            throw error
        }
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        let originalStartDate = fast.startDate
        fast.correctStartDate(to: startDate)

        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            fast.correctStartDate(to: originalStartDate)
            throw error
        }
    }

    func complete(_ fast: FastRecord, at endDate: Date, goal: FastingGoal) throws {
        guard fast.isActive else {
            return
        }

        let originalGoal = fast.historicalGoal
        fast.complete(at: endDate, goal: goal)

        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            fast.restoreActive(goal: originalGoal)
            throw error
        }
    }

    private func failIfRequested() throws {
        if simulateSaveFailure {
            throw ActiveFastPersistenceError.simulatedSaveFailure
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

        do {
            try failIfRequested()
            try modelContext.save()
            return fast
        } catch {
            fast.correctBoundaries(
                startDate: originalStartDate,
                endDate: originalEndDate
            )
            throw error
        }
    }

    func deleteCompletedFast(id: UUID) throws {
        guard let fast = try recordedFasts().first(where: { $0.id == id && !$0.isActive }) else {
            throw ActiveFastPersistenceError.completedFastNotFound
        }

        try failIfRequested()
        modelContext.delete(fast)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
