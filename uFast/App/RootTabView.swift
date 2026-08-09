import SwiftUI

struct RootTabView: View {
    @State private var selection = AppDestination.today
    let clock: any AppClock

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppDestination.allCases) { destination in
                Tab(
                    destination.title,
                    systemImage: destination.systemImage,
                    value: destination
                ) {
                    destinationView(destination)
                }
                .accessibilityIdentifier(destination.accessibilityIdentifier)
            }
        }
        .tint(UFastTheme.action)
        .toolbarBackground(UFastTheme.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onOpenURL { url in
            guard ActiveFastActivityRoute.isCurrentFastURL(url) else { return }
            selection = .today
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .today:
            TodayGoalView(clock: clock)
        case .settings:
            SettingsView()
        case .history:
            HistoryView(
                clock: clock,
                isTabSelected: selection == .history,
                onSelectToday: { selection = .today }
            )
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewFixtures.modelContainer)
}
