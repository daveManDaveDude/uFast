import Foundation

enum AppDestination: String, CaseIterable, Identifiable {
    case today
    case history
    case settings

    var id: Self {
        self
    }

    var text: AppText {
        switch self {
        case .today: .tabToday
        case .history: .tabHistory
        case .settings: .tabSettings
        }
    }

    var title: String {
        String(localized: text.resource)
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
