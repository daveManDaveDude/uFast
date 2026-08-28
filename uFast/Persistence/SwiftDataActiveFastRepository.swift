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
    private let clock: any AppClock
    private let observationSink: BoundaryQueryObservationSink
    private let diagnosticSink: any DiagnosticEventSink

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        clock: any AppClock = SystemAppClock(),
        observationSink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink(),
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.observationSink = observationSink
        self.diagnosticSink = diagnosticSink
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw ActiveFastPersistenceError.simulatedSaveFailure
            } : nil
        )
    }

    func activeFast() throws -> FastRecord? {
        try ActiveFastAuthority.fetch(in: modelContext, diagnosticSink: diagnosticSink)
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
        try saveAtomic {
            modelContext.insert(fast)
        }
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        let originalStartDate = fast.startDate
        try saveAtomic {
            fast.correctStartDate(to: startDate)
        } recovery: {
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
        try saveAtomic {
            fast.complete(at: endDate, goal: goal)
        } recovery: {
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
        try saveAtomic {
            fast.correctBoundaries(startDate: startDate, endDate: endDate)
        } recovery: {
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

        try saveAtomic {
            modelContext.delete(fast)
        }
    }
}

extension SwiftDataActiveFastRepository: CompletedFastCreationRepository {
    func saveCompletedFast(_ fast: FastRecord) throws {
        try saveAtomic {
            modelContext.insert(fast)
        }
    }
}

private extension SwiftDataActiveFastRepository {
    func saveAtomic(
        _ changes: () throws -> Void,
        recovery: @escaping () -> Void = {}
    ) throws {
        let suppressionStore = InferredFastSuppressionStore(
            modelContext: modelContext,
            diagnosticSink: diagnosticSink
        )
        let suppressionSnapshot = try suppressionStore.snapshot()
        do {
            try changes()
            let settings = try SwiftDataSettingsStore(modelContext: modelContext)
                .authoritativeRecord()
            _ = try suppressionStore.reconcileInMemory(
                currentGoal: settings?.fastingGoal ?? .default,
                enabled: settings?.inferredFastDetectionEnabled ?? false,
                mode: .authoritativeMutation,
                now: clock.now,
                updatedAt: clock.now
            )
            try saveTransaction {
                recovery()
                suppressionSnapshot.restore(in: self.modelContext)
            }
        } catch {
            suppressionSnapshot.restore(in: modelContext)
            modelContext.rollback()
            throw error
        }
    }

    func saveTransaction(recovering recovery: @escaping () -> Void = {}) throws {
        do {
            try transaction.save(recovering: recovery)
        } catch {
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
    }
}
