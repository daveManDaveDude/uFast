import SwiftUI

struct RootTabView: View {
    @State private var selection: AppDestination
    let clock: any AppClock

    init(
        clock: any AppClock = SystemAppClock(),
        initialSelection: AppDestination = .today
    ) {
        self.clock = clock
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: .today) {
                destinationView(.today)
            } label: {
                tabLabel(.today)
            }
            .accessibilityIdentifier(AppDestination.today.accessibilityIdentifier)

            Tab(value: .history) {
                destinationView(.history)
            } label: {
                tabLabel(.history)
            }
            .accessibilityIdentifier(AppDestination.history.accessibilityIdentifier)

            Tab(value: .settings) {
                destinationView(.settings)
            } label: {
                tabLabel(.settings)
            }
            .accessibilityIdentifier(AppDestination.settings.accessibilityIdentifier)
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
            TodayFeatureHost(clock: clock)
        case .settings:
            SettingsFeatureHost()
        case .history:
            HistoryFeatureHost(
                clock: clock,
                isTabSelected: selection == .history,
                onSelectToday: { selection = .today }
            )
        }
    }

    private func tabLabel(_ destination: AppDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage)
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewFixtures.modelContainer)
}
