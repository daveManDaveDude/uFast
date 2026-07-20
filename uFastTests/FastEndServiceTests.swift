import Foundation
@testable import uFast
import XCTest

@MainActor
final class FastEndServiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let now = Date(timeIntervalSince1970: 1_800_057_600)

    func testEndNowUsesConfirmationTimeAndCompletesExistingRecordWithCurrentGoal() throws {
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 12))
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let fast = FastRecord(startDate: start, goalAtStart: originalGoal)
        let repository = FastEndRepositorySpy(fasts: [fast])
        let clock = MutableClock(now: start.addingTimeInterval(60))
        let service = FastEndService(repository: repository, clock: clock)

        clock.now = now
        let completedFast = try XCTUnwrap(service.endFast(goal: currentGoal))

        XCTAssertEqual(repository.fasts.count, 1)
        XCTAssertEqual(completedFast.id, fast.id)
        XCTAssertEqual(completedFast.startDate, start)
        XCTAssertEqual(completedFast.endDate, now)
        XCTAssertEqual(completedFast.duration, now.timeIntervalSince(start))
        XCTAssertEqual(completedFast.historicalGoal, currentGoal)
        XCTAssertNil(try repository.activeFast())
    }

    func testPastEndPreservesExactSelectedInstant() throws {
        let selectedEnd = now.addingTimeInterval(-1234)
        let fast = FastRecord(startDate: start, goalAtStart: .default)
        let repository = FastEndRepositorySpy(fasts: [fast])
        let service = FastEndService(
            repository: repository,
            clock: MutableClock(now: now)
        )

        let completedFast = try XCTUnwrap(
            service.endFast(at: selectedEnd, goal: .default)
        )

        XCTAssertEqual(completedFast.id, fast.id)
        XCTAssertEqual(completedFast.startDate, start)
        XCTAssertEqual(completedFast.endDate, selectedEnd)
    }

    func testEndAtOrBeforeStartAndInFutureAreRejectedWithoutMutation() throws {
        let fast = FastRecord(startDate: start, goalAtStart: .default)
        let repository = FastEndRepositorySpy(fasts: [fast])
        let service = FastEndService(
            repository: repository,
            clock: MutableClock(now: now)
        )

        for invalidEnd in [start.addingTimeInterval(-1), start] {
            XCTAssertThrowsError(
                try service.endFast(at: invalidEnd, goal: .default)
            ) { error in
                XCTAssertEqual(error as? FastEndError, .endTimeNotAfterStart)
            }
        }
        XCTAssertThrowsError(
            try service.endFast(at: now.addingTimeInterval(1), goal: .default)
        ) { error in
            XCTAssertEqual(error as? FastEndError, .futureEndTime)
        }
        XCTAssertTrue(fast.isActive)
        XCTAssertNil(fast.endDate)
        XCTAssertTrue(repository.completions.isEmpty)
    }

    func testEndNowAtOrBeforeStartIsRejectedWithoutMutation() throws {
        for currentTime in [start.addingTimeInterval(-1), start] {
            let fast = FastRecord(startDate: start, goalAtStart: .default)
            let repository = FastEndRepositorySpy(fasts: [fast])
            let service = FastEndService(
                repository: repository,
                clock: MutableClock(now: currentTime)
            )

            XCTAssertThrowsError(try service.endFast(goal: .default)) { error in
                XCTAssertEqual(error as? FastEndError, .endTimeNotAfterStart)
            }
            XCTAssertTrue(fast.isActive)
            XCTAssertTrue(repository.completions.isEmpty)
        }
    }

    func testRepeatedEndIsANoOpAfterFirstCompletion() throws {
        let fast = FastRecord(startDate: start, goalAtStart: .default)
        let repository = FastEndRepositorySpy(fasts: [fast])
        let service = FastEndService(
            repository: repository,
            clock: MutableClock(now: now)
        )

        let firstResult = try service.endFast(goal: .default)
        let repeatedResult = try service.endFast(goal: .default)

        XCTAssertEqual(firstResult?.id, fast.id)
        XCTAssertNil(repeatedResult)
        XCTAssertEqual(repository.fasts.count, 1)
        XCTAssertEqual(repository.completions.count, 1)
        XCTAssertNil(try repository.activeFast())
    }

    func testPersistenceFailureLeavesOriginalFastActive() throws {
        let originalGoal = try XCTUnwrap(FastingGoal(hours: 12))
        let currentGoal = try XCTUnwrap(FastingGoal(hours: 18))
        let fast = FastRecord(startDate: start, goalAtStart: originalGoal)
        let repository = FastEndRepositorySpy(fasts: [fast])
        repository.saveError = TestFastEndError.saveFailed
        let service = FastEndService(
            repository: repository,
            clock: MutableClock(now: now)
        )

        XCTAssertThrowsError(try service.endFast(goal: currentGoal))

        XCTAssertTrue(fast.isActive)
        XCTAssertNil(fast.endDate)
        XCTAssertEqual(fast.historicalGoal, originalGoal)
        XCTAssertEqual(try repository.activeFast()?.id, fast.id)
    }

    func testLondonClockChangeEndInstantsAndDisplayTimeZoneChangesPreserveAbsoluteTime() throws {
        let formatter = ISO8601DateFormatter()
        var endInstants: [Date] = []
        try endInstants.append(XCTUnwrap(formatter.date(from: "2026-03-29T01:00:00Z")))
        try endInstants.append(XCTUnwrap(formatter.date(from: "2026-10-25T01:00:00Z")))
        let clock = MutableClock(now: Date(timeIntervalSince1970: 1_900_000_000))

        for endInstant in endInstants {
            let fast = FastRecord(
                startDate: endInstant.addingTimeInterval(-3600),
                goalAtStart: .default
            )
            let repository = FastEndRepositorySpy(fasts: [fast])
            let service = FastEndService(repository: repository, clock: clock)

            try service.endFast(at: endInstant, goal: .default)

            XCTAssertEqual(fast.endDate, endInstant)

            let londonText = try endInstant.formatted(
                Date.FormatStyle(
                    date: .abbreviated,
                    time: .shortened,
                    locale: Locale(identifier: "en_GB"),
                    timeZone: XCTUnwrap(TimeZone(identifier: "Europe/London"))
                )
            )
            let newYorkText = try endInstant.formatted(
                Date.FormatStyle(
                    date: .abbreviated,
                    time: .shortened,
                    locale: Locale(identifier: "en_US"),
                    timeZone: XCTUnwrap(TimeZone(identifier: "America/New_York"))
                )
            )

            XCTAssertNotEqual(londonText, newYorkText)
            XCTAssertEqual(fast.endDate, endInstant)
        }
    }
}

private final class MutableClock: AppClock, @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class FastEndRepositorySpy: ActiveFastRepository {
    var fasts: [FastRecord]
    var completions: [(Date, FastingGoal)] = []
    var saveError: Error?

    init(fasts: [FastRecord]) {
        self.fasts = fasts
    }

    func activeFast() throws -> FastRecord? {
        fasts.first(where: \.isActive)
    }

    func recordedFasts() throws -> [FastRecord] {
        fasts
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        fasts.append(fast)
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        fast.correctStartDate(to: startDate)
    }

    func complete(_ fast: FastRecord, at endDate: Date, goal: FastingGoal) throws {
        if let saveError {
            throw saveError
        }
        guard fast.complete(at: endDate, goal: goal) else {
            return
        }
        completions.append((endDate, goal))
    }
}

private enum TestFastEndError: Error {
    case saveFailed
}
