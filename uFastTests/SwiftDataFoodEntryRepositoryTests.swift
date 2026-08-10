import SwiftData
@testable import uFast
import XCTest

@MainActor
final class SwiftDataFoodEntryRepositoryTests: XCTestCase {
    func testCreateUpdateAndDeleteRoundTripPreservesIdentity() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataFoodEntryRepository(modelContext: container.mainContext)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let original = FoodEntryDraft(description: "Breakfast", occurredAt: createdAt)

        let record = try repository.create(original, at: createdAt)
        let identifier = record.id
        let updatedAt = createdAt.addingTimeInterval(60)
        let changed = FoodEntryDraft(
            description: "Breakfast and fruit",
            occurredAt: createdAt.addingTimeInterval(-300),
            nutrition: FoodNutrition(energyKilocalories: 400, fibreGrams: 5)
        )
        try repository.update(record, with: changed, at: updatedAt)

        let fetched = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).first
        )
        XCTAssertEqual(fetched.id, identifier)
        XCTAssertEqual(fetched.foodDescription, "Breakfast and fruit")
        XCTAssertEqual(fetched.updatedAt, updatedAt)
        XCTAssertEqual(fetched.nutrition.energyKilocalories, 400)
        XCTAssertEqual(fetched.nutrition.fibreGrams, 5)
        XCTAssertNil(fetched.nutrition.proteinGrams)

        try repository.delete(fetched)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
    }

    func testCreateAndUpdateFailuresDoNotExposeUnpersistedState() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let goodRepository = SwiftDataFoodEntryRepository(modelContext: container.mainContext)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let original = FoodEntryDraft(description: "Lunch", occurredAt: now)
        let record = try goodRepository.create(original, at: now)
        let failingRepository = SwiftDataFoodEntryRepository(
            modelContext: container.mainContext,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(
            try failingRepository.create(
                FoodEntryDraft(description: "Phantom", occurredAt: now),
                at: now
            )
        )
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).count, 1)

        XCTAssertThrowsError(
            try failingRepository.update(
                record,
                with: FoodEntryDraft(description: "Changed", occurredAt: now),
                at: now.addingTimeInterval(60)
            )
        )
        XCTAssertEqual(record.foodDescription, "Lunch")
        XCTAssertEqual(record.updatedAt, now)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testDeleteFailureKeepsRecord() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let repository = SwiftDataFoodEntryRepository(modelContext: container.mainContext)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = try repository.create(
            FoodEntryDraft(description: "Dinner", occurredAt: now),
            at: now
        )
        let failingRepository = SwiftDataFoodEntryRepository(
            modelContext: container.mainContext,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(try failingRepository.delete(record))
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).count, 1)
        XCTAssertFalse(container.mainContext.hasChanges)
    }
}
