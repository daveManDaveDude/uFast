import Foundation
import SwiftData

// swiftlint:disable file_length type_body_length

struct ApplicationCommandConfiguration: Equatable {
    var simulateFastSaveFailure = false
    var simulateFastHistoryFailure = false
    var simulateFoodSaveFailure = false
    var simulateDrinkSaveFailure = false
    var simulateFavouriteSaveFailure = false
    var simulateGoalSaveFailure = false
    var simulateLiveActivitySettingsSaveFailure = false
    var simulateInferredFastDetectionSaveFailure = false
    var simulateDeleteAllFailure = false
    var simulateBoundaryReconciliationFailure = false
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

private struct InferredProjectionIdentity: Equatable {
    let startDate: Date
    let endDate: Date

    init(_ interval: InferredFastInterval) {
        startDate = interval.startDate
        endDate = interval.endDate
    }
}

private struct PresentedInferredImpact: Equatable {
    let before: [InferredFastInterval]
    let after: [InferredFastInterval]

    static let none = Self(before: [], after: [])

    var requiresConfirmation: Bool {
        let beforeBySource = Dictionary(uniqueKeysWithValues: before.map {
            ($0.sourceBoundaryReference, InferredProjectionIdentity($0))
        })
        let afterBySource = Dictionary(uniqueKeysWithValues: after.map {
            ($0.sourceBoundaryReference, InferredProjectionIdentity($0))
        })
        return beforeBySource.contains { sourceReference, beforeIdentity in
            guard let afterIdentity = afterBySource[sourceReference] else {
                return true
            }
            return afterIdentity.startDate != beforeIdentity.startDate
                || afterIdentity.endDate < beforeIdentity.endDate
        }
    }
}

@MainActor
final class ApplicationCommands {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private let projectionCoordinator: PostCommitProjectionCoordinator
    private let configuration: ApplicationCommandConfiguration

    var historyPresentationInvalidation: HistoryPresentationInvalidation {
        projectionCoordinator.historyPresentationInvalidation
    }

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        projectionCoordinator: PostCommitProjectionCoordinator,
        configuration: ApplicationCommandConfiguration = .init()
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.projectionCoordinator = projectionCoordinator
        self.configuration = configuration
    }

