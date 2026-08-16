import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length type_body_length trailing_comma

@MainActor
final class Slice3PersistenceMigrationTests: XCTestCase {
    func testIndependentReleaseFixtureMigratesWithoutChangingAnyStoredMeaning() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-release-v1-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = ReleaseFixture(
            storeURL: directory.appending(path: "production.store")
        )
        try writeIndependentReleaseFixture(fixture)

        let migrated = try PersistenceContainer.make(storeURL: fixture.storeURL)
        let context = migrated.mainContext
        try assertSettingsAndFasts(in: context, fixture: fixture)
        try assertFoodHydrationAndUnknowns(in: context, fixture: fixture)
    }

    private func writeIndependentReleaseFixture(_ fixture: ReleaseFixture) throws {
        let legacySchema = Schema(ReleaseBaselineFixture.models)
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
        insertSettingsAndFasts(in: context, fixture: fixture)
        insertFoodHydrationAndUnknowns(in: context, fixture: fixture)
        try context.save()
    }

    private func insertSettingsAndFasts(
        in context: ModelContext,
        fixture: ReleaseFixture
    ) {
        insertSettings(in: context, fixture: fixture)
        insertFasts(in: context, fixture: fixture)
    }

    private func insertSettings(in context: ModelContext, fixture: ReleaseFixture) {
        context.insert(
            ReleaseBaselineFixture.AppSettingsRecord(
                id: fixture.settingsID,
                fastingGoalHours: 17,
                hasCompletedOnboarding: true,
                waterFavouriteMillilitres: 750,
                teaFavouriteMillilitres: 425,
                coffeeFavouriteMillilitres: 225
            )
        )
    }

    private func insertFasts(in context: ModelContext, fixture: ReleaseFixture) {
        context.insert(
            ReleaseBaselineFixture.FastRecord(
                id: fixture.activeID,
                startDate: fixture.createdAt,
                endDate: nil,
                goalHoursAtStart: 17,
                originRaw: "recorded",
                reviewStateRaw: "confirmed",
                wasAdjustedByUser: false,
                hasHistoricalGoal: true,
                startBoundaryKindRaw: nil,
                startBoundaryID: nil,
                endBoundaryKindRaw: nil,
                endBoundaryID: nil
            )
        )
        context.insert(
            ReleaseBaselineFixture.FastRecord(
                id: fixture.completedID,
                startDate: fixture.createdAt.addingTimeInterval(-70000),
                endDate: fixture.createdAt.addingTimeInterval(-10000),
                goalHoursAtStart: 16,
                originRaw: "recorded",
                reviewStateRaw: "confirmed",
                wasAdjustedByUser: false,
                hasHistoricalGoal: true,
                startBoundaryKindRaw: nil,
                startBoundaryID: nil,
                endBoundaryKindRaw: nil,
                endBoundaryID: nil
            )
        )
        context.insert(
            ReleaseBaselineFixture.FastRecord(
                id: fixture.reconstructedID,
                startDate: fixture.createdAt.addingTimeInterval(-140_000),
                endDate: fixture.createdAt.addingTimeInterval(-90000),
                goalHoursAtStart: 12,
                originRaw: "reconstructed",
                reviewStateRaw: "confirmed",
                wasAdjustedByUser: true,
                hasHistoricalGoal: false,
                startBoundaryKindRaw: "food",
                startBoundaryID: fixture.foodID,
                endBoundaryKindRaw: "hydration",
                endBoundaryID: fixture.hydrationID
            )
        )
    }

    private func insertFoodHydrationAndUnknowns(
        in context: ModelContext,
        fixture: ReleaseFixture
    ) {
        context.insert(
            ReleaseBaselineFixture.FoodEntryRecord(
                id: fixture.foodID,
                foodDescription: "Legacy supper",
                occurredAt: fixture.occurredAt,
                isCaloric: true,
                energyKilocalories: 640,
                proteinGrams: 31,
                carbohydrateGrams: 72,
                fatGrams: 22,
                fibreGrams: 8,
                sugarGrams: 6,
                saltGrams: 1.4,
                createdAt: fixture.createdAt,
                updatedAt: fixture.updatedAt
            )
        )
        context.insert(
            ReleaseBaselineFixture.HydrationEntryRecord(
                id: fixture.hydrationID,
                drinkTypeRaw: "custom",
                customName: "Legacy broth",
                volumeMillilitres: 375,
                occurredAt: fixture.occurredAt,
                isCaloric: true,
                createdAt: fixture.createdAt,
                updatedAt: fixture.updatedAt
            )
        )
        context.insert(
            ReleaseBaselineFixture.UnknownPeriodRecord(
                id: fixture.unknownID,
                startDate: fixture.createdAt.addingTimeInterval(-80000),
                endDate: fixture.createdAt.addingTimeInterval(-75000),
                startBoundaryKindRaw: "food",
                startBoundaryID: fixture.foodID,
                endBoundaryKindRaw: "hydration",
                endBoundaryID: fixture.hydrationID,
                reasonRaw: "userChoice",
                createdAt: fixture.createdAt,
                updatedAt: fixture.updatedAt
            )
        )
    }

    private func assertSettingsAndFasts(
        in context: ModelContext,
        fixture: ReleaseFixture
    ) throws {
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettingsRecord>()).first)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 1)
        XCTAssertEqual(settings.id, fixture.settingsID)
        XCTAssertEqual(settings.fastingGoalHours, 17)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.waterFavouriteMillilitres, 750)
        XCTAssertEqual(settings.teaFavouriteMillilitres, 425)
        XCTAssertEqual(settings.coffeeFavouriteMillilitres, 225)
        XCTAssertEqual(settings.automaticLiveActivityPreference, .notAsked)
        XCTAssertFalse(settings.inferredFastDetectionEnabled)

        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(fasts.count, 3)
        let active = try XCTUnwrap(fasts.first { $0.id == fixture.activeID })
        XCTAssertEqual(active.startDate, fixture.createdAt)
        XCTAssertNil(active.endDate)
        XCTAssertEqual(active.goalHoursAtStart, 17)
        XCTAssertEqual(active.originRaw, "recorded")
        XCTAssertEqual(active.reviewStateRaw, "confirmed")
        XCTAssertFalse(active.wasAdjustedByUser)
        XCTAssertTrue(active.hasHistoricalGoal)
        XCTAssertNil(active.startBoundaryKindRaw)
        XCTAssertNil(active.startBoundaryID)
        XCTAssertNil(active.endBoundaryKindRaw)
        XCTAssertNil(active.endBoundaryID)

        let completed = try XCTUnwrap(fasts.first { $0.id == fixture.completedID })
        XCTAssertEqual(completed.startDate, fixture.createdAt.addingTimeInterval(-70000))
        XCTAssertEqual(completed.endDate, fixture.createdAt.addingTimeInterval(-10000))
        XCTAssertEqual(completed.goalHoursAtStart, 16)
        XCTAssertEqual(completed.originRaw, "recorded")
        XCTAssertEqual(completed.reviewStateRaw, "confirmed")
        XCTAssertFalse(completed.wasAdjustedByUser)
        XCTAssertTrue(completed.hasHistoricalGoal)

        let reconstructed = try XCTUnwrap(fasts.first { $0.id == fixture.reconstructedID })
        XCTAssertEqual(reconstructed.startDate, fixture.createdAt.addingTimeInterval(-140_000))
        XCTAssertEqual(reconstructed.endDate, fixture.createdAt.addingTimeInterval(-90000))
        XCTAssertEqual(reconstructed.goalHoursAtStart, 12)
        XCTAssertEqual(reconstructed.originRaw, "reconstructed")
        XCTAssertEqual(reconstructed.reviewStateRaw, "confirmed")
        XCTAssertTrue(reconstructed.wasAdjustedByUser)
        XCTAssertFalse(reconstructed.hasHistoricalGoal)
        XCTAssertEqual(reconstructed.startBoundaryKindRaw, "food")
        XCTAssertEqual(reconstructed.startBoundaryID, fixture.foodID)
        XCTAssertEqual(reconstructed.endBoundaryKindRaw, "hydration")
        XCTAssertEqual(reconstructed.endBoundaryID, fixture.hydrationID)
    }

    private func assertFoodHydrationAndUnknowns(
        in context: ModelContext,
        fixture: ReleaseFixture
    ) throws {
        try assertFood(in: context, fixture: fixture)
        try assertHydration(in: context, fixture: fixture)
        try assertUnknown(in: context, fixture: fixture)
    }

    private func assertFood(in context: ModelContext, fixture: ReleaseFixture) throws {
        let foods = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        XCTAssertEqual(foods.count, 1)
        let food = try XCTUnwrap(foods.first)
        XCTAssertEqual(food.id, fixture.foodID)
        XCTAssertEqual(food.foodDescription, "Legacy supper")
        XCTAssertEqual(food.occurredAt, fixture.occurredAt)
        XCTAssertTrue(food.isCaloric)
        XCTAssertEqual(food.energyKilocalories, 640)
        XCTAssertEqual(food.proteinGrams, 31)
        XCTAssertEqual(food.carbohydrateGrams, 72)
        XCTAssertEqual(food.fatGrams, 22)
        XCTAssertEqual(food.fibreGrams, 8)
        XCTAssertEqual(food.sugarGrams, 6)
        XCTAssertEqual(food.saltGrams, 1.4)
        XCTAssertEqual(food.createdAt, fixture.createdAt)
        XCTAssertEqual(food.updatedAt, fixture.updatedAt)
    }

    private func assertHydration(in context: ModelContext, fixture: ReleaseFixture) throws {
        let hydrations = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        XCTAssertEqual(hydrations.count, 1)
        let hydration = try XCTUnwrap(hydrations.first)
        XCTAssertEqual(hydration.id, fixture.hydrationID)
        XCTAssertEqual(hydration.drinkTypeRaw, "custom")
        XCTAssertEqual(hydration.customName, "Legacy broth")
        XCTAssertEqual(hydration.volumeMillilitres, 375)
        XCTAssertEqual(hydration.occurredAt, fixture.occurredAt)
        XCTAssertTrue(hydration.isCaloric)
        XCTAssertEqual(hydration.createdAt, fixture.createdAt)
        XCTAssertEqual(hydration.updatedAt, fixture.updatedAt)
    }

    private func assertUnknown(in context: ModelContext, fixture: ReleaseFixture) throws {
        let unknowns = try context.fetch(FetchDescriptor<UnknownPeriodRecord>())
        XCTAssertEqual(unknowns.count, 1)
        let unknown = try XCTUnwrap(unknowns.first)
        XCTAssertEqual(unknown.id, fixture.unknownID)
        XCTAssertEqual(unknown.startDate, fixture.createdAt.addingTimeInterval(-80000))
        XCTAssertEqual(unknown.endDate, fixture.createdAt.addingTimeInterval(-75000))
        XCTAssertEqual(unknown.startBoundaryKindRaw, "food")
        XCTAssertEqual(unknown.startBoundaryID, fixture.foodID)
        XCTAssertEqual(unknown.endBoundaryKindRaw, "hydration")
        XCTAssertEqual(unknown.endBoundaryID, fixture.hydrationID)
        XCTAssertEqual(unknown.reasonRaw, "userChoice")
        XCTAssertEqual(unknown.reason, .userChoice)
        XCTAssertEqual(unknown.boundaryPair, fixture.boundaries)
        XCTAssertEqual(unknown.createdAt, fixture.createdAt)
        XCTAssertEqual(unknown.updatedAt, fixture.updatedAt)

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
            context.insert(
                HydrationFavouriteRecord(
                    id: UUID(),
                    name: "Sparkling water",
                    volumeMillilitres: 330,
                    isCaloric: false,
                    createdAt: Date(timeIntervalSince1970: 1000)
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
        let favourites = try reopened.mainContext.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        XCTAssertEqual(favourites.count, 1)
        XCTAssertEqual(favourites.first?.name, "Sparkling water")
        XCTAssertEqual(favourites.first?.volumeMillilitres, 330)
    }
}

private struct ReleaseFixture {
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

/// An independent copy of the d63dc026 persisted contract. These classes are
/// deliberately not production model aliases: the fixture must continue to
/// represent the release store even if V1/V2 or current app models change.
private enum ReleaseBaselineFixture {
    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        UnknownPeriodRecord.self,
    ]

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300

        init(
            id: UUID,
            fastingGoalHours: Int,
            hasCompletedOnboarding: Bool,
            waterFavouriteMillilitres: Int,
            teaFavouriteMillilitres: Int,
            coffeeFavouriteMillilitres: Int
        ) {
            self.id = id
            self.fastingGoalHours = fastingGoalHours
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.waterFavouriteMillilitres = waterFavouriteMillilitres
            self.teaFavouriteMillilitres = teaFavouriteMillilitres
            self.coffeeFavouriteMillilitres = coffeeFavouriteMillilitres
        }
    }

    @Model
    final class FastRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date?
        private(set) var goalHoursAtStart: Int = 12
        private(set) var originRaw: String = "recorded"
        private(set) var reviewStateRaw: String = "confirmed"
        private(set) var wasAdjustedByUser: Bool = false
        private(set) var hasHistoricalGoal: Bool = true
        private(set) var startBoundaryKindRaw: String?
        private(set) var startBoundaryID: UUID?
        private(set) var endBoundaryKindRaw: String?
        private(set) var endBoundaryID: UUID?

        init(
            id: UUID,
            startDate: Date,
            endDate: Date?,
            goalHoursAtStart: Int,
            originRaw: String,
            reviewStateRaw: String,
            wasAdjustedByUser: Bool,
            hasHistoricalGoal: Bool,
            startBoundaryKindRaw: String?,
            startBoundaryID: UUID?,
            endBoundaryKindRaw: String?,
            endBoundaryID: UUID?
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.goalHoursAtStart = goalHoursAtStart
            self.originRaw = originRaw
            self.reviewStateRaw = reviewStateRaw
            self.wasAdjustedByUser = wasAdjustedByUser
            self.hasHistoricalGoal = hasHistoricalGoal
            self.startBoundaryKindRaw = startBoundaryKindRaw
            self.startBoundaryID = startBoundaryID
            self.endBoundaryKindRaw = endBoundaryKindRaw
            self.endBoundaryID = endBoundaryID
        }
    }

    @Model
    final class FoodEntryRecord {
        var id: UUID = UUID()
        private(set) var foodDescription: String = ""
        private(set) var occurredAt: Date = Date.now
        private(set) var isCaloric: Bool = true
        private(set) var energyKilocalories: Double?
        private(set) var proteinGrams: Double?
        private(set) var carbohydrateGrams: Double?
        private(set) var fatGrams: Double?
        private(set) var fibreGrams: Double?
        private(set) var sugarGrams: Double?
        private(set) var saltGrams: Double?
        private(set) var createdAt: Date = Date.now
        private(set) var updatedAt: Date = Date.now

        init(
            id: UUID,
            foodDescription: String,
            occurredAt: Date,
            isCaloric: Bool,
            energyKilocalories: Double?,
            proteinGrams: Double?,
            carbohydrateGrams: Double?,
            fatGrams: Double?,
            fibreGrams: Double?,
            sugarGrams: Double?,
            saltGrams: Double?,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.foodDescription = foodDescription
            self.occurredAt = occurredAt
            self.isCaloric = isCaloric
            self.energyKilocalories = energyKilocalories
            self.proteinGrams = proteinGrams
            self.carbohydrateGrams = carbohydrateGrams
            self.fatGrams = fatGrams
            self.fibreGrams = fibreGrams
            self.sugarGrams = sugarGrams
            self.saltGrams = saltGrams
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class HydrationEntryRecord {
        var id: UUID = UUID()
        private(set) var drinkTypeRaw: String = "water"
        private(set) var customName: String?
        private(set) var volumeMillilitres: Int = 500
        private(set) var occurredAt: Date = Date.now
        private(set) var isCaloric: Bool = false
        private(set) var createdAt: Date = Date.now
        private(set) var updatedAt: Date = Date.now

        init(
            id: UUID,
            drinkTypeRaw: String,
            customName: String?,
            volumeMillilitres: Int,
            occurredAt: Date,
            isCaloric: Bool,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.drinkTypeRaw = drinkTypeRaw
            self.customName = customName
            self.volumeMillilitres = volumeMillilitres
            self.occurredAt = occurredAt
            self.isCaloric = isCaloric
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    final class UnknownPeriodRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date = Date.now
        private(set) var startBoundaryKindRaw: String = "food"
        private(set) var startBoundaryID: UUID = UUID()
        private(set) var endBoundaryKindRaw: String = "food"
        private(set) var endBoundaryID: UUID = UUID()
        private(set) var reasonRaw: String = "insufficientEvidence"
        private(set) var createdAt: Date = Date.now
        private(set) var updatedAt: Date = Date.now

        init(
            id: UUID,
            startDate: Date,
            endDate: Date,
            startBoundaryKindRaw: String,
            startBoundaryID: UUID,
            endBoundaryKindRaw: String,
            endBoundaryID: UUID,
            reasonRaw: String,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.startDate = startDate
            self.endDate = endDate
            self.startBoundaryKindRaw = startBoundaryKindRaw
            self.startBoundaryID = startBoundaryID
            self.endBoundaryKindRaw = endBoundaryKindRaw
            self.endBoundaryID = endBoundaryID
            self.reasonRaw = reasonRaw
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}
