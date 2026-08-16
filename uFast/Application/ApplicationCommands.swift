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
            sourceFoodID: sourceFoodID,
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

    func startInferredFast(
        sourceFoodID: UUID,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String? = nil,
        expectedGoal: FastingGoal? = nil
    ) throws -> ApplicationCommandOutcome {
        let candidate = try revalidatedInferredCandidate(
            sourceFoodID: sourceFoodID,
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
        try FoodEntryService(repository: foodRepository(), clock: clock).save(
            draft,
            replacing: record,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
            projectionCoordinator.enqueue(.fastEndedOrDeleted)
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
    }

    func deleteFood(id: UUID) throws {
        try foodRepository().delete(requiredFoodRecord(id: id))
        projectionCoordinator.publishHistoryInvalidation()
    }

    func saveHydration(
        _ draft: HydrationEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        let record = try recordID.flatMap { try hydrationRecord(id: $0) }
        try HydrationEntryService(repository: hydrationRepository(), clock: clock).save(
            draft,
            replacing: record,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
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
        try HydrationEntryService(repository: hydrationRepository(), clock: clock).save(
            draft,
            replacing: nil,
            goal: goal,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
            projectionCoordinator.enqueue(.fastEndedOrDeleted)
        } else {
            projectionCoordinator.publishHistoryInvalidation()
        }
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

    func deleteHydration(id: UUID) throws {
        try hydrationRepository().delete(requiredHydrationRecord(id: id))
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
            simulateSaveFailure: configuration.simulateFoodSaveFailure
        )
    }

    private func hydrationRepository() -> SwiftDataHydrationEntryRepository {
        SwiftDataHydrationEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: configuration.simulateDrinkSaveFailure
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

    // The expectation captures the presentation identity used to detect a
    // changed source while intentionally allowing an in-progress end to advance.
    // swiftlint:disable:next function_body_length function_parameter_count
    private func revalidatedInferredCandidate(
        sourceFoodID: UUID,
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
        guard let source = foods.first(where: { $0.id == sourceFoodID }),
              source.occurredAt == expectedStartDate,
              expectedSourceDescription == nil || source.foodDescription == expectedSourceDescription
        else { throw InferredFastConversionError.candidateUnavailable }
        let foodSnapshots = foods.map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: true
            )
        }
        let recorded = try modelContext.fetch(FetchDescriptor<FastRecord>())
            .map(\.recordedInterval)
        let withoutRecordedConflicts = InferredFastProjector.project(
            foodEvents: foodSnapshots,
            currentGoal: settings.fastingGoal,
            enabled: true,
            now: clock.now,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        )
        guard let candidate = withoutRecordedConflicts.first(where: { interval in
            interval.sourceFoodID == sourceFoodID
                && interval.startDate == expectedStartDate
                && (expectedState == .inProgress || interval.endDate == expectedEndDate)
                && interval.state == expectedState
        }) else {
            let hasUnconflictedShape = withoutRecordedConflicts.contains {
                $0.sourceFoodID == sourceFoodID
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
