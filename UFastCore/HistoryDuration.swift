import Foundation

public struct HistoryDurationValue: Equatable, Sendable {
    public static let maximumDayDigits = String(Int.max).count

    public let totalSeconds: Int
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    public init(totalSeconds: Int) {
        let clamped = max(totalSeconds, 0)
        self.totalSeconds = clamped
        days = clamped / (24 * 60 * 60)
        hours = clamped % (24 * 60 * 60) / (60 * 60)
        minutes = clamped % (60 * 60) / 60
        seconds = clamped % 60
    }

    public var dayDigits: Int {
        days == 0 ? 0 : String(days).count
    }
}

/// The value policy for a History duration. Completed intervals retain their
/// recorded end; current intervals resolve their end from the injected clock
/// and an optional derived cap.
public struct HistoryDurationSpec: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case completed
        case current(capDate: Date?)
    }

    public let startDate: Date
    public let endDate: Date
    public let mode: Mode

    public init(startDate: Date, endDate: Date, mode: Mode = .completed) {
        self.startDate = startDate
        self.endDate = endDate
        self.mode = mode
    }

    public static func completed(startDate: Date, endDate: Date) -> Self {
        Self(startDate: startDate, endDate: endDate, mode: .completed)
    }

    public static func current(startDate: Date, capDate: Date? = nil) -> Self {
        Self(startDate: startDate, endDate: startDate, mode: .current(capDate: capDate))
    }

    public var isCurrent: Bool {
        if case .current = mode {
            return true
        }
        return false
    }

    /// Completed values are stable snapshots; only current values need the
    /// injected clock observation used by the rendering leaf.
    public var observesClock: Bool {
        isCurrent
    }

    public var capDate: Date? {
        guard case let .current(capDate) = mode else { return nil }
        return capDate
    }

    public func resolvedEndDate(at now: Date) -> Date {
        guard isCurrent else { return endDate }
        return min(now, capDate ?? now)
    }

    public func completedSeconds(at now: Date) -> Int {
        let interval = resolvedEndDate(at: now).timeIntervalSince(startDate)
        guard interval.isFinite, interval > 0 else { return 0 }
        let completed = interval.rounded(.down)
        guard completed < TimeInterval(Int.max) else { return Int.max }
        return Int(completed)
    }

    public func completedMinutes(at now: Date) -> Int {
        completedSeconds(at: now) / 60
    }

    public func value(at now: Date) -> HistoryDurationValue {
        HistoryDurationValue(totalSeconds: completedSeconds(at: now))
    }
}
