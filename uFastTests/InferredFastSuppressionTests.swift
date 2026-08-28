import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable file_length type_body_length
@MainActor
final class InferredFastSuppressionTests: XCTestCase {
    func testInferredHistoryDetailIdentityRemainsBoundToTheSourceUUID() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceID = try XCTUnwrap(
            UUID(uuidString: "10200000-0000-0000-0000-000000000001")
        )
        let container = try makeContainer(
            now: now,
            sourceDate: now.addingTimeInterval(-10 * 60 * 60),
            sourceID: sourceID
        )
        let context = container.mainContext
        let window = try XCTUnwrap(
            Calendar(identifier: .gregorian).dateInterval(of: .day, for: now)
        )
        let data = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        let calendar = Calendar(identifier: .gregorian)
        let snapshot = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: now
        )
        let item = try XCTUnwrap(snapshot.fastItems.first(where: { $0.kind == .inferred }))

        XCTAssertEqual(item.inferredInterval?.sourceBoundaryReference.id, sourceID)
        XCTAssertEqual(item.accessibilityID, sourceID)
    }

    func testDeleteAndReenableKeepSourceAndRecordedFastStateUnchanged() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = now.addingTimeInterval(-10 * 60 * 60)
        let container = try makeContainer(
            now: now,
            sourceDate: sourceDate,
            sourceID: UUID()
        )
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, now: now, sourceID: source.id))
        let invalidation = HistoryPresentationInvalidation()
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in XCTFail("Delete must not publish system projections") },
                activityEffect: { _ in XCTFail("Delete must not publish system projections"); return nil },
                historyPresentationInvalidation: invalidation
            )
        )

        try commands.deleteInferredFast(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            expectedStartDate: candidate.startDate,
            expectedEndDate: candidate.endDate,
            expectedSourceDescription: candidate.sourceDescription,
            expectedGoal: candidate.goal,
            expectedState: candidate.state
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        XCTAssertEqual(invalidation.revision, 1)
        XCTAssertFalse(context.hasChanges)

        try commands.reenableInferredFast(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            expectedStartDate: candidate.startDate,
            expectedEndDate: candidate.endDate,
            expectedSourceDescription: candidate.sourceDescription,
            expectedGoal: candidate.goal,
            expectedState: candidate.state
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 0)
        XCTAssertEqual(invalidation.revision, 2)
        XCTAssertFalse(context.hasChanges)
    }

    // swiftlint:disable:next function_body_length
    func testSuppressionSaveFailureAndStaleReenableLeaveLocalStateIntact() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = now.addingTimeInterval(-10 * 60 * 60)
        let container = try makeContainer(now: now, sourceDate: sourceDate, sourceID: UUID())
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, now: now, sourceID: source.id))
        let failingCommands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(),
            configuration: .init(simulateSuppressionSaveFailure: true)
        )

        XCTAssertThrowsError(
            try failingCommands.deleteInferredFast(
                sourceBoundaryReference: candidate.sourceBoundaryReference,
                expectedStartDate: candidate.startDate,
                expectedEndDate: candidate.endDate,
                expectedSourceDescription: candidate.sourceDescription,
                expectedGoal: candidate.goal,
                expectedState: candidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .simulatedSaveFailure)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 0)
        XCTAssertFalse(context.hasChanges)

        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()
        let staleCommands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(),
            configuration: .init(simulateSuppressionReenableStale: true)
        )

        XCTAssertThrowsError(
            try staleCommands.reenableInferredFast(
                sourceBoundaryReference: candidate.sourceBoundaryReference,
                expectedStartDate: candidate.startDate,
                expectedEndDate: candidate.endDate,
                expectedSourceDescription: candidate.sourceDescription,
                expectedGoal: candidate.goal,
                expectedState: candidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .candidateUnavailable)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testRecordedFastMutationReconcilesUsingAuthoritativeSettingsGoal() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 18))
        let container = try makeContainer(
            now: now,
            sourceDate: now.addingTimeInterval(-10 * 60 * 60),
            sourceID: UUID(),
            fastingGoal: currentGoal,
            detectionEnabled: false
        )
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, now: now, sourceID: source.id, goal: currentGoal))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()

        let recordedFast = FastRecord(
            startDate: now.addingTimeInterval(-2 * 60 * 60),
            goalAtStart: .default
        )
        try SwiftDataActiveFastRepository(
            modelContext: context,
            clock: FixedAppClock(now: now)
        ).saveNewActiveFast(recordedFast)

        let suppression = try XCTUnwrap(
            try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(suppression.goalHoursSnapshot, currentGoal.hours)
    }

    // swiftlint:disable:next function_body_length
    func testBoundaryMutationsApplyPreEligibilityInCapAndAfterCapRules() throws {
        let preNow = Date(timeIntervalSince1970: 1_900_000_000)
        let preSourceDate = preNow.addingTimeInterval(-10 * 60 * 60)
        let pre = try makeSuppressedFood(now: preNow, sourceDate: preSourceDate)
        let preRepository = SwiftDataFoodEntryRepository(
            modelContext: pre.context,
            clock: FixedAppClock(now: preNow)
        )
        try preRepository.saveCaloricEvent(
            .init(description: "Too soon", occurredAt: preSourceDate.addingTimeInterval(7 * 60 * 60)),
            replacing: nil,
            goal: .default
        )
        XCTAssertEqual(try pre.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 0)

        let inCapNow = Date(timeIntervalSince1970: 1_900_000_000)
        let inCapSourceDate = inCapNow.addingTimeInterval(-10 * 60 * 60)
        let inCap = try makeSuppressedFood(now: inCapNow, sourceDate: inCapSourceDate)
        let inCapDate = inCapSourceDate.addingTimeInterval(9 * 60 * 60)
        try SwiftDataFoodEntryRepository(
            modelContext: inCap.context,
            clock: FixedAppClock(now: inCapNow)
        ).saveCaloricEvent(
            .init(description: "Puncture", occurredAt: inCapDate),
            replacing: nil,
            goal: .default
        )
        let inCapSuppression = try XCTUnwrap(
            try inCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first
        )
        XCTAssertEqual(inCapSuppression.projectedEndDate, inCapDate)

        let afterCapNow = Date(timeIntervalSince1970: 1_900_000_000)
        let afterCapSourceDate = afterCapNow.addingTimeInterval(-30 * 60 * 60)
        let afterCap = try makeSuppressedFood(now: afterCapNow, sourceDate: afterCapSourceDate)
        let beforeBoundary = try XCTUnwrap(
            try afterCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first
        )
        let beforeSnapshot = try InferredFastSuppressionRecordSnapshot(
            id: beforeBoundary.id,
            suppression: XCTUnwrap(beforeBoundary.suppression)
        )
        try SwiftDataFoodEntryRepository(
            modelContext: afterCap.context,
            clock: FixedAppClock(now: afterCapNow)
        ).saveCaloricEvent(
            .init(
                description: "After cap",
                occurredAt: afterCapSourceDate.addingTimeInterval(
                    InferredFastProjector.maximumDuration(for: .default) + 60
                )
            ),
            replacing: nil,
            goal: .default
        )
        let afterBoundary = try XCTUnwrap(
            try afterCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first
        )
        XCTAssertEqual(
            try InferredFastSuppressionRecordSnapshot(
                id: afterBoundary.id,
                suppression: XCTUnwrap(afterBoundary.suppression)
            ).suppression,
            beforeSnapshot.suppression
        )

        let deleted = try makeSuppressedFood(now: preNow, sourceDate: preSourceDate)
        try SwiftDataFoodEntryRepository(
            modelContext: deleted.context,
            clock: FixedAppClock(now: preNow)
        ).delete(deleted.source)
        XCTAssertTrue(try deleted.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).isEmpty)
        XCTAssertTrue(try deleted.context.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
    }

    // swiftlint:disable:next function_body_length
    func testSettledAndMotionHistoryExposeOneRecoveryRowOnlyInsideExactWindow() throws {
        let sourceDate = Date(timeIntervalSince1970: 1_900_000_000)
        let now = sourceDate.addingTimeInterval(10 * 60 * 60)
        let sourceID = UUID()
        let candidate = try XCTUnwrap(InferredFastProjector.project(
            boundaries: [CaloricBoundary(
                reference: .init(kind: .food, id: sourceID),
                occurredAt: sourceDate,
                description: "Dinner"
            )],
            currentGoal: .default,
            enabled: true,
            now: now
        ).first)
        let suppression = InferredFastSuppressionDecider.make(candidate: candidate, at: now)
        let settings = AppSettingsSnapshot(
            fastingGoal: .default,
            inferredFastDetectionEnabled: true
        )
        let food = FoodEntrySnapshot(
            id: sourceID,
            foodDescription: "Dinner",
            occurredAt: sourceDate,
            nutrition: .init(),
            isCaloric: true
        )
        let exactWindow = DateInterval(
            start: sourceDate.addingTimeInterval(9 * 60 * 60),
            end: sourceDate.addingTimeInterval(10 * 60 * 60)
        )
        let data = HistoryDataSlice(
            window: exactWindow,
            completedFasts: [],
            activeFast: nil,
            foods: [food],
            drinks: [],
            settings: settings,
            suppressedInferredFasts: [suppression]
        )
        let calendar = Calendar(identifier: .gregorian)
        let settled = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: now
        )
        XCTAssertTrue(settled.fastItems.allSatisfy { $0.kind != .inferred })
        XCTAssertEqual(settled.hiddenInferredFastItems.count, 1)
        XCTAssertEqual(settled.hiddenInferredFastItems.first?.id, candidate.id)

        let motionContext = HistoryMotionInferredContext(data: data)
        XCTAssertTrue(motionContext.project(now: now, visibleInterval: exactWindow.start ..< exactWindow.end).isEmpty)
        let outsideData = HistoryDataSlice(
            window: DateInterval(
                start: sourceDate.addingTimeInterval(20 * 60 * 60),
                end: sourceDate.addingTimeInterval(21 * 60 * 60)
            ),
            completedFasts: [],
            activeFast: nil,
            foods: [food],
            drinks: [],
            settings: settings,
            suppressedInferredFasts: [suppression]
        )
        let outside = HistoryPresentationBuilder.build(
            data: outsideData,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: now
        )
        XCTAssertTrue(outside.hiddenInferredFastItems.isEmpty)
    }

    // swiftlint:disable:next function_body_length
    func testFoodAndCaloricHydrationSuppressionsUseKindBoundIdentityAndReconcileIdempotently() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let foodDate = now.addingTimeInterval(-24 * 60 * 60)
        let hydrationDate = foodDate.addingTimeInterval(10 * 60 * 60)
        let sharedID = UUID()
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        let food = FoodEntryRecord(
            id: sharedID,
            draft: .init(description: "Dinner", occurredAt: foodDate),
            createdAt: foodDate
        )
        let hydration = HydrationEntryRecord(
            id: sharedID,
            type: .coffee,
            volumeMillilitres: 250,
            occurredAt: hydrationDate,
            isCaloric: true,
            createdAt: hydrationDate
        )
        context.insert(settings)
        context.insert(food)
        context.insert(hydration)
        try context.save()

        let foodReference = CaloricBoundaryReference(kind: .food, id: sharedID)
        let hydrationReference = CaloricBoundaryReference(kind: .hydration, id: sharedID)
        let foodCandidate = try XCTUnwrap(
            candidate(in: context, now: now, sourceReference: foodReference)
        )
        let hydrationCandidate = try XCTUnwrap(
            candidate(in: context, now: now, sourceReference: hydrationReference)
        )
        let boundaries = try CaloricBoundaryPersistencePlanner(modelContext: context).allBoundaries()
        XCTAssertEqual(
            Set(boundaries.map(\.reference)),
            Set([foodReference, hydrationReference])
        )

        var presentationCalendar = Calendar(identifier: .gregorian)
        presentationCalendar.timeZone = .gmt
        let data = HistoryDataSlice(
            window: DateInterval(start: foodDate, end: now.addingTimeInterval(60)),
            completedFasts: [],
            activeFast: nil,
            foods: [FoodEntrySnapshot(food)],
            drinks: [HydrationEntrySnapshot(hydration)],
            settings: AppSettingsSnapshot(settings)
        )
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: presentationCalendar,
            timeZone: .gmt,
            referenceNow: now
        )
        let inferredItems = presentation.fastItems.filter { $0.kind == .inferred }
        XCTAssertEqual(inferredItems.count, 2)
        XCTAssertEqual(Set(inferredItems.map(\.historyIdentity)).count, 2)
        XCTAssertEqual(
            Set(inferredItems.compactMap(\.inferredInterval?.sourceBoundaryReference)),
            Set([foodReference, hydrationReference])
        )
        let motion = HistoryMotionPresentation(
            presentation,
            inferredContext: HistoryMotionInferredContext(data: data)
        )
        let motionInferred = motion.ribbonIntervals(activeEndingAt: now)
            .compactMap { motion.inferredInterval(for: $0.id, at: now) }
        XCTAssertEqual(
            Set(motionInferred.map(\.sourceBoundaryReference)),
            Set([foodReference, hydrationReference])
        )

        let store = InferredFastSuppressionStore(modelContext: context)
        try store.insert(InferredFastSuppressionDecider.make(candidate: foodCandidate, at: now))
        try store.insert(InferredFastSuppressionDecider.make(candidate: foodCandidate, at: now))
        try store.insert(InferredFastSuppressionDecider.make(candidate: hydrationCandidate, at: now))
        try store.insert(InferredFastSuppressionDecider.make(candidate: hydrationCandidate, at: now))
        XCTAssertEqual(try store.all().count, 2)
        XCTAssertEqual(
            try store.reconcileInMemory(
                currentGoal: .default,
                enabled: true,
                now: now,
                updatedAt: now
            ).changedCount,
            0
        )
        XCTAssertEqual(
            try store.reconcileInMemory(
                currentGoal: .default,
                enabled: true,
                now: now,
                updatedAt: now
            ).changedCount,
            0
        )

        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator()
        )
        try commands.deleteInferredFast(
            sourceBoundaryReference: foodReference,
            expectedStartDate: foodCandidate.startDate,
            expectedEndDate: foodCandidate.endDate,
            expectedSourceDescription: foodCandidate.sourceDescription,
            expectedGoal: foodCandidate.goal,
            expectedState: foodCandidate.state
        )
        try commands.deleteInferredFast(
            sourceBoundaryReference: foodReference,
            expectedStartDate: foodCandidate.startDate,
            expectedEndDate: foodCandidate.endDate,
            expectedSourceDescription: foodCandidate.sourceDescription,
            expectedGoal: foodCandidate.goal,
            expectedState: foodCandidate.state
        )
        XCTAssertEqual(try store.all().count, 2)

        try commands.reenableInferredFast(
            sourceBoundaryReference: foodReference,
            expectedStartDate: foodCandidate.startDate,
            expectedEndDate: foodCandidate.endDate,
            expectedSourceDescription: foodCandidate.sourceDescription,
            expectedGoal: foodCandidate.goal,
            expectedState: foodCandidate.state
        )
        XCTAssertEqual(try store.all().map(\.sourceBoundaryReference), [hydrationReference])
        XCTAssertThrowsError(
            try commands.reenableInferredFast(
                sourceBoundaryReference: foodReference,
                expectedStartDate: foodCandidate.startDate,
                expectedEndDate: foodCandidate.endDate,
                expectedSourceDescription: foodCandidate.sourceDescription,
                expectedGoal: foodCandidate.goal,
                expectedState: foodCandidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .suppressionUnavailable)
        }
        try commands.reenableInferredFast(
            sourceBoundaryReference: hydrationReference,
            expectedStartDate: hydrationCandidate.startDate,
            expectedEndDate: hydrationCandidate.endDate,
            expectedSourceDescription: hydrationCandidate.sourceDescription,
            expectedGoal: hydrationCandidate.goal,
            expectedState: hydrationCandidate.state
        )

        XCTAssertTrue(try store.all().isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 0)
    }

    // swiftlint:disable:next function_body_length
    func testCaloricHydrationMutationMatrixUsesExactEligibilityAndCapBoundaries() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)

        let pre = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        try SwiftDataHydrationEntryRepository(
            modelContext: pre.context,
            clock: FixedAppClock(now: now)
        ).saveCaloricEvent(
            .init(
                type: .coffee,
                customName: nil,
                volumeMillilitres: 250,
                occurredAt: pre.source.occurredAt.addingTimeInterval(7 * 60 * 60),
                isCaloric: true
            ),
            replacing: nil,
            goal: .default
        )
        XCTAssertTrue(try pre.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).isEmpty)

        let exact = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let exactID = UUID()
        let exactDate = exact.source.occurredAt.addingTimeInterval(8 * 60 * 60)
        try SwiftDataHydrationEntryRepository(
            modelContext: exact.context,
            clock: FixedAppClock(now: now)
        ).saveCaloricEvent(
            .init(
                type: .coffee,
                customName: nil,
                volumeMillilitres: 250,
                occurredAt: exactDate,
                isCaloric: true
            ),
            replacing: nil,
            goal: .default,
            recordID: exactID
        )
        let exactSuppression = try XCTUnwrap(
            try exact.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(exactSuppression.nextBoundaryReference, .init(kind: .hydration, id: exactID))
        XCTAssertEqual(exactSuppression.nextBoundaryDate, exactDate)
        XCTAssertEqual(exactSuppression.projectedEndDate, exactDate)

        let atCap = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-50 * 60 * 60))
        let capDate = atCap.source.occurredAt.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: .default)
        )
        let capID = UUID()
        let capBefore = try XCTUnwrap(
            try atCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        try SwiftDataHydrationEntryRepository(
            modelContext: atCap.context,
            clock: FixedAppClock(now: now)
        ).saveCaloricEvent(
            .init(
                type: .coffee,
                customName: nil,
                volumeMillilitres: 250,
                occurredAt: capDate,
                isCaloric: true
            ),
            replacing: nil,
            goal: .default,
            recordID: capID
        )
        let capAfter = try XCTUnwrap(
            try atCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(capAfter, capBefore)

        let afterCap = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-50 * 60 * 60))
        let afterCapBefore = try XCTUnwrap(
            try afterCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        try SwiftDataHydrationEntryRepository(
            modelContext: afterCap.context,
            clock: FixedAppClock(now: now)
        ).saveCaloricEvent(
            .init(
                type: .coffee,
                customName: nil,
                volumeMillilitres: 250,
                occurredAt: afterCap.source.occurredAt.addingTimeInterval(
                    InferredFastProjector.maximumDuration(for: .default) + 60
                ),
                isCaloric: true
            ),
            replacing: nil,
            goal: .default
        )
        let afterCapAfter = try XCTUnwrap(
            try afterCap.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(afterCapAfter, afterCapBefore)

        let failure = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let failureSource = failure.source.draft
        XCTAssertThrowsError(
            try SwiftDataHydrationEntryRepository(
                modelContext: failure.context,
                simulateSaveFailure: true,
                clock: FixedAppClock(now: now)
            ).saveCaloricEvent(
                .init(
                    type: .coffee,
                    customName: nil,
                    volumeMillilitres: 250,
                    occurredAt: failure.source.occurredAt.addingTimeInterval(7 * 60 * 60),
                    isCaloric: true
                ),
                replacing: nil,
                goal: .default
            )
        ) { error in
            XCTAssertEqual(error as? HydrationEntryPersistenceError, .simulatedSaveFailure)
        }
        XCTAssertEqual(try failure.context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertEqual(try failure.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        XCTAssertEqual(failure.source.draft, failureSource)
        XCTAssertFalse(failure.context.hasChanges)

        let nonCaloric = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        try SwiftDataHydrationEntryRepository(
            modelContext: nonCaloric.context,
            clock: FixedAppClock(now: now)
        ).saveCaloricEvent(
            .init(
                type: .water,
                customName: nil,
                volumeMillilitres: 500,
                occurredAt: nonCaloric.source.occurredAt.addingTimeInterval(7 * 60 * 60),
                isCaloric: false
            ),
            replacing: nil,
            goal: .default
        )
        XCTAssertEqual(try nonCaloric.context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 2)
        XCTAssertEqual(try nonCaloric.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
    }

    // swiftlint:disable:next function_body_length
    func testHydrationReclassificationDeletionSettingsGoalAndRecordedOverlapReconcile() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let reclassified = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let nonCaloricDraft = HydrationEntryDraft(
            type: reclassified.source.drinkType,
            customName: reclassified.source.customName,
            volumeMillilitres: reclassified.source.volumeMillilitres,
            occurredAt: reclassified.source.occurredAt,
            isCaloric: false
        )
        try SwiftDataHydrationEntryRepository(
            modelContext: reclassified.context,
            clock: FixedAppClock(now: now)
        ).update(reclassified.source, with: nonCaloricDraft, at: now)
        XCTAssertTrue(try reclassified.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).isEmpty)
        XCTAssertEqual(try reclassified.context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)

        let deleted = try makeSuppressedHydration(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        try SwiftDataHydrationEntryRepository(
            modelContext: deleted.context,
            clock: FixedAppClock(now: now)
        ).delete(deleted.source)
        XCTAssertTrue(try deleted.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).isEmpty)
        XCTAssertTrue(try deleted.context.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)

        let settings = try makeSuppressedFood(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let settingsCommands = ApplicationCommands(
            modelContext: settings.context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator()
        )
        try settingsCommands.updateInferredFastDetectionEnabled(false)
        XCTAssertEqual(try settings.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        let eighteenHours = try XCTUnwrap(FastingGoal(hours: 18))
        try settingsCommands.updateGoal(eighteenHours)
        let disabledSuppression = try XCTUnwrap(
            try settings.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(disabledSuppression.goalHoursSnapshot, eighteenHours.hours)
        try settingsCommands.updateInferredFastDetectionEnabled(true)
        let enabledSuppression = try XCTUnwrap(
            try settings.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(enabledSuppression.goalHoursSnapshot, eighteenHours.hours)

        let goalFailure = try makeSuppressedFood(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let goalFailureSettings = try XCTUnwrap(
            try goalFailure.context.fetch(FetchDescriptor<AppSettingsRecord>()).first
        )
        let goalFailureBefore = try XCTUnwrap(
            try goalFailure.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        let failingGoalCommands = ApplicationCommands(
            modelContext: goalFailure.context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(),
            configuration: .init(simulateGoalSaveFailure: true)
        )
        XCTAssertThrowsError(try failingGoalCommands.updateGoal(eighteenHours)) { error in
            XCTAssertEqual(error as? SettingsStoreError, .simulatedSaveFailure)
        }
        XCTAssertEqual(goalFailureSettings.fastingGoal, FastingGoal.default)
        let goalFailureAfter = try XCTUnwrap(
            try goalFailure.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(goalFailureAfter, goalFailureBefore)
        XCTAssertFalse(goalFailure.context.hasChanges)

        let overlap = try makeSuppressedFood(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60))
        let candidate = try XCTUnwrap(candidate(in: overlap.context, now: now, sourceID: overlap.source.id))
        let recorded = FastRecord(
            startDate: candidate.startDate.addingTimeInterval(9 * 60 * 60),
            endDate: candidate.startDate.addingTimeInterval(11 * 60 * 60),
            goalAtStart: .default
        )
        try SwiftDataActiveFastRepository(
            modelContext: overlap.context,
            clock: FixedAppClock(now: now)
        ).saveCompletedFast(recorded)
        let overlapCommands = ApplicationCommands(
            modelContext: overlap.context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator()
        )
        XCTAssertThrowsError(
            try overlapCommands.reenableInferredFast(
                sourceBoundaryReference: candidate.sourceBoundaryReference,
                expectedStartDate: candidate.startDate,
                expectedEndDate: candidate.endDate,
                expectedSourceDescription: candidate.sourceDescription,
                expectedGoal: candidate.goal,
                expectedState: candidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .candidateUnavailable)
        }
        XCTAssertEqual(try overlap.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        XCTAssertEqual(try overlap.context.fetchCount(FetchDescriptor<FastRecord>()), 1)
    }

    // swiftlint:disable:next function_body_length
    func testStaleDeleteAndReenableSaveFailureDoNotMutateLocalState() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let stale = try makeContainer(now: now, sourceDate: now.addingTimeInterval(-10 * 60 * 60), sourceID: UUID())
        let staleContext = stale.mainContext
        let staleSource = try XCTUnwrap(try staleContext.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let staleCandidate = try XCTUnwrap(candidate(in: staleContext, now: now, sourceID: staleSource.id))
        staleSource.update(
            from: .init(description: "Edited dinner", occurredAt: staleSource.occurredAt),
            at: now
        )
        try staleContext.save()
        let staleInvalidation = HistoryPresentationInvalidation()
        let staleCommands = ApplicationCommands(
            modelContext: staleContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(
                widgetEffect: { _ in },
                activityEffect: { _ in nil },
                historyPresentationInvalidation: staleInvalidation
            )
        )
        XCTAssertThrowsError(
            try staleCommands.deleteInferredFast(
                sourceBoundaryReference: staleCandidate.sourceBoundaryReference,
                expectedStartDate: staleCandidate.startDate,
                expectedEndDate: staleCandidate.endDate,
                expectedSourceDescription: staleCandidate.sourceDescription,
                expectedGoal: staleCandidate.goal,
                expectedState: staleCandidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .candidateUnavailable)
        }
        XCTAssertEqual(staleSource.foodDescription, "Edited dinner")
        XCTAssertEqual(try staleContext.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 0)
        XCTAssertEqual(staleInvalidation.revision, 0)
        XCTAssertFalse(staleContext.hasChanges)

        let failure = try makeSuppressedFood(
            now: now,
            sourceDate: now.addingTimeInterval(-10 * 60 * 60),
            detectionEnabled: true
        )
        let failureCandidate = try XCTUnwrap(candidate(in: failure.context, now: now, sourceID: failure.source.id))
        let failureCommands = ApplicationCommands(
            modelContext: failure.context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(),
            configuration: .init(simulateSuppressionSaveFailure: true)
        )
        XCTAssertThrowsError(
            try failureCommands.reenableInferredFast(
                sourceBoundaryReference: failureCandidate.sourceBoundaryReference,
                expectedStartDate: failureCandidate.startDate,
                expectedEndDate: failureCandidate.endDate,
                expectedSourceDescription: failureCandidate.sourceDescription,
                expectedGoal: failureCandidate.goal,
                expectedState: failureCandidate.state
            )
        ) { error in
            XCTAssertEqual(error as? InferredFastSuppressionError, .simulatedSaveFailure)
        }
        XCTAssertEqual(try failure.context.fetchCount(FetchDescriptor<InferredFastSuppressionRecord>()), 1)
        XCTAssertEqual(try failure.context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try failure.context.fetchCount(FetchDescriptor<FastRecord>()), 0)
        XCTAssertFalse(failure.context.hasChanges)
    }

    private func makeContainer(
        now: Date,
        sourceDate: Date,
        sourceID: UUID,
        fastingGoal: FastingGoal = .default,
        detectionEnabled: Bool = true
    ) throws -> ModelContainer {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                fastingGoal: fastingGoal,
                hasCompletedOnboarding: true,
                inferredFastDetectionEnabled: detectionEnabled
            )
        )
        context.insert(
            FoodEntryRecord(
                id: sourceID,
                draft: .init(description: "Dinner", occurredAt: sourceDate),
                createdAt: now
            )
        )
        try context.save()
        return container
    }

    private struct SuppressedFoodFixture {
        let container: ModelContainer
        let context: ModelContext
        let source: FoodEntryRecord
    }

    private struct SuppressedHydrationFixture {
        let container: ModelContainer
        let context: ModelContext
        let source: HydrationEntryRecord
    }

    private func makeSuppressedFood(
        now: Date,
        sourceDate: Date,
        detectionEnabled: Bool = false
    ) throws -> SuppressedFoodFixture {
        let container = try makeContainer(
            now: now,
            sourceDate: sourceDate,
            sourceID: UUID(),
            detectionEnabled: detectionEnabled
        )
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, now: now, sourceID: source.id))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()
        return SuppressedFoodFixture(container: container, context: context, source: source)
    }

    private func makeSuppressedHydration(
        now: Date,
        sourceDate: Date,
        sourceID: UUID = UUID(),
        goal: FastingGoal = .default,
        detectionEnabled: Bool = false
    ) throws -> SuppressedHydrationFixture {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                fastingGoal: goal,
                hasCompletedOnboarding: true,
                inferredFastDetectionEnabled: detectionEnabled
            )
        )
        let source = HydrationEntryRecord(
            id: sourceID,
            type: .coffee,
            volumeMillilitres: 250,
            occurredAt: sourceDate,
            isCaloric: true,
            createdAt: sourceDate
        )
        context.insert(source)
        try context.save()
        let reference = CaloricBoundaryReference(kind: .hydration, id: sourceID)
        let candidate = try XCTUnwrap(candidate(
            in: context,
            now: now,
            sourceReference: reference,
            goal: goal
        ))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()
        return SuppressedHydrationFixture(container: container, context: context, source: source)
    }

    private func candidate(
        in context: ModelContext,
        now: Date,
        sourceID: UUID,
        goal: FastingGoal = .default
    ) throws -> InferredFastInterval? {
        try candidate(
            in: context,
            now: now,
            sourceReference: .init(kind: .food, id: sourceID),
            goal: goal
        )
    }

    private func candidate(
        in context: ModelContext,
        now: Date,
        sourceReference: CaloricBoundaryReference,
        goal: FastingGoal = .default
    ) throws -> InferredFastInterval? {
        let boundaries = try CaloricBoundaryPersistencePlanner(modelContext: context).allBoundaries()
        return InferredFastProjector.project(
            boundaries: boundaries,
            currentGoal: goal,
            enabled: true,
            now: now
        ).first { $0.sourceBoundaryReference == sourceReference }
    }

    private func makeProjectionCoordinator() -> PostCommitProjectionCoordinator {
        PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
    }
}
