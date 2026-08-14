import Foundation

public protocol AppClock: Sendable {
    var now: Date { get }
}

public struct SystemAppClock: AppClock {
    public init() {}

    public var now: Date {
        Date()
    }
}

public struct FixedAppClock: AppClock {
    public let now: Date

    public init(now: Date) {
        self.now = now
    }
}

public enum AppClockConfiguration {
    public static func clock(fixedNow: Date?) -> any AppClock {
        fixedNow.map(FixedAppClock.init(now:)) ?? SystemAppClock()
    }
}
