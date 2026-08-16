import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable function_body_length

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

    func testHydrationHistoryInvalidationPublishesOnlyAfterCommit() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let invalidation = HistoryPresentationInvalidation()
        var systemProjectionEffects = 0
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in systemProjectionEffects += 1 },
            activityEffect: { _ in systemProjectionEffects += 1; return nil },
            historyPresentationInvalidation: invalidation
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let water = HydrationEntryDraft(
            type: .water,
            customName: nil,
            volumeMillilitres: 500,
            occurredAt: now,
            isCaloric: false
        )

        try commands.saveHydration(
            water,
            replacing: nil,
            goal: .default,
            endingActiveFast: false
        )
        XCTAssertEqual(invalidation.revision, 1)
        XCTAssertEqual(systemProjectionEffects, 0)

        let failedCommands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection,
            configuration: .init(simulateDrinkSaveFailure: true)
        )
        XCTAssertThrowsError(
            try failedCommands.saveHydration(
                water,
                replacing: nil,
                goal: .default,
                endingActiveFast: false
            )
        )
        XCTAssertEqual(invalidation.revision, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)

        let savedID = try XCTUnwrap(
            context.fetch(FetchDescriptor<HydrationEntryRecord>()).first?.id
        )
        try commands.deleteHydration(id: savedID)
        XCTAssertEqual(invalidation.revision, 2)
    }

    func testCommittedActiveFastCorrectionRefreshesProductionPairAndRetainsItOnFailure() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 16, hour: 8, minute: 40)
            )
        )
        let originalStart = now.addingTimeInterval(-3600)
        let fast = FastRecord(startDate: originalStart, goalAtStart: .default)
        context.insert(fast)
        try context.save()

        let selectedWindow = try XCTUnwrap(
            TemporalHistoryPresentation.calendarDayWindow(containing: now, calendar: calendar)
        ).interval
        let source = SwiftDataHistoryProjectionDataSource(modelContext: context)
        let beforeData = try source.fetchSettled(window: selectedWindow)
        let beforeSettled = HistoryPresentationBuilder.build(
            data: beforeData,
            locale: calendar.locale ?? Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: calendar.timeZone,
            referenceNow: now
        )
        let beforeMotion = HistoryMotionPresentation(beforeSettled)
        let beforeSettledFast = try XCTUnwrap(beforeSettled.fastItems.first)
        let beforeMotionFast = try XCTUnwrap(beforeMotion.intervals.first)
        XCTAssertEqual(beforeSettledFast.id, fast.id)
        XCTAssertEqual(beforeMotionFast.id, fast.id)
        XCTAssertEqual(beforeSettledFast.startDate, originalStart)
        XCTAssertEqual(beforeMotionFast.start, originalStart)

        let coverage = HistoryMotionCoverage(
            firstDay: calendar.startOfDay(for: now),
            lastDay: calendar.startOfDay(for: now),
            calendar: calendar
        )
        let motionWindow = try XCTUnwrap(coverage.visualWindow(calendar: calendar))
        let beforeMotionData = try source.fetchMotion(window: motionWindow, calendar: calendar)
        let beforeMotionExact = HistoryPresentationBuilder.build(
            data: beforeMotionData,
            locale: calendar.locale ?? Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: calendar.timeZone,
            referenceNow: now
        )
        let beforeChunk = HistoryMotionChunk(
            coverage: coverage,
            presentation: HistoryMotionPresentation(beforeMotionExact)
        )
        let beforeMotionSnapshot = HistoryMotionSnapshot(
            coverage: coverage,
            calendar: calendar,
            generation: 1,
            presentation: beforeChunk.presentation
        )
        var state = HistoryProjectionState(
            data: beforeData,
            presentation: beforeSettled,
            motionSnapshot: beforeMotionSnapshot,
            motionChunks: [beforeChunk],
            generation: 1
        )

        let invalidation = HistoryPresentationInvalidation()
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in throw ProjectionError.simulated },
            activityEffect: { _ in nil },
            historyPresentationInvalidation: invalidation
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let correctedStart = try XCTUnwrap(
            calendar.date(bySettingHour: 21, minute: 0, second: 0, of: previousDay)
        )

        _ = try commands.correctActiveFastStart(to: correctedStart, goal: .default)

        XCTAssertEqual(invalidation.revision, 1)
        XCTAssertFalse(context.hasChanges)

        XCTAssertTrue(
            HistoryProjectionRefreshBoundary.refresh(
                state: &state,
                source: source,
                window: selectedWindow,
                locale: calendar.locale ?? Locale(identifier: "en_GB"),
                calendar: calendar,
                timeZone: calendar.timeZone,
                referenceNow: now,
                nextGeneration: 2
            )
        )
        let afterSettledFast = try XCTUnwrap(state.presentation?.fastItems.first)
        let afterMotionFast = try XCTUnwrap(state.motionSnapshot?.presentation.intervals.first)

        XCTAssertEqual(afterSettledFast.id, afterMotionFast.id)
        XCTAssertEqual(afterSettledFast.id, fast.id)
        XCTAssertEqual(afterSettledFast.startDate, correctedStart)
        XCTAssertEqual(afterMotionFast.start, correctedStart)
        XCTAssertEqual(afterSettledFast.endDate, now)
        XCTAssertEqual(afterMotionFast.end, now)
        XCTAssertNotEqual(beforeSettledFast.startDate, correctedStart)
        XCTAssertNotEqual(beforeMotionFast.start, correctedStart)

        let committedState = state
        let failingSource = FailingHistoryProjectionDataSource(settledData: beforeData)
        XCTAssertNotEqual(failingSource.settledData, committedState.data)
        XCTAssertFalse(
            HistoryProjectionRefreshBoundary.refresh(
                state: &state,
                source: failingSource,
                window: selectedWindow,
                locale: calendar.locale ?? Locale(identifier: "en_GB"),
                calendar: calendar,
                timeZone: calendar.timeZone,
                referenceNow: now,
                nextGeneration: 3
            )
        )
        XCTAssertEqual(state.data, committedState.data)
        XCTAssertEqual(state.presentation, committedState.presentation)
        XCTAssertEqual(state.motionSnapshot, committedState.motionSnapshot)
        XCTAssertEqual(state.motionChunks, committedState.motionChunks)
        XCTAssertEqual(state.generation, committedState.generation)
        XCTAssertEqual(state, committedState)
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

@MainActor
private final class FailingHistoryProjectionDataSource: HistoryProjectionDataSource {
    let settledData: HistoryDataSlice

    init(settledData: HistoryDataSlice) {
        self.settledData = settledData
    }

    func fetchSettled(window _: DateInterval) throws -> HistoryDataSlice {
        settledData
    }

    func fetchMotion(window _: DateInterval, calendar _: Calendar) throws -> HistoryDataSlice {
        throw RefreshSourceError.simulated
    }
}

private enum RefreshSourceError: Error {
    case simulated
}
