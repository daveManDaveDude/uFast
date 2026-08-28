import Foundation
import SwiftData

struct ApplicationCommandConfiguration: Equatable {
    var simulateFastSaveFailure = false
    var simulateFastHistoryFailure = false
    var simulateFoodSaveFailure = false
    var simulateDrinkSaveFailure = false
    var simulateFavouriteSaveFailure = false
    var simulateFoodFavouriteSaveFailure = false
    var simulateFoodFavouriteStale = false
    var simulateFoodFavStaleAfterConfirm = false
    var simulateGoalSaveFailure = false
    var simulateLiveActivitySettingsSaveFailure = false
    var simulateInferredFastDetectionSaveFailure = false
    var simulateDeleteAllFailure = false
    var simulateBoundaryReconciliationFailure = false
    var simulateSuppressionSaveFailure = false
    var simulateSuppressionReenableStale = false
}

struct ApplicationCommandOutcome: Equatable {
    let recordID: UUID?
    let projectionEnqueued: Bool
}

enum InferredFastConversionError: Error, Equatable {
    case candidateUnavailable
    case conflictingRecordedFast
    case activeFastAlreadyExists
}

enum InferredFastSuppressionError: Error, Equatable {
    case candidateUnavailable
    case suppressionUnavailable
    case simulatedSaveFailure
}

@MainActor
// swiftlint:disable:next type_body_length
final class ApplicationCommands {
    let modelContext: ModelContext
    let clock: any AppClock
    let projectionCoordinator: PostCommitProjectionCoordinator
    let configuration: ApplicationCommandConfiguration
    let observationSink: BoundaryQueryObservationSink
    let diagnosticSink: any DiagnosticEventSink
    private let caloricEventCommands: CaloricEventCommands
    var hasSimulatedFoodFavouriteStale = false
    var hasSimulatedFoodFavStaleAfterConfirm = false

