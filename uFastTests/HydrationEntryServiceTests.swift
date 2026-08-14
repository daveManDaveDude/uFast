import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable large_tuple line_length

@MainActor
final class HydrationEntryServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCustomValidationAndCRUDPreserveIdentifier() throws {
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertNil(HydrationEntryValidator.validated(type: .custom, customName: "  ", volumeMillilitres: 250, occurredAt: now, isCaloric: false, now: now, calendar: calendar))
        let draft = try XCTUnwrap(HydrationEntryValidator.validated(type: .custom, customName: "  Sparkling water ", volumeMillilitres: 250, occurredAt: now, isCaloric: false, now: now, calendar: calendar))
        XCTAssertEqual(draft.customName, "Sparkling water")

        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataHydrationEntryRepository(modelContext: container.mainContext)
        let record = try repository.create(draft, at: now)
        let id = record.id
        let edited = HydrationEntryDraft(type: .tea, customName: nil, volumeMillilitres: 400, occurredAt: now, isCaloric: false)
        try repository.update(record, with: edited, at: now.addingTimeInterval(1))
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.displayName, "Tea")
        XCTAssertEqual(record.volumeMillilitres, 400)
        try repository.delete(record)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
    }

    func testNonCaloricDrinkDoesNotEndFastAndCaloricRequiresConfirmation() throws {
        let fixture = try makeFixture()
        try fixture.service.save(HydrationEntryDraft(type: .water, customName: nil, volumeMillilitres: 500, occurredAt: now, isCaloric: false), replacing: nil, goal: .default)
        XCTAssertTrue(fixture.fast.isActive)
        XCTAssertThrowsError(try fixture.service.save(HydrationEntryDraft(type: .custom, customName: "Juice", volumeMillilitres: 200, occurredAt: now, isCaloric: true), replacing: nil, goal: .default)) {
            XCTAssertEqual($0 as? HydrationEntrySaveError, .confirmationRequired)
        }
        XCTAssertTrue(fixture.fast.isActive)
        XCTAssertEqual(try fixture.container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).count, 1)
    }

    func testConfirmedCaloricDrinkAtomicallyEndsFastAndFailureRollsBack() throws {
        let fixture = try makeFixture()
        let draft = HydrationEntryDraft(type: .custom, customName: "Juice", volumeMillilitres: 200, occurredAt: now, isCaloric: true)
        try fixture.service.save(draft, replacing: nil, goal: .default, endingActiveFast: true)
        XCTAssertEqual(fixture.fast.endDate, now)

        let failed = try makeFixture(simulateFailure: true)
        XCTAssertThrowsError(try failed.service.save(draft, replacing: nil, goal: .default, endingActiveFast: true))
        XCTAssertTrue(failed.fast.isActive)
        XCTAssertTrue(try failed.container.mainContext.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
        XCTAssertFalse(failed.container.mainContext.hasChanges)
    }

    func testExactStartIsRejected() throws {
        let fixture = try makeFixture()
        let draft = HydrationEntryDraft(type: .custom, customName: "Juice", volumeMillilitres: 200, occurredAt: fixture.fast.startDate, isCaloric: true)
        XCTAssertThrowsError(try fixture.service.save(draft, replacing: nil, goal: .default, endingActiveFast: true)) {
            XCTAssertEqual($0 as? HydrationEntrySaveError, .eventAtActiveFastStart)
        }
    }

    private func makeFixture(simulateFailure: Bool = false) throws -> (container: ModelContainer, fast: FastRecord, service: HydrationEntryService) {
        let container = try PersistenceContainer.make(inMemory: true)
        let fast = FastRecord(startDate: now.addingTimeInterval(-3600), goalAtStart: .default)
        container.mainContext.insert(fast); try container.mainContext.save()
        return (container, fast, HydrationEntryService(repository: SwiftDataHydrationEntryRepository(modelContext: container.mainContext, simulateSaveFailure: simulateFailure), clock: FixedAppClock(now: now)))
    }
}
