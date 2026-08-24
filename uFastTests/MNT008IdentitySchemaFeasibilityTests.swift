import Foundation
import SwiftData
@testable import uFast
import XCTest

// This file is deliberately test-target-only.  The nested V4 fixture and V5
// schema are independent of the production declarations so that a migration
// experiment cannot change the V1-V4 model checksums or production target.
// swiftlint:disable type_body_length file_length function_body_length line_length trailing_comma

@MainActor
final class MNT008IdentitySchemaFeasibilityTests: XCTestCase {
    func testV5SchemaExposesPerEntityIdentityAndCandidateIndexes() {
        let schema = Schema(versionedSchema: MNT008V5Schema.self)
        XCTAssertEqual(schema.version, Schema.Version(5, 0, 0))
        XCTAssertEqual(schema.entities.count, 6)

        let expectedEntities = [
            "AppSettingsRecord",
            "FastRecord",
            "FoodEntryRecord",
            "HydrationEntryRecord",
            "HydrationFavouriteRecord",
            "UnknownPeriodRecord",
        ]
        XCTAssertEqual(Set(schema.entities.map(\.name)), Set(expectedEntities))

        for entity in schema.entities {
            XCTAssertEqual(entity.uniquenessConstraints, [["id"]], entity.name)
        }

        XCTAssertEqual(schema.entitiesByName["FoodEntryRecord"]?.indices, [["binary", "occurredAt"]])
        XCTAssertEqual(
            schema.entitiesByName["HydrationEntryRecord"]?.indices,
            [["binary", "occurredAt"], ["binary", "isCaloric", "occurredAt"]]
        )
        XCTAssertEqual(
            schema.entitiesByName["FastRecord"]?.indices,
            [["binary", "startDate"], ["binary", "endDate"]]
        )
        XCTAssertEqual(
            schema.entitiesByName["HydrationFavouriteRecord"]?.indices,
            [["binary", "createdAt", "creationOrder", "id"]]
        )
        XCTAssertEqual(schema.entitiesByName["AppSettingsRecord"]?.indices, [])
        XCTAssertEqual(schema.entitiesByName["UnknownPeriodRecord"]?.indices, [])
    }

    func testIndependentCleanV4FixtureMigratesAndPreservesEveryLogicalValue() throws {
        let directory = try temporaryDirectory(named: "clean-v4")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "clean.store")
        let fixture = MNT008FixtureIDs()
        try MNT008V4Fixture.writeClean(to: storeURL, ids: fixture)

        let before = try MNT008V4Fixture.readSnapshot(from: storeURL)
        XCTAssertEqual(before.settings.count, 1)
        XCTAssertEqual(before.fasts.count, 3)
        XCTAssertEqual(before.foods.count, 2)
        XCTAssertEqual(before.hydration.count, 1)
        XCTAssertEqual(before.favourites.count, 1)
        XCTAssertEqual(before.unknownPeriods.count, 1)
        let migrated = try makeV5Container(storeURL: storeURL, plan: MNT008V5LightweightPlan.self)
        let after = try MNT008V5Snapshot(context: migrated.mainContext)

