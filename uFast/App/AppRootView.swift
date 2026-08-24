import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRecords: [AppSettingsRecord]
    let clock: any AppClock
    let liveActivityCoordinator: ActiveFastLiveActivityCoordinator?
    let applicationCommands: ApplicationCommands?
    let appTextResolver: AppTextResolver
    let suppressAutomaticLiveActivityOffer: Bool
    let initialDestination: AppDestination

    init(
        clock: any AppClock = SystemAppClock(),
        liveActivityCoordinator: ActiveFastLiveActivityCoordinator? = nil,
        applicationCommands: ApplicationCommands? = nil,
        appTextResolver: AppTextResolver = AppTextResolver(),
        suppressAutomaticLiveActivityOffer: Bool = false,
        initialDestination: AppDestination = .today
    ) {
        self.clock = clock
        self.liveActivityCoordinator = liveActivityCoordinator
        self.applicationCommands = applicationCommands
        self.appTextResolver = appTextResolver
        self.suppressAutomaticLiveActivityOffer = suppressAutomaticLiveActivityOffer
        self.initialDestination = initialDestination
    }

    var body: some View {
        Group {
            if settingsRecords.count > 1 {
                DataIntegrityUnavailableView()
            } else if settingsRecords.count == 1, settingsRecords[0].hasCompletedOnboarding {
                RootTabView(clock: clock, initialSelection: initialDestination)
            } else {
                FastingGoalOnboardingView()
            }
        }
        .environment(\.liveActivityCoordinator, liveActivityCoordinator)
        .environment(\.applicationCommands, applicationCommands)
        .environment(\.appTextResolver, appTextResolver)
        .environment(
            \.historyPresentationInvalidation,
            applicationCommands?.historyPresentationInvalidation
        )
        .environment(\.suppressAutomaticLiveActivityOffer, suppressAutomaticLiveActivityOffer)
        .task {
            _ = await liveActivityCoordinator?.didBecomeActive()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { _ = await liveActivityCoordinator?.didBecomeActive() }
            } else {
                liveActivityCoordinator?.didBecomeInactive()
            }
        }
    }
}

private struct DataIntegrityUnavailableView: View {
    @Environment(\.appTextResolver) private var textResolver

    var body: some View {
        VStack(spacing: 12) {
            Text(textResolver(.localDataIntegrityTitle))
                .font(.title2.weight(.semibold))
            Text(textResolver(.localDataIntegrityMessage))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("data-integrity.unavailable")
    }
}
