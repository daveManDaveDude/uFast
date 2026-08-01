import Foundation
import SwiftData

enum FoodEntryPersistenceError: Error {
    case simulatedSaveFailure
    case recordNotFound
}

@MainActor
protocol FoodEntryRepository {
    func activeFast() throws -> FastRecord?
    func recordedFasts() throws -> [FastRecord]
    func create(_ draft: FoodEntryDraft, at creationDate: Date) throws -> FoodEntryRecord
    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> FoodEntryRecord
    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date
    ) throws
    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws
    func delete(_ record: FoodEntryRecord) throws
}

@MainActor
final class SwiftDataFoodEntryRepository: FoodEntryRepository {
    private let modelContext: ModelContext
    private let simulateSaveFailure: Bool

    init(modelContext: ModelContext, simulateSaveFailure: Bool = false) {
        self.modelContext = modelContext
        self.simulateSaveFailure = simulateSaveFailure
    }

    func create(_ draft: FoodEntryDraft, at creationDate: Date) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        modelContext.insert(record)
        do {
            try failIfRequested()
            try modelContext.save()
            return record
        } catch {
            modelContext.delete(record)
            throw error
        }
    }

    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        let previousGoal = activeFast.historicalGoal
        modelContext.insert(record)
        activeFast.complete(at: draft.occurredAt, goal: goal)
        do {
            try failIfRequested()
            try modelContext.save()
            return record
        } catch {
            activeFast.restoreActive(goal: previousGoal)
            modelContext.delete(record)
            throw error
        }
    }

    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date
    ) throws {
        let previousSnapshot = record.snapshot
        record.update(from: draft, at: updateDate)
        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            record.restore(from: previousSnapshot)
            throw error
        }
    }

    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws {
        let previousSnapshot = record.snapshot
        let previousGoal = activeFast.historicalGoal
        record.update(from: draft, at: updateDate)
        activeFast.complete(at: draft.occurredAt, goal: goal)
        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            record.restore(from: previousSnapshot)
            activeFast.restoreActive(goal: previousGoal)
            throw error
        }
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

    func delete(_ record: FoodEntryRecord) throws {
        do {
            try failIfRequested()
        } catch {
            throw error
        }
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func failIfRequested() throws {
        if simulateSaveFailure {
            throw FoodEntryPersistenceError.simulatedSaveFailure
        }
    }
}
