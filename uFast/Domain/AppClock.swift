import Foundation

protocol AppClock: Sendable {
    var now: Date { get }
}

struct SystemAppClock: AppClock {
    var now: Date {
        Date()
    }
}

struct FixedAppClock: AppClock {
    let now: Date
}

enum AppClockConfiguration {
    static func clock(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any AppClock {
        guard arguments.contains("--ui-testing"),
              let argumentIndex = arguments.firstIndex(of: "--fixed-now"),
              arguments.indices.contains(argumentIndex + 1),
              let interval = TimeInterval(arguments[argumentIndex + 1])
        else {
            return SystemAppClock()
        }

        return FixedAppClock(now: Date(timeIntervalSince1970: interval))
    }
}
