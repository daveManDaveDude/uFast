@testable import uFast
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma
@MainActor
final class FeatureControllerTests: XCTestCase {
    func testTodayStartSuccessAndPersistenceFailureTransitions() {
        let commands = FeatureCommandSpy()
        let controller = TodayFeatureController()
        controller.connect(commands: commands)

        controller.startFast(goal: .default, onOutcome: {})
        XCTAssertNil(controller.startError)
        XCTAssertFalse(controller.fastRecorded)

        commands.error = TestFailure.requested
        controller.startFast(goal: .default, onOutcome: {})
        XCTAssertEqual(controller.startError, "Your fast couldn’t be started. Please try again.")
    }

    func testTodayIgnoresOlderOptionalSurfaceCompletion() {
        let commands = FeatureCommandSpy()
        let controller = TodayFeatureController()
        controller.connect(commands: commands)
        var accepted = 0

        controller.startFast(goal: .default) { accepted += 1 }
        controller.startFast(goal: .default) { accepted += 1 }
        commands.completions[0](.init(widgetError: nil, liveActivityResult: .requestFailed))
        XCTAssertEqual(accepted, 0)
        XCTAssertNil(controller.liveActivityStatus)

        commands.completions[1](.init(widgetError: nil, liveActivityResult: .requestFailed))
        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(
            controller.liveActivityStatus,
            AppTextResolver()(.liveActivityStatus(.requestFailed))
        )
    }

    func testSettingsLoadsSnapshotAndRestoresGoalAfterFailure() {
        let commands = FeatureCommandSpy()
        let controller = SettingsFeatureController()
        controller.connect(commands: commands)
        controller.load(SettingsFeatureSnapshot(settings: [
            AppSettingsSnapshot(
                fastingGoal: FastingGoal(hours: 16) ?? .default,
                waterFavouriteMillilitres: 750,
                teaFavouriteMillilitres: 250,
                coffeeFavouriteMillilitres: 200
            ),
        ]))
        XCTAssertEqual(controller.selection.hours, 16)
        XCTAssertEqual(controller.waterAmount, "750")

        commands.error = TestFailure.requested
        controller.saveGoal(FastingGoal(hours: 18) ?? .default, previousGoal: controller.selection)
        XCTAssertEqual(controller.selection.hours, 16)
        XCTAssertEqual(controller.saveError, "Your goal couldn’t be saved. Please try again.")
    }

    func testSettingsRestoresFavouritesAndReportsDeleteFailure() {
        let commands = FeatureCommandSpy()
        commands.error = TestFailure.requested
        let controller = SettingsFeatureController()
        controller.connect(commands: commands)

        controller.saveFavourites(
            values: .init(water: 1, tea: 2, coffee: 3),
            previous: .init(water: 500, tea: 300, coffee: 300)
        )
        XCTAssertEqual(controller.waterAmount, "500")
        XCTAssertEqual(controller.saveError, "Your drink favourites couldn’t be saved. Please try again.")

        controller.deleteAllData()
        XCTAssertEqual(controller.deleteError, "Your data couldn’t be deleted. Please try again.")
    }
}

private enum TestFailure: Error {
    case requested
}

@MainActor
private final class FeatureCommandSpy: TodayFeatureCommanding, SettingsFeatureCommanding {
    var error: Error?
    var completions: [(PostCommitProjectionOutcome) -> Void] = []

    func todayStartFast(
        at _: Date?,
        goal _: FastingGoal,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome {
        try failIfRequested()
        if let completion {
            completions.append(completion)
        }
        return .init(recordID: UUID(), projectionEnqueued: true)
    }

    func todayCorrectActiveFastStart(
        to _: Date,
        goal _: FastingGoal,
        completion _: ((PostCommitProjectionOutcome) -> Void)?
    ) throws -> ApplicationCommandOutcome {
        try failIfRequested()
        return .init(recordID: UUID(), projectionEnqueued: true)
    }

    func todayHasStartConflict(startDate _: Date, excluding _: UUID?) throws -> Bool {
        false
    }

    func todayEndFast(at _: Date?, goal _: FastingGoal) throws -> ApplicationCommandOutcome {
        try failIfRequested()
        return .init(recordID: UUID(), projectionEnqueued: true)
    }

    func saveFood(
        _: FoodEntryDraft,
        replacing _: UUID?,
        goal _: FastingGoal,
        endingActiveFast _: Bool
    ) throws {
        try failIfRequested()
    }

    func deleteFood(id _: UUID, confirmingInferredImpact _: Bool) throws {
        try failIfRequested()
    }

    func todayAddFavouriteDrink(_: HydrationFavourite) throws {
        try failIfRequested()
    }

    func saveHydration(
        _: HydrationEntryDraft,
        replacing _: UUID?,
        goal _: FastingGoal,
        endingActiveFast _: Bool
    ) throws {
        try failIfRequested()
    }

    func deleteHydration(id _: UUID, confirmingInferredImpact _: Bool) throws {
        try failIfRequested()
    }

    func settingsUpdateGoal(_: FastingGoal) throws {
        try failIfRequested()
    }

    func settingsUpdateHydrationFavourites(water _: Int, tea _: Int, coffee _: Int) throws {
        try failIfRequested()
    }

    func todayUpdateAutomaticLiveActivityPreference(
        _: AutomaticLiveActivityPreference,
        projectSystemSurfaces _: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws {
        try failIfRequested()
        if let completion {
            completions.append(completion)
        }
    }

    func settingsUpdateAutomaticLiveActivityPreference(
        _: AutomaticLiveActivityPreference,
        projectSystemSurfaces _: Bool,
        completion: ((PostCommitProjectionOutcome) -> Void)?
    ) throws {
        try failIfRequested()
        if let completion {
            completions.append(completion)
        }
    }

    func settingsUpdateInferredFastDetectionEnabled(_: Bool) throws {
        try failIfRequested()
    }

    func settingsDeleteAllData() throws {
        try failIfRequested()
    }

    private func failIfRequested() throws {
        if let error {
            throw error
        }
    }
}

@MainActor
final class SettingsInferredFastFailureTests: XCTestCase {
    func testSettingsRestoresInferredFastToggleAndReportsSaveFailure() {
        let commands = FeatureCommandSpy()
        let controller = SettingsFeatureController()
        controller.connect(commands: commands)
        controller.load(SettingsFeatureSnapshot(settings: [
            AppSettingsSnapshot(
                fastingGoal: .default,
                inferredFastDetectionEnabled: false
            ),
        ]))

        commands.error = TestFailure.requested
        controller.setInferredFastDetection(enabled: true)

        XCTAssertFalse(controller.inferredFastDetectionEnabled)
        XCTAssertEqual(
            controller.saveError,
            "Your inferred fast setting couldn’t be saved. Please try again."
        )
    }
}
