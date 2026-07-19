import SwiftUI

struct RootTabView: View {
    @State private var selection = AppDestination.today

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
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .today:
            TodayGoalView()
        case .settings:
            SettingsView()
        case .history, .progress:
            DestinationPlaceholderView(destination: destination)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewFixtures.modelContainer)
}
