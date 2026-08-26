import Foundation
import SwiftData

private struct PendingFoodRecordProposal {
    let draft: FoodEntryDraft
    let id: UUID
}

private struct PendingHydrationRecordProposal {
    let draft: HydrationEntryDraft
    let id: UUID
}

@MainActor
final class CaloricEventCommands {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private let projectionCoordinator: PostCommitProjectionCoordinator
    private let configuration: ApplicationCommandConfiguration
    private let observationSink: BoundaryQueryObservationSink
    private let diagnosticSink: any DiagnosticEventSink
    private let recordIDProvider: () -> UUID
    private let impactPresenter: CaloricEventImpactPresenter
    private var pendingFoodRecordProposal: PendingFoodRecordProposal?
    private var pendingHydrationRecordProposal: PendingHydrationRecordProposal?

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        projectionCoordinator: PostCommitProjectionCoordinator,
        configuration: ApplicationCommandConfiguration,
        observationSink: BoundaryQueryObservationSink,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        recordIDProvider: @escaping () -> UUID
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.projectionCoordinator = projectionCoordinator
        self.configuration = configuration
        self.observationSink = observationSink
        self.diagnosticSink = diagnosticSink
        self.recordIDProvider = recordIDProvider
        impactPresenter = CaloricEventImpactPresenter(
            modelContext: modelContext,
            clock: clock,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink
        )
    }

    func saveFood(
        _ draft: FoodEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool,
        operationID: UUID? = nil
    ) throws {
        let record = try recordID.flatMap { try foodRecord(id: $0) }
        // A favourite quick-add operation owns the normal event identifier for
        // its one commit attempt. Once that event exists, replaying the same
        // operation is an idempotent no-op. This check is deliberately inside
        // the caloric command boundary so it covers both the event and any
        // active-fast completion transaction, rather than relying on picker UI
        // state.
        if let operationID, try foodRecord(id: operationID) != nil {
            return
        }
        let eventReference = foodEventReference(
            for: draft,
            replacing: record,
            operationID: operationID
        )
        let inferredImpact = try impactPresenter.presentedImpact(
            resultingEventReference: eventReference,
            resultingEventDate: draft.occurredAt,
            resultingEventIsCaloric: draft.isCaloric,
            replacing: record.map { .init(kind: .food, id: $0.id) }
        )
        let persistedImpact = try foodRepository().caloricEventImpact(
            for: draft,
            replacing: record,
            recordID: eventReference.id
        )
        if inferredImpact.requiresConfirmation, !persistedImpact.requiresConfirmation, !endingActiveFast {
            throw FoodEntrySaveError.inferredConfirmationWithImpact(
                .init(persistedImpact: .none, includesInferredInterval: true)
            )
        }
        let activeBefore = try ActiveFastAuthority.fetch(
            in: modelContext,
            diagnosticSink: diagnosticSink
        )
        do {
            try FoodEntryService(repository: foodRepository(), clock: clock).save(
                draft,
                replacing: record,
                goal: goal,
                endingActiveFast: endingActiveFast,
                recordID: eventReference.id
            )
            if record == nil {
                pendingFoodRecordProposal = nil
            }
        } catch let error as FoodEntrySaveError where inferredImpact.requiresConfirmation {
            throw error.includingInferredImpact()
        }
        try publishAfterMutation(activeBefore: activeBefore)
    }

    func deleteFood(id: UUID, confirmingInferredImpact: Bool = false) throws {
        let record = try requiredFoodRecord(id: id)
        let reference = CaloricBoundaryReference(kind: .food, id: id)
        let inferredImpact = try impactPresenter.presentedImpact(
            resultingEventReference: reference,
            resultingEventDate: record.occurredAt,
            resultingEventIsCaloric: false,
            replacing: reference
        )
        let persistedImpact = try foodRepository().caloricEventImpact(forDeletion: record)
        if persistedImpact.requiresConfirmation, !confirmingInferredImpact {
            let context = CaloricEventConfirmationContext(
                persistedImpact: persistedImpact,
                includesInferredInterval: inferredImpact.requiresConfirmation
            )
            if persistedImpact.affectsActiveFast {
                throw FoodEntrySaveError.confirmationRequiredWithImpact(context)
            }
            throw FoodEntrySaveError.completedConfirmationWithImpact(context)
        }
        if inferredImpact.requiresConfirmation, !confirmingInferredImpact {
            throw FoodEntrySaveError.inferredConfirmationWithImpact(
                .init(persistedImpact: .none, includesInferredInterval: true)
            )
        }
        try foodRepository().delete(record)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func saveHydration(
        _ draft: HydrationEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        let record = try recordID.flatMap { try hydrationRecord(id: $0) }
        let eventReference = hydrationEventReference(for: draft, replacing: record)
        let inferredImpact = try impactPresenter.presentedImpact(
            resultingEventReference: eventReference,
            resultingEventDate: draft.occurredAt,
            resultingEventIsCaloric: draft.isCaloric,
            replacing: record.map { .init(kind: .hydration, id: $0.id) }
        )
        let persistedImpact = try hydrationRepository().caloricEventImpact(
            for: draft,
            replacing: record,
            recordID: eventReference.id
        )
        if inferredImpact.requiresConfirmation, !persistedImpact.requiresConfirmation, !endingActiveFast {
            throw HydrationEntrySaveError.inferredConfirmationWithImpact(
                .init(persistedImpact: .none, includesInferredInterval: true)
            )
        }
        let activeBefore = try ActiveFastAuthority.fetch(
            in: modelContext,
            diagnosticSink: diagnosticSink
        )
        do {
            try HydrationEntryService(repository: hydrationRepository(), clock: clock).save(
                draft,
                replacing: record,
                goal: goal,
                endingActiveFast: endingActiveFast,
                recordID: eventReference.id
            )
            if record == nil {
                pendingHydrationRecordProposal = nil
            }
        } catch let error as HydrationEntrySaveError where inferredImpact.requiresConfirmation {
            throw error.includingInferredImpact()
        }
        try publishAfterMutation(activeBefore: activeBefore)
    }

    func deleteHydration(id: UUID, confirmingInferredImpact: Bool = false) throws {
        let record = try requiredHydrationRecord(id: id)
        let reference = CaloricBoundaryReference(kind: .hydration, id: id)
        let inferredImpact = try impactPresenter.presentedImpact(
            resultingEventReference: reference,
            resultingEventDate: record.occurredAt,
            resultingEventIsCaloric: false,
            replacing: reference
        )
        let persistedImpact = try hydrationRepository().caloricEventImpact(forDeletion: record)
        if persistedImpact.requiresConfirmation, !confirmingInferredImpact {
            let context = CaloricEventConfirmationContext(
                persistedImpact: persistedImpact,
                includesInferredInterval: inferredImpact.requiresConfirmation
            )
            if persistedImpact.affectsActiveFast {
                throw HydrationEntrySaveError.confirmationRequiredWithImpact(context)
            }
            throw HydrationEntrySaveError.completedConfirmationWithImpact(context)
        }
        if inferredImpact.requiresConfirmation, !confirmingInferredImpact {
            throw HydrationEntrySaveError.inferredConfirmationWithImpact(
                .init(persistedImpact: .none, includesInferredInterval: true)
            )
        }
        try hydrationRepository().delete(record)
        projectionCoordinator.publishHistoryInvalidation()
    }

    private func publishAfterMutation(activeBefore: FastRecord?) throws {
        let activeAfter = try ActiveFastAuthority.fetch(
            in: modelContext,
            diagnosticSink: diagnosticSink
        )
        if activeBefore != nil, activeAfter == nil {
            projectionCoordinator.enqueue(.fastEndedOrDeleted)
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
    }

    private func foodEventReference(
        for draft: FoodEntryDraft,
        replacing record: FoodEntryRecord?,
        operationID: UUID? = nil
    ) -> CaloricBoundaryReference {
        if let record {
            pendingFoodRecordProposal = nil
            return .init(kind: .food, id: record.id)
        }
        if let operationID {
            pendingFoodRecordProposal = PendingFoodRecordProposal(draft: draft, id: operationID)
            return .init(kind: .food, id: operationID)
        }
        if let proposal = pendingFoodRecordProposal, proposal.draft == draft {
            return .init(kind: .food, id: proposal.id)
        }
        let id = recordIDProvider()
        pendingFoodRecordProposal = PendingFoodRecordProposal(draft: draft, id: id)
        return .init(kind: .food, id: id)
    }

    private func hydrationEventReference(
        for draft: HydrationEntryDraft,
        replacing record: HydrationEntryRecord?
    ) -> CaloricBoundaryReference {
        if let record {
            pendingHydrationRecordProposal = nil
            return .init(kind: .hydration, id: record.id)
        }
        if let proposal = pendingHydrationRecordProposal, proposal.draft == draft {
            return .init(kind: .hydration, id: proposal.id)
        }
        let id = recordIDProvider()
        pendingHydrationRecordProposal = PendingHydrationRecordProposal(draft: draft, id: id)
        return .init(kind: .hydration, id: id)
    }

    private func foodRepository() -> SwiftDataFoodEntryRepository {
        SwiftDataFoodEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFoodSaveFailure,
            clock: clock,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink
        )
    }

    private func hydrationRepository() -> SwiftDataHydrationEntryRepository {
        SwiftDataHydrationEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateDrinkSaveFailure,
            clock: clock,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink
        )
    }

    private func foodRecord(id: UUID) throws -> FoodEntryRecord? {
        switch try SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        ).food(id: id) {
        case .missing: return nil
        case let .unique(record): return record
        case .duplicate: throw FoodEntryPersistenceError.duplicateRecord
        }
    }

    private func requiredFoodRecord(id: UUID) throws -> FoodEntryRecord {
        guard let record = try foodRecord(id: id) else {
            throw FoodEntryPersistenceError.recordNotFound
        }
        return record
    }

    private func hydrationRecord(id: UUID) throws -> HydrationEntryRecord? {
        switch try SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        ).hydration(id: id) {
        case .missing: return nil
        case let .unique(record): return record
        case .duplicate: throw HydrationEntryPersistenceError.duplicateRecord
        }
    }

    private func requiredHydrationRecord(id: UUID) throws -> HydrationEntryRecord {
        guard let record = try hydrationRecord(id: id) else {
            throw ApplicationCommandError.recordNotFound
        }
        return record
    }
}

private extension FoodEntrySaveError {
    func includingInferredImpact() -> Self {
        switch self {
        case let .confirmationRequiredWithImpact(context):
            .confirmationRequiredWithImpact(context.includingInferredInterval())
        case let .completedConfirmationWithImpact(context):
            .completedConfirmationWithImpact(context.includingInferredInterval())
        case let .inferredConfirmationWithImpact(context):
            .inferredConfirmationWithImpact(context.includingInferredInterval())
        default:
            self
        }
    }
}

private extension HydrationEntrySaveError {
    func includingInferredImpact() -> Self {
        switch self {
        case let .confirmationRequiredWithImpact(context):
            .confirmationRequiredWithImpact(context.includingInferredInterval())
        case let .completedConfirmationWithImpact(context):
            .completedConfirmationWithImpact(context.includingInferredInterval())
        case let .inferredConfirmationWithImpact(context):
            .inferredConfirmationWithImpact(context.includingInferredInterval())
        default:
            self
        }
    }
}