    var historyPresentationInvalidation: HistoryPresentationInvalidation {
        projectionCoordinator.historyPresentationInvalidation
    }

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        projectionCoordinator: PostCommitProjectionCoordinator,
        configuration: ApplicationCommandConfiguration = .init(),
        observationSink: BoundaryQueryObservationSink = NoOpBoundaryQueryObservationSink(),
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        recordIDProvider: @escaping () -> UUID = { UUID() }
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.projectionCoordinator = projectionCoordinator
        self.configuration = configuration
        self.observationSink = observationSink
        self.diagnosticSink = diagnosticSink
        caloricEventCommands = CaloricEventCommands(
            modelContext: modelContext,
            clock: clock,
            projectionCoordinator: projectionCoordinator,
            configuration: configuration,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink,
            recordIDProvider: recordIDProvider
        )
    }

    func saveInferredFast(
        sourceFoodID: UUID,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String? = nil,
        expectedGoal: FastingGoal? = nil
    ) throws -> ApplicationCommandOutcome {
        let candidate = try revalidatedInferredCandidate(
            sourceBoundaryReference: CaloricBoundaryReference(kind: .food, id: sourceFoodID),
            expectedStartDate: expectedStartDate,
            expectedEndDate: expectedEndDate,
            expectedSourceDescription: expectedSourceDescription,
            expectedGoal: expectedGoal,
            expectedState: .historical
        )
        let fast = try CompletedFastCreationService(
            repository: completedFastRepository(),
            clock: clock
        ).save(
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            goal: candidate.goal
        )
        projectionCoordinator.publishHistoryInvalidation()
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: false)
    }

    func saveInferredFast(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String? = nil,
        expectedGoal: FastingGoal? = nil
    ) throws -> ApplicationCommandOutcome {
        let candidate = try revalidatedInferredCandidate(
            sourceBoundaryReference: sourceBoundaryReference,
            expectedStartDate: expectedStartDate,
            expectedEndDate: expectedEndDate,
            expectedSourceDescription: expectedSourceDescription,
            expectedGoal: expectedGoal,
            expectedState: .historical
        )
        let fast = try CompletedFastCreationService(
            repository: completedFastRepository(),
            clock: clock
        ).save(startDate: candidate.startDate, endDate: candidate.endDate, goal: candidate.goal)
        projectionCoordinator.publishHistoryInvalidation()
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: false)
    }

    func startInferredFast(
        sourceFoodID: UUID,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String? = nil,
        expectedGoal: FastingGoal? = nil
    ) throws -> ApplicationCommandOutcome {
        let candidate = try revalidatedInferredCandidate(
            sourceBoundaryReference: CaloricBoundaryReference(kind: .food, id: sourceFoodID),
            expectedStartDate: expectedStartDate,
            expectedEndDate: expectedEndDate,
            expectedSourceDescription: expectedSourceDescription,
            expectedGoal: expectedGoal,
            expectedState: .inProgress
        )
        let repository = activeFastRepository()
        guard try repository.activeFast() == nil else {
            throw InferredFastConversionError.activeFastAlreadyExists
        }
        let fast = try FastStartService(repository: repository, clock: clock).startFast(
            at: candidate.startDate,
            goal: candidate.goal
        )
        projectionCoordinator.enqueue(
            .activeFastStarted(fast: fast, goal: candidate.goal, now: clock.now)
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func startInferredFast(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String? = nil,
        expectedGoal: FastingGoal? = nil
    ) throws -> ApplicationCommandOutcome {
        let candidate = try revalidatedInferredCandidate(
            sourceBoundaryReference: sourceBoundaryReference,
            expectedStartDate: expectedStartDate,
            expectedEndDate: expectedEndDate,
            expectedSourceDescription: expectedSourceDescription,
            expectedGoal: expectedGoal,
            expectedState: .inProgress
        )
        let repository = activeFastRepository()
        guard try repository.activeFast() == nil else {
            throw InferredFastConversionError.activeFastAlreadyExists
        }
        let fast = try FastStartService(repository: repository, clock: clock).startFast(
            at: candidate.startDate,
            goal: candidate.goal
        )
        projectionCoordinator.enqueue(
            .activeFastStarted(fast: fast, goal: candidate.goal, now: clock.now)
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func saveFood(
        _ draft: FoodEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        try saveFood(
            draft,
            replacing: recordID,
            goal: goal,
            endingActiveFast: endingActiveFast,
            operationID: nil
        )
    }

    func saveFood(
        _ draft: FoodEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool,
        operationID: UUID?
    ) throws {
        try caloricEventCommands.saveFood(
            draft,
            replacing: recordID,
            goal: goal,
            endingActiveFast: endingActiveFast,
            operationID: operationID
        )
    }

    func deleteFood(id: UUID, confirmingInferredImpact: Bool = false) throws {
        try caloricEventCommands.deleteFood(
            id: id,
            confirmingInferredImpact: confirmingInferredImpact
        )
    }

    func saveHydration(
        _ draft: HydrationEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        try caloricEventCommands.saveHydration(
            draft,
            replacing: recordID,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
    }

    func addFavouriteDrink(
        _ favourite: HydrationFavourite,
        endingActiveFast: Bool = false
    ) throws {
        let draft = try hydrationDraft(for: favourite, occurredAt: clock.now)
        let goal = try authoritativeSettingsRecord()?.fastingGoal ?? .default
        try saveHydration(
            draft,
            replacing: nil,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
    }

    func hydrationDraft(
        for favourite: HydrationFavourite,
        occurredAt: Date
    ) throws -> HydrationEntryDraft {
        try requireUnambiguousSettingsAuthority()
        let resolved = try resolveFavourite(favourite)
        guard HydrationEntryValidator.isValid(volumeMillilitres: resolved.volumeMillilitres) else {
            throw HydrationFavouriteStoreError.invalidAmount
        }
        if resolved.type == .custom {
            _ = try HydrationFavouriteValidator.validated(
                name: resolved.displayName,
                amount: resolved.volumeMillilitres,
                isCaloric: resolved.isCaloric,
                existing: []
            )
        }
        return HydrationFavouriteProjection.hydrationDraft(
            from: resolved,
            occurredAt: occurredAt
        )
    }

    func createFavourite(
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws -> HydrationFavouriteSnapshot {
        try requireUnambiguousSettingsAuthority()
        let snapshot = try favouriteStore().create(
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            at: clock.now
        )
        projectionCoordinator.publishHistoryInvalidation()
        return snapshot
    }

    func updateFavourite(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws -> HydrationFavouriteSnapshot {
        try requireUnambiguousSettingsAuthority()
        let snapshot = try favouriteStore().update(
            id: id,
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            at: clock.now
        )
        projectionCoordinator.publishHistoryInvalidation()
        return snapshot
    }

    func deleteFavourite(id: UUID) throws {
        try requireUnambiguousSettingsAuthority()
        try favouriteStore().delete(id: id)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func deleteHydration(id: UUID, confirmingInferredImpact: Bool = false) throws {
        try caloricEventCommands.deleteHydration(
            id: id,
            confirmingInferredImpact: confirmingInferredImpact
        )
    }

    func updateGoal(_ goal: FastingGoal) throws {
        let suppressionStore = InferredFastSuppressionStore(
            modelContext: modelContext,
            diagnosticSink: diagnosticSink
        )
        let suppressionSnapshot = try suppressionStore.snapshot()
        try settingsStore(simulateFailure: configuration.simulateGoalSaveFailure).updateGoal(
            goal,
            additionalChanges: {
                _ = try suppressionStore.reconcileInMemory(
                    currentGoal: goal,
                    enabled: self.authoritativeSettingsRecord()?.inferredFastDetectionEnabled ?? false,
                    mode: .authoritativeMutation,
                    now: self.clock.now,
                    updatedAt: self.clock.now
                )
            },
            additionalRecovery: {
                suppressionSnapshot.restore(in: self.modelContext)
            }
        )
        if let activeFast = try? ActiveFastAuthority.fetch(
            in: modelContext,
            diagnosticSink: diagnosticSink
        ) {
            projectionCoordinator.enqueue(
                .activeFastChanged(fast: activeFast, goal: goal, now: clock.now)
            )
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
    }

    func updateInferredFastDetectionEnabled(_ enabled: Bool) throws {
        let suppressionStore = InferredFastSuppressionStore(
            modelContext: modelContext,
            diagnosticSink: diagnosticSink
        )
        let suppressionSnapshot = try suppressionStore.snapshot()
        try settingsStore(
            simulateFailure: configuration.simulateInferredFastDetectionSaveFailure
        ).updateInferredFastDetectionEnabled(
            enabled,
            additionalChanges: {
                _ = try suppressionStore.reconcileInMemory(
                    currentGoal: self.authoritativeSettingsRecord()?.fastingGoal ?? .default,
                    enabled: enabled,
                    now: self.clock.now,
                    updatedAt: self.clock.now
                )
            },
            additionalRecovery: {
                suppressionSnapshot.restore(in: self.modelContext)
            }
        )
        projectionCoordinator.enqueue(.inferredFastDetectionChanged(enabled))
    }

    func completeOnboarding(goal: FastingGoal) throws {
        _ = try settingsStore(
            simulateFailure: configuration.simulateGoalSaveFailure
        ).completeOnboarding(goal: goal)
    }

    func updateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool = true,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) throws {
        try settingsStore(
            simulateFailure: configuration.simulateLiveActivitySettingsSaveFailure
        ).updateAutomaticLiveActivityPreference(preference)
        guard projectSystemSurfaces else { return }
        projectionCoordinator.enqueue(
            .automaticPreferenceChanged(preference),
            completion: completion
        )
    }

    func activeFastRepository() -> SwiftDataActiveFastRepository {
        SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFastSaveFailure,
            clock: clock,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink
        )
    }

    func completedFastRepository() -> SwiftDataActiveFastRepository {
        SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFastHistoryFailure,
            clock: clock,
            observationSink: observationSink,
            diagnosticSink: diagnosticSink
        )
    }

    private func settingsStore(simulateFailure: Bool = false) -> SwiftDataSettingsStore {
        SwiftDataSettingsStore(
            modelContext: modelContext,
            simulateSaveFailure: simulateFailure,
            diagnosticSink: diagnosticSink,
            now: clock.now
        )
    }
}

extension ApplicationCommands {
    func deleteAllData() throws {
        try AppDataDeletionService.deleteEverything(
            in: modelContext,
            simulateFailure: configuration.simulateDeleteAllFailure,
            diagnosticSink: diagnosticSink
        )
        projectionCoordinator.enqueue(.allDataDeleted)
    }
}

extension ApplicationCommands {
    func favouriteStore() -> SwiftDataHydrationFavouriteStore {
        SwiftDataHydrationFavouriteStore(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFavouriteSaveFailure,
            diagnosticSink: diagnosticSink
        )
    }

    func resolveFavourite(_ favourite: HydrationFavourite) throws -> HydrationFavourite {
        try favouriteStore().resolve(id: favourite.id).hydrationFavourite
    }

    func requireUnambiguousSettingsAuthority() throws {
        _ = try authoritativeSettingsRecord()
    }

    func authoritativeSettingsRecord() throws -> AppSettingsRecord? {
        do {
            return try settingsStore().authoritativeRecord()
        } catch let error as SettingsStoreError {
            switch error {
            case .conflictingAuthorities:
                throw HydrationFavouriteStoreError.conflictingAuthorities
            default:
                throw error
            }
        }
    }
}

enum ApplicationCommandError: Error {
    case recordNotFound
}
