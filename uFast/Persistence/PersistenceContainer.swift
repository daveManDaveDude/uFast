import Foundation
import SwiftData

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

enum UFastSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        UnknownPeriodRecord.self,
    ]

    /// These declarations are intentionally separate from the current model
    /// types below.  V1 is the persisted contract shipped before preferences
    /// and hydration favourites were added; changing it would make old stores
    /// look like a different schema to SwiftData.
    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = FastingGoal.default.hours
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300

        init() {}
    }

    @Model
    final class FastRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date?
        private(set) var goalHoursAtStart: Int = FastingGoal.default.hours
        private(set) var originRaw: String = FastOrigin.recorded.rawValue
        private(set) var reviewStateRaw: String = FastReviewState.confirmed.rawValue
        private(set) var wasAdjustedByUser: Bool = false
        private(set) var hasHistoricalGoal: Bool = true
        private(set) var startBoundaryKindRaw: String?
        private(set) var startBoundaryID: UUID?
        private(set) var endBoundaryKindRaw: String?
        private(set) var endBoundaryID: UUID?

        init() {}
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

        init() {}
    }

    @Model
    final class HydrationEntryRecord {
        var id: UUID = UUID()
        private(set) var drinkTypeRaw: String = HydrationDrinkType.water.rawValue
        private(set) var customName: String?
        private(set) var volumeMillilitres: Int = 500
        private(set) var occurredAt: Date = Date.now
        private(set) var isCaloric: Bool = false
        private(set) var createdAt: Date = Date.now
        private(set) var updatedAt: Date = Date.now

        init() {}
    }

    @Model
    final class UnknownPeriodRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date = Date.now
        private(set) var startBoundaryKindRaw: String = CaloricBoundaryKind.food.rawValue
        private(set) var startBoundaryID: UUID = UUID()
        private(set) var endBoundaryKindRaw: String = CaloricBoundaryKind.food.rawValue
        private(set) var endBoundaryID: UUID = UUID()
        private(set) var reasonRaw: String = UnknownPeriodReason.insufficientEvidence.rawValue
        private(set) var createdAt: Date = Date.now
        private(set) var updatedAt: Date = Date.now

        init() {}
    }
}

enum UFastSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    @Model
    final class AppSettingsRecord {
        var id: UUID = UUID()
        var fastingGoalHours: Int = FastingGoal.default.hours
        var hasCompletedOnboarding: Bool = false
        var waterFavouriteMillilitres: Int = 500
        var teaFavouriteMillilitres: Int = 300
        var coffeeFavouriteMillilitres: Int = 300
        var automaticLiveActivityPreferenceRawValue: String = "notAsked"

        init() {}
    }

    @Model
    final class FastRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date?
        private(set) var goalHoursAtStart: Int = FastingGoal.default.hours
        private(set) var originRaw: String = FastOrigin.recorded.rawValue
        private(set) var reviewStateRaw: String = FastReviewState.confirmed.rawValue
        private(set) var wasAdjustedByUser: Bool = false
        private(set) var hasHistoricalGoal: Bool = true
        private(set) var startBoundaryKindRaw: String?
        private(set) var startBoundaryID: UUID?
        private(set) var endBoundaryKindRaw: String?
        private(set) var endBoundaryID: UUID?

        init() {}
    }

    static let models: [any PersistentModel.Type] = [
        UFastSchemaV2.AppSettingsRecord.self,
        UFastSchemaV2.FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]
}

enum UFastSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    @Model
    final class FastRecord {
        var id: UUID = UUID()
        private(set) var startDate: Date = Date.now
        private(set) var endDate: Date?
        private(set) var goalHoursAtStart: Int = FastingGoal.default.hours
        private(set) var originRaw: String = FastOrigin.recorded.rawValue
        private(set) var reviewStateRaw: String = FastReviewState.confirmed.rawValue
        private(set) var wasAdjustedByUser: Bool = false
        private(set) var hasHistoricalGoal: Bool = true
        private(set) var startBoundaryKindRaw: String?
        private(set) var startBoundaryID: UUID?
        private(set) var endBoundaryKindRaw: String?
        private(set) var endBoundaryID: UUID?

        init() {}
    }

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        UFastSchemaV3.FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]
}

enum UFastSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]
}

enum UFastSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
        HydrationFavouriteMigrationRecord.self,
    ]
}

enum UFastSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        FoodFavouriteRecord.self,
        UnknownPeriodRecord.self,
        HydrationFavouriteMigrationRecord.self,
    ]
}

enum UFastMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        UFastSchemaV1.self,
        UFastSchemaV2.self,
        UFastSchemaV3.self,
        UFastSchemaV4.self,
        UFastSchemaV5.self,
        UFastSchemaV6.self,
    ]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: UFastSchemaV1.self, toVersion: UFastSchemaV2.self),
        .lightweight(fromVersion: UFastSchemaV2.self, toVersion: UFastSchemaV3.self),
        .lightweight(fromVersion: UFastSchemaV3.self, toVersion: UFastSchemaV4.self),
        .lightweight(fromVersion: UFastSchemaV4.self, toVersion: UFastSchemaV5.self),
        .lightweight(fromVersion: UFastSchemaV5.self, toVersion: UFastSchemaV6.self),
    ]
}

enum PersistenceContainer {
    static let schema = Schema(versionedSchema: UFastSchemaV6.self)

    @MainActor
    static func make(
        inMemory: Bool = false,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        now: Date = .now,
        simulateMigrationFailure: Bool = false
    ) throws -> ModelContainer {
        if simulateMigrationFailure {
            throw PersistenceBootstrapError.migrationFailed(FoodFavouriteStoreError.simulatedSaveFailure)
        }
        let configuration = configuration(inMemory: inMemory)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UFastMigrationPlan.self,
                configurations: [configuration]
            )
            try HydrationFavouriteMigration.run(
                in: container.mainContext,
                now: now,
                diagnosticSink: diagnosticSink
            )
            return container
        } catch {
            recordMigrationFailure(to: diagnosticSink)
            throw PersistenceBootstrapError.migrationFailed(error)
        }
    }

    static func configuration(inMemory: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
    }

    @MainActor
    static func make(
        storeURL: URL,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        now: Date = .now,
        simulateMigrationFailure: Bool = false
    ) throws -> ModelContainer {
        if simulateMigrationFailure {
            throw PersistenceBootstrapError.migrationFailed(FoodFavouriteStoreError.simulatedSaveFailure)
        }
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UFastMigrationPlan.self,
                configurations: [configuration]
            )
            try HydrationFavouriteMigration.run(
                in: container.mainContext,
                now: now,
                diagnosticSink: diagnosticSink
            )
            return container
        } catch {
            recordMigrationFailure(to: diagnosticSink)
            throw PersistenceBootstrapError.migrationFailed(error)
        }
    }

    private static func recordMigrationFailure(to sink: any DiagnosticEventSink) {
        guard let event = DiagnosticEvent(
            subsystem: .persistence,
            outcome: .migrationFailed,
            severity: .error
        ) else {
            return
        }
        sink.record(event)
    }
}
