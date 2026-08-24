import Foundation

/// Deterministic timing seam for the Today calendar-day task.
struct TodayRolloverSchedule: Equatable {
    let end: Date

    init(interval: TodayCalendarInterval) {
        end = interval.end
    }

    func nanosecondsUntil(now: Date) -> UInt64 {
        guard end > now else { return 0 }
        return UInt64((end.timeIntervalSince(now) * 1_000_000_000).rounded(.up))
    }

    func shouldRefresh(now: Date, taskIsCancelled: Bool) -> Bool {
        !taskIsCancelled && now >= end
    }
}
