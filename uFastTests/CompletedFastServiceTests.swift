import Foundation
@testable import uFast
import XCTest

@MainActor
final class CompletedFastServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testValidationUsesStructuralFutureThenConflictOrder() throws {
        let selected = completed(start: -7200, end: -3600)
        let other = completed(start: -1800, end: -900)
        let repository = CompletedFastRepositorySpy(fasts: [selected, other])
        let service = makeService(repository)

        XCTAssertEqual(
            try service.validationError(
                id: selected.id,
                startDate: now.addingTimeInterval(1),
                endDate: now
            ),
            .startTimeNotBeforeEndTime
        )
        XCTAssertEqual(
            try service.validationError(
                id: selected.id,
                startDate: now.addingTimeInterval(1),
                endDate: now.addingTimeInterval(2)
            ),
            .futureStartTime
        )
        XCTAssertEqual(
            try service.validationError(
                id: selected.id,
                startDate: now.addingTimeInterval(-1),
                endDate: now.addingTimeInterval(1)
            ),
            .futureEndTime
        )
        XCTAssertEqual(
            try service.validationError(
                id: selected.id,
                startDate: now.addingTimeInterval(-2000),
                endDate: now.addingTimeInterval(-1000)
            ),
            .conflict
        )
    }

    func testCompletedOrderingUsesNewestEndThenAscendingIdentifier() throws {
        let sharedEnd = now.addingTimeInterval(-3600)
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let older = FastRecord(
            startDate: now.addingTimeInterval(-10800),
            endDate: now.addingTimeInterval(-7200),
            goalAtStart: .default
        )
        let tiedHigher = FastRecord(
            id: higherID,
            startDate: now.addingTimeInterval(-7200),
            endDate: sharedEnd,
            goalAtStart: .default
        )
        let tiedLower = FastRecord(
            id: lowerID,
            startDate: now.addingTimeInterval(-7200),
            endDate: sharedEnd,
            goalAtStart: .default
        )

        let ordered = CompletedFastOrdering.newestEndedFirst(
            [older, tiedHigher, tiedLower]
        )

        XCTAssertEqual(ordered.map(\.id), [lowerID, higherID, older.id])
    }

    func testUpdatePreservesIdentityAndHistoricalGoal() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 18))
        let selected = FastRecord(
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            goalAtStart: goal
        )
        let repository = CompletedFastRepositorySpy(fasts: [selected])
        let service = makeService(repository)
        let newStart = now.addingTimeInterval(-10800)
        let newEnd = now.addingTimeInterval(-1800)

        let updated = try service.update(
            id: selected.id,
            startDate: newStart,
            endDate: newEnd
        )

        XCTAssertEqual(updated.id, selected.id)
        XCTAssertEqual(updated.startDate, newStart)
        XCTAssertEqual(updated.endDate, newEnd)
        XCTAssertEqual(updated.historicalGoal, goal)
    }

    func testConflictRejectsUpdateWithoutChangingEitherRecord() throws {
        let selected = completed(start: -7200, end: -3600)
        let other = completed(start: -1800, end: -900)
        let repository = CompletedFastRepositorySpy(fasts: [selected, other])
        let service = makeService(repository)

        XCTAssertThrowsError(
            try service.update(
                id: selected.id,
                startDate: now.addingTimeInterval(-2000),
                endDate: now.addingTimeInterval(-1000)
            )
        ) { error in
            XCTAssertEqual(error as? CompletedFastError, .conflict)
        }
        XCTAssertEqual(selected.startDate, now.addingTimeInterval(-7200))
        XCTAssertEqual(selected.endDate, now.addingTimeInterval(-3600))
        XCTAssertEqual(other.startDate, now.addingTimeInterval(-1800))
        XCTAssertEqual(other.endDate, now.addingTimeInterval(-900))
    }

    func testTouchingBoundaryCanBeSaved() throws {
        let selected = completed(start: -7200, end: -3600)
        let other = completed(start: -1800, end: -900)
        let repository = CompletedFastRepositorySpy(fasts: [selected, other])
        let service = makeService(repository)

        let updated = try service.update(
            id: selected.id,
            startDate: now.addingTimeInterval(-3600),
            endDate: now.addingTimeInterval(-1800)
        )

        XCTAssertEqual(updated.endDate, other.startDate)
    }

    private func makeService(
        _ repository: CompletedFastRepositorySpy
    ) -> CompletedFastService {
        CompletedFastService(
            repository: repository,
            clock: FixedCompletedFastClock(now: now)
        )
    }

    private func completed(
        start: TimeInterval,
        end: TimeInterval
    ) -> FastRecord {
        FastRecord(
            startDate: now.addingTimeInterval(start),
            endDate: now.addingTimeInterval(end),
            goalAtStart: .default
        )
    }
}

private struct FixedCompletedFastClock: AppClock {
    let now: Date
}

@MainActor
private final class CompletedFastRepositorySpy: CompletedFastRepository {
    var fasts: [FastRecord]

    init(fasts: [FastRecord]) {
        self.fasts = fasts
    }

    func recordedFasts() throws -> [FastRecord] {
        fasts
    }

    func updateCompletedFast(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws -> FastRecord {
        guard let fast = fasts.first(where: { $0.id == id && !$0.isActive }) else {
            throw CompletedFastError.noCompletedFast
        }
        fast.correctBoundaries(startDate: startDate, endDate: endDate)
        return fast
    }

    func deleteCompletedFast(id: UUID) throws {
        guard let index = fasts.firstIndex(where: { $0.id == id && !$0.isActive }) else {
            throw CompletedFastError.noCompletedFast
        }
        fasts.remove(at: index)
    }
}
