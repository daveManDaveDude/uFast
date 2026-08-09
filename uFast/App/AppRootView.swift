import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRecords: [AppSettingsRecord]
    let clock: any AppClock
    let liveActivityCoordinator: ActiveFastLiveActivityCoordinator?

    init(
        clock: any AppClock = SystemAppClock(),
        liveActivityCoordinator: ActiveFastLiveActivityCoordinator? = nil
    ) {
        self.clock = clock
        self.liveActivityCoordinator = liveActivityCoordinator
    }

    var body: some View {
        Group {
            if settingsRecords.contains(where: \.hasCompletedOnboarding) {
                RootTabView(clock: clock)
            } else {
                FastingGoalOnboardingView()
            }
        }
        .environment(\.liveActivityCoordinator, liveActivityCoordinator)
        .task {
            _ = await liveActivityCoordinator?.reconcile()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { _ = await liveActivityCoordinator?.reconcile() }
        }
    }
}
