import Foundation
import SwiftData

enum FoodEntryPersistenceError: Error {
    case simulatedSaveFailure
    case recordNotFound
    case duplicateRecord
}

@MainActor
protocol FoodEntryRepository: CaloricBoundaryQuerying {
    func activeFast() throws -> FastRecord?
    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws -> FoodEntryRecord
    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID: UUID?
    ) throws -> FoodEntryRecord
    func update(
        _ record: FoodEntryRecord,
        with draft: FoodEntryDraft,
        at updateDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal
    ) throws
    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?
    ) throws -> CaloricEventImpact
    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        recordID: UUID?
    ) throws -> CaloricEventImpact
    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal
    ) throws
    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        recordID: UUID?
    ) throws
}

extension FoodEntryRepository {
    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?
    ) throws -> CaloricEventImpact {
        try caloricEventImpact(for: draft, replacing: record, recordID: nil)
    }

    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID _: UUID?
    ) throws -> FoodEntryRecord {
        try create(draft, at: creationDate, ending: activeFast, goal: goal)
    }

    func caloricEventImpact(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        recordID _: UUID?
    ) throws -> CaloricEventImpact {
        try caloricEventImpact(for: draft, replacing: record)
    }

    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        recordID _: UUID?
    ) throws {
        try saveCaloricEvent(draft, replacing: record, goal: goal)
    }

    func saveCaloricEvent(
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal
    ) throws {
        try saveCaloricEvent(draft, replacing: record, goal: goal, recordID: nil)
    }
}

@MainActor
final class SwiftDataFoodEntryRepository: FoodEntryRepository {
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
        try create(
            draft,
            at: creationDate,
            ending: activeFast,
            goal: goal,
            recordID: nil
        )
    }

    func create(
        _ draft: FoodEntryDraft,
        at creationDate: Date,
        ending activeFast: FastRecord,
        goal: FastingGoal,
        recordID: UUID?
    ) throws -> FoodEntryRecord {
        let record = FoodEntryRecord(
            id: recordID ?? UUID(),
            draft: draft,
            createdAt: creationDate
        )
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

    func delete(_ record: FoodEntryRecord) throws {
        let oldReference = CaloricBoundaryReference(kind: .food, id: record.id)
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
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        recordID: UUID? = nil
    ) throws -> CaloricEventImpact {
        let oldReference = record.map { CaloricBoundaryReference(kind: .food, id: $0.id) }
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let reference = oldReference ?? CaloricBoundaryReference(
            kind: .food,
            id: recordID ?? UUID()
        )
        let newBoundary = draft.isCaloric
            ? CaloricBoundary(
                reference: reference,
                occurredAt: draft.occurredAt,
                description: draft.description
            )
            : nil
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
        _ draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        goal: FastingGoal,
        recordID: UUID? = nil
    ) throws {
        let now = clock.now
        let createdRecord = record == nil
            ? FoodEntryRecord(id: recordID ?? UUID(), draft: draft, createdAt: now)
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
        let oldSnapshot = record?.snapshot
        if let record {
            record.update(from: draft, at: updatedAt)
        } else if let createdRecord {
            modelContext.insert(createdRecord)
        }
        _ = planner.apply(bounded.mutation, to: fasts, currentGoal: goal)
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
