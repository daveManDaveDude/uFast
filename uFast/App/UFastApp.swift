import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable opening_brace trailing_comma

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
        try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).forEach(context.delete)

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--seed-onboarded") {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        if arguments.contains("--seed-slice3-history") {
            try seedSlice3History(in: context)
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

    private func seedSlice3History(in context: ModelContext) throws {
        if try context.fetch(FetchDescriptor<AppSettingsRecord>()).isEmpty {
            context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        }
        let now = clock.now
        let dates = [-60, -48, -36, -24].map {
            now.addingTimeInterval(TimeInterval($0 * 60 * 60))
        }
        let entries = [
            FoodEntryRecord(draft: .init(description: "Late dinner", occurredAt: dates[0]), createdAt: dates[0]),
            FoodEntryRecord(draft: .init(description: "Breakfast", occurredAt: dates[1]), createdAt: dates[1]),
            FoodEntryRecord(draft: .init(description: "Supper", occurredAt: dates[2]), createdAt: dates[2]),
            FoodEntryRecord(draft: .init(description: "Morning meal", occurredAt: dates[3]), createdAt: dates[3]),
        ]
        entries.forEach(context.insert)
        let confirmed = FastRecord(
            reconstructedStart: dates[0],
            endDate: dates[1],
            boundaries: .init(
                start: .init(kind: .food, id: entries[0].id),
                end: .init(kind: .food, id: entries[1].id)
            ),
            adjustedByUser: false
        )
        let needsReview = FastRecord(
            reconstructedStart: dates[2],
            endDate: dates[3],
            boundaries: .init(
                start: .init(kind: .food, id: entries[2].id),
                end: .init(kind: .food, id: entries[3].id)
            ),
            adjustedByUser: true
        )
        needsReview.markNeedsReview()
        context.insert(confirmed)
        context.insert(needsReview)
        context.insert(
            UnknownPeriodRecord(
                startDate: now.addingTimeInterval(-18 * 60 * 60),
                endDate: now.addingTimeInterval(-10 * 60 * 60),
                boundaries: .init(
                    start: .init(kind: .food, id: UUID()),
                    end: .init(kind: .hydration, id: UUID())
                ),
                reason: .userChoice,
                createdAt: now
            )
        )
    }
}
