import SwiftData
@testable import uFast
import XCTest

@MainActor
final class SwiftDataActiveFastRepositoryTests: XCTestCase {
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
    }
}
