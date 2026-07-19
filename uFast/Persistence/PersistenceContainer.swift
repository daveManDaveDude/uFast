import SwiftData

enum PersistenceContainer {
    static let schema = Schema([AppSettingsRecord.self, FastRecord.self])

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
