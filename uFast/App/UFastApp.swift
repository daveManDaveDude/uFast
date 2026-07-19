import SwiftData
import SwiftUI

@main
struct UFastApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try PersistenceContainer.make()
            try resetDataIfRequested(in: modelContainer)
        } catch {
            fatalError("Unable to create the local persistence container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }

    private func resetDataIfRequested(in container: ModelContainer) throws {
        guard ProcessInfo.processInfo.arguments.contains("--reset-data") else {
            return
        }

        let context = container.mainContext
        try context.fetch(FetchDescriptor<AppSettingsRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<FastRecord>()).forEach(context.delete)
        try context.save()
    }
}
