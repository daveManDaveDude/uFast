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
    var savedFasts: [FastRecord] = []
    var saveError: Error?

    func activeFast() throws -> FastRecord? {
        savedFasts.first(where: \.isActive)
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        if let saveError {
            throw saveError
        }
        savedFasts.append(fast)
    }
}

private enum TestError: Error {
    case saveFailed
}
