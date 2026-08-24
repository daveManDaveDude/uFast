import Foundation

struct DevelopmentFixtureConfiguration: Equatable {
    var resetData = false
    var seedOnboarded = false
    var seedSlice3History = false
    var seedHistoryEventGrouping = false
    var seedHistoryMidnightSeam = false
    var seedHistoryMidnightSeamExtended = false
    var seedActiveFastStart: Date?
    var seedLiveActivityRecovery = false
    var seedMultipleActiveFasts = false
    var seedUnknownProvenance = false
    var seedFavouritePopulated = false
    var seedFavouriteDuplicateName = false
    var seedFavouriteValidation = false
    var seedCaloricFavouriteActiveFast = false
    var seedInferredFast = false
    var seedTodayMultiYear = false
    var seedCaloricBoundaryMultiYear = false

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
    let pseudolocalizationEnabled: Bool
    let fixedNow: Date?
    let fixtures: DevelopmentFixtureConfiguration
    let commands: ApplicationCommandConfiguration
    let liveActivityAdapter: LiveActivityAdapterConfiguration
    let liveActivityBuildIdentity: LiveActivityBuildIdentity?
    let simulatePersistenceBootstrapFailure: Bool
    let suppressAutomaticLiveActivityOffer: Bool
    let startsOnHistory: Bool
    let historyMotionRetryFixture: Bool

    static func current() -> Self {
        Self(arguments: ProcessInfo.processInfo.arguments)
    }

    // swiftlint:disable:next function_body_length
    init(arguments: [String]) {
        let isUITesting = arguments.contains("--ui-testing")
        self.isUITesting = isUITesting
        guard isUITesting else {
            pseudolocalizationEnabled = false
            fixedNow = nil
            fixtures = .disabled
            commands = .init()
            liveActivityAdapter = .activityKit
            liveActivityBuildIdentity = LiveActivityBuildIdentity.production()
            simulatePersistenceBootstrapFailure = false
            suppressAutomaticLiveActivityOffer = false
            startsOnHistory = false
            historyMotionRetryFixture = false
            return
        }

        pseudolocalizationEnabled = arguments.contains("--ui-testing-pseudolocalization")
        fixedNow = Self.date(after: "--fixed-now", in: arguments)
        fixtures = DevelopmentFixtureConfiguration(
            resetData: arguments.contains("--reset-data"),
            seedOnboarded: arguments.contains("--seed-onboarded"),
            seedSlice3History: arguments.contains("--seed-slice3-history"),
            seedHistoryEventGrouping: arguments.contains("--seed-history-event-grouping"),
            seedHistoryMidnightSeam: arguments.contains("--seed-history-midnight-seam"),
            seedHistoryMidnightSeamExtended: arguments.contains(
                "--seed-history-midnight-seam-extended"
            ),
            seedActiveFastStart: Self.date(after: "--seed-active-fast-start", in: arguments),
            seedLiveActivityRecovery: arguments.contains("--seed-live-activity-recovery"),
            seedMultipleActiveFasts: arguments.contains("--seed-multiple-active-fasts"),
            seedUnknownProvenance: arguments.contains("--seed-unknown-provenance"),
            seedFavouritePopulated: arguments.contains("--seed-favourite-populated"),
            seedFavouriteDuplicateName: arguments.contains("--seed-favourite-duplicate-name"),
            seedFavouriteValidation: arguments.contains("--seed-favourite-validation"),
            seedCaloricFavouriteActiveFast: arguments.contains("--seed-caloric-favourite-active-fast"),
            seedInferredFast: arguments.contains("--seed-inferred-fast"),
            seedTodayMultiYear: arguments.contains("--seed-today-multi-year"),
            seedCaloricBoundaryMultiYear: arguments.contains(
                "--seed-caloric-boundary-multi-year"
            )
        )
        commands = Self.commandConfiguration(from: arguments)
        liveActivityAdapter = Self.liveActivityAdapterConfiguration(from: arguments)
        liveActivityBuildIdentity = Self.liveActivityBuildIdentity(from: arguments)
        simulatePersistenceBootstrapFailure = arguments.contains(
            "--simulate-persistence-bootstrap-failure"
        )
        suppressAutomaticLiveActivityOffer = arguments.contains(
            "--suppress-automatic-live-activity-offer"
        )
        startsOnHistory = arguments.contains("--ui-testing-start-history")
        historyMotionRetryFixture = arguments.contains("--ui-testing-history-retry-fixture")
    }

    private static func commandConfiguration(from arguments: [String]) -> ApplicationCommandConfiguration {
        ApplicationCommandConfiguration(
            simulateFastSaveFailure: arguments.contains("--simulate-fast-save-failure"),
            simulateFastHistoryFailure: arguments.contains("--simulate-fast-history-failure"),
            simulateFoodSaveFailure: arguments.contains("--simulate-food-save-failure"),
            simulateDrinkSaveFailure: arguments.contains("--simulate-drink-save-failure"),
            simulateFavouriteSaveFailure: arguments.contains("--simulate-favourite-save-failure"),
            simulateGoalSaveFailure: arguments.contains("--simulate-goal-save-failure"),
            simulateLiveActivitySettingsSaveFailure: arguments.contains(
                "--simulate-live-activity-settings-save-failure"
            ),
            simulateInferredFastDetectionSaveFailure: arguments.contains(
                "--simulate-inferred-fast-detection-save-failure"
            ),
            simulateDeleteAllFailure: arguments.contains("--simulate-delete-all-failure"),
            simulateBoundaryReconciliationFailure: arguments.contains(
                "--simulate-caloric-boundary-reconciliation-failure"
            )
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

    private static func liveActivityBuildIdentity(
        from arguments: [String]
    ) -> LiveActivityBuildIdentity? {
        let defaultIdentity = LiveActivityBuildIdentity.deterministic()
        let releaseVersion = string(after: "--live-activity-release", in: arguments)
            ?? defaultIdentity.releaseVersion
        let buildNumber = string(after: "--live-activity-build", in: arguments)
            ?? defaultIdentity.buildNumber
        let identity = LiveActivityBuildIdentity(
            releaseVersion: releaseVersion,
            buildNumber: buildNumber
        )
        return identity.isValid ? identity : nil
    }

    private static func date(after option: String, in arguments: [String]) -> Date? {
        guard let index = arguments.firstIndex(of: option),
              arguments.indices.contains(index + 1),
              let interval = TimeInterval(arguments[index + 1])
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func string(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }
}