        XCTAssertEqual(after.settings.count, 1)
        XCTAssertEqual(after.fasts.count, 3)
        XCTAssertEqual(after.foods.count, 2)
        XCTAssertEqual(after.hydration.count, 1)
        XCTAssertEqual(after.favourites.count, 1)
        XCTAssertEqual(after.unknownPeriods.count, 1)
        XCTAssertEqual(after, before.v5Equivalent)
        print("MNT-008F clean migration: logical values and IDs preserved; source=(before)")
    }

    func testLightweightAndCustomMigrationReportDuplicatePreflightAndV4Reopenability() throws {
        let lightweight = try duplicateMigrationEvidence(plan: MNT008V5LightweightPlan.self)
        let custom = try duplicateMigrationEvidence(plan: MNT008V5CustomPreflightPlan.self)

        XCTAssertEqual(lightweight.duplicateFoodCount, 3)
        XCTAssertEqual(custom.duplicateFoodCount, 3)
        XCTAssertTrue(lightweight.originalV4Reopened)
        XCTAssertTrue(custom.originalV4Reopened)
        XCTAssertTrue(lightweight.protectedV4Reopened)
        XCTAssertTrue(custom.protectedV4Reopened)
        XCTAssertFalse(lightweight.errorChain.isEmpty)
        XCTAssertFalse(custom.errorChain.isEmpty)
        XCTAssertTrue(custom.preflightError.contains("duplicateIDs"), custom.preflightError)

        print("MNT-008F lightweight duplicate migration: \(lightweight)")
        print("MNT-008F custom duplicate migration: \(custom)")
    }

    func testFreshV5DuplicateSaveObservationAndCrossEntityUUIDReuse() throws {
        let directory = try temporaryDirectory(named: "fresh-v5")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "fresh.store")
        let container = try makeV5Container(storeURL: storeURL)
        let context = container.mainContext
        let duplicateID = UUID()
        let first = MNT008V5Schema.FoodEntryRecord(
            id: duplicateID,
            foodDescription: "first",
            occurredAt: Date(timeIntervalSince1970: 100),
            isCaloric: true,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        context.insert(first)
        try context.save()

        let duplicate = MNT008V5Schema.FoodEntryRecord(
            id: duplicateID,
            foodDescription: "must not replace first",
            occurredAt: Date(timeIntervalSince1970: 200),
            isCaloric: false,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        context.insert(duplicate)
        let existingError = captureSaveError(context: context)
        context.rollback()
        let existingRows = try context.fetch(FetchDescriptor<MNT008V5Schema.FoodEntryRecord>())
        XCTAssertEqual(existingRows.count, 1)
        XCTAssertEqual(existingRows.map(\.id), [duplicateID])
        XCTAssertEqual(existingRows.map(\.foodDescription), ["must not replace first"])
        XCTAssertFalse(context.hasChanges)

        let transactionContext = ModelContext(container)
        let transactionDuplicateID = UUID()
        transactionContext.insert(
            MNT008V5Schema.FoodEntryRecord(
                id: transactionDuplicateID,
                foodDescription: "transaction one",
                occurredAt: Date(timeIntervalSince1970: 300),
                isCaloric: true,
                createdAt: Date(timeIntervalSince1970: 300),
                updatedAt: Date(timeIntervalSince1970: 300)
            )
        )
        transactionContext.insert(
            MNT008V5Schema.FoodEntryRecord(
                id: transactionDuplicateID,
                foodDescription: "transaction duplicate",
                occurredAt: Date(timeIntervalSince1970: 400),
                isCaloric: true,
                createdAt: Date(timeIntervalSince1970: 400),
                updatedAt: Date(timeIntervalSince1970: 400)
            )
        )
        let transactionError = captureSaveError(context: transactionContext)
        transactionContext.rollback()
        let transactionRows = try transactionContext.fetch(FetchDescriptor<MNT008V5Schema.FoodEntryRecord>())
        let transactionDuplicateRows = transactionRows.filter { $0.id == transactionDuplicateID }
        XCTAssertEqual(transactionError, "unexpected success")
        XCTAssertEqual(transactionRows.count, 2)
        XCTAssertEqual(transactionDuplicateRows.count, 1)
        XCTAssertFalse(transactionContext.hasChanges)

        let crossEntityContext = ModelContext(container)
        crossEntityContext.insert(
            MNT008V5Schema.HydrationEntryRecord(
                id: duplicateID,
                drinkTypeRaw: "water",
                customName: nil,
                volumeMillilitres: 500,
                occurredAt: Date(timeIntervalSince1970: 500),
                isCaloric: false,
                createdAt: Date(timeIntervalSince1970: 500),
                updatedAt: Date(timeIntervalSince1970: 500)
            )
        )
        try crossEntityContext.save()
        XCTAssertEqual(
            try crossEntityContext.fetchCount(FetchDescriptor<MNT008V5Schema.FoodEntryRecord>()),
            2
        )
        XCTAssertEqual(
            try crossEntityContext.fetchCount(FetchDescriptor<MNT008V5Schema.HydrationEntryRecord>()),
            1
        )

        XCTAssertEqual(existingError, "unexpected success")
        XCTAssertEqual(transactionError, "unexpected success")
        print(
            "MNT-008F fresh duplicate against existing observed merge/upsert: " +
                "result=\(existingError), rowsAfterRollback=\(existingRows.count), " +
                "descriptions=\(existingRows.map(\.foodDescription))"
        )
        print(
            "MNT-008F fresh duplicate in one transaction observed persisted duplicates: " +
                "result=\(transactionError), newUUID=\(transactionDuplicateID), " +
                "rowsAfterRollback=\(transactionRows.count), sameUUIDRows=\(transactionDuplicateRows.count)"
        )
        print("MNT-008F cross-entity same UUID: succeeded")
    }

    func testSettingsAuthorityRemainsSeparateFromPerEntityIdentity() throws {
        let schema = Schema(versionedSchema: MNT008V5Schema.self)
        let settings = try XCTUnwrap(schema.entitiesByName["AppSettingsRecord"])
        XCTAssertEqual(settings.uniquenessConstraints, [["id"]])
        XCTAssertEqual(settings.indices, [])

        let container = try makeV5Container(inMemory: true, plan: MNT008V5LightweightPlan.self)
        let context = container.mainContext
        let first = MNT008V5Schema.AppSettingsRecord(id: UUID(), fastingGoalHours: 12)
        let second = MNT008V5Schema.AppSettingsRecord(id: UUID(), fastingGoalHours: 16)
        context.insert(first)
        context.insert(second)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MNT008V5Schema.AppSettingsRecord>()), 2)
        print("MNT-008F settings authority remains application-level zero/one/many; no sentinel/global UUID registry")
    }

    func testRepresentativeIndexedQueriesReturnExpectedRows() throws {
        let container = try makeV5Container(inMemory: true, plan: MNT008V5LightweightPlan.self)
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 10000)
        for index in 0 ..< 120 {
            let date = base.addingTimeInterval(TimeInterval(index * 60))
            context.insert(
                MNT008V5Schema.FoodEntryRecord(
                    id: UUID(),
                    foodDescription: "food \(index)",
                    occurredAt: date,
                    isCaloric: index.isMultiple(of: 2),
                    createdAt: date,
                    updatedAt: date
                )
            )
            context.insert(
                MNT008V5Schema.HydrationEntryRecord(
                    id: UUID(),
                    drinkTypeRaw: "water",
                    customName: nil,
                    volumeMillilitres: 500,
                    occurredAt: date,
                    isCaloric: index.isMultiple(of: 3),
                    createdAt: date,
                    updatedAt: date
                )
            )
            context.insert(
                MNT008V5Schema.FastRecord(
                    id: UUID(),
                    startDate: date,
                    endDate: index.isMultiple(of: 2) ? date.addingTimeInterval(3600) : nil
                )
            )
            context.insert(
                MNT008V5Schema.HydrationFavouriteRecord(
                    id: UUID(),
                    name: "favourite \(index)",
                    volumeMillilitres: 250,
                    isCaloric: false,
                    createdAt: date,
                    updatedAt: date,
                    creationOrder: Int64(index)
                )
            )
        }
        try context.save()

        let lowerDate = base
        let upperDate = base.addingTimeInterval(TimeInterval(120 * 60))
        let foodDescriptor = FetchDescriptor<MNT008V5Schema.FoodEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lowerDate && $0.occurredAt < upperDate },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        let hydrationDescriptor = FetchDescriptor<MNT008V5Schema.HydrationEntryRecord>(
            predicate: #Predicate { $0.occurredAt >= lowerDate && $0.occurredAt < upperDate },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        let caloricHydrationDescriptor = FetchDescriptor<MNT008V5Schema.HydrationEntryRecord>(
            predicate: #Predicate {
                $0.isCaloric && $0.occurredAt >= lowerDate && $0.occurredAt < upperDate
            },
            sortBy: [SortDescriptor<MNT008V5Schema.HydrationEntryRecord>(\.occurredAt)]
        )
        let fastStartDescriptor = FetchDescriptor<MNT008V5Schema.FastRecord>(
            predicate: #Predicate { $0.startDate >= lowerDate && $0.startDate < upperDate },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let fastEndDescriptor = FetchDescriptor<MNT008V5Schema.FastRecord>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.endDate)]
        )
        let favouriteDescriptor = FetchDescriptor<MNT008V5Schema.HydrationFavouriteRecord>(
            predicate: #Predicate { $0.createdAt >= lowerDate && $0.createdAt < upperDate },
            sortBy: [
                SortDescriptor<MNT008V5Schema.HydrationFavouriteRecord>(\.createdAt),
                SortDescriptor<MNT008V5Schema.HydrationFavouriteRecord>(\.creationOrder),
                SortDescriptor<MNT008V5Schema.HydrationFavouriteRecord>(\.id),
            ]
        )

        let food = try context.fetch(foodDescriptor)
        let hydration = try context.fetch(hydrationDescriptor)
        let caloricHydration = try context.fetch(caloricHydrationDescriptor)
        let fastStart = try context.fetch(fastStartDescriptor)
        let fastEnd = try context.fetch(fastEndDescriptor)
        let favourites = try context.fetch(favouriteDescriptor)
        XCTAssertEqual(food.count, 120)
        XCTAssertEqual(hydration.count, 120)
        XCTAssertEqual(caloricHydration.count, 40)
        XCTAssertEqual(fastStart.count, 120)
        XCTAssertEqual(fastEnd.count, 60)
        XCTAssertEqual(favourites.count, 120)

        measure(metrics: [XCTClockMetric()]) {
            _ = try? context.fetch(foodDescriptor)
            _ = try? context.fetch(hydrationDescriptor)
            _ = try? context.fetch(caloricHydrationDescriptor)
            _ = try? context.fetch(fastStartDescriptor)
            _ = try? context.fetch(fastEndDescriptor)
            _ = try? context.fetch(favouriteDescriptor)
        }
        print(
            "MNT-008F indexed predicate/sort query counts: foodOccurredAt=\(food.count) " +
                "hydrationOccurredAt=\(hydration.count) caloricHydration=\(caloricHydration.count) " +
                "fastStartDate=\(fastStart.count) fastEndDate=\(fastEnd.count) " +
                "favouriteCreatedOrderID=\(favourites.count); timings are in XCTClockMetric"
        )
    }

    private func duplicateMigrationEvidence(
        plan: any SchemaMigrationPlan.Type
    ) throws -> DuplicateMigrationEvidence {
        let directory = try temporaryDirectory(named: "duplicate-v4")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "duplicate.store")
        let fixture = MNT008FixtureIDs()
        try MNT008V4Fixture.writeDuplicate(to: storeURL, ids: fixture)

        let beforeAttempt = try MNT008V4Fixture.readSnapshot(from: storeURL)
        let duplicateCount = beforeAttempt.foodRowCount
        let protectedURL = directory.appending(path: "protected.store")
        try MNT008V4Fixture.copyStoreFamily(from: storeURL, to: protectedURL)
        let error: Error
        MNT008V5DuplicatePreflight.lastErrorDescription = ""
        do {
            _ = try makeV5Container(storeURL: storeURL, plan: plan)
            throw MNT008UnexpectedSuccess()
        } catch let caught {
            error = caught
        }

        let originalV4Reopened = (try? MNT008V4Fixture.readSnapshot(from: storeURL))
            .map { $0 == beforeAttempt }
            ?? false
        let protectedV4Reopened = (try? MNT008V4Fixture.readSnapshot(from: protectedURL))
            .map { $0 == beforeAttempt }
            ?? false
        return DuplicateMigrationEvidence(
            duplicateFoodCount: duplicateCount,
            originalV4Reopened: originalV4Reopened,
            protectedV4Reopened: protectedV4Reopened,
            errorChain: describe(error),
            preflightError: MNT008V5DuplicatePreflight.lastErrorDescription
        )
    }

    private func captureSaveError(context: ModelContext) -> String {
        do {
            try context.save()
            return "unexpected success"
        } catch {
            return describe(error)
        }
    }

    private func makeV5Container(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        plan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: MNT008V5Schema.self)
        let configuration = if let storeURL {
            ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: plan,
            configurations: [configuration]
        )
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-mnt008-\(name)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func describe(_ error: Error) -> String {
        var descriptions: [String] = []
        var current: NSError? = error as NSError
        var seen = Set<ObjectIdentifier>()
        while let value = current, seen.insert(ObjectIdentifier(value)).inserted {
            descriptions.append("\(value.domain)[\(value.code)]: \(value.localizedDescription)")
            current = value.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return descriptions.joined(separator: " -> ")
    }
}

