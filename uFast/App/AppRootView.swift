import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRecords: [AppSettingsRecord]
    let clock: any AppClock
    let liveActivityCoordinator: ActiveFastLiveActivityCoordinator?
    let applicationCommands: ApplicationCommands?
    let suppressAutomaticLiveActivityOffer: Bool

    init(
        clock: any AppClock = SystemAppClock(),
        liveActivityCoordinator: ActiveFastLiveActivityCoordinator? = nil,
        applicationCommands: ApplicationCommands? = nil,
        suppressAutomaticLiveActivityOffer: Bool = false
    ) {
        self.clock = clock
        self.liveActivityCoordinator = liveActivityCoordinator
        self.applicationCommands = applicationCommands
        self.suppressAutomaticLiveActivityOffer = suppressAutomaticLiveActivityOffer
    }

    var body: some View {
        Group {
            if settingsRecords.count > 1 {
                DataIntegrityUnavailableView()
            } else if settingsRecords.count == 1, settingsRecords[0].hasCompletedOnboarding {
                RootTabView(clock: clock)
            } else {
                FastingGoalOnboardingView()
            }
        }
        .environment(\.liveActivityCoordinator, liveActivityCoordinator)
        .environment(\.applicationCommands, applicationCommands)
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
    var body: some View {
        VStack(spacing: 12) {
            Text("Your local data needs attention")
                .font(.title2.weight(.semibold))
            Text("uFast found conflicting local settings and did not choose between them. Nothing was changed.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("data-integrity.unavailable")
    }
}
