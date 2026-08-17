import SwiftData
@testable import uFast
import XCTest

@MainActor
final class CaloricBoundaryIntegrityTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testCompletedFoodRequiresConfirmationAndShortensAtomically() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let end = start.addingTimeInterval(16 * 60 * 60)
        let fast = FastRecord(startDate: start, endDate: end, goalAtStart: .default)
        container.mainContext.insert(fast)
        try container.mainContext.save()
        let eventDate = start.addingTimeInterval(10 * 60 * 60)
        let service = FoodEntryService(
            repository: SwiftDataFoodEntryRepository(modelContext: container.mainContext),
            clock: FixedAppClock(now: end)
        )
        let draft = FoodEntryDraft(description: "Lunch", occurredAt: eventDate)

        XCTAssertThrowsError(try service.save(draft, replacing: nil, goal: .default)) {
            XCTAssertEqual($0 as? FoodEntrySaveError, .completedFastConfirmationRequired)
        }
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
        XCTAssertEqual(fast.endDate, end)

        try service.save(draft, replacing: nil, goal: .default, endingActiveFast: true)
        XCTAssertEqual(fast.endDate, eventDate)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).count, 1)
    }

    func testCompletedCaloricHydrationRequiresConfirmationAndShortensFast() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let end = start.addingTimeInterval(16 * 60 * 60)
        let fast = FastRecord(startDate: start, endDate: end, goalAtStart: .default)
        container.mainContext.insert(fast)
        try container.mainContext.save()
        let eventDate = start.addingTimeInterval(9 * 60 * 60)
        let service = HydrationEntryService(
            repository: SwiftDataHydrationEntryRepository(modelContext: container.mainContext),
            clock: FixedAppClock(now: end)
        )
        let draft = HydrationEntryDraft(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: eventDate,
            isCaloric: true
        )

        XCTAssertThrowsError(try service.save(draft, replacing: nil, goal: .default)) {
            XCTAssertEqual($0 as? HydrationEntrySaveError, .completedFastConfirmationRequired)
        }
        try service.save(draft, replacing: nil, goal: .default, endingActiveFast: true)
        XCTAssertEqual(fast.endDate, eventDate)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).count, 1)
    }

    func testReconstructedFastUsesNewBoundaryProvenanceWhenShortened() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let startRecord = FoodEntryRecord(
            draft: FoodEntryDraft(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        let oldEndDate = start.addingTimeInterval(18 * 60 * 60)
        let oldEndRecord = FoodEntryRecord(
            draft: FoodEntryDraft(description: "Breakfast", occurredAt: oldEndDate),
            createdAt: oldEndDate
        )
        container.mainContext.insert(startRecord)
        container.mainContext.insert(oldEndRecord)
        let pair = ReconstructionBoundaryPair(
            start: CaloricBoundaryReference(kind: .food, id: startRecord.id),
            end: CaloricBoundaryReference(kind: .food, id: oldEndRecord.id)
        )
        let fast = FastRecord(
            reconstructedStart: start,
            endDate: oldEndDate,
            boundaries: pair,
            adjustedByUser: false
        )
        container.mainContext.insert(fast)
        try container.mainContext.save()

        let eventDate = start.addingTimeInterval(11 * 60 * 60)
        let service = FoodEntryService(
            repository: SwiftDataFoodEntryRepository(modelContext: container.mainContext),
            clock: FixedAppClock(now: oldEndDate)
        )
        let event = FoodEntryDraft(description: "Snack", occurredAt: eventDate)
        XCTAssertThrowsError(try service.save(event, replacing: nil, goal: .default))
        try service.save(event, replacing: nil, goal: .default, endingActiveFast: true)

        XCTAssertEqual(fast.endDate, eventDate)
        XCTAssertEqual(fast.reviewState, .confirmed)
        XCTAssertEqual(
            fast.boundaryPair?.end,
            try CaloricBoundaryReference(kind: .food, id: XCTUnwrap(
                container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>())
                    .first { $0.foodDescription == "Snack" }?.id
            ))
        )
    }

    func testReconciliationShortensStaleReconstructedFastToInteriorBoundary() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let oldEndDate = start.addingTimeInterval(18 * 60 * 60)
        let interiorDate = start.addingTimeInterval(11 * 60 * 60)
        let startRecord = FoodEntryRecord(
            draft: FoodEntryDraft(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        let staleEndID = UUID()
        let staleEndRecord = HydrationEntryRecord(
            id: staleEndID,
            type: .custom,
            customName: "Water",
            volumeMillilitres: 250,
            occurredAt: oldEndDate,
            isCaloric: false,
            createdAt: oldEndDate
        )
        let interiorRecord = HydrationEntryRecord(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: interiorDate,
            isCaloric: true,
            createdAt: interiorDate
        )
        let pair = ReconstructionBoundaryPair(
            start: CaloricBoundaryReference(kind: .food, id: startRecord.id),
            end: CaloricBoundaryReference(kind: .hydration, id: staleEndID)
        )
        let fast = FastRecord(
            reconstructedStart: start,
            endDate: oldEndDate,
            boundaries: pair,
            adjustedByUser: false
        )
        container.mainContext.insert(startRecord)
        container.mainContext.insert(staleEndRecord)
        container.mainContext.insert(interiorRecord)
        container.mainContext.insert(fast)
        try container.mainContext.save()

        let reconciler = CaloricBoundaryReconciler(modelContext: container.mainContext, currentGoal: .default)
        _ = try reconciler.reconcile()

        assertReconciledStaleFast(
            fast,
            endDate: interiorDate,
            currentEnd: .init(kind: .hydration, id: interiorRecord.id),
            retainedEnd: pair.end
        )

        let secondChangedCount = try reconciler.reconcile().changedCount
        XCTAssertEqual(secondChangedCount, 0)
    }

    func testFoodRepositoryUsesInjectedClockForEventMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let occurredAt = now.addingTimeInterval(-3600)
        let clock = FixedAppClock(now: now)

        let foodContainer = try PersistenceContainer.make(inMemory: true)
        let foodRepository = SwiftDataFoodEntryRepository(
            modelContext: foodContainer.mainContext,
            clock: clock
        )
        try foodRepository.saveCaloricEvent(
            FoodEntryDraft(description: "Lunch", occurredAt: occurredAt),
            replacing: nil,
            goal: .default
        )
        let food = try XCTUnwrap(
            foodContainer.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).first
        )
        XCTAssertEqual(food.createdAt, now)
        XCTAssertEqual(food.updatedAt, now)
    }

    func testHydrationRepositoryUsesInjectedClockForEventMetadata() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let occurredAt = now.addingTimeInterval(-3600)
        let clock = FixedAppClock(now: now)
        let hydrationContainer = try PersistenceContainer.make(inMemory: true)
        let hydrationRepository = SwiftDataHydrationEntryRepository(
            modelContext: hydrationContainer.mainContext,
            clock: clock
        )
        try hydrationRepository.saveCaloricEvent(
            HydrationEntryDraft(
                type: .custom,
                customName: "Juice",
                volumeMillilitres: 250,
                occurredAt: occurredAt,
                isCaloric: true
            ),
            replacing: nil,
            goal: .default
        )
        let hydration = try XCTUnwrap(
            hydrationContainer.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).first
        )
        XCTAssertEqual(hydration.createdAt, now)
        XCTAssertEqual(hydration.updatedAt, now)
    }

    func testDeletingOrMovingEndEventNeverLengthensCompletedFast() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let eventDate = start.addingTimeInterval(10 * 60 * 60)
        let record = FoodEntryRecord(
            draft: FoodEntryDraft(description: "Lunch", occurredAt: eventDate),
            createdAt: eventDate
        )
        let fast = FastRecord(startDate: start, endDate: eventDate, goalAtStart: .default)
        container.mainContext.insert(record)
        container.mainContext.insert(fast)
        try container.mainContext.save()
        let repository = SwiftDataFoodEntryRepository(modelContext: container.mainContext)

        try repository.delete(record)
        XCTAssertEqual(fast.endDate, eventDate)

        let laterRecord = try repository.create(
            FoodEntryDraft(description: "Later", occurredAt: eventDate),
            at: eventDate
        )
        try repository.update(
            laterRecord,
            with: FoodEntryDraft(description: "Moved", occurredAt: eventDate.addingTimeInterval(60)),
            at: eventDate.addingTimeInterval(60)
        )
        XCTAssertEqual(fast.endDate, eventDate)
    }

    func testReconciliationEndsActiveFastAndIsIdempotent() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let fast = FastRecord(startDate: start, goalAtStart: .default)
        let drinkDate = start.addingTimeInterval(9 * 60 * 60)
        let drink = HydrationEntryRecord(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: drinkDate,
            isCaloric: true,
            createdAt: drinkDate
        )
        container.mainContext.insert(fast)
        container.mainContext.insert(drink)
        try container.mainContext.save()

        let goal = try XCTUnwrap(FastingGoal(hours: 16))
        let reconciler = CaloricBoundaryReconciler(
            modelContext: container.mainContext,
            currentGoal: goal
        )
        let first = try reconciler.reconcile()
        XCTAssertEqual(first.scannedCount, 1)
        XCTAssertEqual(first.changedCount, 1)
        XCTAssertTrue(first.activeFastEnded)
        XCTAssertEqual(fast.endDate, drinkDate)
        XCTAssertEqual(fast.historicalGoal, FastingGoal(hours: 16))

        let second = try reconciler.reconcile()
        XCTAssertEqual(second.changedCount, 0)
        XCTAssertFalse(second.activeFastEnded)
    }

    func testReconciliationPersistsReviewEvidenceWhenReconstructedEndIsRemoved() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let startRecord = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        let oldEndDate = start.addingTimeInterval(18 * 60 * 60)
        let oldEndRecord = FoodEntryRecord(
            draft: .init(description: "Breakfast", occurredAt: oldEndDate),
            createdAt: oldEndDate
        )
        let pair = ReconstructionBoundaryPair(
            start: .init(kind: .food, id: startRecord.id),
            end: .init(kind: .food, id: oldEndRecord.id)
        )
        let fast = FastRecord(
            reconstructedStart: start,
            endDate: oldEndDate,
            boundaries: pair,
            adjustedByUser: false
        )
        context.insert(startRecord)
        context.insert(oldEndRecord)
        context.insert(fast)
        try context.save()

        context.delete(oldEndRecord)
        try context.save()
        let result = try CaloricBoundaryReconciler(
            modelContext: context,
            currentGoal: .default
        ).reconcile()

        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(fast.reviewState, .needsReview)
        XCTAssertEqual(fast.retainedReviewBoundary, pair.end)
        XCTAssertEqual(fast.boundaryPair, pair)
        XCTAssertEqual(try CaloricBoundaryReconciler(
            modelContext: context,
            currentGoal: .default
        ).reconcile().changedCount, 0)
    }
}

