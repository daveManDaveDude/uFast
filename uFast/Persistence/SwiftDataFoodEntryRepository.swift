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
final class SwiftDataFoodEntryRepository: FoodEntryRepository, CaloricBoundaryAwareFoodEntryRepository {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction
    private let clock: any AppClock

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        clock: any AppClock = SystemAppClock()
    ) {
        self.modelContext = modelContext
        self.clock = clock
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw FoodEntryPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func create(_ draft: FoodEntryDraft, at creationDate: Date) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        try saveCaloricEvent(
            draft,
            replacing: nil,
            goal: .default,
            updatedAt: creationDate,
            createdRecord: record
        )
        return record
    }

    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(draft: draft, createdAt: creationDate)
        _ = activeFast
        try saveCaloricEvent(
            draft,
            replacing: nil,
            goal: goal,
            updatedAt: creationDate,
            createdRecord: record
        )
        return record
    }

    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date
    ) throws {
        try saveCaloricEvent(draft, replacing: record, goal: .default, updatedAt: updateDate)
    }

    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws {
        _ = activeFast
        try saveCaloricEvent(draft, replacing: record, goal: goal, updatedAt: updateDate)
    }

    func activeFast() throws -> FastRecord? {
        try ActiveFastAuthority.fetch(in: modelContext)
    }

    func recordedFasts() throws -> [FastRecord] {
        try modelContext.fetch(FetchDescriptor<FastRecord>())
    }

    func delete(_ record: FoodEntryRecord) throws {
        let oldReference = CaloricBoundaryReference(kind: .food, id: record.id)
        let oldOccurredAt = record.occurredAt
        let oldIsCaloric = record.isCaloric
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let resulting = try planner.allBoundaries(excluding: oldReference)
        let fasts = try planner.fasts()
        let snapshots = planner.snapshots(for: fasts)
        modelContext.delete(record)
        _ = planner.apply(
            CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: oldOccurredAt,
                oldIsCaloric: oldIsCaloric,
                newBoundary: nil,
                resultingBoundaries: resulting
            ),
            to: fasts,
            currentGoal: .default
        )
        try transaction.save {
            record.restore(from: FoodEntryRecordSnapshot(
                draft: record.draft,
                isCaloric: record.isCaloric,
                updatedAt: record.updatedAt
            ))
            for fast in fasts {
                snapshots[fast.id]?.restore(fast)
            }
        }
    }

    func caloricEventImpact(forDeletion record: FoodEntryRecord) throws -> CaloricEventImpact {
        let oldReference = CaloricBoundaryReference(kind: .food, id: record.id)
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let mutation = try CaloricBoundaryMutation(
            oldReference: oldReference,
            oldOccurredAt: record.occurredAt,
            oldIsCaloric: record.isCaloric,
            newBoundary: nil,
            resultingBoundaries: planner.allBoundaries(excluding: oldReference)
        )
        return try planner.impact(for: mutation, fasts: planner.fasts())
    }

    func savedCaloricBoundaries() throws -> [CaloricBoundary] {
        try CaloricBoundaryPersistencePlanner(modelContext: modelContext).allBoundaries()
    }

    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?
    ) throws -> CaloricEventImpact {
        let oldReference = record.map { CaloricBoundaryReference(kind: .food, id: $0.id) }
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let reference = oldReference ?? CaloricBoundaryReference(kind: .food, id: UUID())
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.description
            )
            : nil
        let resultingBoundaries = try planner.allBoundaries(excluding: oldReference).adding(newBoundary)
        let mutation = CaloricBoundaryMutation(
            oldReference: oldReference,
            oldOccurredAt: record?.occurredAt,
            oldIsCaloric: record?.isCaloric ?? false,
            newBoundary: newBoundary,
            resultingBoundaries: resultingBoundaries
        )
        let fasts = try planner.fasts()
        return planner.impact(for: mutation, fasts: fasts)
    }

    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal
    ) throws {
        let now = clock.now
        let createdRecord = record == nil
            ? FoodEntryRecord(draft: draft, createdAt: now)
            : nil
        try saveCaloricEvent(
            draft,
            replacing: record,
            goal: goal,
            updatedAt: now,
            createdRecord: createdRecord
        )
    }

    private func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        updatedAt: Date,
        createdRecord: FoodEntryRecord? = nil
    ) throws {
        let oldReference = record.map { CaloricBoundaryReference(kind: .food, id: $0.id) }
        let reference = oldReference ?? CaloricBoundaryReference(
            kind: .food,
            id: createdRecord?.id ?? UUID()
        )
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.description
            )
            : nil
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let resulting = try planner.allBoundaries(excluding: oldReference).adding(newBoundary)
        let fasts = try planner.fasts()
        let snapshots = planner.snapshots(for: fasts)
        let oldSnapshot = record?.snapshot
        let oldOccurredAt = record?.occurredAt
        let oldIsCaloric = record?.isCaloric ?? false
        if let record {
            record.update(from: draft, at: updatedAt)
        } else if let createdRecord {
            modelContext.insert(createdRecord)
        }
        _ = planner.apply(
            CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: oldOccurredAt,
                oldIsCaloric: oldIsCaloric,
                newBoundary: newBoundary,
                resultingBoundaries: resulting
            ),
            to: fasts,
            currentGoal: goal
        )
        try transaction.save {
            if let record, let oldSnapshot {
                record.restore(from: oldSnapshot)
            }
            for fast in fasts {
                snapshots[fast.id]?.restore(fast)
            }
        }
    }
}
