import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length type_body_length

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

    func testHistoricalInferredSaveCreatesCompletedFastWithoutSystemSurfaceEffects() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = FoodEntryRecord(
            draft: .init(
                description: "Dinner",
                occurredAt: now.addingTimeInterval(-25 * 60 * 60)
            ),
            createdAt: now.addingTimeInterval(-25 * 60 * 60)
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        var widgetEffects = 0
        var activityEffects = 0
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in widgetEffects += 1 },
            activityEffect: { _ in activityEffects += 1; return .updated }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let start = source.occurredAt
        let end = start.addingTimeInterval(24 * 60 * 60)

        let outcome = try commands.saveInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: start,
            expectedEndDate: end
        )

        XCTAssertFalse(outcome.projectionEnqueued)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
        let fast = try XCTUnwrap(context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertFalse(fast.isActive)
        XCTAssertEqual(fast.startDate, start)
        XCTAssertEqual(fast.endDate, end)
        XCTAssertEqual(fast.capturedHistoricalGoal, .default)
        XCTAssertEqual(widgetEffects, 0)
        XCTAssertEqual(activityEffects, 0)
    }

    func testHistoricalInferredHydrationSaveUsesHydrationBoundaryReference() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let source = HydrationEntryRecord(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: sourceDate,
            isCaloric: true,
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in },
                activityEffect: { _ in nil }
            )
        )

        let outcome = try commands.saveInferredFast(
            sourceBoundaryReference: .init(kind: .hydration, id: source.id),
            expectedStartDate: sourceDate,
            expectedEndDate: sourceDate.addingTimeInterval(24 * 60 * 60),
            expectedSourceDescription: "Juice"
        )

        XCTAssertNotNil(outcome.recordID)
        let fast = try XCTUnwrap(context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertEqual(fast.startDate, sourceDate)
        XCTAssertEqual(fast.endDate, sourceDate.addingTimeInterval(24 * 60 * 60))
    }

    func testPresentedInferredSourceRemovalRequiresConfirmationBeforeHydrationMutation() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = HydrationEntryRecord(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: now.addingTimeInterval(-10 * 60 * 60),
            isCaloric: true,
            createdAt: now
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in },
                activityEffect: { _ in nil }
            )
        )
        let nonCaloric = HydrationEntryDraft(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: source.occurredAt,
            isCaloric: false
        )

        XCTAssertThrowsError(try commands.saveHydration(
            nonCaloric,
            replacing: source.id,
            goal: .default,
            endingActiveFast: false
        )) { error in
            guard case let .inferredConfirmationWithImpact(context) =
                error as? HydrationEntrySaveError
            else {
                return XCTFail("Expected inferred impact confirmation, got \(error)")
            }
            XCTAssertEqual(context.kind, .inferred)
            XCTAssertEqual(context.affectedPersistedFastCount, 0)
            XCTAssertTrue(context.includesInferredInterval)
        }
        XCTAssertTrue(source.isCaloric)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertFalse(context.hasChanges)

        try commands.saveHydration(
            nonCaloric,
            replacing: source.id,
            goal: .default,
            endingActiveFast: true
        )
        XCTAssertFalse(source.isCaloric)
    }

    func testPresentedInferredMoveLaterAndDeleteRequireConfirmationWithoutMutation() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: now.addingTimeInterval(-10 * 60 * 60)),
            createdAt: now
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in },
                activityEffect: { _ in nil }
            )
        )

        XCTAssertThrowsError(try commands.saveFood(
            .init(description: "Dinner", occurredAt: now.addingTimeInterval(-60 * 60)),
            replacing: source.id,
            goal: .default,
            endingActiveFast: false
        )) { error in
            guard case .inferredConfirmationWithImpact = error as? FoodEntrySaveError else {
                return XCTFail("Expected inferred impact confirmation, got \(error)")
            }
        }
        XCTAssertEqual(source.occurredAt, now.addingTimeInterval(-10 * 60 * 60))
        XCTAssertFalse(context.hasChanges)

        XCTAssertThrowsError(try commands.deleteFood(id: source.id)) { error in
            guard case .inferredConfirmationWithImpact = error as? FoodEntrySaveError else {
                return XCTFail("Expected inferred impact confirmation, got \(error)")
            }
        }
        XCTAssertNotNil(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        XCTAssertFalse(context.hasChanges)
    }

    func testHistoricalInferredSaveRejectsAmbiguousActiveAuthorityWithoutMutation() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        context.insert(FastRecord(
            startDate: now.addingTimeInterval(24 * 60 * 60),
            goalAtStart: .default
        ))
        context.insert(FastRecord(
            startDate: now.addingTimeInterval(48 * 60 * 60),
            goalAtStart: .default
        ))
        try context.save()

        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in },
                activityEffect: { _ in nil }
            )
        )
        let foodCountBefore = try context.fetchCount(FetchDescriptor<FoodEntryRecord>())
        let fastCountBefore = try context.fetchCount(FetchDescriptor<FastRecord>())

        XCTAssertThrowsError(try commands.saveInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: sourceDate,
            expectedEndDate: sourceDate.addingTimeInterval(24 * 60 * 60)
        )) { error in
            XCTAssertEqual(
                error as? ActiveFastIntegrityError,
                .multipleActiveFasts(count: 2)
            )
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), foodCountBefore)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), fastCountBefore)
        XCTAssertFalse(context.hasChanges)
    }

    func testCurrentInferredStartUsesSourceInstantBeforePostCommitSurfaces() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceDate = now.addingTimeInterval(-10 * 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        var order: [String] = []
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { event in
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
                XCTAssertFalse(context.hasChanges)
                if case .activeFastStarted = event {
                    order.append("widget")
                }
            },
            activityEffect: { event in
                if case .activeFastStarted = event {
                    order.append("activity")
                }
                return .shown(activityIdentifier: "inferred")
            }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )

        let outcome = try commands.startInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: sourceDate,
            expectedEndDate: now
        )
        await projection.waitForPendingEffects()

        XCTAssertTrue(outcome.projectionEnqueued)
        XCTAssertEqual(order, ["widget", "activity"])
        let fast = try XCTUnwrap(context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertTrue(fast.isActive)
        XCTAssertEqual(fast.startDate, sourceDate)
    }

    func testInferredRevalidationTreatsCompatibilityFoodAsCaloric() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let nonCaloricSource = FoodEntryRecord(
            draft: .init(description: "Non-caloric food", occurredAt: now.addingTimeInterval(-10 * 60 * 60)),
            createdAt: now
        )
        nonCaloricSource.restore(from: FoodEntryRecordSnapshot(
            draft: nonCaloricSource.draft,
            isCaloric: false,
            updatedAt: now
        ))
        context.insert(nonCaloricSource)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )

        _ = try commands.startInferredFast(
            sourceFoodID: nonCaloricSource.id,
            expectedStartDate: nonCaloricSource.occurredAt,
            expectedEndDate: now
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)
        let fast = try XCTUnwrap(context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertEqual(fast.startDate, nonCaloricSource.occurredAt)
        XCTAssertTrue(fast.isActive)
    }

    func testCurrentInferredStartAcceptsAnAdvancingNowEndpointButRejectsSourceEdits() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let displayedNow = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceDate = displayedNow.addingTimeInterval(-10 * 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
        let advancedCommands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: displayedNow.addingTimeInterval(60)),
            projectionCoordinator: projection
        )
        _ = try advancedCommands.startInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: sourceDate,
            expectedEndDate: displayedNow,
            expectedSourceDescription: "Dinner",
            expectedGoal: .default
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 1)

        let secondContainer = try PersistenceContainer.make(inMemory: true)
        let secondContext = secondContainer.mainContext
        let editedSource = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        secondContext.insert(editedSource)
        secondContext.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try secondContext.save()
        editedSource.update(
            from: .init(description: "Updated dinner", occurredAt: sourceDate),
            at: displayedNow
        )
        try secondContext.save()

        let staleCommands = ApplicationCommands(
            modelContext: secondContext,
            clock: FixedAppClock(now: displayedNow.addingTimeInterval(60)),
            projectionCoordinator: projection
        )
        XCTAssertThrowsError(try staleCommands.startInferredFast(
            sourceFoodID: editedSource.id,
            expectedStartDate: sourceDate,
            expectedEndDate: displayedNow,
            expectedSourceDescription: "Dinner",
            expectedGoal: .default
        )) { error in
            XCTAssertEqual(error as? InferredFastConversionError, .candidateUnavailable)
        }
        XCTAssertEqual(try secondContext.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertFalse(secondContext.hasChanges)
    }

    func testStaleInferredCandidateAndPersistenceFailureLeaveFastCountUnchanged() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let start = sourceDate
        let oldEnd = sourceDate.addingTimeInterval(24 * 60 * 60)
        let later = FoodEntryRecord(
            draft: .init(description: "Breakfast", occurredAt: now.addingTimeInterval(-2 * 60 * 60)),
            createdAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        context.insert(later)
        try context.save()

        XCTAssertThrowsError(try commands.saveInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: start,
            expectedEndDate: oldEnd
        )) { error in
            XCTAssertEqual(error as? InferredFastConversionError, .candidateUnavailable)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)

        context.delete(later)
        try context.save()
        let failing = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection,
            configuration: .init(simulateFastHistoryFailure: true)
        )
        XCTAssertThrowsError(try failing.saveInferredFast(
            sourceFoodID: source.id,
            expectedStartDate: start,
            expectedEndDate: oldEnd
        ))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertFalse(context.hasChanges)
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