extension CaloricBoundaryIntegrityTests {
    func testConfirmationContextKeepsActivePrecedenceAndCombinedImpactDetails() {
        let activeID = UUID()
        let completedID = UUID()
        let reconstructedID = UUID()
        let impact = CaloricEventImpact(
            activeFastIDs: [activeID],
            completedFastIDs: [completedID],
            reconstructedFastIDs: [reconstructedID],
            reconstructedReviewIDs: [reconstructedID]
        )
        let context = CaloricEventConfirmationContext(
            persistedImpact: impact,
            includesInferredInterval: true
        )

        XCTAssertEqual(context.kind, .active)
        XCTAssertEqual(context.affectedPersistedFastCount, 3)
        XCTAssertTrue(context.includesReconstructedFast)
        XCTAssertTrue(context.includesInferredInterval)
        XCTAssertTrue(context.isCombined)
    }

    func testCombinedActiveConfirmationCopyStatesTotalPersistedFastCount() {
        let impact = CaloricEventImpact(
            activeFastIDs: [UUID()],
            completedFastIDs: [UUID()],
            reconstructedFastIDs: [UUID()],
            reconstructedReviewIDs: []
        )
        let context = CaloricEventConfirmationContext(persistedImpact: impact)

        let foodMessage = FoodEntryEditor.activeConfirmationMessage(
            context: context,
            action: "Saving",
            time: "10:30"
        )
        let hydrationMessage = HydrationEntryEditor.activeConfirmationMessage(
            context: context,
            action: "Saving",
            time: "10:30"
        )

        XCTAssertTrue(foodMessage.hasPrefix("Ending your active fast"))
        XCTAssertTrue(foodMessage.contains("3 persisted fasts"))
        XCTAssertTrue(hydrationMessage.hasPrefix("Ending your active fast"))
        XCTAssertTrue(hydrationMessage.contains("3 persisted fasts"))
    }
}

private func assertReconciledStaleFast(
    _ fast: FastRecord,
    endDate: Date,
    currentEnd: CaloricBoundaryReference,
    retainedEnd: CaloricBoundaryReference
) {
    XCTAssertEqual(fast.endDate, endDate)
    XCTAssertEqual(fast.reviewState, .needsReview)
    XCTAssertEqual(fast.boundaryPair?.end, currentEnd)
    XCTAssertEqual(fast.retainedReviewBoundary, retainedEnd)
}
