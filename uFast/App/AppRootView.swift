import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query private var settingsRecords: [AppSettingsRecord]
    let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    var body: some View {
        if settingsRecords.contains(where: \.hasCompletedOnboarding) {
            RootTabView(clock: clock)
        } else {
            FastingGoalOnboardingView()
        }
    }
}
