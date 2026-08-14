import SwiftData
@testable import uFast
import XCTest

@MainActor
final class Slice3PersistenceMigrationTests: XCTestCase {
    func testPreVersionedProductionStoreOpensWithoutChangingAnyStoredMeaning() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-pre-versioned-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = PreVersionedFixture(
            storeURL: directory.appending(path: "production.store")
        )
        try writePreVersionedFixture(fixture)

        let migrated = try PersistenceContainer.make(storeURL: fixture.storeURL)
        let context = migrated.mainContext
        try assertSettingsAndFasts(in: context, fixture: fixture)
        try assertFoodHydrationAndUnknowns(in: context, fixture: fixture)
    }

    private func writePreVersionedFixture(_ fixture: PreVersionedFixture) throws {
        let legacySchema = Schema(UFastSchemaV1.models)
        let configuration = ModelConfiguration(
            schema: legacySchema,
            url: fixture.storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: legacySchema,
            configurations: [configuration]
        )
        let context = container.mainContext
        try insertSettingsAndFasts(in: context, fixture: fixture)
        insertFoodHydrationAndUnknowns(in: context, fixture: fixture)
        try context.save()
    }

    private func insertSettingsAndFasts(
        in context: ModelContext,
        fixture: PreVersionedFixture
    ) throws {
        try context.insert(
            AppSettingsRecord(
                id: fixture.settingsID,
                fastingGoal: XCTUnwrap(FastingGoal(hours: 17)),
                hasCompletedOnboarding: true,
                waterFavouriteMillilitres: 750,
                teaFavouriteMillilitres: 425,
                coffeeFavouriteMillilitres: 225,
                automaticLiveActivityPreference: .enabled
            )
        )
        try context.insert(
            FastRecord(
                id: fixture.activeID,
                startDate: fixture.createdAt,
                goalAtStart: XCTUnwrap(FastingGoal(hours: 17))
            )
        )
        try context.insert(
            FastRecord(
                id: fixture.completedID,
                startDate: fixture.createdAt.addingTimeInterval(-70000),
                endDate: fixture.createdAt.addingTimeInterval(-10000),
                goalAtStart: XCTUnwrap(FastingGoal(hours: 16))
            )
        )
        context.insert(
            FastRecord(
                id: fixture.reconstructedID,
                reconstructedStart: fixture.createdAt.addingTimeInterval(-140_000),
                endDate: fixture.createdAt.addingTimeInterval(-90000),
                boundaries: fixture.boundaries,
                adjustedByUser: true
            )
        )
    }

    private func insertFoodHydrationAndUnknowns(
        in context: ModelContext,
        fixture: PreVersionedFixture
    ) {
        let food = FoodEntryRecord(
            id: fixture.foodID,
            draft: FoodEntryDraft(
                description: "Legacy supper",
                occurredAt: fixture.occurredAt,
                nutrition: FoodNutrition(
                    energyKilocalories: 640,
                    proteinGrams: 31,
                    carbohydrateGrams: 72,
                    fatGrams: 22,
                    fibreGrams: 8,
                    sugarGrams: 6,
                    saltGrams: 1.4
                )
            ),
            createdAt: fixture.createdAt
        )
        food.update(from: food.draft, at: fixture.updatedAt)
        context.insert(food)
        let hydration = HydrationEntryRecord(
            id: fixture.hydrationID,
            type: .custom,
            customName: "Legacy broth",
            volumeMillilitres: 375,
            occurredAt: fixture.occurredAt,
            isCaloric: true,
            createdAt: fixture.createdAt
        )
        hydration.update(from: hydration.draft, at: fixture.updatedAt)
        context.insert(hydration)
        context.insert(
            UnknownPeriodRecord(
                id: fixture.unknownID,
                startDate: fixture.createdAt.addingTimeInterval(-80000),
                endDate: fixture.createdAt.addingTimeInterval(-75000),
                boundaries: fixture.boundaries,
                reason: .userChoice,
                createdAt: fixture.createdAt
            )
        )
    }

    private func assertSettingsAndFasts(
        in context: ModelContext,
        fixture: PreVersionedFixture
    ) throws {
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettingsRecord>()).first)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
        XCTAssertEqual(settings.id, fixture.settingsID)
        XCTAssertEqual(settings.fastingGoalHours, 17)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.waterFavouriteMillilitres, 750)
        XCTAssertEqual(settings.teaFavouriteMillilitres, 425)
        XCTAssertEqual(settings.coffeeFavouriteMillilitres, 225)
        XCTAssertEqual(settings.automaticLiveActivityPreference, .enabled)

        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(fasts.count, 3)
        let active = try XCTUnwrap(fasts.first { $0.id == fixture.activeID })
        XCTAssertEqual(active.startDate, fixture.createdAt)
        XCTAssertNil(active.endDate)
        XCTAssertEqual(active.historicalGoal?.hours, 17)
        let completed = try XCTUnwrap(fasts.first { $0.id == fixture.completedID })
        XCTAssertEqual(completed.endDate, fixture.createdAt.addingTimeInterval(-10000))
        XCTAssertEqual(completed.historicalGoal?.hours, 16)
        let reconstructed = try XCTUnwrap(fasts.first { $0.id == fixture.reconstructedID })
        XCTAssertEqual(reconstructed.origin, .reconstructed)
        XCTAssertEqual(reconstructed.boundaryPair, fixture.boundaries)
        XCTAssertTrue(reconstructed.wasAdjustedByUser)
    }

    private func assertFoodHydrationAndUnknowns(
        in context: ModelContext,
        fixture: PreVersionedFixture
    ) throws {
        let foods = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        XCTAssertEqual(foods.count, 1)
        let food = try XCTUnwrap(foods.first)
        XCTAssertEqual(food.id, fixture.foodID)
        XCTAssertEqual(food.draft.description, "Legacy supper")
        XCTAssertEqual(food.occurredAt, fixture.occurredAt)
        XCTAssertEqual(food.createdAt, fixture.createdAt)
        XCTAssertEqual(food.updatedAt, fixture.updatedAt)
        XCTAssertEqual(food.nutrition.energyKilocalories, 640)
        XCTAssertEqual(food.nutrition.proteinGrams, 31)
        XCTAssertEqual(food.nutrition.carbohydrateGrams, 72)
        XCTAssertEqual(food.nutrition.fatGrams, 22)
        XCTAssertEqual(food.nutrition.fibreGrams, 8)
        XCTAssertEqual(food.nutrition.sugarGrams, 6)
        XCTAssertEqual(food.nutrition.saltGrams, 1.4)

        let hydrations = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        XCTAssertEqual(hydrations.count, 1)
        let hydration = try XCTUnwrap(hydrations.first)
        XCTAssertEqual(hydration.id, fixture.hydrationID)
        XCTAssertEqual(hydration.drinkType, .custom)
        XCTAssertEqual(hydration.customName, "Legacy broth")
        XCTAssertEqual(hydration.volumeMillilitres, 375)
        XCTAssertEqual(hydration.occurredAt, fixture.occurredAt)
        XCTAssertTrue(hydration.isCaloric)
        XCTAssertEqual(hydration.createdAt, fixture.createdAt)
        XCTAssertEqual(hydration.updatedAt, fixture.updatedAt)

        let unknowns = try context.fetch(FetchDescriptor<UnknownPeriodRecord>())
        XCTAssertEqual(unknowns.count, 1)
        let unknown = try XCTUnwrap(unknowns.first)
        XCTAssertEqual(unknown.id, fixture.unknownID)
        XCTAssertEqual(unknown.reason, .userChoice)
        XCTAssertEqual(unknown.boundaryPair, fixture.boundaries)
        XCTAssertEqual(unknown.createdAt, fixture.createdAt)

        XCTAssertTrue(
            try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).isEmpty
        )
    }

    func testRecordedAndReconstructedHistorySurviveDiskReopenWithAdditiveDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-slice3-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "history.store")
        let recordedID = UUID()
        let reconstructedID = UUID()
        let startReference = CaloricBoundaryReference(kind: .food, id: UUID())
        let endReference = CaloricBoundaryReference(kind: .hydration, id: UUID())

        do {
            let container = try PersistenceContainer.make(storeURL: storeURL)
            let context = container.mainContext
            try context.insert(
                FastRecord(
                    id: recordedID,
                    startDate: Date(timeIntervalSince1970: 1000),
                    endDate: Date(timeIntervalSince1970: 50000),
                    goalAtStart: XCTUnwrap(FastingGoal(hours: 16))
                )
            )
            context.insert(
                FastRecord(
                    id: reconstructedID,
                    reconstructedStart: Date(timeIntervalSince1970: 60000),
                    endDate: Date(timeIntervalSince1970: 110_000),
                    boundaries: .init(start: startReference, end: endReference),
                    adjustedByUser: true
                )
            )
            try context.save()
        }

        let reopened = try PersistenceContainer.make(storeURL: storeURL)
        let fasts = try reopened.mainContext.fetch(FetchDescriptor<FastRecord>())
        let recorded = try XCTUnwrap(fasts.first { $0.id == recordedID })
        XCTAssertEqual(recorded.origin, .recorded)
        XCTAssertEqual(recorded.reviewState, .confirmed)
        XCTAssertEqual(recorded.capturedHistoricalGoal?.hours, 16)
        XCTAssertNil(recorded.boundaryPair)

        let reconstructed = try XCTUnwrap(fasts.first { $0.id == reconstructedID })
        XCTAssertEqual(reconstructed.origin, .reconstructed)
        XCTAssertTrue(reconstructed.wasAdjustedByUser)
        XCTAssertNil(reconstructed.capturedHistoricalGoal)
        XCTAssertEqual(
            reconstructed.boundaryPair,
            .init(start: startReference, end: endReference)
        )
    }
}

private struct PreVersionedFixture {
    let storeURL: URL
    let settingsID = UUID()
    let activeID = UUID()
    let completedID = UUID()
    let reconstructedID = UUID()
    let foodID = UUID()
    let hydrationID = UUID()
    let unknownID = UUID()
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    var occurredAt: Date {
        createdAt.addingTimeInterval(120)
    }

    var updatedAt: Date {
        occurredAt.addingTimeInterval(60)
    }

    var boundaries: ReconstructionBoundaryPair {
        ReconstructionBoundaryPair(
            start: CaloricBoundaryReference(kind: .food, id: foodID),
            end: CaloricBoundaryReference(kind: .hydration, id: hydrationID)
        )
    }
}