    func startFast(
        at startDate: Date? = nil,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) throws -> ApplicationCommandOutcome {
        let repository = activeFastRepository()
        let existingID = try repository.activeFast()?.id
        let service = FastStartService(repository: repository, clock: clock)
        let fast = try startDate.map { try service.startFast(at: $0, goal: goal) }
            ?? service.startFast(goal: goal)
        guard existingID == nil else {
            return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: false)
        }
        projectionCoordinator.enqueue(
            .activeFastStarted(fast: fast, goal: goal, now: clock.now),
            completion: completion
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func correctActiveFastStart(
        to startDate: Date,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) throws -> ApplicationCommandOutcome {
        let fast = try FastStartService(
            repository: activeFastRepository(),
            clock: clock
        ).correctActiveFastStart(to: startDate)
        projectionCoordinator.enqueue(
            .activeFastChanged(fast: fast, goal: goal, now: clock.now),
            completion: completion
        )
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func hasStartConflict(startDate: Date, excluding excludedID: UUID?) throws -> Bool {
        try FastStartService(repository: activeFastRepository(), clock: clock)
            .hasConflict(startDate: startDate, excluding: excludedID)
    }

    func endFast(at endDate: Date? = nil, goal: FastingGoal) throws -> ApplicationCommandOutcome {
        let service = FastEndService(repository: activeFastRepository(), clock: clock)
        let fast = try endDate.map { try service.endFast(at: $0, goal: goal) }
            ?? service.endFast(goal: goal)
        guard let fast else {
            return ApplicationCommandOutcome(recordID: nil, projectionEnqueued: false)
        }
        projectionCoordinator.enqueue(.fastEndedOrDeleted)
        return ApplicationCommandOutcome(recordID: fast.id, projectionEnqueued: true)
    }

    func updateCompletedFast(id: UUID, startDate: Date, endDate: Date) throws {
        _ = try CompletedFastService(
            repository: completedFastRepository(),
            clock: clock
        ).update(id: id, startDate: startDate, endDate: endDate)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func completedFastValidationError(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> CompletedFastError? {
        try CompletedFastService(
            repository: completedFastRepository(),
            clock: clock
        ).validationError(id: id, startDate: startDate, endDate: endDate)
    }

    func deleteCompletedFast(id: UUID) throws {
        try CompletedFastService(repository: completedFastRepository(), clock: clock).delete(id: id)
        projectionCoordinator.publishHistoryInvalidation()
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
        let record = try recordID.flatMap { try foodRecord(id: $0) }
        let eventReference = record.map {
            CaloricBoundaryReference(kind: .food, id: $0.id)
        } ?? CaloricBoundaryReference(kind: .food, id: UUID())
        let inferredImpact = try presentedInferredImpact(
            resultingEventReference: eventReference,
            resultingEventDate: draft.occurredAt,
            resultingEventIsCaloric: draft.isCaloric,
            replacing: record.map { CaloricBoundaryReference(kind: .food, id: $0.id) }
        )
        let persistedImpact = try foodRepository().caloricEventImpact(for: draft, replacing: record)
        if inferredImpact.requiresConfirmation, !persistedImpact.requiresConfirmation, !endingActiveFast {
            throw FoodEntrySaveError.inferredConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: .none,
                    includesInferredInterval: true
                )
            )
        }
        let activeBefore = try ActiveFastAuthority.fetch(in: modelContext)
        do {
            try FoodEntryService(repository: foodRepository(), clock: clock).save(
                draft,
                replacing: record,
                goal: goal,
                endingActiveFast: endingActiveFast
            )
        } catch let error as FoodEntrySaveError where inferredImpact.requiresConfirmation {
            throw error.includingInferredImpact(persistedImpact: persistedImpact)
        }
        let activeAfter = try ActiveFastAuthority.fetch(in: modelContext)
        if activeBefore != nil, activeAfter == nil {
            projectionCoordinator.enqueue(.fastEndedOrDeleted)
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
    }

    func deleteFood(id: UUID, confirmingInferredImpact: Bool = false) throws {
        let record = try requiredFoodRecord(id: id)
        let reference = CaloricBoundaryReference(kind: .food, id: id)
        let inferredImpact = try presentedInferredImpact(
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
                CaloricEventConfirmationContext(
                    persistedImpact: .none,
                    includesInferredInterval: true
                )
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
        let eventReference = record.map {
            CaloricBoundaryReference(kind: .hydration, id: $0.id)
        } ?? CaloricBoundaryReference(kind: .hydration, id: UUID())
        let inferredImpact = try presentedInferredImpact(
            resultingEventReference: eventReference,
            resultingEventDate: draft.occurredAt,
            resultingEventIsCaloric: draft.isCaloric,
            replacing: record.map { CaloricBoundaryReference(kind: .hydration, id: $0.id) }
        )
        let persistedImpact = try hydrationRepository().caloricEventImpact(for: draft, replacing: record)
        if inferredImpact.requiresConfirmation, !persistedImpact.requiresConfirmation, !endingActiveFast {
            throw HydrationEntrySaveError.inferredConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: .none,
                    includesInferredInterval: true
                )
            )
        }
        let activeBefore = try ActiveFastAuthority.fetch(in: modelContext)
        do {
            try HydrationEntryService(repository: hydrationRepository(), clock: clock).save(
                draft,
                replacing: record,
                goal: goal,
                endingActiveFast: endingActiveFast
            )
        } catch let error as HydrationEntrySaveError where inferredImpact.requiresConfirmation {
            throw error.includingInferredImpact(persistedImpact: persistedImpact)
        }
        let activeAfter = try ActiveFastAuthority.fetch(in: modelContext)
        if activeBefore != nil, activeAfter == nil {
            projectionCoordinator.enqueue(.fastEndedOrDeleted)
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
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
        return try favouriteStore().create(
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            at: clock.now
        )
    }

    func updateFavourite(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws -> HydrationFavouriteSnapshot {
        try requireUnambiguousSettingsAuthority()
        return try favouriteStore().update(
            id: id,
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            at: clock.now
        )
    }

    func deleteFavourite(id: UUID) throws {
        try requireUnambiguousSettingsAuthority()
        try favouriteStore().delete(id: id)
    }

    func deleteHydration(id: UUID, confirmingInferredImpact: Bool = false) throws {
        let record = try requiredHydrationRecord(id: id)
        let reference = CaloricBoundaryReference(kind: .hydration, id: id)
        let inferredImpact = try presentedInferredImpact(
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
                CaloricEventConfirmationContext(
                    persistedImpact: .none,
                    includesInferredInterval: true
                )
            )
        }
        try hydrationRepository().delete(record)
        projectionCoordinator.publishHistoryInvalidation()
    }

    func updateGoal(_ goal: FastingGoal) throws {
        try settingsStore(simulateFailure: configuration.simulateGoalSaveFailure).updateGoal(goal)
        if let activeFast = try? ActiveFastAuthority.fetch(in: modelContext) {
            projectionCoordinator.enqueue(
                .activeFastChanged(fast: activeFast, goal: goal, now: clock.now)
            )
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
    }

    func updateInferredFastDetectionEnabled(_ enabled: Bool) throws {
        try settingsStore(
            simulateFailure: configuration.simulateInferredFastDetectionSaveFailure
        ).updateInferredFastDetectionEnabled(enabled)
        projectionCoordinator.enqueue(.inferredFastDetectionChanged(enabled))
    }

    func updateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws {
        try settingsStore().updateHydrationFavourites(water: water, tea: tea, coffee: coffee)
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

    func deleteAllData() throws {
        try AppDataDeletionService.deleteEverything(
            in: modelContext,
            simulateFailure: configuration.simulateDeleteAllFailure
        )
        projectionCoordinator.enqueue(.allDataDeleted)
    }

    private func activeFastRepository() -> SwiftDataActiveFastRepository {
        SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFastSaveFailure
        )
    }

    private func completedFastRepository() -> SwiftDataActiveFastRepository {
        SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFastHistoryFailure
        )
    }

    private func foodRepository() -> SwiftDataFoodEntryRepository {
        SwiftDataFoodEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFoodSaveFailure,
            clock: clock
        )
    }

    private func hydrationRepository() -> SwiftDataHydrationEntryRepository {
        SwiftDataHydrationEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateDrinkSaveFailure,
            clock: clock
        )
    }

    private func settingsStore(simulateFailure: Bool = false) -> SwiftDataSettingsStore {
        SwiftDataSettingsStore(
            modelContext: modelContext,
            simulateSaveFailure: simulateFailure
        )
    }

    private func foodRecord(id: UUID) throws -> FoodEntryRecord? {
        try modelContext.fetch(FetchDescriptor<FoodEntryRecord>()).first { $0.id == id }
    }

    private func requiredFoodRecord(id: UUID) throws -> FoodEntryRecord {
        guard let record = try foodRecord(id: id) else {
            throw FoodEntryPersistenceError.recordNotFound
        }
        return record
    }

    private func hydrationRecord(id: UUID) throws -> HydrationEntryRecord? {
        try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>()).first { $0.id == id }
    }

