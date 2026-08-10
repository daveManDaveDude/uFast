import Observation

@MainActor
protocol SettingsFeatureCommanding: AnyObject {
    func settingsUpdateGoal(_ goal: FastingGoal) throws
    func settingsUpdateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws
    func settingsUpdateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        projectSystemSurfaces: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws
    func settingsDeleteAllData() throws
}

extension ApplicationCommands: SettingsFeatureCommanding {
    func settingsUpdateGoal(_ goal: FastingGoal) throws {
        try updateGoal(goal)
    }

    func settingsUpdateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws {
        try updateHydrationFavourites(water: water, tea: tea, coffee: coffee)
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

    func settingsDeleteAllData() throws {
        try deleteAllData()
    }
}

@MainActor
@Observable
final class SettingsFeatureController {
    var selection = FastingGoal.default
    var saveError: String?
    var deleteError: String?
    var automaticallyShowLiveActivities = false
    var liveActivityStatus: String?
    var waterAmount = "500"
    var teaAmount = "300"
    var coffeeAmount = "300"

    @ObservationIgnored private weak var commands: (any SettingsFeatureCommanding)?
    @ObservationIgnored private var outcomeRevision = 0

    func connect(commands: (any SettingsFeatureCommanding)?) {
        self.commands = commands
    }

    func load(_ snapshot: SettingsFeatureSnapshot) {
        if snapshot.settings.count > 1 {
            saveError = "Your local settings conflict. Nothing was changed."
        }
        guard snapshot.settings.count == 1, let settings = snapshot.settings.first else { return }
        selection = settings.fastingGoal
        automaticallyShowLiveActivities = settings.automaticLiveActivityPreference == .enabled
        waterAmount = String(settings.waterFavouriteMillilitres)
        teaAmount = String(settings.teaFavouriteMillilitres)
        coffeeAmount = String(settings.coffeeFavouriteMillilitres)
    }

    func saveGoal(_ goal: FastingGoal, previousGoal: FastingGoal) {
        selection = goal
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsUpdateGoal(goal)
            saveError = nil
        } catch {
            selection = previousGoal
            saveError = "Your goal couldn’t be saved. Please try again."
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
                    liveActivityStatus = ActiveFastLiveActivityStatusCopy.message(for: result)
                }
                onOutcome()
            }
            liveActivityStatus = nil
        } catch {
            automaticallyShowLiveActivities = previousPreference == .enabled
            liveActivityStatus = AutomaticLiveActivityCopy.settingsSaveFailure
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
            saveError = "Your drink favourites couldn’t be saved. Please try again."
        }
    }

    func deleteAllData() {
        do {
            guard let commands else { throw ApplicationCommandError.recordNotFound }
            try commands.settingsDeleteAllData()
            deleteError = nil
        } catch {
            deleteError = "Your data couldn’t be deleted. Please try again."
        }
    }
}

struct HydrationFavouriteAmounts: Equatable {
    let water: Int
    let tea: Int
    let coffee: Int
}
