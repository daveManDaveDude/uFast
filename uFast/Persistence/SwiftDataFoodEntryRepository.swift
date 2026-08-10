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
    private let transaction: PersistenceTransaction

    init(modelContext: ModelContext, simulateSaveFailure: Bool = false) {
        self.modelContext = modelContext
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw FoodEntryPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func create(_ draft: FoodEntryDraft, at creationDate: Date) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        modelContext.insert(record)
        try transaction.save()
        return record
    }

    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        guard let previousGoal = activeFast.historicalGoal else {
            throw FastRecordIntegrityError.invalidHistoricalGoal(
                rawHours: activeFast.goalHoursAtStart
            )
        }
        modelContext.insert(record)
        activeFast.complete(at: draft.occurredAt, goal: goal)
        try transaction.save {
            activeFast.restoreActive(goal: previousGoal)
        }
        return record
    }

    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date
    ) throws {
        let previousSnapshot = record.snapshot
        record.update(from: draft, at: updateDate)
        try transaction.save {
            record.restore(from: previousSnapshot)
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
        guard let previousGoal = activeFast.historicalGoal else {
            throw FastRecordIntegrityError.invalidHistoricalGoal(
                rawHours: activeFast.goalHoursAtStart
            )
        }
        record.update(from: draft, at: updateDate)
        activeFast.complete(at: draft.occurredAt, goal: goal)
        try transaction.save {
            record.restore(from: previousSnapshot)
            activeFast.restoreActive(goal: previousGoal)
        }
    }

    func activeFast() throws -> FastRecord? {
        try ActiveFastAuthority.fetch(in: modelContext)
    }

    func recordedFasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func delete(_ record: FoodEntryRecord) throws {
        modelContext.delete(record)
        try transaction.save()
    }
}
