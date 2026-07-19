import Foundation

enum AppDestination: String, CaseIterable, Identifiable {
    case today
    case history
    case progress
    case settings

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .progress: "Progress"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .progress: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
