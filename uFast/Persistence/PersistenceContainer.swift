import Foundation
import SwiftData

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

enum PersistenceContainer {
    static let cloudKitContainerIdentifier = "iCloud.com.davidmcgrath.uFast"

    static let schema = Schema([
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
        UnknownPeriodRecord.self,
    ])

    static func make(
        inMemory: Bool = false,
        cloudSyncEnabled: Bool = true
    ) throws -> ModelContainer {
        let configuration = if inMemory || !cloudSyncEnabled {
            ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        } else {
            ModelConfiguration(
                "Cloud",
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    static func make(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
