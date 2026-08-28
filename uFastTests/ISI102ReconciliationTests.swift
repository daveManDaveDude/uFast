import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable trailing_comma

@MainActor
final class ISI102ReconciliationTests: XCTestCase {
    func testLaunchCoordinatorInvokesEachInjectedDependencyOnceInOrder() throws {
        var events: [String] = []
        let expectedBoundary = CaloricBoundaryReconciliationResult(
            scannedCount: 1,
            changedCount: 0,
            activeFastEnded: false
        )
        let expectedSuppression = SuppressionReconciliationResult(
            scannedCount: 2,
            changedCount: 0
        )
        let coordinator = LaunchReconciliationCoordinator(
            boundaryReconciliation: {
                events.append("boundary")
                return expectedBoundary
            },
            suppressionReconciliation: {
                events.append("suppression")
                return expectedSuppression
            }
        )

        let result = try coordinator.reconcile()

        XCTAssertEqual(events, ["boundary", "suppression"])
        XCTAssertEqual(result.boundary, expectedBoundary)
        XCTAssertEqual(result.suppression, expectedSuppression)
    }

    // swiftlint:disable:next function_body_length
    func testBatchReconciliationProjectsOnceForMultipleSourceSuppressions() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                hasCompletedOnboarding: true,
                inferredFastDetectionEnabled: true
            )
        )
        let firstID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000002"))
        let firstDate = now.addingTimeInterval(-30 * 60 * 60)
        let secondDate = now.addingTimeInterval(-10 * 60 * 60)
        context.insert(
            FoodEntryRecord(
                id: firstID,
                draft: .init(description: "First", occurredAt: firstDate),
                createdAt: firstDate
            )
        )
        context.insert(
            FoodEntryRecord(
                id: secondID,
                draft: .init(description: "Second", occurredAt: secondDate),
                createdAt: secondDate
            )
        )
        try context.save()

        let boundaries = try CaloricBoundaryPersistencePlanner(modelContext: context).allBoundaries()
        let candidates = InferredFastProjector.project(
            boundaries: boundaries,
            currentGoal: .default,
            enabled: true,
            now: now
        )
        for candidate in candidates {
            context.insert(
                InferredFastSuppressionRecord(
                    suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
                )
            )
        }
        try context.save()
        XCTAssertEqual(candidates.count, 2)
        let duplicateIndex = InferredFastProjectionIndex(candidates: [
            candidates[0],
            candidates[0].refreshed(at: now.addingTimeInterval(60)),
        ])
        XCTAssertEqual(duplicateIndex.candidates.count, 1)
        XCTAssertEqual(
            duplicateIndex.candidate(for: candidates[0].sourceBoundaryReference),
            candidates[0]
        )

        var projectionCalls = 0
        let store = InferredFastSuppressionStore(
            modelContext: context,
            projector: { boundaries, goal, enabled, projectionNow in
                projectionCalls += 1
                return InferredFastProjector.project(
                    boundaries: boundaries,
                    currentGoal: goal,
                    enabled: enabled,
                    now: projectionNow
                )
            }
        )

        let result = try store.reconcileInMemory(
            currentGoal: .default,
            enabled: true,
            now: now,
            updatedAt: now
        )
        XCTAssertEqual(projectionCalls, 1)
        XCTAssertEqual(result.scannedCount, 2)
        XCTAssertEqual(result.changedCount, 0)
        XCTAssertFalse(context.hasChanges)
    }

    func testLaunchClockMovementDoesNotSaveBeforeAtOrAfterCap() throws {
        let base = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = base.addingTimeInterval(-9 * 60 * 60)
        let container = try makeContainer(sourceDate: sourceDate, now: base)
        let context = container.mainContext
        let sourceID = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first?.id)
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: sourceID, now: base))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: base, updatedAt: base)
            )
        )
        try context.save()
        let original = try XCTUnwrap(
            try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        let cap = sourceDate.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: .default)
        )

        for launchNow in [
            base.addingTimeInterval(5 * 60 * 60),
            base.addingTimeInterval(5 * 60 * 60),
            cap,
            cap.addingTimeInterval(60),
        ] {
            var saveCount = 0
            let coordinator = LaunchReconciliationCoordinator(
                modelContext: context,
                clock: FixedAppClock(now: launchNow),
                suppressionSaveAction: {
                    saveCount += 1
                    try context.save()
                }
            )
            let result = try coordinator.reconcile()
            XCTAssertEqual(result.suppression.changedCount, 0)
            XCTAssertEqual(saveCount, 0)
            let stored = try XCTUnwrap(
                try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
            )
            XCTAssertEqual(stored.projectedEndDate, original.projectedEndDate)
            XCTAssertEqual(stored.updatedAt, original.updatedAt)
            XCTAssertFalse(context.hasChanges)
        }
    }

    func testHistoryAdvancesClockOnlyEndWithoutSavingSuppression() throws {
        let base = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = base.addingTimeInterval(-9 * 60 * 60)
        let later = base.addingTimeInterval(5 * 60 * 60)
        let container = try makeContainer(sourceDate: sourceDate, now: base)
        let context = container.mainContext
        let sourceID = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first?.id)
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: sourceID, now: base))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: base, updatedAt: base)
            )
        )
        try context.save()
        let storedBefore = try XCTUnwrap(
            try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )

        let window = DateInterval(start: sourceDate, end: later.addingTimeInterval(60))
        let data = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: later
        )
        let hidden = try XCTUnwrap(presentation.hiddenInferredFastItems.first)
        XCTAssertEqual(hidden.inferredInterval?.endDate, later)

        let storedAfter = try XCTUnwrap(
            try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(storedAfter.projectedEndDate, storedBefore.projectedEndDate)
        XCTAssertEqual(storedAfter.updatedAt, storedBefore.updatedAt)
        XCTAssertFalse(context.hasChanges)
    }

    func testLaunchCoordinatorRemovesStructuralStalenessWithOneSave() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = now.addingTimeInterval(-10 * 60 * 60)
        let container = try makeContainer(sourceDate: sourceDate, now: now)
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: source.id, now: now))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()
        context.delete(source)
        try context.save()

        var saveCount = 0
        let coordinator = LaunchReconciliationCoordinator(
            modelContext: context,
            clock: FixedAppClock(now: now),
            suppressionSaveAction: {
                saveCount += 1
                try context.save()
            }
        )
        let result = try coordinator.reconcile()

        XCTAssertEqual(result.suppression.changedCount, 1)
        XCTAssertEqual(saveCount, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    private func makeContainer(sourceDate: Date, now: Date) throws -> ModelContainer {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            AppSettingsRecord(
                hasCompletedOnboarding: true,
                inferredFastDetectionEnabled: true
            )
        )
        context.insert(
            FoodEntryRecord(
                draft: .init(description: "Dinner", occurredAt: sourceDate),
                createdAt: now
            )
        )
        try context.save()
        return container
    }

    private func candidate(
        in context: ModelContext,
        sourceID: UUID,
        now: Date
    ) throws -> InferredFastInterval? {
        let boundaries = try CaloricBoundaryPersistencePlanner(modelContext: context).allBoundaries()
        return InferredFastProjector.project(
            boundaries: boundaries,
            currentGoal: .default,
            enabled: true,
            now: now
        ).first { $0.sourceBoundaryReference == .init(kind: .food, id: sourceID) }
    }
}
