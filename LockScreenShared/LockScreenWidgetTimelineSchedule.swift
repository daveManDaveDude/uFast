import Foundation

/// The bounded set of fixed-value dates supplied to all active-fast widgets.
///
/// WidgetKit remains responsible for rendering date-relative progress between
/// entries. These values only advance at a calm cadence and are never
/// persisted or written back to the app's authoritative store.
struct LockScreenWidgetTimelineSchedule: Equatable, Sendable {
    static let cadence: TimeInterval = 5 * 60
    static let horizon: TimeInterval = 2 * 60 * 60

    let dates: [Date]
    let reloadDate: Date

    static func make(
        projectionResult: Result<ActiveFastWidgetProjection?, Error>,
        now: Date
    ) -> Self {
        guard case let .success(projection?) = projectionResult else {
            return fallback(now: now)
        }

        do {
            try projection.validate(now: now)
        } catch {
            return fallback(now: now)
        }

        let horizonDate = now.addingTimeInterval(horizon)
        let cadenceEntries = (0 ... Int(horizon / cadence)).map { index in
            now.addingTimeInterval(TimeInterval(index) * cadence)
        }
        var dates = cadenceEntries

        let shouldInsertTarget = projection.targetDate > now
            && projection.targetDate <= horizonDate
            && !dates.contains(projection.targetDate)
        if shouldInsertTarget {
            dates.append(projection.targetDate)
        }

        return Self(
            dates: dates.sorted(),
            reloadDate: horizonDate
        )
    }

    private static func fallback(now: Date) -> Self {
        Self(
            dates: [now],
            reloadDate: now.addingTimeInterval(cadence)
        )
    }
}