private struct DuplicateMigrationEvidence: CustomStringConvertible {
    let duplicateFoodCount: Int
    let originalV4Reopened: Bool
    let protectedV4Reopened: Bool
    let errorChain: String
    let preflightError: String

    var description: String {
        "duplicateFoodCount=\(duplicateFoodCount), originalV4Reopened=\(originalV4Reopened), protectedV4Reopened=\(protectedV4Reopened), errorChain=\(errorChain), preflightError=\(preflightError)"
    }
}

private struct MNT008UnexpectedSuccess: Error {}
private struct MNT008FixtureMissingValue: Error, CustomStringConvertible {
    let entity: String

    var description: String {
        "fixture missing value for \(entity)"
    }
}

private struct MNT008FixtureIDs {
    let settings: UUID
    let activeFast: UUID
    let completedFast: UUID
    let reconstructedFast: UUID
    let food: UUID
    let foodDuplicate: UUID
    let hydration: UUID
    let hydrationFavourite: UUID
    let unknownPeriod: UUID
    let date: Date

    init() {
        settings = UUID()
        activeFast = UUID()
        completedFast = UUID()
        reconstructedFast = UUID()
        food = UUID()
        foodDuplicate = UUID()
        hydration = UUID()
        hydrationFavourite = UUID()
        unknownPeriod = UUID()
        date = Date(timeIntervalSince1970: 1_700_000_000)
    }
}

