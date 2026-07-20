import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable opening_brace

@main
struct UFastApp: App {
    private let modelContainer: ModelContainer
    private let clock: any AppClock

    init() {
        clock = AppClockConfiguration.clock()

        do {
            modelContainer = try PersistenceContainer.make()
            try resetDataIfRequested(in: modelContainer)
        } catch {
            fatalError("Unable to create the local persistence container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(clock: clock)
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
        try context.fetch(FetchDescriptor<FoodEntryRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<HydrationEntryRecord>()).forEach(context.delete)

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--seed-onboarded") {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        if let index = arguments.firstIndex(of: "--seed-active-fast-start"),
           arguments.indices.contains(index + 1),
           let interval = TimeInterval(arguments[index + 1])
        {
            context.insert(
                FastRecord(
                    startDate: Date(timeIntervalSince1970: interval),
                    goalAtStart: .default
                )
            )
        }
        try context.save()
    }
}
