import Foundation
import SwiftData

enum HydrationEntryPersistenceError: Error { case simulatedSaveFailure }

@MainActor
protocol HydrationEntryRepository {
    func activeFast() throws -> FastRecord?
    func recordedFasts() throws -> [FastRecord]
    func create(_ draft: HydrationEntryDraft, at creationDate: Date) throws -> HydrationEntryRecord
    func create(
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> HydrationEntryRecord
    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date) throws
    func update(
        _ record: HydrationEntryRecord,
        with draft: HydrationEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws
    func delete(_ record: HydrationEntryRecord) throws
}

@MainActor
final class SwiftDataHydrationEntryRepository: HydrationEntryRepository, CaloricHydrationRepository {
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
                throw HydrationEntryPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func createFavourite(
        _ favourite: HydrationFavourite,
        occurredAt: Date
    ) throws -> HydrationEntryRecord {
        try create(
            HydrationEntryDraft(
                type: favourite.type,
                customName: nil,
                volumeMillilitres: favourite.volumeMillilitres,
                occurredAt: occurredAt,
                isCaloric: false
            ),
            at: occurredAt
        )
    }

    func create(_ draft: HydrationEntryDraft, at creationDate: Date) throws -> HydrationEntryRecord {
        let record = makeRecord(draft, creationDate)
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
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> HydrationEntryRecord {
        let record = makeRecord(draft, creationDate)
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

    func update(_ record: HydrationEntryRecord, with draft: HydrationEntryDraft, at updateDate: Date) throws {
        try saveCaloricEvent(draft, replacing: record, goal: .default, updatedAt: updateDate)
    }

    func update(
        _ record: HydrationEntryRecord,
        with draft: HydrationEntryDraft,
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

    func delete(_ record: HydrationEntryRecord) throws {
        let oldReference = CaloricBoundaryReference(kind: .hydration, id: record.id)
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
            for fast in fasts {
                snapshots[fast.id]?.restore(fast)
            }
        }
    }

    func caloricEventImpact(forDeletion record: HydrationEntryRecord) throws -> CaloricEventImpact {
        let oldReference = CaloricBoundaryReference(kind: .hydration, id: record.id)
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
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?
    ) throws -> CaloricEventImpact {
        let oldReference = record.map { CaloricBoundaryReference(kind: .hydration, id: $0.id) }
        let reference = oldReference ?? CaloricBoundaryReference(kind: .hydration, id: UUID())
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.customName ?? draft.type.displayName
            )
            : nil
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let mutation = try CaloricBoundaryMutation(
            oldReference: oldReference,
            oldOccurredAt: record?.occurredAt,
            oldIsCaloric: record?.isCaloric ?? false,
            newBoundary: newBoundary,
            resultingBoundaries: planner.allBoundaries(excluding: oldReference).adding(newBoundary)
        )
        return try planner.impact(for: mutation, fasts: planner.fasts())
    }

    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal
    ) throws {
        let now = clock.now
        let createdRecord = record == nil
            ? makeRecord(draft, now)
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
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        updatedAt: Date,
        createdRecord: HydrationEntryRecord? = nil
    ) throws {
        let oldReference = record.map { CaloricBoundaryReference(kind: .hydration, id: $0.id) }
        let reference = oldReference ?? CaloricBoundaryReference(
            kind: .hydration,
            id: createdRecord?.id ?? UUID()
        )
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.customName ?? draft.type.displayName
            )
            : nil
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let resulting = try planner.allBoundaries(excluding: oldReference).adding(newBoundary)
        let fasts = try planner.fasts()
        let snapshots = planner.snapshots(for: fasts)
        let oldOccurredAt = record?.occurredAt
        let oldIsCaloric = record?.isCaloric ?? false
        let oldDraft = record?.draft
        let oldUpdatedAt = record?.updatedAt
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
            if let record, let oldDraft, let oldUpdatedAt {
                record.update(from: oldDraft, at: oldUpdatedAt)
            }
            for fast in fasts {
                snapshots[fast.id]?.restore(fast)
            }
        }
    }

    private func makeRecord(
        _ draft: HydrationEntryDraft,
        _ createdAt: Date
    ) -> HydrationEntryRecord {
        HydrationEntryRecord(
            type: draft.type,
            customName: draft.customName,
            volumeMillilitres: draft.volumeMillilitres,
            occurredAt: draft.occurredAt,
            isCaloric: draft.isCaloric,
            createdAt: createdAt
        )
    }
}