private enum MNT008V5MigrationError: Error, CustomStringConvertible {
    case duplicateIDs(entity: String, ids: [UUID])

    var description: String {
        switch self {
        case let .duplicateIDs(entity, ids):
            "duplicateIDs(entity=\(entity), ids=\(ids.map(\.uuidString).joined(separator: ",")))"
        }
    }
}

private enum MNT008V5DuplicatePreflight {
    nonisolated(unsafe) static var lastErrorDescription = ""

    static func run(_ context: ModelContext) throws {
        let food = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        let duplicateFoodIDs = duplicateIDs(food.map(\.id))
        if !duplicateFoodIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "FoodEntryRecord",
                ids: duplicateFoodIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(entity: "FoodEntryRecord", ids: duplicateFoodIDs)
        }

        let hydration = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        let duplicateHydrationIDs = duplicateIDs(hydration.map(\.id))
        if !duplicateHydrationIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "HydrationEntryRecord",
                ids: duplicateHydrationIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(
                entity: "HydrationEntryRecord",
                ids: duplicateHydrationIDs
            )
        }

        let fast = try context.fetch(FetchDescriptor<FastRecord>())
        let duplicateFastIDs = duplicateIDs(fast.map(\.id))
        if !duplicateFastIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "FastRecord",
                ids: duplicateFastIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(entity: "FastRecord", ids: duplicateFastIDs)
        }

        let favourites = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        let duplicateFavouriteIDs = duplicateIDs(favourites.map(\.id))
        if !duplicateFavouriteIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "HydrationFavouriteRecord",
                ids: duplicateFavouriteIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(
                entity: "HydrationFavouriteRecord",
                ids: duplicateFavouriteIDs
            )
        }

        let unknowns = try context.fetch(FetchDescriptor<UnknownPeriodRecord>())
        let duplicateUnknownIDs = duplicateIDs(unknowns.map(\.id))
        if !duplicateUnknownIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "UnknownPeriodRecord",
                ids: duplicateUnknownIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(entity: "UnknownPeriodRecord", ids: duplicateUnknownIDs)
        }

        let settings = try context.fetch(FetchDescriptor<AppSettingsRecord>())
        let duplicateSettingsIDs = duplicateIDs(settings.map(\.id))
        if !duplicateSettingsIDs.isEmpty {
            lastErrorDescription = MNT008V5MigrationError.duplicateIDs(
                entity: "AppSettingsRecord",
                ids: duplicateSettingsIDs
            ).description
            throw MNT008V5MigrationError.duplicateIDs(entity: "AppSettingsRecord", ids: duplicateSettingsIDs)
        }
    }

    private static func duplicateIDs(_ ids: [UUID]) -> [UUID] {
        var counts: [UUID: Int] = [:]
        for id in ids {
            counts[id, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.map(\.key).sorted { $0.uuidString < $1.uuidString }
    }
}

private enum MNT008V5LightweightPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [UFastSchemaV4.self, MNT008V5Schema.self]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: UFastSchemaV4.self, toVersion: MNT008V5Schema.self),
    ]
}

private enum MNT008V5CustomPreflightPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [UFastSchemaV4.self, MNT008V5Schema.self]
    static let stages: [MigrationStage] = [
        .custom(
            fromVersion: UFastSchemaV4.self,
            toVersion: MNT008V5Schema.self,
            willMigrate: { context in try MNT008V5DuplicatePreflight.run(context) },
            didMigrate: nil
        ),
    ]
}

private struct MNT008SettingsSnapshot: Equatable {
    let id: UUID
    let fastingGoalHours: Int
    let hasCompletedOnboarding: Bool
    let waterFavouriteMillilitres: Int
    let teaFavouriteMillilitres: Int
    let coffeeFavouriteMillilitres: Int
    let automaticLiveActivityPreferenceRawValue: String
    let inferredFastDetectionEnabled: Bool

    init(_ record: MNT008V4Fixture.AppSettingsRecord) {
        id = record.id
        fastingGoalHours = record.fastingGoalHours
        hasCompletedOnboarding = record.hasCompletedOnboarding
        waterFavouriteMillilitres = record.waterFavouriteMillilitres
        teaFavouriteMillilitres = record.teaFavouriteMillilitres
        coffeeFavouriteMillilitres = record.coffeeFavouriteMillilitres
        automaticLiveActivityPreferenceRawValue = record.automaticLiveActivityPreferenceRawValue
        inferredFastDetectionEnabled = record.inferredFastDetectionEnabled
    }

