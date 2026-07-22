import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable force_unwrapping function_body_length trailing_comma

@MainActor
final class ReconstructionReviewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    func testValidatorAcceptsUnderEightHourAdjustmentWithinBoundaries() throws {
        let candidate = makeCandidate(startHours: 0, endHours: 13, identifier: 1)
        let reviewed = ReviewedReconstruction(
            result: .proposal(candidate),
            choice: .adjust(
                startDate: candidate.startDate.addingTimeInterval(6 * 60 * 60),
                endDate: candidate.endDate
            )
        )

        let outcomes = try ReconstructionReviewValidator.validate(
            reviewed: [reviewed],
            expectedResults: [.proposal(candidate)],
            savedFasts: []
        )

        guard case let .fast(startDate, endDate, adjusted) = try XCTUnwrap(outcomes.first).kind else {
            return XCTFail("Expected fast outcome")
        }
        XCTAssertTrue(adjusted)
        XCTAssertEqual(endDate.timeIntervalSince(startDate), 7 * 60 * 60)
    }

    func testValidatorRejectsOutOfBoundsNonPositiveConflictAndBlockedAcceptance() throws {
        let candidate = makeCandidate(startHours: 0, endHours: 13, identifier: 1)
        let conflict = RecordedFastInterval(
            id: UUID(),
            startDate: candidate.startDate.addingTimeInterval(2 * 60 * 60),
            endDate: candidate.startDate.addingTimeInterval(3 * 60 * 60)
        )

        XCTAssertThrowsError(
            try ReconstructionReviewValidator.validate(
                reviewed: [
                    ReviewedReconstruction(
                        result: .proposal(candidate),
                        choice: .adjust(
                            startDate: candidate.startDate.addingTimeInterval(-1),
                            endDate: candidate.endDate
                        )
                    ),
                ],
                expectedResults: [.proposal(candidate)],
                savedFasts: []
            )
        ) { XCTAssertEqual($0 as? ReconstructionReviewValidationError, .outsideSupportingBoundaries) }

        XCTAssertThrowsError(
            try ReconstructionReviewValidator.validate(
                reviewed: [
                    ReviewedReconstruction(
                        result: .proposal(candidate),
                        choice: .adjust(startDate: candidate.startDate, endDate: candidate.startDate)
                    ),
                ],
                expectedResults: [.proposal(candidate)],
                savedFasts: []
            )
        ) { XCTAssertEqual($0 as? ReconstructionReviewValidationError, .nonPositiveDuration) }

        XCTAssertThrowsError(
            try ReconstructionReviewValidator.validate(
                reviewed: [ReviewedReconstruction(result: .proposal(candidate), choice: .accept)],
                expectedResults: [.proposal(candidate)],
                savedFasts: [conflict]
            )
        ) { XCTAssertEqual($0 as? ReconstructionReviewValidationError, .savedHistoryConflict) }

        XCTAssertThrowsError(
            try ReconstructionReviewValidator.validate(
                reviewed: [
                    ReviewedReconstruction(
                        result: .blocked(candidate, reason: .savedHistoryConflict),
                        choice: .accept
                    ),
                ],
                expectedResults: [.blocked(candidate, reason: .savedHistoryConflict)],
                savedFasts: []
            )
        ) { XCTAssertEqual($0 as? ReconstructionReviewValidationError, .unavailableChoice) }
    }

    func testAtomicCommitPersistsAcceptedAdjustedAndUnknownWithoutHistoricalGoals() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        try insertBoundaries(hours: [1, 14, 27, 40], context: context)
        let repository = SwiftDataReconstructionRepository(
            modelContext: context,
            clock: FixedAppClock(now: now)
        )
        let range = now ..< now.addingTimeInterval(48 * 60 * 60)
        let generation = try repository.generation(range: range)
        let proposals = generation.results.compactMap { result -> ReconstructionCandidate? in
            if case let .proposal(candidate) = result {
                return candidate
            }
            return nil
        }
        XCTAssertEqual(proposals.count, 3)

        let reviewed = [
            ReviewedReconstruction(result: .proposal(proposals[0]), choice: .accept),
            ReviewedReconstruction(
                result: .proposal(proposals[1]),
                choice: .adjust(
                    startDate: proposals[1].startDate.addingTimeInterval(6 * 60 * 60),
                    endDate: proposals[1].endDate
                )
            ),
            ReviewedReconstruction(result: .proposal(proposals[2]), choice: .leaveUnknown),
        ]

        try repository.commit(
            reviewed: reviewed,
            expectedGeneration: generation,
            range: range
        )

        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        let unknowns = try context.fetch(FetchDescriptor<UnknownPeriodRecord>())
        XCTAssertEqual(fasts.count, 2)
        XCTAssertEqual(unknowns.count, 1)
        XCTAssertTrue(fasts.allSatisfy { $0.origin == .reconstructed })
        XCTAssertTrue(fasts.allSatisfy { $0.reviewState == .confirmed })
        XCTAssertTrue(fasts.allSatisfy { $0.capturedHistoricalGoal == nil })
        XCTAssertEqual(fasts.filter(\.wasAdjustedByUser).count, 1)
        XCTAssertEqual(unknowns.first?.reason, .userChoice)
        XCTAssertEqual(try repository.generation(range: range).suppressedPairCount, 3)
        XCTAssertThrowsError(
            try repository.commit(
                reviewed: reviewed,
                expectedGeneration: generation,
                range: range
            )
        ) { XCTAssertEqual($0 as? ReconstructionPersistenceError, .staleEvidence) }
        XCTAssertEqual(try context.fetch(FetchDescriptor<FastRecord>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).count, 1)
    }

    func testFailureRollsBackEntireReviewedSetAndKeepsNoTransientProposal() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        try insertBoundaries(hours: [1, 14, 27], context: context)
        let repository = SwiftDataReconstructionRepository(
            modelContext: context,
            clock: FixedAppClock(now: now),
            simulateSaveFailure: true
        )
        let range = now ..< now.addingTimeInterval(36 * 60 * 60)
        let generation = try repository.generation(range: range)
        let reviewed = generation.results.compactMap { result -> ReviewedReconstruction? in
            guard case .proposal = result else { return nil }
            return ReviewedReconstruction(result: result, choice: .accept)
        }

        XCTAssertThrowsError(
            try repository.commit(
                reviewed: reviewed,
                expectedGeneration: generation,
                range: range
            )
        ) { XCTAssertEqual($0 as? ReconstructionPersistenceError, .simulatedSaveFailure) }
        XCTAssertTrue(try context.fetch(FetchDescriptor<FastRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).isEmpty)
    }

    func testStaleBoundaryPreventsEveryOutcomeFromSaving() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        try insertBoundaries(hours: [1, 14], context: context)
        let repository = SwiftDataReconstructionRepository(
            modelContext: context,
            clock: FixedAppClock(now: now)
        )
        let range = now ..< now.addingTimeInterval(24 * 60 * 60)
        let generation = try repository.generation(range: range)
        let proposal = try XCTUnwrap(generation.results.compactMap(\.candidate).first)
        let event = try XCTUnwrap(context.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        event.update(
            from: FoodEntryDraft(
                description: event.foodDescription,
                occurredAt: event.occurredAt.addingTimeInterval(60),
                nutrition: event.nutrition
            ),
            at: now
        )
        try context.save()

        XCTAssertThrowsError(
            try repository.commit(
                reviewed: [ReviewedReconstruction(result: .proposal(proposal), choice: .accept)],
                expectedGeneration: generation,
                range: range
            )
        ) { XCTAssertEqual($0 as? ReconstructionPersistenceError, .staleEvidence) }
        XCTAssertTrue(try context.fetch(FetchDescriptor<FastRecord>()).isEmpty)
    }

    func testExistingFastDefaultsRemainRecordedWithHistoricalGoal() throws {
        let goal = try XCTUnwrap(FastingGoal(hours: 16))
        let fast = FastRecord(
            startDate: now,
            endDate: now.addingTimeInterval(16 * 60 * 60),
            goalAtStart: goal
        )
        XCTAssertEqual(fast.origin, .recorded)
        XCTAssertEqual(fast.reviewState, .confirmed)
        XCTAssertFalse(fast.wasAdjustedByUser)
        XCTAssertEqual(fast.capturedHistoricalGoal, goal)
        XCTAssertNil(fast.boundaryPair)
    }

    private func makeCandidate(
        startHours: Int,
        endHours: Int,
        identifier: Int
    ) -> ReconstructionCandidate {
        let start = CaloricBoundary(
            reference: .init(kind: .food, id: uuid(identifier)),
            occurredAt: now.addingTimeInterval(TimeInterval(startHours * 60 * 60)),
            description: "Start"
        )
        let end = CaloricBoundary(
            reference: .init(kind: .food, id: uuid(identifier + 1)),
            occurredAt: now.addingTimeInterval(TimeInterval(endHours * 60 * 60)),
            description: "End"
        )
        return ReconstructionCandidate(
            pair: ReconstructionBoundaryPair(start: start.reference, end: end.reference),
            startBoundary: start,
            endBoundary: end
        )
    }

    private func insertBoundaries(hours: [Int], context: ModelContext) throws {
        for (index, hour) in hours.enumerated() {
            let date = now.addingTimeInterval(TimeInterval(hour * 60 * 60))
            context.insert(
                FoodEntryRecord(
                    id: uuid(index + 1),
                    draft: FoodEntryDraft(description: "Meal \(index + 1)", occurredAt: date),
                    createdAt: date
                )
            )
        }
        try context.save()
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", value))!
    }
}
