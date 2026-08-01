import Foundation

enum AppDestination: String, CaseIterable, Identifiable {
    case today
    case history
    case settings

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
