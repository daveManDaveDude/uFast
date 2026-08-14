import Foundation
import SwiftData

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length statement_position

enum HydrationEntryPersistenceError: Error { case simulatedSaveFailure }

@MainActor
protocol HydrationEntryRepository {
    func activeFast() throws -> FastRecord?
    func recordedFasts() throws -> [FastRecord]
    func create(_ draft: HydrationEntryDraft, at creationDate: Date) throws -> HydrationEntryRecord
    func create(_ draft: HydrationEntryDraft, at creationDate: Date, ending activeFast: FastRecord, goal: FastingGoal) throws -> HydrationEntryRecord
    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date) throws
    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date, ending activeFast: FastRecord, goal: FastingGoal) throws
    func delete(_ record: HydrationEntryRecord) throws
}

@MainActor
final class SwiftDataHydrationEntryRepository: HydrationEntryRepository {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction

    init(modelContext: ModelContext, simulateSaveFailure: Bool = false) {
        self.modelContext = modelContext
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw HydrationEntryPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func createFavourite(_ favourite: HydrationFavourite, occurredAt: Date) throws -> HydrationEntryRecord {
        try create(HydrationEntryDraft(type: favourite.type, customName: nil, volumeMillilitres: favourite.volumeMillilitres, occurredAt: occurredAt, isCaloric: false), at: occurredAt)
    }

    func create(_ draft: HydrationEntryDraft, at creationDate: Date) throws -> HydrationEntryRecord {
        let record = makeRecord(draft, creationDate)
        modelContext.insert(record)
        try transaction.save()
        return record
    }

    func create(_ draft: HydrationEntryDraft, at creationDate: Date, ending activeFast: FastRecord, goal: FastingGoal) throws -> HydrationEntryRecord {
        let record = makeRecord(draft, creationDate)
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

    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date) throws {
        let old = record.draft
        let oldUpdatedAt = record.updatedAt
        record.update(from: draft, at: updateDate)
        try transaction.save {
            record.update(from: old, at: oldUpdatedAt)
        }
    }

    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date, ending activeFast: FastRecord, goal: FastingGoal) throws {
        let old = record.draft
        let oldUpdatedAt = record.updatedAt
        guard let previousGoal = activeFast.historicalGoal else {
            throw FastRecordIntegrityError.invalidHistoricalGoal(
                rawHours: activeFast.goalHoursAtStart
            )
        }
        record.update(from: draft, at: updateDate)
        activeFast.complete(at: draft.occurredAt, goal: goal)
        try transaction.save {
            record.update(from: old, at: oldUpdatedAt)
            activeFast.restoreActive(goal: previousGoal)
        }
    }

    func activeFast() throws -> FastRecord? {
        try ActiveFastAuthority.fetch(in: modelContext)
    }

    func recordedFasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func delete(_ record: HydrationEntryRecord) throws {
        modelContext.delete(record)
        try transaction.save()
    }

    private func makeRecord(_ draft: HydrationEntryDraft, _ createdAt: Date) -> HydrationEntryRecord {
        HydrationEntryRecord(type: draft.type, customName: draft.customName, volumeMillilitres: draft.volumeMillilitres, occurredAt: draft.occurredAt, isCaloric: draft.isCaloric, createdAt: createdAt)
    }
}