    init(_ record: MNT008V5Schema.AppSettingsRecord) {
        id = record.id
        fastingGoalHours = record.fastingGoalHours
        hasCompletedOnboarding = record.hasCompletedOnboarding
        waterFavouriteMillilitres = record.waterFavouriteMillilitres
        teaFavouriteMillilitres = record.teaFavouriteMillilitres
        coffeeFavouriteMillilitres = record.coffeeFavouriteMillilitres
        automaticLiveActivityPreferenceRawValue = record.automaticLiveActivityPreferenceRawValue
        inferredFastDetectionEnabled = record.inferredFastDetectionEnabled
    }
}

private struct MNT008FastSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let goalHoursAtStart: Int
    let originRaw: String
    let reviewStateRaw: String
    let wasAdjustedByUser: Bool
    let hasHistoricalGoal: Bool
    let startBoundaryKindRaw: String?
    let startBoundaryID: UUID?
    let endBoundaryKindRaw: String?
    let endBoundaryID: UUID?
    let reviewBoundaryKindRaw: String?
    let reviewBoundaryID: UUID?

    init(_ record: MNT008V4Fixture.FastRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
        goalHoursAtStart = record.goalHoursAtStart
        originRaw = record.originRaw
        reviewStateRaw = record.reviewStateRaw
        wasAdjustedByUser = record.wasAdjustedByUser
        hasHistoricalGoal = record.hasHistoricalGoal
        startBoundaryKindRaw = record.startBoundaryKindRaw
        startBoundaryID = record.startBoundaryID
        endBoundaryKindRaw = record.endBoundaryKindRaw
        endBoundaryID = record.endBoundaryID
        reviewBoundaryKindRaw = record.reviewBoundaryKindRaw
        reviewBoundaryID = record.reviewBoundaryID
    }

    init(_ record: MNT008V5Schema.FastRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
        goalHoursAtStart = record.goalHoursAtStart
        originRaw = record.originRaw
        reviewStateRaw = record.reviewStateRaw
        wasAdjustedByUser = record.wasAdjustedByUser
        hasHistoricalGoal = record.hasHistoricalGoal
        startBoundaryKindRaw = record.startBoundaryKindRaw
        startBoundaryID = record.startBoundaryID
        endBoundaryKindRaw = record.endBoundaryKindRaw
        endBoundaryID = record.endBoundaryID
        reviewBoundaryKindRaw = record.reviewBoundaryKindRaw
        reviewBoundaryID = record.reviewBoundaryID
    }
}

private struct MNT008FoodSnapshot: Equatable {
    let id: UUID
    let foodDescription: String
    let occurredAt: Date
    let isCaloric: Bool
    let energyKilocalories: Double?
    let proteinGrams: Double?
    let carbohydrateGrams: Double?
    let fatGrams: Double?
    let fibreGrams: Double?
    let sugarGrams: Double?
    let saltGrams: Double?
    let createdAt: Date
    let updatedAt: Date

