import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable force_unwrapping large_tuple trailing_comma

@MainActor
final class HistoryProvenanceTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 2_200_000_000)

    func testMixedHistoryOrderingUsesEndKindThenStableIdentifier() {
        let end = base.addingTimeInterval(20 * 60 * 60)
        let recordedID = uuid(3)
        let reconstructedID = uuid(1)
        let unknownID = uuid(2)
        let earlierID = uuid(4)
        let values = [
            HistoryOrderingValue(id: unknownID, endDate: end, kind: .unknownPeriod),
            HistoryOrderingValue(id: earlierID, endDate: end.addingTimeInterval(-1), kind: .recordedFast),
            HistoryOrderingValue(id: reconstructedID, endDate: end, kind: .reconstructedFast),
            HistoryOrderingValue(id: recordedID, endDate: end, kind: .recordedFast),
        ]

        XCTAssertEqual(
            HistoryOrdering.newestFirst(values).map(\.id),
            [recordedID, reconstructedID, unknownID, earlierID]
        )
    }

    func testReconstructedAdjustmentRemainsProvenancedAndGoalUnknown() throws {
        let fixture = try makeFixture()
        let adjustedStart = fixture.start.occurredAt.addingTimeInterval(2 * 60 * 60)
        let adjustedEnd = fixture.end.occurredAt.addingTimeInterval(-2 * 60 * 60)

        try fixture.repository.adjustReconstructedFast(
            id: fixture.fast.id,
            startDate: adjustedStart,
            endDate: adjustedEnd
        )

        XCTAssertEqual(fixture.fast.startDate, adjustedStart)
        XCTAssertEqual(fixture.fast.endDate, adjustedEnd)
        XCTAssertEqual(fixture.fast.origin, .reconstructed)
        XCTAssertEqual(fixture.fast.reviewState, .confirmed)
        XCTAssertTrue(fixture.fast.wasAdjustedByUser)
        XCTAssertNil(fixture.fast.capturedHistoricalGoal)
        XCTAssertEqual(fixture.fast.boundaryPair, fixture.pair)
    }

    func testRemoveReconstructionToUnknownIsAtomicAndMarkerCanBeRemoved() throws {
        let fixture = try makeFixture()

        try fixture.repository.removeAndLeaveUnknown(id: fixture.fast.id)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<FastRecord>()).isEmpty)
        let unknown = try XCTUnwrap(
            fixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).first
        )
        XCTAssertEqual(unknown.startDate, fixture.fast.startDate)
        XCTAssertEqual(unknown.endDate, fixture.fast.endDate)
        XCTAssertEqual(unknown.boundaryPair, fixture.pair)

        try fixture.repository.removeUnknownMarker(id: unknown.id)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).isEmpty)
    }

    func testAdjustmentAndRemoveFailureLeaveOriginalReconstruction() throws {
        let fixture = try makeFixture(simulateFailure: true)
        let oldStart = fixture.fast.startDate
        let oldEnd = fixture.fast.endDate

        XCTAssertThrowsError(
            try fixture.repository.adjustReconstructedFast(
                id: fixture.fast.id,
                startDate: oldStart.addingTimeInterval(60),
                endDate: XCTUnwrap(oldEnd).addingTimeInterval(-60)
            )
        )
        XCTAssertEqual(fixture.fast.startDate, oldStart)
        XCTAssertEqual(fixture.fast.endDate, oldEnd)
        XCTAssertFalse(fixture.fast.wasAdjustedByUser)

        XCTAssertThrowsError(try fixture.repository.removeAndLeaveUnknown(id: fixture.fast.id))
        XCTAssertEqual(try fixture.context.fetch(FetchDescriptor<FastRecord>()).count, 1)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).isEmpty)
    }

    func testConvertedRecordedFastCanOmitUnknownHistoricalGoal() {
        let start = CaloricBoundaryReference(kind: .food, id: uuid(1))
        let end = CaloricBoundaryReference(kind: .food, id: uuid(2))
        let fast = FastRecord(
            reconstructedStart: base,
            endDate: base.addingTimeInterval(12 * 60 * 60),
            boundaries: ReconstructionBoundaryPair(start: start, end: end),
            adjustedByUser: false
        )

        fast.convertToRecordedWithoutHistoricalGoal()

        XCTAssertEqual(fast.origin, .recorded)
        XCTAssertEqual(fast.reviewState, .confirmed)
        XCTAssertNil(fast.boundaryPair)
        XCTAssertNil(fast.capturedHistoricalGoal)
    }

    private func makeFixture(simulateFailure: Bool = false) throws -> (
        container: ModelContainer,
        context: ModelContext,
        repository: SwiftDataReconstructionRepository,
        fast: FastRecord,
        start: CaloricBoundary,
        end: CaloricBoundary,
        pair: ReconstructionBoundaryPair
    ) {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let startDate = base.addingTimeInterval(60 * 60)
        let endDate = base.addingTimeInterval(14 * 60 * 60)
        let startRecord = FoodEntryRecord(
            id: uuid(1),
            draft: FoodEntryDraft(description: "Dinner", occurredAt: startDate),
            createdAt: startDate
        )
        let endRecord = FoodEntryRecord(
            id: uuid(2),
            draft: FoodEntryDraft(description: "Breakfast", occurredAt: endDate),
            createdAt: endDate
        )
        let start = CaloricBoundary(
            reference: .init(kind: .food, id: startRecord.id),
            occurredAt: startDate,
            description: startRecord.foodDescription
        )
        let end = CaloricBoundary(
            reference: .init(kind: .food, id: endRecord.id),
            occurredAt: endDate,
            description: endRecord.foodDescription
        )
        let pair = ReconstructionBoundaryPair(start: start.reference, end: end.reference)
        let fast = FastRecord(
            reconstructedStart: startDate,
            endDate: endDate,
            boundaries: pair,
            adjustedByUser: false
        )
        context.insert(startRecord)
        context.insert(endRecord)
        context.insert(fast)
        try context.save()
        return (
            container,
            context,
            SwiftDataReconstructionRepository(
                modelContext: context,
                clock: FixedAppClock(now: base.addingTimeInterval(30 * 60 * 60)),
                simulateSaveFailure: simulateFailure
            ),
            fast,
            start,
            end,
            pair
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", value))!
    }
}
