import SwiftData
@testable import uFast
import XCTest

@MainActor
final class FoodEntryServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCaloricEventRequiresConfirmationBeforeEitherRecordChanges() throws {
        let fixture = try makeFixture()

        XCTAssertThrowsError(
            try fixture.service.save(
                FoodEntryDraft(description: "Lunch", occurredAt: now),
                replacing: nil,
                goal: .default
            )
        ) { error in
            guard case let .confirmationRequiredWithImpact(context) = error as? FoodEntrySaveError else {
                return XCTFail("Expected active boundary impact, got \(error)")
            }
            XCTAssertEqual(context.kind, .active)
            XCTAssertEqual(context.affectedPersistedFastCount, 1)
            XCTAssertFalse(context.includesReconstructedReview)
            XCTAssertFalse(context.includesInferredInterval)
        }
        XCTAssertTrue(fixture.fast.isActive)
        XCTAssertTrue(try foodEntries(in: fixture.container).isEmpty)
    }

    func testConfirmedCaloricEventAtomicallyCreatesEntryAndEndsFastAtEventTime() throws {
        let fixture = try makeFixture()
        let goal = FastingGoal(hours: 16) ?? .default

        try fixture.service.save(
            FoodEntryDraft(description: "Lunch", occurredAt: now),
            replacing: nil,
            goal: goal,
            endingActiveFast: true
        )

        XCTAssertEqual(fixture.fast.endDate, now)
        XCTAssertEqual(fixture.fast.historicalGoal, goal)
        let entry = try XCTUnwrap(foodEntries(in: fixture.container).first)
        XCTAssertEqual(entry.foodDescription, "Lunch")
        XCTAssertTrue(entry.isCaloric)
    }

    func testExactStartIsRejectedAndBeforeStartDoesNotEndFast() throws {
        let fixture = try makeFixture()

        XCTAssertThrowsError(
            try fixture.service.save(
                FoodEntryDraft(
                    description: "At start",
                    occurredAt: fixture.fast.startDate
                ),
                replacing: nil,
                goal: .default,
                endingActiveFast: true
            )
        ) { error in
            XCTAssertEqual(error as? FoodEntrySaveError, .eventAtActiveFastStart)
        }
        XCTAssertTrue(try foodEntries(in: fixture.container).isEmpty)

        try fixture.service.save(
            FoodEntryDraft(
                description: "Before start",
                occurredAt: fixture.fast.startDate.addingTimeInterval(-60)
            ),
            replacing: nil,
            goal: .default
        )
        XCTAssertTrue(fixture.fast.isActive)
        XCTAssertEqual(try foodEntries(in: fixture.container).count, 1)
    }

    func testAtomicFailureLeavesFastActiveAndDoesNotCreateEntry() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let fast = FastRecord(
            startDate: now.addingTimeInterval(-3600),
            goalAtStart: .default
        )
        container.mainContext.insert(fast)
        try container.mainContext.save()
        let repository = SwiftDataFoodEntryRepository(
            modelContext: container.mainContext,
            simulateSaveFailure: true
        )
        let service = FoodEntryService(
            repository: repository,
            clock: FixedAppClock(now: now)
        )

        XCTAssertThrowsError(
            try service.save(
                FoodEntryDraft(description: "Lunch", occurredAt: now),
                replacing: nil,
                goal: .default,
                endingActiveFast: true
            )
        )
        XCTAssertTrue(fast.isActive)
        XCTAssertTrue(try foodEntries(in: container).isEmpty)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testEditingIntoActiveIntervalPreservesIdentifierAndEndsFast() throws {
        let fixture = try makeFixture()
        let repository = SwiftDataFoodEntryRepository(modelContext: fixture.container.mainContext)
        let record = try repository.create(
            FoodEntryDraft(
                description: "Drink",
                occurredAt: fixture.fast.startDate.addingTimeInterval(-60)
            ),
            at: now.addingTimeInterval(-120)
        )
        let identifier = record.id

        try fixture.service.save(
            FoodEntryDraft(description: "Snack", occurredAt: now),
            replacing: record,
            goal: .default,
            endingActiveFast: true
        )

        XCTAssertEqual(record.id, identifier)
        XCTAssertEqual(record.foodDescription, "Snack")
        XCTAssertTrue(record.isCaloric)
        XCTAssertEqual(fixture.fast.endDate, now)
        XCTAssertEqual(try foodEntries(in: fixture.container).count, 1)
    }

    private func makeFixture() throws -> Fixture {
        let container = try PersistenceContainer.make(inMemory: true)
        let fast = FastRecord(
            startDate: now.addingTimeInterval(-3600),
            goalAtStart: .default
        )
        container.mainContext.insert(fast)
        try container.mainContext.save()
        let service = FoodEntryService(
            repository: SwiftDataFoodEntryRepository(modelContext: container.mainContext),
            clock: FixedAppClock(now: now)
        )
        return Fixture(container: container, fast: fast, service: service)
    }

    private func foodEntries(in container: ModelContainer) throws -> [FoodEntryRecord] {
        try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>())
    }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let fast: FastRecord
    let service: FoodEntryService
}
