import SwiftData
@testable import uFast
import XCTest

@MainActor
final class ApplicationCommandsTests: XCTestCase {
    private enum ProjectionError: Error { case simulated }

    func testStartCommitsBeforeWidgetThenActivityAndRepeatedIntentIsCoalesced() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        var order: [String] = []
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
                XCTAssertFalse(context.hasChanges)
                order.append("widget")
            },
            activityEffect: { _ in
                order.append("activity")
                return .shown(activityIdentifier: "activity")
            }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: projection
        )

        let first = try commands.startFast(goal: .default)
        let repeated = try commands.startFast(goal: .default)
        await projection.waitForPendingEffects()

        XCTAssertTrue(first.projectionEnqueued)
        XCTAssertFalse(repeated.projectionEnqueued)
        XCTAssertEqual(first.recordID, repeated.recordID)
        XCTAssertEqual(order, ["widget", "activity"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
    }

    func testPersistenceFailureAttemptsNoProjectionEffect() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        var effects = 0
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in effects += 1 },
            activityEffect: { _ in effects += 1; return .updated }
        )
        let commands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: projection,
            configuration: ApplicationCommandConfiguration(simulateFastSaveFailure: true)
        )

        XCTAssertThrowsError(try commands.startFast(goal: .default))
        XCTAssertEqual(effects, 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testProjectionFailureDoesNotRollbackCommittedLocalRecord() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        var activityAttempted = false
        var outcome: PostCommitProjectionOutcome?
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in throw ProjectionError.simulated },
            activityEffect: { _ in activityAttempted = true; return .requestFailed }
        )
        let commands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000)),
            projectionCoordinator: projection
        )

        _ = try commands.startFast(goal: .default) { outcome = $0 }
        await projection.waitForPendingEffects()

        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FastRecord>()), 1)
        XCTAssertFalse(container.mainContext.hasChanges)
        XCTAssertTrue(activityAttempted)
        XCTAssertNotNil(outcome?.widgetError)
        XCTAssertEqual(outcome?.liveActivityResult, .requestFailed)
    }

    func testFoodGoalAndDeleteAllUseTheSamePostCommitCoordinator() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.save()
        var widgetEffects = 0
        var activityEffects = 0
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in
                XCTAssertFalse(context.hasChanges)
                widgetEffects += 1
            },
            activityEffect: { _ in activityEffects += 1; return .updated }
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )

        _ = try commands.startFast(at: now.addingTimeInterval(-3600), goal: .default)
        try commands.saveFood(
            FoodEntryDraft(description: "Lunch", occurredAt: now),
            replacing: nil,
            goal: .default,
            endingActiveFast: true
        )
        try commands.updateGoal(XCTUnwrap(FastingGoal(hours: 18)))
        try commands.deleteAllData()
        await projection.waitForPendingEffects()

        XCTAssertEqual(widgetEffects, 3)
        XCTAssertEqual(activityEffects, 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 0)
    }
}
