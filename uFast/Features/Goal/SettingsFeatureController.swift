import Foundation
import Observation

@MainActor
protocol SettingsFeatureCommanding: AnyObject {
    func settingsUpdateGoal(_ goal: FastingGoal) throws
    func settingsUpdateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws
    func settingsCreateFavourite(
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws
    func settingsUpdateFavourite(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws
    func settingsDeleteFavourite(id: UUID) throws
    func settingsUpdateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws
    func settingsUpdateInferredFastDetectionEnabled(_ enabled: Bool) throws
    func settingsDeleteAllData() throws
}

extension ApplicationCommands: SettingsFeatureCommanding {
    func settingsUpdateGoal(_ goal: FastingGoal) throws {
        try updateGoal(goal)
    }

    func settingsUpdateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws {
        try updateHydrationFavourites(water: water, tea: tea, coffee: coffee)
    }

    func settingsCreateFavourite(
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws {
        _ = try createFavourite(
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric
        )
    }

    func settingsUpdateFavourite(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool
    ) throws {
        _ = try updateFavourite(
            id: id,
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric
        )
    }

    func settingsDeleteFavourite(id: UUID) throws {
        try deleteFavourite(id: id)
    }

    func settingsUpdateAutomaticLiveActivityPreference(
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

    func settingsUpdateInferredFastDetectionEnabled(_ enabled: Bool) throws {
        try updateInferredFastDetectionEnabled(enabled)
    }

    func settingsDeleteAllData() throws {
        try deleteAllData()
    }
}

extension SettingsFeatureCommanding {
    func settingsCreateFavourite(
        name _: String,
        volumeMillilitres _: Int,
        isCaloric _: Bool
    ) throws {
        throw ApplicationCommandError.recordNotFound
    }

    func settingsUpdateFavourite(
        id _: UUID,
        name _: String,
        volumeMillilitres _: Int,
        isCaloric _: Bool
    ) throws {
        throw ApplicationCommandError.recordNotFound
    }

    func settingsDeleteFavourite(id _: UUID) throws {
        throw ApplicationCommandError.recordNotFound
    }
}

extension TodayFeatureCommanding {
    func todayAddFavouriteDrink(
        _ favourite: HydrationFavourite,
        endingActiveFast: Bool
    ) throws {
        guard !endingActiveFast else { throw ApplicationCommandError.recordNotFound }
        try todayAddFavouriteDrink(favourite)
    }
}

@MainActor
@Observable
final class SettingsFeatureController {
    var selection = FastingGoal.default
    var saveError: String?
    var deleteError: String?
    var automaticallyShowLiveActivities = false
    var inferredFastDetectionEnabled = false
    var liveActivityStatus: String?
    var waterAmount = "500"
    var teaAmount = "300"
    var coffeeAmount = "300"

    @ObservationIgnored private weak var commands: (any SettingsFeatureCommanding)?
    @ObservationIgnored private var textResolver = AppTextResolver()
    @ObservationIgnored private var outcomeRevision = 0

    func connect(commands: (any SettingsFeatureCommanding)?) {
        self.commands = commands
    }

    func setTextResolver(_ resolver: AppTextResolver) {
        textResolver = resolver
    }

    func load(_ snapshot: SettingsFeatureSnapshot) {
        if snapshot.settings.count > 1 {
            saveError = textResolver(.settingsConflictError)
        }
        guard snapshot.settings.count == 1, let settings = snapshot.settings.first else { return }
        selection = settings.fastingGoal
        automaticallyShowLiveActivities = settings.automaticLiveActivityPreference == .enabled
        inferredFastDetectionEnabled = settings.inferredFastDetectionEnabled
        waterAmount = String(settings.waterFavouriteMillilitres)
        teaAmount = String(settings.teaFavouriteMillilitres)
        coffeeAmount = String(settings.coffeeFavouriteMillilitres)
    }

    func setInferredFastDetection(enabled: Bool) {
        let previousValue = inferredFastDetectionEnabled
        inferredFastDetectionEnabled = enabled
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsUpdateInferredFastDetectionEnabled(enabled)
            saveError = nil
        } catch {
            inferredFastDetectionEnabled = previousValue
            saveError = textResolver(.settingsInferredSaveError)
        }
    }

    func saveGoal(_ goal: FastingGoal, previousGoal: FastingGoal) {
        selection = goal
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsUpdateGoal(goal)
            saveError = nil
        } catch {
            selection = previousGoal
            saveError = textResolver(.settingsGoalSaveError)
        }
    }

    func setAutomaticLiveActivities(
        enabled: Bool,
        previousPreference: AutomaticLiveActivityPreference,
        onOutcome: @escaping () -> Void
    ) {
        automaticallyShowLiveActivities = enabled
        let preference: AutomaticLiveActivityPreference = enabled ? .enabled : .disabled
        outcomeRevision += 1
        let revision = outcomeRevision
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsUpdateAutomaticLiveActivityPreference(
                preference, projectSystemSurfaces: true
            ) { [weak self] outcome in
                guard let self, revision == outcomeRevision else { return }
                if let result = outcome.liveActivityResult {
                    liveActivityStatus = ActiveFastLiveActivityStatus.status(for: result).map {
                        textResolver(.liveActivityStatus($0))
                    }
                }
                onOutcome()
            }
            liveActivityStatus = nil
        } catch {
            automaticallyShowLiveActivities = previousPreference == .enabled
            liveActivityStatus = textResolver(.settingsLiveActivitySaveError)
        }
    }

    func saveFavourites(values: HydrationFavouriteAmounts, previous: HydrationFavouriteAmounts) {
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsUpdateHydrationFavourites(
                water: values.water, tea: values.tea, coffee: values.coffee
            )
            saveError = nil
        } catch {
            waterAmount = String(previous.water)
            teaAmount = String(previous.tea)
            coffeeAmount = String(previous.coffee)
            saveError = textResolver(.settingsFavouritesSaveError)
        }
    }

    func deleteAllData() {
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsDeleteAllData()
            deleteError = nil
        } catch {
            deleteError = textResolver(.settingsDeleteError)
        }
    }

    func createFavourite(_ name: String, amount: String, isCaloric: Bool) throws {
        guard let volume = Int(amount), let commands else {
            throw HydrationFavouriteStoreError.invalidAmount
        }
        try commands.settingsCreateFavourite(
            name: name,
            volumeMillilitres: volume,
            isCaloric: isCaloric
        )
    }

    func updateFavourite(
        id: UUID,
        name: String,
        amount: String,
        isCaloric: Bool
    ) throws {
        guard let volume = Int(amount), let commands else {
            throw HydrationFavouriteStoreError.invalidAmount
        }
        try commands.settingsUpdateFavourite(
            id: id,
            name: name,
            volumeMillilitres: volume,
            isCaloric: isCaloric
        )
    }

    func deleteFavourite(id: UUID) throws {
        guard let commands else { throw ApplicationCommandError.recordNotFound }
        try commands.settingsDeleteFavourite(id: id)
    }
}

struct HydrationFavouriteAmounts: Equatable {
    let water: Int
    let tea: Int
    let coffee: Int
}
