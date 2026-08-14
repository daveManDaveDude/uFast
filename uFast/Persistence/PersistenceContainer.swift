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
}

enum UFastSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static let models: [any PersistentModel.Type] = [
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        HydrationFavouriteRecord.self,
        UnknownPeriodRecord.self,
    ]
}

enum UFastMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [UFastSchemaV1.self, UFastSchemaV2.self]
    static let stages: [MigrationStage] = [
        .lightweight(fromVersion: UFastSchemaV1.self, toVersion: UFastSchemaV2.self),
    ]
}

enum PersistenceContainer {
    static let schema = Schema(versionedSchema: UFastSchemaV2.self)

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = configuration(inMemory: inMemory)
        return try ModelContainer(
            for: schema,
            migrationPlan: UFastMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func configuration(inMemory: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
    }

    static func make(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: UFastMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
