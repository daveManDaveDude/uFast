import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable opening_brace trailing_comma

private enum SimulatedPersistenceBootstrapError: Error {
    case requested
}

@main
struct UFastApp: App {
    private let persistence: PersistenceBootstrapResult
    private let clock: any AppClock
    private let liveActivityCoordinator: ActiveFastLiveActivityCoordinator?
    private let applicationCommands: ApplicationCommands?
    private let suppressAutomaticLiveActivityOffer: Bool

    init() {
        let launchConfiguration = AppLaunchConfiguration.current()
        let configuredClock = AppClockConfiguration.clock(fixedNow: launchConfiguration.fixedNow)
        clock = configuredClock
        suppressAutomaticLiveActivityOffer = launchConfiguration.suppressAutomaticLiveActivityOffer
        let bootstrap = PersistenceBootstrapResult.open {
            if launchConfiguration.simulatePersistenceBootstrapFailure {
                throw SimulatedPersistenceBootstrapError.requested
            }
            return try PersistenceContainer.make()
        }

        switch bootstrap {
        case let .ready(container):
            do {
                try SwiftDataSettingsStore(modelContext: container.mainContext).prepareForUse()
                try Self.resetDataIfRequested(
                    in: container,
                    clock: configuredClock,
                    configuration: launchConfiguration.fixtures
                )
                WidgetProjectionSupport.synchronize(in: container, now: configuredClock.now)
                persistence = .ready(container)
                let coordinator = Self.makeLiveActivityCoordinator(
                    container: container,
                    clock: configuredClock,
                    configuration: launchConfiguration.liveActivityAdapter,
                    buildIdentity: launchConfiguration.liveActivityBuildIdentity
                )
                liveActivityCoordinator = coordinator
                applicationCommands = ApplicationCommands(
                    modelContext: container.mainContext,
                    clock: configuredClock,
                    projectionCoordinator: PostCommitProjectionCoordinator(
                        liveActivityCoordinator: coordinator
                    ),
                    configuration: launchConfiguration.commands
                )
            } catch {
                persistence = .unavailable(
                    PersistenceBootstrapFailure(
                        diagnosticDescription: String(describing: error)
                    )
                )
                liveActivityCoordinator = nil
                applicationCommands = nil
            }
        case let .unavailable(failure):
            persistence = .unavailable(failure)
            liveActivityCoordinator = nil
            applicationCommands = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case let .ready(container):
                AppRootView(
                    clock: clock,
                    liveActivityCoordinator: liveActivityCoordinator,
                    applicationCommands: applicationCommands,
                    suppressAutomaticLiveActivityOffer: suppressAutomaticLiveActivityOffer
                )
                .modelContainer(container)
            case .unavailable:
                PersistenceUnavailableView()
            }
        }
    }

    private static func resetDataIfRequested(
        in container: ModelContainer,
        clock: any AppClock,
        configuration: DevelopmentFixtureConfiguration
    ) throws {
        try UITestDataReset.runIfRequested(
            in: container,
            configuration: configuration,
            now: clock.now,
            clock: clock
        )
    }

    private static func makeLiveActivityCoordinator(
        container: ModelContainer,
        clock: any AppClock,
        configuration: LiveActivityAdapterConfiguration,
        buildIdentity: LiveActivityBuildIdentity?
    ) -> ActiveFastLiveActivityCoordinator {
        let client: any LiveActivityClient
        switch configuration {
        case .activityKit:
            client = ActivityKitLiveActivityClient()
        case let .deterministic(availability, failRequests, failEnds):
            let fake = DeterministicLiveActivityClient(availability: availability)
            fake.failRequests = failRequests
            fake.failEnds = failEnds
            client = fake
        }

        return ActiveFastLiveActivityCoordinator(
            clock: clock,
            client: client,
            lifecycleStore: UserDefaultsLiveActivityLifecycleStore(),
            resolveActiveFast: {
                let context = container.mainContext
                guard let fast = try ActiveFastAuthority.fetch(in: context) else {
                    return nil
                }
                let goal = try SwiftDataSettingsStore(modelContext: context)
                    .authoritativeRecord()?.fastingGoal ?? .default
                return ActiveFastActivitySource(
                    activeRecordIdentifier: fast.id,
                    startDate: fast.startDate,
                    targetDate: fast.startDate.addingTimeInterval(
                        TimeInterval(goal.hours * 60 * 60)
                    ),
                    goalHours: goal.hours
                )
            },
            resolveAutomaticPreference: {
                let context = container.mainContext
                return (try? SwiftDataSettingsStore(modelContext: context)
                    .authoritativeRecord()?.automaticLiveActivityPreference) ?? .disabled
            },
            installedBuildIdentity: buildIdentity
        )
    }
}
