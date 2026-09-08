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

/// A process-local clock used only by deterministic UI tests. It deliberately
/// remains an AppClock so production presentation code cannot accidentally
/// depend on wall time or a test-only API.
public final class MutableAppClock: AppClock, @unchecked Sendable {
    private let lock = NSLock()
    private var storedNow: Date

    public init(now: Date) {
        storedNow = now
    }

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return storedNow
    }

    public func setNow(_ now: Date) {
        lock.lock()
        storedNow = now
        lock.unlock()
        NotificationCenter.default.post(name: .uFastTestClockDidAdvance, object: self)
    }

    public func advance(by interval: TimeInterval) {
        setNow(now.addingTimeInterval(interval))
    }
}

public extension Notification.Name {
    static let uFastTestClockDidAdvance = Notification.Name("uFast.testClockDidAdvance")
}

public enum AppClockConfiguration {
    public static func clock(fixedNow: Date?, mutableForTesting: Bool = false) -> any AppClock {
        if mutableForTesting, let fixedNow {
            return MutableAppClock(now: fixedNow)
        }
        if let fixedNow {
            return FixedAppClock(now: fixedNow)
        }
        return SystemAppClock()
    }
}