    private func requiredHydrationRecord(id: UUID) throws -> HydrationEntryRecord {
        guard let record = try hydrationRecord(id: id) else {
            throw ApplicationCommandError.recordNotFound
        }
        return record
    }

    private func presentedInferredImpact(
        resultingEventReference: CaloricBoundaryReference,
        resultingEventDate: Date,
        resultingEventIsCaloric: Bool,
        replacing reference: CaloricBoundaryReference?
    ) throws -> PresentedInferredImpact {
        guard let settings = try authoritativeSettingsRecord(),
              settings.inferredFastDetectionEnabled
        else { return .none }
        let planner = CaloricBoundaryPersistencePlanner(modelContext: modelContext)
        let fasts = try planner.fasts().map(\.recordedInterval)
        let before = try InferredFastProjector.project(
            boundaries: planner.allBoundaries(),
            recordedFasts: fasts,
            currentGoal: settings.fastingGoal,
            enabled: true,
            now: clock.now,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        )
        let afterBoundaries = try planner.allBoundaries(excluding: reference).adding(
            resultingEventIsCaloric
                ? CaloricBoundary(
                    reference: resultingEventReference,
                    occurredAt: resultingEventDate,
                    description: ""
                )
                : nil
        )
        let after = InferredFastProjector.project(
            boundaries: afterBoundaries,
            recordedFasts: fasts,
            currentGoal: settings.fastingGoal,
            enabled: true,
            now: clock.now,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        )
        return PresentedInferredImpact(before: before, after: after)
    }

