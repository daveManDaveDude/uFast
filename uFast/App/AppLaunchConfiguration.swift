import Foundation

struct DevelopmentFixtureConfiguration: Equatable {
    var resetData = false
    var seedOnboarded = false
    var seedSlice3History = false
    var seedHistoryEventGrouping = false
    var seedActiveFastStart: Date?
    var seedMultipleActiveFasts = false
    var seedUnknownProvenance = false

    static let disabled = Self()
}

enum LiveActivityAdapterConfiguration: Equatable {
    case activityKit
    case deterministic(
        availability: LiveActivityAvailability,
        failRequests: Bool,
        failEnds: Bool
    )
}

struct AppLaunchConfiguration {
    let isUITesting: Bool
    let fixedNow: Date?
    let fixtures: DevelopmentFixtureConfiguration
    let commands: ApplicationCommandConfiguration
    let liveActivityAdapter: LiveActivityAdapterConfiguration
    let simulatePersistenceBootstrapFailure: Bool
    let suppressAutomaticLiveActivityOffer: Bool

    static func current() -> Self {
        Self(arguments: ProcessInfo.processInfo.arguments)
    }

    init(arguments: [String]) {
        let isUITesting = arguments.contains("--ui-testing")
        self.isUITesting = isUITesting
        guard isUITesting else {
            fixedNow = nil
            fixtures = .disabled
            commands = .init()
            liveActivityAdapter = .activityKit
            simulatePersistenceBootstrapFailure = false
            suppressAutomaticLiveActivityOffer = false
            return
        }

        fixedNow = Self.date(after: "--fixed-now", in: arguments)
        fixtures = DevelopmentFixtureConfiguration(
            resetData: arguments.contains("--reset-data"),
            seedOnboarded: arguments.contains("--seed-onboarded"),
            seedSlice3History: arguments.contains("--seed-slice3-history"),
            seedHistoryEventGrouping: arguments.contains("--seed-history-event-grouping"),
            seedActiveFastStart: Self.date(after: "--seed-active-fast-start", in: arguments),
            seedMultipleActiveFasts: arguments.contains("--seed-multiple-active-fasts"),
            seedUnknownProvenance: arguments.contains("--seed-unknown-provenance")
        )
        commands = Self.commandConfiguration(from: arguments)
        liveActivityAdapter = Self.liveActivityAdapterConfiguration(from: arguments)
        simulatePersistenceBootstrapFailure = arguments.contains(
            "--simulate-persistence-bootstrap-failure"
        )
        suppressAutomaticLiveActivityOffer = arguments.contains(
            "--suppress-automatic-live-activity-offer"
        )
    }

    private static func commandConfiguration(from arguments: [String]) -> ApplicationCommandConfiguration {
        ApplicationCommandConfiguration(
            simulateFastSaveFailure: arguments.contains("--simulate-fast-save-failure"),
            simulateFastHistoryFailure: arguments.contains("--simulate-fast-history-failure"),
            simulateFoodSaveFailure: arguments.contains("--simulate-food-save-failure"),
            simulateDrinkSaveFailure: arguments.contains("--simulate-drink-save-failure"),
            simulateGoalSaveFailure: arguments.contains("--simulate-goal-save-failure"),
            simulateLiveActivitySettingsSaveFailure: arguments.contains(
                "--simulate-live-activity-settings-save-failure"
            ),
            simulateDeleteAllFailure: arguments.contains("--simulate-delete-all-failure")
        )
    }

    private static func liveActivityAdapterConfiguration(
        from arguments: [String]
    ) -> LiveActivityAdapterConfiguration {
        let availability: LiveActivityAvailability = if arguments.contains(
            "--simulate-live-activity-unsupported"
        ) {
            .unsupported
        } else if arguments.contains("--simulate-live-activity-disabled") {
            .disabled
        } else {
            .enabled
        }
        return .deterministic(
            availability: availability,
            failRequests: arguments.contains("--simulate-live-activity-request-failure"),
            failEnds: arguments.contains("--simulate-live-activity-hide-failure")
        )
    }

    private static func date(after option: String, in arguments: [String]) -> Date? {
        guard let index = arguments.firstIndex(of: option),
              arguments.indices.contains(index + 1),
              let interval = TimeInterval(arguments[index + 1])
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
