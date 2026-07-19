import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query private var settingsRecords: [AppSettingsRecord]

    var body: some View {
        if settingsRecords.contains(where: \.hasCompletedOnboarding) {
            RootTabView()
        } else {
            FastingGoalOnboardingView()
        }
    }
}