    // The expectation captures the presentation identity used to detect a
    // changed source while intentionally allowing an in-progress end to advance.
    // swiftlint:disable:next function_body_length function_parameter_count
    private func revalidatedInferredCandidate(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String?,
        expectedGoal: FastingGoal?,
        expectedState: InferredFastState
    ) throws -> InferredFastInterval {
        // Resolve the active authority before validating or converting either
        // inferred state.  A historical save must not bypass the same
        // zero/one/many integrity rule used by current-start conversion.
        _ = try ActiveFastAuthority.fetch(in: modelContext)
        guard let settings = try authoritativeSettingsRecord(),
              settings.inferredFastDetectionEnabled,
              expectedGoal == nil || expectedGoal == settings.fastingGoal
        else { throw InferredFastConversionError.candidateUnavailable }

        let foods = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>())
        let drinks = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>())
        let sourceDescription: String? = switch sourceBoundaryReference.kind {
        case .food:
            foods.first(where: { $0.id == sourceBoundaryReference.id })?.foodDescription
        case .hydration:
            drinks.first(where: { $0.id == sourceBoundaryReference.id })?.displayName
        }
        guard let sourceDescription,
              expectedSourceDescription == nil || sourceDescription == expectedSourceDescription
        else { throw InferredFastConversionError.candidateUnavailable }
        let foodSnapshots = foods.map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: true
            )
        }
        let hydrationSnapshots = drinks.map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: $0.isCaloric
            )
        }
        guard let sourceBoundary = CaloricBoundaryExtractor.boundaries(
            food: foodSnapshots,
            hydration: hydrationSnapshots
        ).first(where: { $0.reference == sourceBoundaryReference }),
            sourceBoundary.occurredAt == expectedStartDate
        else { throw InferredFastConversionError.candidateUnavailable }
        let recorded = try modelContext.fetch(FetchDescriptor<FastRecord>())
            .map(\.recordedInterval)
        let withoutRecordedConflicts = InferredFastProjector.project(
            boundaries: CaloricBoundaryExtractor.boundaries(
                food: foodSnapshots,
                hydration: hydrationSnapshots
            ),
            currentGoal: settings.fastingGoal,
            enabled: true,
            now: clock.now,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        )
        guard let candidate = withoutRecordedConflicts.first(where: { interval in
            interval.sourceBoundaryReference == sourceBoundaryReference
                && interval.startDate == expectedStartDate
                && (expectedState == .inProgress || interval.endDate == expectedEndDate)
                && interval.state == expectedState
        }) else {
            let hasUnconflictedShape = withoutRecordedConflicts.contains {
                $0.sourceBoundaryReference == sourceBoundaryReference
                    && $0.startDate == expectedStartDate
                    && (expectedState == .inProgress || $0.endDate == expectedEndDate)
                    && $0.state == expectedState
            }
            if hasUnconflictedShape {
                throw InferredFastConversionError.conflictingRecordedFast
            }
            throw InferredFastConversionError.candidateUnavailable
        }

        guard !FastConflictChecker.hasConflict(
            proposedStart: candidate.startDate,
            proposedEnd: candidate.endDate,
            among: recorded
        ) else {
            throw InferredFastConversionError.conflictingRecordedFast
        }
        return candidate
    }
}

private extension ApplicationCommands {
    func favouriteStore() -> SwiftDataHydrationFavouriteStore {
        SwiftDataHydrationFavouriteStore(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateFavouriteSaveFailure
        )
    }

    func resolveFavourite(_ favourite: HydrationFavourite) throws -> HydrationFavourite {
        if let id = favourite.userCreatedID {
            return try favouriteStore().resolve(id: id).hydrationFavourite
        }
        guard favourite.type != .custom else {
            throw HydrationFavouriteStoreError.recordNotFound
        }
        let settings = try authoritativeSettingsRecord()
        return HydrationFavouriteProvider.favourites(settings: settings)
            .first { $0.type == favourite.type } ?? favourite
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

private extension FoodEntrySaveError {
    func includingInferredImpact(persistedImpact: CaloricEventImpact) -> Self {
        switch self {
        case .confirmationRequired:
            .confirmationRequiredWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    fallbackKind: .active,
                    includesInferredInterval: true
                )
            )
        case let .confirmationRequiredWithImpact(context):
            .confirmationRequiredWithImpact(context.includingInferredInterval())
        case .completedFastConfirmationRequired:
            .completedConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    includesInferredInterval: true
                )
            )
        case let .completedConfirmationWithImpact(context):
            .completedConfirmationWithImpact(context.includingInferredInterval())
        case .inferredFastConfirmationRequired:
            .inferredConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    includesInferredInterval: true
                )
            )
        case let .inferredConfirmationWithImpact(context):
            .inferredConfirmationWithImpact(context.includingInferredInterval())
        default:
            self
        }
    }
}

private extension HydrationEntrySaveError {
    func includingInferredImpact(persistedImpact: CaloricEventImpact) -> Self {
        switch self {
        case .confirmationRequired:
            .confirmationRequiredWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    fallbackKind: .active,
                    includesInferredInterval: true
                )
            )
        case let .confirmationRequiredWithImpact(context):
            .confirmationRequiredWithImpact(context.includingInferredInterval())
        case .completedFastConfirmationRequired:
            .completedConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    includesInferredInterval: true
                )
            )
        case let .completedConfirmationWithImpact(context):
            .completedConfirmationWithImpact(context.includingInferredInterval())
        case .inferredFastConfirmationRequired:
            .inferredConfirmationWithImpact(
                CaloricEventConfirmationContext(
                    persistedImpact: persistedImpact,
                    includesInferredInterval: true
                )
            )
        case let .inferredConfirmationWithImpact(context):
            .inferredConfirmationWithImpact(context.includingInferredInterval())
        default:
            self
        }
    }
}
