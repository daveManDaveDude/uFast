import SwiftData
@testable import uFast
import XCTest

@MainActor
final class SwiftDataActiveFastRepositoryTests: XCTestCase {
    func testMultipleActiveFastsReturnIntegrityFailureWithoutSelectingOrMutating() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let first = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            goalAtStart: .default
        )
        let second = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_003_600),
            goalAtStart: .default
        )
        context.insert(first)
        context.insert(second)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)

        XCTAssertThrowsError(try repository.activeFast()) { error in
            XCTAssertEqual(
                error as? ActiveFastIntegrityError,
                .multipleActiveFasts(count: 2)
            )
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FastRecord>()), 2)
        XCTAssertFalse(context.hasChanges)
    }

    func testSaveFailureRemovesUnsavedFastFromContext() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataActiveFastRepository(
            modelContext: container.mainContext,
            simulateSaveFailure: true
        )
        let fast = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            goalAtStart: .default
        )

        XCTAssertThrowsError(try repository.saveNewActiveFast(fast))

        let storedFasts = try container.mainContext.fetch(FetchDescriptor<FastRecord>())
        XCTAssertTrue(storedFasts.isEmpty)
        XCTAssertNil(try repository.activeFast())
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testStartCorrectionUpdatesRecordInPlace() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalStart = Date(timeIntervalSince1970: 1_800_000_000)
        let correctedStart = originalStart.addingTimeInterval(-7200)
        let fast = FastRecord(startDate: originalStart, goalAtStart: .default)
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)

        try repository.updateStartDate(of: fast, to: correctedStart)

        let storedFasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(storedFasts.count, 1)
        XCTAssertEqual(storedFasts.first?.id, fast.id)
        XCTAssertEqual(storedFasts.first?.startDate, correctedStart)
        XCTAssertEqual(storedFasts.first?.historicalGoal, .default)
    }

    func testCorrectionSaveFailureRestoresExistingRecord() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalStart = Date(timeIntervalSince1970: 1_800_000_000)
        let fast = FastRecord(startDate: originalStart, goalAtStart: .default)
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(
            try repository.updateStartDate(
                of: fast,
                to: originalStart.addingTimeInterval(-7200)
            )
        )

        let storedFasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(storedFasts.count, 1)
        XCTAssertEqual(storedFasts.first?.id, fast.id)
        XCTAssertEqual(storedFasts.first?.startDate, originalStart)
        XCTAssertFalse(context.hasChanges)
    }

    func testLegacyActiveStartCanBeReopenedAndReplacedWithoutChangingIdentityOrGoal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let legacyStart = now.addingTimeInterval(-48 * 60 * 60)
        let goal = try XCTUnwrap(FastingGoal(hours: 18))
        let fast = FastRecord(startDate: legacyStart, goalAtStart: goal)
        context.insert(fast)
        try context.save()

        let repository = SwiftDataActiveFastRepository(modelContext: context)
        let reopened = try XCTUnwrap(try repository.activeFast())
        XCTAssertEqual(reopened.id, fast.id)
        XCTAssertEqual(reopened.startDate, legacyStart)
        XCTAssertEqual(reopened.historicalGoal, goal)

        let replacementStart = now.addingTimeInterval(-36 * 60 * 60)
        try repository.updateStartDate(of: reopened, to: replacementStart)

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<FastRecord>()).first)
        XCTAssertEqual(stored.id, fast.id)
        XCTAssertEqual(stored.startDate, replacementStart)
        XCTAssertEqual(stored.historicalGoal, goal)
    }

    func testCompletionUpdatesExistingRecordInPlaceAndCapturesGoal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 12))
        let completionGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(16 * 60 * 60)
        let fast = FastRecord(startDate: start, goalAtStart: originalGoal)
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)

        try repository.complete(fast, at: end, goal: completionGoal)

        let storedFasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(storedFasts.count, 1)
        XCTAssertEqual(storedFasts.first?.id, fast.id)
        XCTAssertEqual(storedFasts.first?.startDate, start)
        XCTAssertEqual(storedFasts.first?.endDate, end)
        XCTAssertEqual(storedFasts.first?.historicalGoal, completionGoal)
        XCTAssertNil(try repository.activeFast())
    }

    func testCompletionSaveFailureRollsBackEndAndHistoricalGoal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 12))
        let completionGoal = try XCTUnwrap(FastingGoal(hours: 18))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let fast = FastRecord(startDate: start, goalAtStart: originalGoal)
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(
            try repository.complete(
                fast,
                at: start.addingTimeInterval(18 * 60 * 60),
                goal: completionGoal
            )
        )

        let storedFasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(storedFasts.count, 1)
        XCTAssertEqual(storedFasts.first?.id, fast.id)
        XCTAssertNil(storedFasts.first?.endDate)
        XCTAssertEqual(storedFasts.first?.historicalGoal, originalGoal)
        XCTAssertEqual(try repository.activeFast()?.id, fast.id)
        XCTAssertFalse(context.hasChanges)
    }

    func testRepeatedCompletionDoesNotRewriteCompletedRecord() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let firstGoal = try XCTUnwrap(FastingGoal(hours: 14))
        let repeatedGoal = try XCTUnwrap(FastingGoal(hours: 20))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let firstEnd = start.addingTimeInterval(14 * 60 * 60)
        let fast = FastRecord(startDate: start, goalAtStart: .default)
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)

        try repository.complete(fast, at: firstEnd, goal: firstGoal)
        try repository.complete(
            fast,
            at: firstEnd.addingTimeInterval(60),
            goal: repeatedGoal
        )

        let storedFasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(storedFasts.count, 1)
        XCTAssertEqual(storedFasts.first?.endDate, firstEnd)
        XCTAssertEqual(storedFasts.first?.historicalGoal, firstGoal)
    }

    func testCompletedEditRoundTripPreservesIdentityAndGoal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let goal = try XCTUnwrap(FastingGoal(hours: 18))
        let originalStart = Date(timeIntervalSince1970: 1_800_000_000)
        let originalEnd = originalStart.addingTimeInterval(18 * 60 * 60)
        let fast = FastRecord(
            startDate: originalStart,
            endDate: originalEnd,
            goalAtStart: goal
        )
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)
        let newStart = originalStart.addingTimeInterval(-3600)
        let newEnd = originalEnd.addingTimeInterval(1800)

        let updated = try repository.updateCompletedFast(
            id: fast.id,
            startDate: newStart,
            endDate: newEnd
        )

        XCTAssertEqual(updated.id, fast.id)
        XCTAssertEqual(updated.startDate, newStart)
        XCTAssertEqual(updated.endDate, newEnd)
        XCTAssertEqual(updated.historicalGoal, goal)
        XCTAssertFalse(context.hasChanges)
    }

    func testCompletedEditFailureRollsBackBoundaries() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let originalStart = Date(timeIntervalSince1970: 1_800_000_000)
        let originalEnd = originalStart.addingTimeInterval(12 * 60 * 60)
        let fast = FastRecord(
            startDate: originalStart,
            endDate: originalEnd,
            goalAtStart: .default
        )
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(
            try repository.updateCompletedFast(
                id: fast.id,
                startDate: originalStart.addingTimeInterval(-3600),
                endDate: originalEnd.addingTimeInterval(3600)
            )
        )

        XCTAssertEqual(fast.startDate, originalStart)
        XCTAssertEqual(fast.endDate, originalEnd)
        XCTAssertFalse(context.hasChanges)
    }

    func testCompletedDeleteRoundTripLeavesOtherRecords() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let first = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_003_600),
            goalAtStart: .default
        )
        let second = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_007_200),
            endDate: Date(timeIntervalSince1970: 1_800_010_800),
            goalAtStart: .default
        )
        context.insert(first)
        context.insert(second)
        try context.save()
        let repository = SwiftDataActiveFastRepository(modelContext: context)

        try repository.deleteCompletedFast(id: first.id)

        let stored = try repository.recordedFasts()
        XCTAssertEqual(stored.map(\.id), [second.id])
        XCTAssertFalse(context.hasChanges)
    }

    func testCompletedDeleteFailureKeepsRecord() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let fast = FastRecord(
            startDate: Date(timeIntervalSince1970: 1_800_000_000),
            endDate: Date(timeIntervalSince1970: 1_800_003_600),
            goalAtStart: .default
        )
        context.insert(fast)
        try context.save()
        let repository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(try repository.deleteCompletedFast(id: fast.id))

        XCTAssertEqual(try repository.recordedFasts().map(\.id), [fast.id])
        XCTAssertFalse(context.hasChanges)
    }
}
