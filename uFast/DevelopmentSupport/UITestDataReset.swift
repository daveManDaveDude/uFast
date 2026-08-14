import Foundation
import SwiftData

@MainActor
enum UITestDataReset {
    static func runIfRequested(
        in container: ModelContainer,
        configuration: DevelopmentFixtureConfiguration,
        now: Date,
        clock: any AppClock
    ) throws {
        guard configuration.resetData else { return }

        let context = container.mainContext
        try context.fetch(FetchDescriptor<AppSettingsRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<FastRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<FoodEntryRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<HydrationEntryRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<HydrationFavouriteRecord>()).forEach(context.delete)
        try UserDefaultsLiveActivityLifecycleStore().clearAll()

        if configuration.seedOnboarded || configuration.seedLiveActivityRecovery {
            context.insert(
                AppSettingsRecord(
                    hasCompletedOnboarding: true,
                    automaticLiveActivityPreference: configuration.seedLiveActivityRecovery
                        ? .enabled
                        : .notAsked
                )
            )
        }
        if configuration.seedSlice3History {
            try UITestSeedFixtures.seedSlice3History(in: context, clock: clock)
        }
        if configuration.seedHistoryEventGrouping {
            try UITestSeedFixtures.seedHistoryEventGrouping(in: context, clock: clock)
        }
        seedFavouriteFixtures(in: context, configuration: configuration, clock: clock)
        if let startDate = configuration.seedActiveFastStart {
            let fast = FastRecord(
                startDate: startDate,
                goalAtStart: .default
            )
            context.insert(fast)
            if configuration.seedLiveActivityRecovery {
                try? UserDefaultsLiveActivityLifecycleStore().save(
                    LiveActivityLifecycleMetadata(
                        activeRecordIdentifier: fast.id,
                        hasRequested: true,
                        lastRequestDate: now.addingTimeInterval(-60),
                        lastRequestBuildIdentity: .deterministic(buildNumber: "A")
                    )
                )
            }
        }
        seedIntegrityFixtures(in: context, configuration: configuration, now: now)
        try context.save()
    }

    private static func seedFavouriteFixtures(
        in context: ModelContext,
        configuration: DevelopmentFixtureConfiguration,
        clock: any AppClock
    ) {
        if configuration.seedFavouritePopulated {
            UITestSeedFixtures.seedFavouritePopulated(in: context, clock: clock)
        }
        if configuration.seedFavouriteDuplicateName {
            UITestSeedFixtures.seedFavouriteDuplicateName(in: context, clock: clock)
        }
        if configuration.seedFavouriteValidation {
            UITestSeedFixtures.seedFavouriteValidation(in: context, clock: clock)
        }
        if configuration.seedCaloricFavouriteActiveFast {
            UITestSeedFixtures.seedCaloricFavouriteActiveFast(in: context, clock: clock)
        }
    }

    private static func seedIntegrityFixtures(
        in context: ModelContext,
        configuration: DevelopmentFixtureConfiguration,
        now: Date
    ) {
        if configuration.seedMultipleActiveFasts {
            context.insert(
                FastRecord(startDate: now.addingTimeInterval(-7200), goalAtStart: .default)
            )
            context.insert(
                FastRecord(startDate: now.addingTimeInterval(-3600), goalAtStart: .default)
            )
        }
        guard configuration.seedUnknownProvenance else { return }
        let fast = FastRecord(
            startDate: now.addingTimeInterval(-7200),
            endDate: now.addingTimeInterval(-3600),
            goalAtStart: .default
        )
        fast.restoreProvenance(
            FastRecordProvenanceSnapshot(
                originRaw: "future-origin",
                reviewStateRaw: "future-review",
                wasAdjustedByUser: false,
                hasHistoricalGoal: true,
                startBoundaryKindRaw: nil,
                startBoundaryID: nil,
                endBoundaryKindRaw: nil,
                endBoundaryID: nil
            )
        )
        fast.restorePersistedHistoricalGoal(rawHours: 99, isCaptured: true)
        context.insert(fast)
    }
}
