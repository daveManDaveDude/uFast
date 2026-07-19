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
}
