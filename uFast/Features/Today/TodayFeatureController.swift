import Foundation
import Observation

@MainActor
protocol TodayFeatureCommanding: AnyObject {
    func todayStartFast(
        at startDate: Date?,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome
    func todayCorrectActiveFastStart(
        to startDate: Date,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome
    func todayHasStartConflict(startDate: Date, excluding excludedID: UUID?) throws -> Bool
    func todayEndFast(at endDate: Date?, goal: FastingGoal) throws -> ApplicationCommandOutcome
    func saveFood(
        _ draft: FoodEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws
    func deleteFood(id: UUID) throws
    func todayAddFavouriteDrink(_ favourite: HydrationFavourite) throws
    func todayAddFavouriteDrink(
        _ favourite: HydrationFavourite,
        endingActiveFast: Bool
    ) throws
    func saveHydration(
        _ draft: HydrationEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws
    func deleteHydration(id: UUID) throws
    func todayUpdateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws
}

extension ApplicationCommands: TodayFeatureCommanding {
    func todayStartFast(
        at startDate: Date?,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome {
        try startFast(at: startDate, goal: goal, completion: completion)
    }

    func todayCorrectActiveFastStart(
        to startDate: Date,
        goal: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome {
        try correctActiveFastStart(to: startDate, goal: goal, completion: completion)
    }

    func todayHasStartConflict(startDate: Date, excluding excludedID: UUID?) throws -> Bool {
        try hasStartConflict(startDate: startDate, excluding: excludedID)
    }

    func todayEndFast(at endDate: Date?, goal: FastingGoal) throws -> ApplicationCommandOutcome {
        try endFast(at: endDate, goal: goal)
    }

    func todayAddFavouriteDrink(_ favourite: HydrationFavourite) throws {
        try addFavouriteDrink(favourite, endingActiveFast: false)
    }

    func todayAddFavouriteDrink(
        _ favourite: HydrationFavourite,
        endingActiveFast: Bool
    ) throws {
        try addFavouriteDrink(favourite, endingActiveFast: endingActiveFast)
    }

    func todayUpdateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws {
        try updateAutomaticLiveActivityPreference(
            preference,
            projectSystemSurfaces: projectSystemSurfaces,
            completion: completion
        )
    }
}

@MainActor
@Observable
final class TodayFeatureController {
    var startError: String?
    var endError: String?
    var fastRecorded = false
    var liveActivityStatus: String?

    @ObservationIgnored private weak var commands: (any TodayFeatureCommanding)?
    @ObservationIgnored private var outcomeRevision = 0

    func connect(commands: (any TodayFeatureCommanding)?) {
        self.commands = commands
    }

    func startFast(goal: FastingGoal, onOutcome: @escaping () -> Void) {
        let revision = nextOutcomeRevision()
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            _ = try commands.todayStartFast(at: nil, goal: goal) { [weak self] outcome in
                self?.accept(outcome, revision: revision, onOutcome: onOutcome)
            }
            startError = nil
            fastRecorded = false
        } catch {
            startError = "Your fast couldn’t be started. Please try again."
        }
    }

    func startFast(
        at startDate: Date,
        goal: FastingGoal,
        onOutcome: @escaping () -> Void
    ) throws {
        let revision = nextOutcomeRevision()
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        _ = try commands.todayStartFast(at: startDate, goal: goal) { [weak self] outcome in
            self?.accept(outcome, revision: revision, onOutcome: onOutcome)
        }
        fastRecorded = false
    }

    func correctActiveFastStart(to startDate: Date, goal: FastingGoal) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        _ = try commands.todayCorrectActiveFastStart(to: startDate, goal: goal, completion: nil)
    }

    func hasStartConflict(startDate: Date, excluding excludedID: UUID?) -> Bool {
        (try? commands?.todayHasStartConflict(startDate: startDate, excluding: excludedID)) ?? false
    }

    func endFast(goal: FastingGoal) {
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            _ = try commands.todayEndFast(at: nil, goal: goal)
            endError = nil
            fastRecorded = true
        } catch {
            endError = "Your fast couldn’t be ended. Please try again."
        }
    }

    func endFast(at endDate: Date, goal: FastingGoal) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        _ = try commands.todayEndFast(at: endDate, goal: goal)
        endError = nil
        fastRecorded = true
    }

    func saveFood(
        _ draft: FoodEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.saveFood(
            draft, replacing: recordID, goal: goal, endingActiveFast: endingActiveFast
        )
    }

    func deleteFood(id: UUID) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.deleteFood(id: id)
    }

    func addFavouriteDrink(_ favourite: HydrationFavourite) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.todayAddFavouriteDrink(favourite)
    }

    func addFavouriteDrink(
        _ favourite: HydrationFavourite,
        endingActiveFast: Bool
    ) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.todayAddFavouriteDrink(favourite, endingActiveFast: endingActiveFast)
    }

    func saveHydration(
        _ draft: HydrationEntryDraft,
        replacing recordID: UUID?,
        goal: FastingGoal,
        endingActiveFast: Bool
    ) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.saveHydration(
            draft, replacing: recordID, goal: goal, endingActiveFast: endingActiveFast
        )
    }

    func deleteHydration(id: UUID) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.deleteHydration(id: id)
    }

    func updateAutomaticPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool,
        onOutcome: @escaping () -> Void
    ) throws {
        let revision = nextOutcomeRevision()
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.todayUpdateAutomaticLiveActivityPreference(
            preference,
            projectSystemSurfaces: projectSystemSurfaces
        ) { [weak self] outcome in
            self?.accept(outcome, revision: revision, onOutcome: onOutcome)
        }
    }

    func setLiveActivityStatus(_ result: ActiveFastLiveActivityResult) {
        liveActivityStatus = ActiveFastLiveActivityStatusCopy.message(for: result)
    }

    private func nextOutcomeRevision() -> Int {
        outcomeRevision += 1
        return outcomeRevision
    }

    private func accept(
        _ outcome: PostCommitProjectionOutcome,
        revision: Int,
        onOutcome: @escaping () -> Void
    ) {
        guard revision == outcomeRevision else { return }
        if let result = outcome.liveActivityResult {
            setLiveActivityStatus(result)
        }
        onOutcome()
    }
}
