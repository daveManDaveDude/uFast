import SwiftData
@testable import uFast
import XCTest

@MainActor
final class ISI102CorrectionTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testDuplicateSuppressionRecordsKeepOneCanonicalSourceForReconciliationAndHistory() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000011"))
        let container = try makeContainer(
            sourceDate: now.addingTimeInterval(-10 * 60 * 60),
            now: now,
            sourceID: sourceID
        )
        let context = container.mainContext
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: sourceID, now: now))
        let canonicalID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000001"))
        let duplicateID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000002"))
        let duplicate = InferredFastSuppression(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            projectedStartDate: candidate.startDate,
            projectedEndDate: candidate.endDate.addingTimeInterval(-60),
            nextBoundaryReference: candidate.nextBoundaryReference,
            nextBoundaryDate: candidate.nextBoundaryDate,
            goalHoursSnapshot: candidate.goal.hours,
            createdAt: now.addingTimeInterval(-120),
            updatedAt: now.addingTimeInterval(-120)
        )
        context.insert(
            InferredFastSuppressionRecord(
                id: canonicalID,
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        context.insert(InferredFastSuppressionRecord(id: duplicateID, suppression: duplicate))
        try context.save()

        var projectionCalls = 0
        var saveCount = 0
        let store = InferredFastSuppressionStore(
            modelContext: context,
            projector: { boundaries, goal, _, projectionNow in
                projectionCalls += 1
                return InferredFastProjector.project(
                    boundaries: boundaries,
                    currentGoal: goal,
                    enabled: true,
                    now: projectionNow
                )
            }
        )
        let result = try store.reconcile(
            currentGoal: .default,
            enabled: true,
            now: now,
            updatedAt: now,
            saveAction: {
                saveCount += 1
                try context.save()
            }
        )

        XCTAssertEqual(result.scannedCount, 2)
        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(projectionCalls, 1)
        XCTAssertEqual(saveCount, 1)
        let remaining = try context.fetch(FetchDescriptor<InferredFastSuppressionRecord>())
        XCTAssertEqual(remaining.map(\.id), [canonicalID])

        let data = try SwiftDataHistoryDataProvider(modelContext: context).fetch(
            window: DateInterval(
                start: now.addingTimeInterval(-10 * 60 * 60),
                end: now.addingTimeInterval(60)
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: now
        )
        XCTAssertEqual(presentation.hiddenInferredFastItems.count, 1)
        XCTAssertEqual(
            presentation.hiddenInferredFastItems.first?.inferredInterval?.sourceBoundaryReference,
            candidate.sourceBoundaryReference
        )

        let repeated = try store.reconcile(
            currentGoal: .default,
            enabled: true,
            now: now,
            updatedAt: now,
            saveAction: {
                saveCount += 1
                try context.save()
            }
        )
        XCTAssertEqual(repeated.changedCount, 0)
        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(projectionCalls, 2)
        XCTAssertFalse(context.hasChanges)
    }

    func testPunctuatedCandidateStaleEndIsDurableAndUpdatesTimestamp() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let punctuationID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000012"))
        let fixture = try makePunctuatedFixture(
            now: now,
            punctuationID: punctuationID
        )
        var saveCount = 0
        let store = InferredFastSuppressionStore(modelContext: fixture.context)
        let result = try store.reconcile(
            currentGoal: .default,
            enabled: true,
            now: now,
            updatedAt: now,
            saveAction: {
                saveCount += 1
                try fixture.context.save()
            }
        )

        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(saveCount, 1)
        let repaired = try XCTUnwrap(
            try fixture.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(repaired.projectedEndDate, fixture.punctuationDate)
        XCTAssertEqual(repaired.updatedAt, now)
        XCTAssertFalse(fixture.context.hasChanges)
    }

    func testLaunchCoordinatorReadsOneClockInstantForOnePass() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let container = try makeContainer(
            sourceDate: now.addingTimeInterval(-10 * 60 * 60),
            now: now
        )
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: source.id, now: now))
        context.insert(
            InferredFastSuppressionRecord(
                suppression: .init(candidate: candidate, createdAt: now, updatedAt: now)
            )
        )
        try context.save()

        let clock = CountingAppClock(now: now)
        let coordinator = LaunchReconciliationCoordinator(modelContext: context, clock: clock)
        let result = try coordinator.reconcile()

        XCTAssertEqual(result.suppression.changedCount, 0)
        XCTAssertEqual(clock.accessCount, 1)
        XCTAssertFalse(context.hasChanges)
    }

    func testLaunchCoordinatorBoundaryFailureDoesNotInvokeSuppression() throws {
        var suppressionCalls = 0
        let coordinator = LaunchReconciliationCoordinator(
            boundaryReconciliation: {
                throw LaunchCoordinatorTestError.boundaryFailed
            },
            suppressionReconciliation: {
                suppressionCalls += 1
                return SuppressionReconciliationResult(scannedCount: 0, changedCount: 0)
            }
        )

        XCTAssertThrowsError(try coordinator.reconcile()) { error in
            XCTAssertTrue(error is LaunchCoordinatorTestError)
        }
        XCTAssertEqual(suppressionCalls, 0)
    }

    func testLaunchCoordinatorSuppressionSaveFailureRestoresStateAndClearsChanges() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let punctuationID = try XCTUnwrap(UUID(uuidString: "10200000-0000-0000-0000-000000000013"))
        let fixture = try makePunctuatedFixture(
            now: now,
            punctuationID: punctuationID
        )
        var saveCount = 0
        let coordinator = LaunchReconciliationCoordinator(
            modelContext: fixture.context,
            clock: FixedAppClock(now: now),
            suppressionSaveAction: {
                saveCount += 1
                throw LaunchCoordinatorTestError.saveFailed
            }
        )

        XCTAssertThrowsError(try coordinator.reconcile()) { error in
            XCTAssertTrue(error is LaunchCoordinatorTestError)
        }
        let restored = try XCTUnwrap(
            try fixture.context.fetch(FetchDescriptor<InferredFastSuppressionRecord>()).first?.suppression
        )
        XCTAssertEqual(restored, fixture.prior)
        XCTAssertEqual(saveCount, 1)
        XCTAssertFalse(fixture.context.hasChanges)
    }

    private func makeContainer(
        sourceDate: Date,
        now: Date,
        sourceID: UUID = UUID()
    ) throws -> ModelContainer {
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
                id: sourceID,
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

    private struct PunctuatedFixture {
        let container: ModelContainer
        let context: ModelContext
        let candidate: InferredFastInterval
        let prior: InferredFastSuppression
        let punctuationDate: Date
    }

    private func makePunctuatedFixture(
        now: Date,
        punctuationID: UUID
    ) throws -> PunctuatedFixture {
        let sourceDate = now.addingTimeInterval(-12 * 60 * 60)
        let punctuationDate = sourceDate.addingTimeInterval(10 * 60 * 60)
        let container = try makeContainer(sourceDate: sourceDate, now: now)
        let context = container.mainContext
        let source = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        context.insert(
            FoodEntryRecord(
                id: punctuationID,
                draft: .init(description: "Lunch", occurredAt: punctuationDate),
                createdAt: punctuationDate
            )
        )
        try context.save()
        let candidate = try XCTUnwrap(candidate(in: context, sourceID: source.id, now: now))
        XCTAssertEqual(candidate.nextBoundaryReference, .init(kind: .food, id: punctuationID))
        let prior = InferredFastSuppression(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            projectedStartDate: candidate.startDate,
            projectedEndDate: punctuationDate.addingTimeInterval(-60),
            nextBoundaryReference: candidate.nextBoundaryReference,
            nextBoundaryDate: candidate.nextBoundaryDate,
            goalHoursSnapshot: candidate.goal.hours,
            createdAt: now.addingTimeInterval(-120),
            updatedAt: now.addingTimeInterval(-120)
        )
        context.insert(InferredFastSuppressionRecord(suppression: prior))
        try context.save()
        return PunctuatedFixture(
            container: container,
            context: context,
            candidate: candidate,
            prior: prior,
            punctuationDate: punctuationDate
        )
    }
}

private enum LaunchCoordinatorTestError: Error {
    case boundaryFailed
    case saveFailed
}

private final class CountingAppClock: AppClock, @unchecked Sendable {
    let value: Date
    private(set) var accessCount = 0

    init(now: Date) {
        value = now
    }

    var now: Date {
        accessCount += 1
        return value
    }
}