    init(_ record: MNT008V4Fixture.FoodEntryRecord) {
        id = record.id
        foodDescription = record.foodDescription
        occurredAt = record.occurredAt
        isCaloric = record.isCaloric
        energyKilocalories = record.energyKilocalories
        proteinGrams = record.proteinGrams
        carbohydrateGrams = record.carbohydrateGrams
        fatGrams = record.fatGrams
        fibreGrams = record.fibreGrams
        sugarGrams = record.sugarGrams
        saltGrams = record.saltGrams
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    init(_ record: MNT008V5Schema.FoodEntryRecord) {
        id = record.id
        foodDescription = record.foodDescription
        occurredAt = record.occurredAt
        isCaloric = record.isCaloric
        energyKilocalories = record.energyKilocalories
        proteinGrams = record.proteinGrams
        carbohydrateGrams = record.carbohydrateGrams
        fatGrams = record.fatGrams
        fibreGrams = record.fibreGrams
        sugarGrams = record.sugarGrams
        saltGrams = record.saltGrams
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}

private struct MNT008HydrationSnapshot: Equatable {
    let id: UUID
    let drinkTypeRaw: String
    let customName: String?
    let volumeMillilitres: Int
    let occurredAt: Date
    let isCaloric: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ record: MNT008V4Fixture.HydrationEntryRecord) {
        id = record.id
        drinkTypeRaw = record.drinkTypeRaw
        customName = record.customName
        volumeMillilitres = record.volumeMillilitres
        occurredAt = record.occurredAt
        isCaloric = record.isCaloric
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    init(_ record: MNT008V5Schema.HydrationEntryRecord) {
        id = record.id
        drinkTypeRaw = record.drinkTypeRaw
        customName = record.customName
        volumeMillilitres = record.volumeMillilitres
        occurredAt = record.occurredAt
        isCaloric = record.isCaloric
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}

private struct MNT008FavouriteSnapshot: Equatable {
    let id: UUID
    let name: String
    let volumeMillilitres: Int
    let isCaloric: Bool
    let createdAt: Date
    let updatedAt: Date
    let creationOrder: Int64

    init(_ record: MNT008V4Fixture.HydrationFavouriteRecord) {
        id = record.id
        name = record.name
        volumeMillilitres = record.volumeMillilitres
        isCaloric = record.isCaloric
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        creationOrder = record.creationOrder
    }

    init(_ record: MNT008V5Schema.HydrationFavouriteRecord) {
        id = record.id
        name = record.name
        volumeMillilitres = record.volumeMillilitres
        isCaloric = record.isCaloric
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        creationOrder = record.creationOrder
    }
}

private struct MNT008UnknownPeriodSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let startBoundaryKindRaw: String
    let startBoundaryID: UUID
    let endBoundaryKindRaw: String
    let endBoundaryID: UUID
    let reasonRaw: String
    let createdAt: Date
    let updatedAt: Date

    init(_ record: MNT008V4Fixture.UnknownPeriodRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
        startBoundaryKindRaw = record.startBoundaryKindRaw
        startBoundaryID = record.startBoundaryID
        endBoundaryKindRaw = record.endBoundaryKindRaw
        endBoundaryID = record.endBoundaryID
        reasonRaw = record.reasonRaw
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    init(_ record: MNT008V5Schema.UnknownPeriodRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
        startBoundaryKindRaw = record.startBoundaryKindRaw
        startBoundaryID = record.startBoundaryID
        endBoundaryKindRaw = record.endBoundaryKindRaw
        endBoundaryID = record.endBoundaryID
        reasonRaw = record.reasonRaw
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }
}

private struct MNT008V4Snapshot: Equatable {
    let settings: [MNT008SettingsSnapshot]
    let fasts: [MNT008FastSnapshot]
    let foods: [MNT008FoodSnapshot]
    let hydration: [MNT008HydrationSnapshot]
    let favourites: [MNT008FavouriteSnapshot]
    let unknownPeriods: [MNT008UnknownPeriodSnapshot]

    var foodRowCount: Int {
        foods.count
    }

    var v5Equivalent: MNT008V5Snapshot {
        MNT008V5Snapshot(
            settings: settings,
            fasts: fasts,
            foods: foods,
            hydration: hydration,
            favourites: favourites,
            unknownPeriods: unknownPeriods
        )
    }
}

private struct MNT008V5Snapshot: Equatable {
    let settings: [MNT008SettingsSnapshot]
    let fasts: [MNT008FastSnapshot]
    let foods: [MNT008FoodSnapshot]
    let hydration: [MNT008HydrationSnapshot]
    let favourites: [MNT008FavouriteSnapshot]
    let unknownPeriods: [MNT008UnknownPeriodSnapshot]

    init(context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<MNT008V5Schema.AppSettingsRecord>())
        let fasts = try context.fetch(FetchDescriptor<MNT008V5Schema.FastRecord>())
        let foods = try context.fetch(FetchDescriptor<MNT008V5Schema.FoodEntryRecord>())
        let hydration = try context.fetch(FetchDescriptor<MNT008V5Schema.HydrationEntryRecord>())
        let favourites = try context.fetch(FetchDescriptor<MNT008V5Schema.HydrationFavouriteRecord>())
        let unknownPeriods = try context.fetch(FetchDescriptor<MNT008V5Schema.UnknownPeriodRecord>())
        self.settings = settings.map(MNT008SettingsSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        self.fasts = fasts.map(MNT008FastSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        self.foods = foods.map(MNT008FoodSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        self.hydration = hydration.map(MNT008HydrationSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        self.favourites = favourites.map(MNT008FavouriteSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        self.unknownPeriods = unknownPeriods.map(MNT008UnknownPeriodSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
    }

    init(
        settings: [MNT008SettingsSnapshot],
        fasts: [MNT008FastSnapshot],
        foods: [MNT008FoodSnapshot],
        hydration: [MNT008HydrationSnapshot],
        favourites: [MNT008FavouriteSnapshot],
        unknownPeriods: [MNT008UnknownPeriodSnapshot]
    ) {
        self.settings = settings
        self.fasts = fasts
        self.foods = foods
        self.hydration = hydration
        self.favourites = favourites
        self.unknownPeriods = unknownPeriods
    }
}

/// Independent V4 disk fixture: none of these classes aliases a production
/// model.  Their stored names/properties intentionally match UFastSchemaV4.
@MainActor
private enum MNT008V4Fixture {
    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]

    @Model final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false
        init(id: UUID, fastingGoalHours: Int) {
            self.id = id; self.fastingGoalHours = fastingGoalHours
        }
    }

    @Model final class FastRecord {
        var id: UUID = UUID()
        var startDate: Date = Date(timeIntervalSince1970: 0)
        var endDate: Date?
        var goalHoursAtStart: Int = 12
        var originRaw: String = "recorded"
        var reviewStateRaw: String = "confirmed"
        var wasAdjustedByUser: Bool = false
        var hasHistoricalGoal: Bool = true
        var startBoundaryKindRaw: String?
        var startBoundaryID: UUID?
        var endBoundaryKindRaw: String?
        var endBoundaryID: UUID?
        var reviewBoundaryKindRaw: String?
        var reviewBoundaryID: UUID?
        init(id: UUID, startDate: Date, endDate: Date?, originRaw: String = "recorded") {
            self.id = id; self.startDate = startDate; self.endDate = endDate; self.originRaw = originRaw
        }
    }

    @Model final class FoodEntryRecord {
        var id: UUID = UUID()
        var foodDescription: String = ""
        var occurredAt: Date = Date(timeIntervalSince1970: 0)
        var isCaloric: Bool = true
        var energyKilocalories: Double?
        var proteinGrams: Double?
        var carbohydrateGrams: Double?
        var fatGrams: Double?
        var fibreGrams: Double?
        var sugarGrams: Double?
        var saltGrams: Double?
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        init(id: UUID, description: String, occurredAt: Date, createdAt: Date) {
            self.id = id; foodDescription = description; self.occurredAt = occurredAt; self.createdAt = createdAt; updatedAt = createdAt
        }
    }

    @Model final class HydrationEntryRecord {
        var id: UUID = UUID()
        var drinkTypeRaw: String = "water"
        var customName: String?
        var volumeMillilitres: Int = 500
        var occurredAt: Date = Date(timeIntervalSince1970: 0)
        var isCaloric: Bool = false
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        init(id: UUID, type: String, occurredAt: Date, createdAt: Date) {
            self.id = id; drinkTypeRaw = type; self.occurredAt = occurredAt; self.createdAt = createdAt; updatedAt = createdAt
        }
    }

    @Model final class HydrationFavouriteRecord {
        var id: UUID = UUID()
        var name: String = ""
        var volumeMillilitres: Int = 1
        var isCaloric: Bool = false
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        var creationOrder: Int64 = 0
        init(id: UUID, name: String, createdAt: Date) {
            self.id = id; self.name = name; self.createdAt = createdAt; updatedAt = createdAt
        }
    }

    @Model final class UnknownPeriodRecord {
        var id: UUID = UUID()
        var startDate: Date = Date(timeIntervalSince1970: 0)
        var endDate: Date = Date(timeIntervalSince1970: 0)
        var startBoundaryKindRaw: String = "food"
        var startBoundaryID: UUID = UUID()
        var endBoundaryKindRaw: String = "food"
        var endBoundaryID: UUID = UUID()
        var reasonRaw: String = "insufficientEvidence"
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        init(id: UUID, startDate: Date, endDate: Date, createdAt: Date) {
            self.id = id; self.startDate = startDate; self.endDate = endDate; self.createdAt = createdAt; updatedAt = createdAt
        }
    }

    static func writeClean(to storeURL: URL, ids: MNT008FixtureIDs) throws {
        let container = try makeContainer(storeURL: storeURL)
        let context = container.mainContext
        context.insert(AppSettingsRecord(id: ids.settings, fastingGoalHours: 17))
        context.insert(FastRecord(id: ids.activeFast, startDate: ids.date, endDate: nil))
        context.insert(FastRecord(id: ids.completedFast, startDate: ids.date.addingTimeInterval(-7200), endDate: ids.date))
        let reconstructed = FastRecord(id: ids.reconstructedFast, startDate: ids.date.addingTimeInterval(-10000), endDate: ids.date.addingTimeInterval(-5000), originRaw: "reconstructed")
        reconstructed.wasAdjustedByUser = true
        reconstructed.hasHistoricalGoal = false
        reconstructed.startBoundaryKindRaw = "food"
        reconstructed.startBoundaryID = ids.food
        reconstructed.endBoundaryKindRaw = "hydration"
        reconstructed.endBoundaryID = ids.hydration
        reconstructed.reviewStateRaw = "needsReview"
        reconstructed.reviewBoundaryKindRaw = "food"
        reconstructed.reviewBoundaryID = ids.food
        context.insert(reconstructed)
        let food = FoodEntryRecord(id: ids.food, description: "Legacy supper", occurredAt: ids.date, createdAt: ids.date)
        food.energyKilocalories = 640; food.proteinGrams = 31; food.carbohydrateGrams = 72; food.fatGrams = 22; food.fibreGrams = 8; food.sugarGrams = 6; food.saltGrams = 1.4
        context.insert(food)
        let nonCaloricFood = FoodEntryRecord(id: ids.foodDuplicate, description: "Legacy tea", occurredAt: ids.date.addingTimeInterval(60), createdAt: ids.date)
        nonCaloricFood.isCaloric = false
        context.insert(nonCaloricFood)
        let hydration = HydrationEntryRecord(id: ids.hydration, type: "custom", occurredAt: ids.date, createdAt: ids.date)
        hydration.customName = "Legacy broth"; hydration.volumeMillilitres = 375; hydration.isCaloric = true
        context.insert(hydration)
        context.insert(HydrationFavouriteRecord(id: ids.hydrationFavourite, name: "Sparkling water", createdAt: ids.date))
        context.insert(UnknownPeriodRecord(id: ids.unknownPeriod, startDate: ids.date.addingTimeInterval(-4000), endDate: ids.date.addingTimeInterval(-3000), createdAt: ids.date))
        try context.save()
    }

    static func writeDuplicate(to storeURL: URL, ids: MNT008FixtureIDs) throws {
        try writeClean(to: storeURL, ids: ids)
        let container = try open(storeURL: storeURL)
        let context = container.mainContext
        context.insert(FoodEntryRecord(id: ids.food, description: "duplicate", occurredAt: ids.date.addingTimeInterval(1), createdAt: ids.date))
        try context.save()
    }

    static func open(storeURL: URL) throws -> ModelContainer {
        try makeContainer(storeURL: storeURL)
    }

    static func copyStoreFamily(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: sourceURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: destinationURL.path + suffix)
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func makeContainer(storeURL: URL) throws -> ModelContainer {
        let schema = Schema(models, version: Schema.Version(4, 0, 0))
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)])
    }

    static func readSnapshot(from storeURL: URL) throws -> MNT008V4Snapshot {
        let container = try open(storeURL: storeURL)
        let context = container.mainContext
        let settings = try context.fetch(FetchDescriptor<AppSettingsRecord>())
        guard !settings.isEmpty else { throw MNT008FixtureMissingValue(entity: "AppSettingsRecord") }
        let fasts = try context.fetch(FetchDescriptor<FastRecord>())
        guard fasts.contains(where: { $0.endDate == nil }) else {
            throw MNT008FixtureMissingValue(entity: "FastRecord.active")
        }
        guard fasts.contains(where: { $0.endDate != nil && $0.originRaw == "recorded" }) else {
            throw MNT008FixtureMissingValue(entity: "FastRecord.completed")
        }
        guard fasts.contains(where: { $0.originRaw == "reconstructed" }) else {
            throw MNT008FixtureMissingValue(entity: "FastRecord.reconstructed")
        }
        let foods = try context.fetch(FetchDescriptor<FoodEntryRecord>())
        guard foods.count >= 2 else { throw MNT008FixtureMissingValue(entity: "FoodEntryRecord") }
        let hydration = try context.fetch(FetchDescriptor<HydrationEntryRecord>())
        guard !hydration.isEmpty else { throw MNT008FixtureMissingValue(entity: "HydrationEntryRecord") }
        let favourites = try context.fetch(FetchDescriptor<HydrationFavouriteRecord>())
        guard !favourites.isEmpty else { throw MNT008FixtureMissingValue(entity: "HydrationFavouriteRecord") }
        let unknownPeriods = try context.fetch(FetchDescriptor<UnknownPeriodRecord>())
        guard !unknownPeriods.isEmpty else { throw MNT008FixtureMissingValue(entity: "UnknownPeriodRecord") }
        return MNT008V4Snapshot(
            settings: settings.map(MNT008SettingsSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString },
            fasts: fasts.map(MNT008FastSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString },
            foods: foods.map(MNT008FoodSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString },
            hydration: hydration.map(MNT008HydrationSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString },
            favourites: favourites.map(MNT008FavouriteSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString },
            unknownPeriods: unknownPeriods.map(MNT008UnknownPeriodSnapshot.init).sorted { $0.id.uuidString < $1.id.uuidString }
        )
    }
}

private enum MNT008V5Schema: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]

    @Model final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = 12
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"
        var inferredFastDetectionEnabled: Bool = false
        #Unique<AppSettingsRecord>([\.id])
        init(id: UUID = UUID(), fastingGoalHours: Int = 12) {
            self.id = id; self.fastingGoalHours = fastingGoalHours
        }
    }

