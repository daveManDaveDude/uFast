import Foundation
import SwiftData

enum HydrationEntryPersistenceError: Error {
    case simulatedSaveFailure
    case duplicateRecord
}

@MainActor
protocol HydrationEntryRepository: CaloricBoundaryQuerying {
    func activeFast() throws -> FastRecord?
    func create(
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> HydrationEntryRecord
    func create(
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID: UUID?
    ) throws -> HydrationEntryRecord
    func update(
        _ record: HydrationEntryRecord,
        with draft: HydrationEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws
    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?
    ) throws -> CaloricEventImpact
    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        recordID: UUID?
    ) throws -> CaloricEventImpact
    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal
    ) throws
    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        recordID: UUID?
    ) throws
}

extension HydrationEntryRepository {
    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?
    ) throws -> CaloricEventImpact {
        try caloricEventImpact(for: draft, replacing: record, recordID: nil)
    }

    func create(
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID _: UUID?
    ) throws -> HydrationEntryRecord {
        try create(draft, at: creationDate, ending: activeFast, goal: goal)
    }

    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        recordID _: UUID?
    ) throws -> CaloricEventImpact {
        try caloricEventImpact(for: draft, replacing: record)
    }

    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        recordID _: UUID?
    ) throws {
        try saveCaloricEvent(draft, replacing: record, goal: goal)
    }

    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal
    ) throws {
        try saveCaloricEvent(draft, replacing: record, goal: goal, recordID: nil)
    }
}

@MainActor
// swiftlint:disable:next type_body_length
final class SwiftDataHydrationEntryRepository: HydrationEntryRepository {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction
    private let clock: any AppClock
    private let observationSink: BoundaryQueryObservationSink

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        clock: any AppClock = SystemAppClock(),
        observationSink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.observationSink = observationSink
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
        try create(
            draft,
            at: creationDate,
            ending: activeFast,
            goal: goal,
            recordID: nil
        )
    }

    func create(
        _ draft: HydrationEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID: UUID?
    ) throws -> HydrationEntryRecord {
        let record = makeRecord(draft, creationDate, id: recordID)
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

    func earliestCaloricBoundary(after startDate: Date) throws -> CaloricBoundary? {
        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let food = try query.earliestFood(after: startDate).first.map {
            CaloricBoundary(
                reference: .init(kind: .food, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.foodDescription
            )
        }
        let hydration = try query.earliestCaloricHydration(after: startDate).first.map {
            CaloricBoundary(
                reference: .init(kind: .hydration, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.displayName
            )
        }
        return CaloricBoundaryOrdering.sorted([food, hydration].compactMap(\.self)).first
    }

    func firstCaloricBoundary(in interval: Range<Date>) throws -> CaloricBoundary? {
        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let food = try query.firstFood(in: interval).first.map {
            CaloricBoundary(
                reference: .init(kind: .food, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.foodDescription
            )
        }
        let hydration = try query.firstCaloricHydration(in: interval).first.map {
            CaloricBoundary(
                reference: .init(kind: .hydration, id: $0.id),
                occurredAt: $0.occurredAt,
                description: $0.displayName
            )
        }
        return CaloricBoundaryOrdering.sorted([food, hydration].compactMap(\.self)).first
    }

    func delete(_ record: HydrationEntryRecord) throws {
        let oldReference = CaloricBoundaryReference(kind: .hydration, id: record.id)
        let oldOccurredAt = record.occurredAt
        let oldIsCaloric = record.isCaloric
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let bounded = try planner.boundedMutation(
            for: CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: oldOccurredAt,
                oldIsCaloric: oldIsCaloric,
                newBoundary: nil,
                resultingBoundaries: []
            ),
            currentGoal: .default
        )
        let fasts = bounded.fasts
        let snapshots = planner.snapshots(for: fasts)
        modelContext.delete(record)
        _ = planner.apply(bounded.mutation, to: fasts, currentGoal: .default)
        try transaction.save {
            for fast in fasts {
                snapshots[fast.id]?.restore(fast)
            }
        }
    }

    func caloricEventImpact(forDeletion record: HydrationEntryRecord) throws -> CaloricEventImpact {
        let oldReference = CaloricBoundaryReference(kind: .hydration, id: record.id)
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let bounded = try planner.boundedMutation(
            for: CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: record.occurredAt,
                oldIsCaloric: record.isCaloric,
                newBoundary: nil,
                resultingBoundaries: []
            ),
            currentGoal: .default
        )
        return planner.impact(for: bounded.mutation, fasts: bounded.fasts)
    }

    func savedCaloricBoundaries() throws -> [CaloricBoundary] {
        try CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        ).allBoundaries()
    }

    func caloricEventImpact(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        recordID: UUID? = nil
    ) throws -> CaloricEventImpact {
        let oldReference = record.map { CaloricBoundaryReference(kind: .hydration, id: $0.id) }
        let reference = oldReference ?? CaloricBoundaryReference(
            kind: .hydration,
            id: recordID ?? UUID()
        )
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.customName ?? draft.type.displayName
            )
            : nil
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let bounded = try planner.boundedMutation(
            for: CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: record?.occurredAt,
                oldIsCaloric: record?.isCaloric ?? false,
                newBoundary: newBoundary,
                resultingBoundaries: []
            ),
            currentGoal: .default
        )
        return planner.impact(for: bounded.mutation, fasts: bounded.fasts)
    }

    func saveCaloricEvent(
        _ draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?,
        goal: FastingGoal,
        recordID: UUID? = nil
    ) throws {
        let now = clock.now
        let createdRecord = record == nil
            ? makeRecord(draft, now, id: recordID)
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
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let bounded = try planner.boundedMutation(
            for: CaloricBoundaryMutation(
                oldReference: oldReference,
                oldOccurredAt: record?.occurredAt,
                oldIsCaloric: record?.isCaloric ?? false,
                newBoundary: newBoundary,
                resultingBoundaries: []
            ),
            currentGoal: goal
        )
        let fasts = bounded.fasts
        let snapshots = planner.snapshots(for: fasts)
        let oldDraft = record?.draft
        let oldUpdatedAt = record?.updatedAt
        if let record {
            record.update(from: draft, at: updatedAt)
        } else if let createdRecord {
            modelContext.insert(createdRecord)
        }
        _ = planner.apply(bounded.mutation, to: fasts, currentGoal: goal)
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
        _ createdAt: Date,
        id: UUID? = nil
    ) -> HydrationEntryRecord {
        HydrationEntryRecord(
            id: id ?? UUID(),
            type: draft.type,
            customName: draft.customName,
            volumeMillilitres: draft.volumeMillilitres,
            occurredAt: draft.occurredAt,
            isCaloric: draft.isCaloric,
            createdAt: createdAt
        )
    }
}
