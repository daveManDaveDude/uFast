import SwiftData

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable trailing_comma

enum PersistenceContainer {
    static let schema = Schema([
        AppSettingsRecord.self,
        FastRecord.self,
        FoodEntryRecord.self,
        HydrationEntryRecord.self,
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
