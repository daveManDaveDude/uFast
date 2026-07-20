import Foundation
@testable import uFast
import XCTest

@MainActor
final class FastStartServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStartCreatesOneActiveFastAtClockInstantWithCurrentGoal() throws {
        let repository = ActiveFastRepositorySpy()
        let goal = try XCTUnwrap(FastingGoal(hours: 16))
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        let fast = try service.startFast(goal: goal)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(fast.startDate, now)
        XCTAssertEqual(fast.historicalGoal, goal)
        XCTAssertTrue(fast.isActive)
    }

    func testRepeatedStartReturnsExistingFastWithoutCreatingAnother() throws {
        let repository = ActiveFastRepositorySpy()
        let goal = try XCTUnwrap(FastingGoal(hours: 12))
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        let firstFast = try service.startFast(goal: goal)
        let repeatedFast = try service.startFast(goal: goal)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(repeatedFast.id, firstFast.id)
        XCTAssertEqual(repeatedFast.startDate, firstFast.startDate)
    }

    func testPastStartCreatesActiveFastAtExactInstantWithCurrentGoal() throws {
        let repository = ActiveFastRepositorySpy()
        let goal = try XCTUnwrap(FastingGoal(hours: 18))
        let pastStart = now.addingTimeInterval(-3 * 24 * 60 * 60)
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        let fast = try service.startFast(at: pastStart, goal: goal)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(fast.startDate, pastStart)
        XCTAssertEqual(fast.historicalGoal, goal)
        XCTAssertTrue(fast.isActive)
    }

    func testCorrectionUpdatesExistingFastAndPreservesIdentityAndHistoricalGoal() throws {
        let historicalGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 14))
        let originalStart = now.addingTimeInterval(-7200)
        let correctedStart = now.addingTimeInterval(-10800)
        let existingFast = FastRecord(startDate: originalStart, goalAtStart: historicalGoal)
        let repository = ActiveFastRepositorySpy(savedFasts: [existingFast])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        let correctedFast = try service.correctActiveFastStart(to: correctedStart)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(correctedFast.id, existingFast.id)
        XCTAssertEqual(correctedFast.startDate, correctedStart)
        XCTAssertEqual(correctedFast.historicalGoal, historicalGoal)
        XCTAssertEqual(
            correctedFast.targetDate(currentGoal: currentGoal),
            correctedStart.addingTimeInterval(14 * 60 * 60)
        )
    }

    func testFutureStartAndCorrectionAreRejectedWithoutMutation() throws {
        let originalStart = now.addingTimeInterval(-7200)
        let existingFast = FastRecord(startDate: originalStart, goalAtStart: .default)
        let repository = ActiveFastRepositorySpy(savedFasts: [existingFast])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )
        let futureStart = now.addingTimeInterval(1)

        XCTAssertThrowsError(try service.startFast(at: futureStart, goal: .default)) { error in
            XCTAssertEqual(error as? FastStartError, .futureStartTime)
        }
        XCTAssertThrowsError(try service.correctActiveFastStart(to: futureStart)) { error in
            XCTAssertEqual(error as? FastStartError, .futureStartTime)
        }
        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(existingFast.startDate, originalStart)
        XCTAssertTrue(repository.updatedStartDates.isEmpty)
    }

    func testCorrectionAllowsExactlyTwentyFourHoursAgo() throws {
        let existingFast = FastRecord(
            startDate: now.addingTimeInterval(-3600),
            goalAtStart: .default
        )
        let repository = ActiveFastRepositorySpy(savedFasts: [existingFast])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )
        let earliestAllowedStart = now.addingTimeInterval(
            -FastStartService.maximumCorrectionAge
        )

        let correctedFast = try service.correctActiveFastStart(to: earliestAllowedStart)

        XCTAssertEqual(correctedFast.startDate, earliestAllowedStart)
        XCTAssertEqual(repository.updatedStartDates, [earliestAllowedStart])
    }

    func testCorrectionRejectsMoreThanTwentyFourHoursAgoWithoutMutation() throws {
        let originalStart = now.addingTimeInterval(-3600)
        let existingFast = FastRecord(
            startDate: originalStart,
            goalAtStart: .default
        )
        let repository = ActiveFastRepositorySpy(savedFasts: [existingFast])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )
        let tooOldStart = now.addingTimeInterval(
            -FastStartService.maximumCorrectionAge - 1
        )

        XCTAssertThrowsError(
            try service.correctActiveFastStart(to: tooOldStart)
        ) { error in
            XCTAssertEqual(error as? FastStartError, .startTimeBeyondCorrectionLimit)
        }
        XCTAssertEqual(existingFast.startDate, originalStart)
        XCTAssertTrue(repository.updatedStartDates.isEmpty)
    }

    func testCorrectionRequiresAnActiveFast() {
        let repository = ActiveFastRepositorySpy()
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        XCTAssertThrowsError(try service.correctActiveFastStart(to: now)) { error in
            XCTAssertEqual(error as? FastStartError, .noActiveFast)
        }
    }

    func testRepeatedPastStartKeepsSingleOriginalActiveFast() throws {
        let repository = ActiveFastRepositorySpy()
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )
        let firstStart = now.addingTimeInterval(-7200)
        let duplicateStart = now.addingTimeInterval(-10800)

        let firstFast = try service.startFast(at: firstStart, goal: .default)
        let duplicateResult = try service.startFast(at: duplicateStart, goal: .default)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(duplicateResult.id, firstFast.id)
        XCTAssertEqual(duplicateResult.startDate, firstStart)
    }

    func testPastStartRejectsCompletedOverlapAndAllowsTouchingBoundary() throws {
        let completed = FastRecord(
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            goalAtStart: .default
        )
        let repository = ActiveFastRepositorySpy(savedFasts: [completed])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        XCTAssertThrowsError(
            try service.startFast(
                at: now.addingTimeInterval(-5400),
                goal: .default
            )
        ) { error in
            XCTAssertEqual(error as? FastStartError, .conflict)
        }
        XCTAssertEqual(repository.savedFasts.count, 1)

        let active = try service.startFast(
            at: now.addingTimeInterval(-3600),
            goal: .default
        )

        XCTAssertEqual(active.startDate, completed.endDate)
        XCTAssertEqual(repository.savedFasts.count, 2)
    }

    func testCorrectionRejectsCompletedOverlapAndAllowsTouchingBoundary() throws {
        let completed = FastRecord(
            startDate: now.addingTimeInterval(-10800),
            endDate: now.addingTimeInterval(-7200),
            goalAtStart: .default
        )
        let originalStart = now.addingTimeInterval(-3600)
        let active = FastRecord(startDate: originalStart, goalAtStart: .default)
        let repository = ActiveFastRepositorySpy(savedFasts: [completed, active])
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        XCTAssertThrowsError(
            try service.correctActiveFastStart(
                to: now.addingTimeInterval(-9000)
            )
        ) { error in
            XCTAssertEqual(error as? FastStartError, .conflict)
        }
        XCTAssertEqual(active.startDate, originalStart)

        let corrected = try service.correctActiveFastStart(
            to: now.addingTimeInterval(-7200)
        )

        XCTAssertEqual(corrected.startDate, completed.endDate)
    }

    func testExactInstantsAroundLondonClockChangesArePreserved() throws {
        let formatter = ISO8601DateFormatter()
        var instants: [Date] = []
        try instants.append(XCTUnwrap(formatter.date(from: "2026-03-29T00:59:59Z")))
        try instants.append(XCTUnwrap(formatter.date(from: "2026-03-29T01:00:00Z")))
        try instants.append(XCTUnwrap(formatter.date(from: "2026-10-25T00:59:59Z")))
        try instants.append(XCTUnwrap(formatter.date(from: "2026-10-25T01:00:00Z")))

        for instant in instants {
            let repository = ActiveFastRepositorySpy()
            let service = FastStartService(
                repository: repository,
                clock: FixedClock(now: now)
            )

            let fast = try service.startFast(at: instant, goal: .default)

            XCTAssertEqual(fast.startDate, instant)
        }
    }

    func testSaveFailureDoesNotExposeAnActiveFastAndCanBeRetried() throws {
        let repository = ActiveFastRepositorySpy()
        repository.saveError = TestError.saveFailed
        let service = FastStartService(
            repository: repository,
            clock: FixedClock(now: now)
        )

        XCTAssertThrowsError(try service.startFast(goal: .default))
        XCTAssertNil(try repository.activeFast())

        repository.saveError = nil
        let fast = try service.startFast(goal: .default)

        XCTAssertEqual(repository.savedFasts.count, 1)
        XCTAssertEqual(fast.startDate, now)
    }
}

private struct FixedClock: AppClock {
    let now: Date
}

@MainActor
private final class ActiveFastRepositorySpy: ActiveFastRepository {
    var savedFasts: [FastRecord]
    var updatedStartDates: [Date] = []
    var saveError: Error?

    init(savedFasts: [FastRecord] = []) {
        self.savedFasts = savedFasts
    }

    func activeFast() throws -> FastRecord? {
        savedFasts.first(where: \.isActive)
    }

    func recordedFasts() throws -> [FastRecord] {
        savedFasts
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        if let saveError {
            throw saveError
        }
        savedFasts.append(fast)
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        if let saveError {
            throw saveError
        }
        fast.correctStartDate(to: startDate)
        updatedStartDates.append(startDate)
    }

    func complete(_: FastRecord, at _: Date, goal _: FastingGoal) throws {
        if let saveError {
            throw saveError
        }
    }
}

private enum TestError: Error {
    case saveFailed
}