    @Model final class FastRecord {
        var id: UUID = UUID()
        var startDate: Date = Date(timeIntervalSince1970: 0)
        var endDate: Date?
        var goalHoursAtStart: Int = 12
        var originRaw: String = "recorded"
        var reviewStateRaw: String = "confirmed"
        var wasAdjustedByUser: Bool = false
        var hasHistoricalGoal: Bool = true
        var startBoundaryKindRaw: String?
        var startBoundaryID: UUID?
        var endBoundaryKindRaw: String?
        var endBoundaryID: UUID?
        var reviewBoundaryKindRaw: String?
        var reviewBoundaryID: UUID?
        #Index<FastRecord>([\.startDate], [\.endDate])
        #Unique<FastRecord>([\.id])
        init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
            self.id = id; self.startDate = startDate; self.endDate = endDate
        }
    }

    @Model final class FoodEntryRecord {
        var id: UUID = UUID()
        var foodDescription: String = ""
        var occurredAt: Date = Date(timeIntervalSince1970: 0)
        var isCaloric: Bool = true
        var energyKilocalories: Double?
        var proteinGrams: Double?
        var carbohydrateGrams: Double?
        var fatGrams: Double?
        var fibreGrams: Double?
        var sugarGrams: Double?
        var saltGrams: Double?
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        #Index<FoodEntryRecord>([\.occurredAt])
        #Unique<FoodEntryRecord>([\.id])
        init(id: UUID = UUID(), foodDescription: String, occurredAt: Date, isCaloric: Bool, createdAt: Date, updatedAt: Date) {
            self.id = id; self.foodDescription = foodDescription; self.occurredAt = occurredAt; self.isCaloric = isCaloric; self.createdAt = createdAt; self.updatedAt = updatedAt
        }
    }

    @Model final class HydrationEntryRecord {
        var id: UUID = UUID()
        var drinkTypeRaw: String = "water"
        var customName: String?
        var volumeMillilitres: Int = 500
        var occurredAt: Date = Date(timeIntervalSince1970: 0)
        var isCaloric: Bool = false
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        #Index<HydrationEntryRecord>([\.occurredAt], [\.isCaloric, \.occurredAt])
        #Unique<HydrationEntryRecord>([\.id])
        init(id: UUID = UUID(), drinkTypeRaw: String, customName: String?, volumeMillilitres: Int, occurredAt: Date, isCaloric: Bool, createdAt: Date, updatedAt: Date) {
            self.id = id; self.drinkTypeRaw = drinkTypeRaw; self.customName = customName; self.volumeMillilitres = volumeMillilitres; self.occurredAt = occurredAt; self.isCaloric = isCaloric; self.createdAt = createdAt; self.updatedAt = updatedAt
        }
    }

    @Model final class HydrationFavouriteRecord {
        var id: UUID = UUID()
        var name: String = ""
        var volumeMillilitres: Int = 1
        var isCaloric: Bool = false
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        var creationOrder: Int64 = 0
        #Index<HydrationFavouriteRecord>([\.createdAt, \.creationOrder, \.id])
        #Unique<HydrationFavouriteRecord>([\.id])
        init(id: UUID = UUID(), name: String, volumeMillilitres: Int, isCaloric: Bool, createdAt: Date, updatedAt: Date, creationOrder: Int64) {
            self.id = id; self.name = name; self.volumeMillilitres = volumeMillilitres; self.isCaloric = isCaloric; self.createdAt = createdAt; self.updatedAt = updatedAt; self.creationOrder = creationOrder
        }
    }

    @Model final class UnknownPeriodRecord {
        var id: UUID = UUID()
        var startDate: Date = Date(timeIntervalSince1970: 0)
        var endDate: Date = Date(timeIntervalSince1970: 0)
        var startBoundaryKindRaw: String = "food"
        var startBoundaryID: UUID = UUID()
        var endBoundaryKindRaw: String = "food"
        var endBoundaryID: UUID = UUID()
        var reasonRaw: String = "insufficientEvidence"
        var createdAt: Date = Date(timeIntervalSince1970: 0)
        var updatedAt: Date = Date(timeIntervalSince1970: 0)
        #Unique<UnknownPeriodRecord>([\.id])
        init(id: UUID = UUID(), startDate: Date, endDate: Date, createdAt: Date) {
            self.id = id; self.startDate = startDate; self.endDate = endDate; self.createdAt = createdAt; updatedAt = createdAt
        }
    }
}
