import SwiftData
import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command function_body_length
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
    private let appTextResolver: AppTextResolver
    private let suppressAutomaticLiveActivityOffer: Bool
    private let initialDestination: AppDestination

    init() {
        let launchConfiguration = AppLaunchConfiguration.current()
        appTextResolver = AppTextResolver(
            pseudolocalizationEnabled: launchConfiguration.pseudolocalizationEnabled
        )
        let configuredClock = AppClockConfiguration.clock(fixedNow: launchConfiguration.fixedNow)
        clock = configuredClock
        suppressAutomaticLiveActivityOffer = launchConfiguration.suppressAutomaticLiveActivityOffer
        initialDestination = launchConfiguration.startsOnHistory ? .history : .today
        let diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()
        let bootstrap = PersistenceBootstrapResult.open(
            containerFactory: {
                if launchConfiguration.simulatePersistenceBootstrapFailure {
                    throw SimulatedPersistenceBootstrapError.requested
                }
                return try PersistenceContainer.make(
                    diagnosticSink: diagnosticSink,
                    now: configuredClock.now,
                    simulateMigrationFailure: launchConfiguration.simulateFoodFavouriteMigrationFailure
                )
            },
            diagnosticSink: diagnosticSink
        )

        switch bootstrap {
        case let .ready(container):
            do {
                let settingsStore = SwiftDataSettingsStore(
                    modelContext: container.mainContext,
                    diagnosticSink: diagnosticSink
                )
                try settingsStore.prepareForUse()
                let currentGoal = try settingsStore.authoritativeRecord()?.fastingGoal ?? .default
                _ = try CaloricBoundaryReconciler(
                    modelContext: container.mainContext,
                    currentGoal: currentGoal,
                    saveAction: launchConfiguration.commands.simulateBoundaryReconciliationFailure
                        ? { throw SimulatedPersistenceBootstrapError.requested }
                        : nil
                ).reconcile()
                _ = try InferredFastSuppressionStore(
                    modelContext: container.mainContext,
                    diagnosticSink: diagnosticSink
                ).reconcile(
                    currentGoal: currentGoal,
                    enabled: settingsStore.authoritativeRecord()?.inferredFastDetectionEnabled ?? false,
                    now: configuredClock.now,
                    updatedAt: configuredClock.now
                )
                try Self.resetDataIfRequested(
                    in: container,
                    clock: configuredClock,
                    configuration: launchConfiguration.fixtures
                )
                WidgetProjectionSupport.synchronize(
                    in: container,
                    now: configuredClock.now,
                    diagnosticSink: diagnosticSink
                )
                persistence = .ready(container)
                let coordinator = Self.makeLiveActivityCoordinator(
                    container: container,
                    clock: configuredClock,
                    configuration: launchConfiguration.liveActivityAdapter,
                    buildIdentity: launchConfiguration.liveActivityBuildIdentity,
                    diagnosticSink: diagnosticSink
                )
                liveActivityCoordinator = coordinator
                applicationCommands = ApplicationCommands(
                    modelContext: container.mainContext,
                    clock: configuredClock,
                    projectionCoordinator: PostCommitProjectionCoordinator(
                        liveActivityCoordinator: coordinator,
                        diagnosticSink: diagnosticSink
                    ),
                    configuration: launchConfiguration.commands,
                    diagnosticSink: diagnosticSink
                )
            } catch let error as SettingsStoreError {
                if case .conflictingAuthorities = error {
                    persistence = .unavailable(
                        PersistenceBootstrapFailure(
                            diagnosticDescription: String(describing: error)
                        )
                    )
                } else {
                    Self.record(.migrationFailed, to: diagnosticSink)
                    persistence = .unavailable(
                        PersistenceBootstrapFailure(
                            diagnosticDescription: String(describing: error)
                        )
                    )
                }
                liveActivityCoordinator = nil
                applicationCommands = nil
            } catch {
                Self.record(.migrationFailed, to: diagnosticSink)
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
                    appTextResolver: appTextResolver,
                    suppressAutomaticLiveActivityOffer: suppressAutomaticLiveActivityOffer,
                    initialDestination: initialDestination
                )
                .modelContainer(container)
            case .unavailable:
                PersistenceUnavailableView()
                    .environment(\.appTextResolver, appTextResolver)
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
        buildIdentity: LiveActivityBuildIdentity?,
        diagnosticSink: any DiagnosticEventSink
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
            installedBuildIdentity: buildIdentity,
            diagnosticSink: diagnosticSink
        )
    }

    private static func record(
        _ outcome: DiagnosticOutcome,
        to sink: any DiagnosticEventSink
    ) {
        guard let event = DiagnosticEvent(
            subsystem: .persistence,
            outcome: outcome,
            severity: .error
        ) else {
            return
        }
        sink.record(event)
    }
}
