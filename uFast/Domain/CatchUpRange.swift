import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable identifier_name

struct CatchUpRange: Equatable, Sendable {
    static let maximumDayCount = 7

    let firstDay: Date
    let lastDay: Date
    let interval: Range<Date>
    let days: [Date]

    var dayCount: Int {
        days.count
    }

    func contains(_ date: Date) -> Bool {
        interval.contains(date)
    }
}

enum CatchUpRangeError: Error, Equatable {
    case endBeforeStart
    case includesTodayOrFuture
    case moreThanSevenDays
    case unresolvedCalendarDay
}

enum CatchUpRangeResolver {
    static func defaultDates(now: Date, calendar: Calendar) throws -> (from: Date, to: Date) {
        let today = calendar.startOfDay(for: now)
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: today),
              let firstDay = calendar.date(
                  byAdding: .day,
                  value: -(CatchUpRange.maximumDayCount - 1),
                  to: lastDay
              )
        else {
            throw CatchUpRangeError.unresolvedCalendarDay
        }
        return (firstDay, lastDay)
    }

    static func resolve(
        from: Date,
        to: Date,
        now: Date,
        calendar: Calendar
    ) throws -> CatchUpRange {
        let firstDay = calendar.startOfDay(for: from)
        let lastDay = calendar.startOfDay(for: to)
        let today = calendar.startOfDay(for: now)

        guard lastDay >= firstDay else {
            throw CatchUpRangeError.endBeforeStart
        }
        guard lastDay < today else {
            throw CatchUpRangeError.includesTodayOrFuture
        }
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            throw CatchUpRangeError.unresolvedCalendarDay
        }

        var days: [Date] = []
        var day = firstDay
        while day < endExclusive, days.count <= CatchUpRange.maximumDayCount {
            days.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  nextDay > day
            else {
                throw CatchUpRangeError.unresolvedCalendarDay
            }
            day = nextDay
        }

        guard days.count <= CatchUpRange.maximumDayCount else {
            throw CatchUpRangeError.moreThanSevenDays
        }

        return CatchUpRange(
            firstDay: firstDay,
            lastDay: lastDay,
            interval: firstDay ..< endExclusive,
            days: days
        )
    }

    static func prefilledInstant(
        on day: Date,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: now)
        var components = calendar.dateComponents([.era, .year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        if let exact = calendar.date(from: components), calendar.isDate(exact, inSameDayAs: day) {
            return exact
        }

        let start = calendar.startOfDay(for: day)
        return calendar.nextDate(
            after: start,
            matching: DateComponents(hour: 12, minute: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ).flatMap { calendar.isDate($0, inSameDayAs: day) ? $0 : nil } ?? start
    }
}

enum HistoricalEventRangeValidator {
    static func contains(_ date: Date, allowedRange: Range<Date>) -> Bool {
        allowedRange.contains(date)
    }
}
