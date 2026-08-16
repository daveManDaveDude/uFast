import Foundation
@testable import UFastCore
import XCTest

final class InferredFastProjectionTests: XCTestCase {
    func testOptInAndExactEightHourThreshold() throws {
        let source = food(at: 1000, description: "Dinner")
        let before = Date(timeIntervalSince1970: 1000 + 8 * 60 * 60 - 1)
        let exact = Date(timeIntervalSince1970: 1000 + 8 * 60 * 60)

        XCTAssertTrue(project(source: source, now: before, enabled: false).isEmpty)
        XCTAssertTrue(project(source: source, now: before).isEmpty)

        let candidate = try XCTUnwrap(project(source: source, now: exact).first)
        XCTAssertEqual(candidate.startDate, source.occurredAt)
        XCTAssertEqual(candidate.endDate, exact)
        XCTAssertEqual(candidate.state, .inProgress)
        XCTAssertTrue(candidate.offersStart)
        XCTAssertFalse(candidate.offersSave)
    }

    func testNoLaterFoodUsesGoalPlusTwelveHourCapAndBecomesSaveOnlyAtCap() throws {
        let source = food(at: 10000, description: "Dinner")
        let goal = try XCTUnwrap(FastingGoal(hours: 12))
        let current = try XCTUnwrap(project(
            source: source,
            now: source.occurredAt.addingTimeInterval(10 * 60 * 60),
            goal: goal
        ).first)
        XCTAssertEqual(current.startDate, source.occurredAt)
        XCTAssertEqual(
            current.endDate,
            source.occurredAt.addingTimeInterval(10 * 60 * 60)
        )
        XCTAssertEqual(current.state, .inProgress)

        let capped = try XCTUnwrap(project(
            source: source,
            now: source.occurredAt.addingTimeInterval(25 * 60 * 60),
            goal: goal
        ).first)
        XCTAssertEqual(
            capped.endDate,
            source.occurredAt.addingTimeInterval(24 * 60 * 60)
        )
        XCTAssertEqual(capped.state, .historical)
        XCTAssertFalse(capped.offersStart)
        XCTAssertTrue(capped.offersSave)
    }

    func testLaterFoodBeforeGoalPlusTwelveHourCapTerminatesIntervalAtFood() throws {
        let source = food(at: 20000, description: "Dinner")
        let next = food(at: 20000 + 20 * 60 * 60, description: "Breakfast")
        let now = next.occurredAt

        let candidate = try XCTUnwrap(InferredFastProjector.project(
            foodEvents: [source, next],
            currentGoal: .default,
            enabled: true,
            now: now
        ).first { $0.sourceFoodID == source.id })

        XCTAssertEqual(candidate.endDate, next.occurredAt)
        XCTAssertEqual(candidate.nextFoodID, next.id)
        XCTAssertEqual(candidate.nextFoodDate, next.occurredAt)
        XCTAssertEqual(candidate.state, .historical)
        XCTAssertTrue(candidate.offersSave)
    }

    func testNextFoodTerminatesHistoricalIntervalAndShortGapDoesNotQualify() {
        let source = food(at: 20000, description: "Dinner")
        let next = food(at: 20000 + 10 * 60 * 60, description: "Breakfast")
        let historical = InferredFastProjector.project(
            foodEvents: [source, next],
            currentGoal: .default,
            enabled: true,
            now: next.occurredAt
        )
        XCTAssertEqual(historical.count, 1)
        XCTAssertEqual(historical[0].nextFoodID, next.id)
        XCTAssertEqual(historical[0].endDate, next.occurredAt)
        XCTAssertEqual(historical[0].state, .historical)

        let short = food(at: 30000 + 7 * 60 * 60, description: "Snack")
        XCTAssertTrue(InferredFastProjector.project(
            foodEvents: [food(at: 30000), short],
            currentGoal: .default,
            enabled: true,
            now: short.occurredAt
        ).isEmpty)
    }

    func testSameTimestampFoodSourcesProduceOneDeterministicCandidate() throws {
        let timestamp = Date(timeIntervalSince1970: 35000)
        let firstID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let secondFood = FoodBoundarySnapshot(
            id: secondID,
            occurredAt: timestamp,
            description: "Second food",
            isCaloric: true
        )
        let firstFood = FoodBoundarySnapshot(
            id: firstID,
            occurredAt: timestamp,
            description: "First food",
            isCaloric: true
        )
        let foods = [secondFood, firstFood]

        let candidates = InferredFastProjector.project(
            foodEvents: foods,
            currentGoal: .default,
            enabled: true,
            now: timestamp.addingTimeInterval(9 * 60 * 60)
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.sourceFoodID, firstID)
    }

    func testShortFoodGapStaysExcludedAfterLaterFoodHasPassed() {
        let source = food(at: 50000, description: "Dinner")
        let next = food(at: 50000 + 7 * 60 * 60, description: "Snack")
        let now = Date(timeIntervalSince1970: 50000 + 14 * 60 * 60)

        let projections = InferredFastProjector.project(
            foodEvents: [source, next],
            currentGoal: .default,
            enabled: true,
            now: now
        )

        XCTAssertFalse(projections.contains { $0.sourceFoodID == source.id })
        XCTAssertTrue(projections.isEmpty)
    }

    func testFoodIsAlwaysAUsableSourceAndRecordedFastSuppressesWholeCandidate() throws {
        let source = food(at: 40000, description: "Food with no details", isCaloric: false)
        let now = source.occurredAt.addingTimeInterval(9 * 60 * 60)
        let candidate = try XCTUnwrap(project(source: source, now: now).first)
        XCTAssertEqual(candidate.sourceFoodID, source.id)

        let recorded = RecordedFastInterval(
            id: UUID(),
            startDate: source.occurredAt.addingTimeInterval(60 * 60),
            endDate: source.occurredAt.addingTimeInterval(10 * 60 * 60)
        )
        XCTAssertTrue(project(source: source, now: now, recorded: [recorded]).isEmpty)
    }

    func testDaylightSavingChangeStillUsesEightAbsoluteHours() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let sourceDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 29, hour: 0, minute: 30
        )))
        let now = sourceDate.addingTimeInterval(8 * 60 * 60)
        let candidate = try XCTUnwrap(project(
            source: FoodBoundarySnapshot(
                id: UUID(),
                occurredAt: sourceDate,
                description: "DST dinner",
                isCaloric: true
            ),
            now: now
        ).first)
        XCTAssertEqual(candidate.startDate, sourceDate)
        XCTAssertEqual(candidate.endDate, now)
        XCTAssertEqual(candidate.endDate.timeIntervalSince(candidate.startDate), 8 * 60 * 60)
    }

    private func project(
        source: FoodBoundarySnapshot,
        now: Date,
        enabled: Bool = true,
        goal: FastingGoal = .default,
        recorded: [RecordedFastInterval] = []
    ) -> [InferredFastInterval] {
        InferredFastProjector.project(
            foodEvents: [source],
            recordedFasts: recorded,
            currentGoal: goal,
            enabled: enabled,
            now: now
        )
    }

    private func food(
        at timestamp: TimeInterval,
        description: String = "Food",
        isCaloric: Bool = true
    ) -> FoodBoundarySnapshot {
        FoodBoundarySnapshot(
            id: UUID(),
            occurredAt: Date(timeIntervalSince1970: timestamp),
            description: description,
            isCaloric: isCaloric
        )
    }
}
