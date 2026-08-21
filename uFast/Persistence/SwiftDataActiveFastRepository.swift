import Foundation
import SwiftData

enum ActiveFastPersistenceError: Error {
    case simulatedSaveFailure
    case completedFastNotFound
    case duplicateRecord
}

@MainActor
final class SwiftDataActiveFastRepository: ActiveFastRepository, CaloricBoundaryQuerying {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction
    private let observationSink: BoundaryQueryObservationSink

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        observationSink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink()
    ) {
        self.modelContext = modelContext
        self.observationSink = observationSink
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

    func savedCaloricBoundaries() throws -> [CaloricBoundary] {
        try CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        ).allBoundaries()
    }

    func hasRecordedFastConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID?
    ) throws -> Bool {
        try SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        ).hasFastConflict(
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            excluding: excludedID
        )
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
        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let fast: FastRecord
        switch try query.fast(id: id) {
        case .missing: throw ActiveFastPersistenceError.completedFastNotFound
        case .duplicate: throw ActiveFastPersistenceError.duplicateRecord
        case let .unique(record):
            guard !record.isActive else {
                throw ActiveFastPersistenceError.completedFastNotFound
            }
            fast = record
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
        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let fast: FastRecord
        switch try query.fast(id: id) {
        case .missing: throw ActiveFastPersistenceError.completedFastNotFound
        case .duplicate: throw ActiveFastPersistenceError.duplicateRecord
        case let .unique(record):
            guard !record.isActive else {
                throw ActiveFastPersistenceError.completedFastNotFound
            }
            fast = record
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
