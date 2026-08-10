import Foundation
import SwiftData

struct ApplicationCommandConfiguration: Equatable {
    var simulateFastSaveFailure = false
    var simulateFastHistoryFailure = false
    var simulateFoodSaveFailure = false
    var simulateDrinkSaveFailure = false
    var simulateGoalSaveFailure = false
    var simulateLiveActivitySettingsSaveFailure = false
    var simulateDeleteAllFailure = false
}

struct ApplicationCommandOutcome: Equatable {
    let recordID: UUID?
    let projectionEnqueued: Bool
}

@MainActor
final class ApplicationCommands {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private let projectionCoordinator: PostCommitProjectionCoordinator
    private let configuration: ApplicationCommandConfiguration

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
        }
    }

    func deleteFood(id: UUID) throws {
        try foodRepository().delete(requiredFoodRecord(id: id))
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
        }
    }

    func addFavouriteDrink(_ favourite: HydrationFavourite) throws {
        _ = try hydrationRepository().createFavourite(favourite, occurredAt: clock.now)
    }

    func deleteHydration(id: UUID) throws {
        try hydrationRepository().delete(requiredHydrationRecord(id: id))
    }

    func updateGoal(_ goal: FastingGoal) throws {
        try settingsStore(simulateFailure: configuration.simulateGoalSaveFailure).updateGoal(goal)
        if let activeFast = try? ActiveFastAuthority.fetch(in: modelContext) {
            projectionCoordinator.enqueue(
                .activeFastChanged(fast: activeFast, goal: goal, now: clock.now)
            )
        }
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
}

enum ApplicationCommandError: Error {
    case recordNotFound
}
