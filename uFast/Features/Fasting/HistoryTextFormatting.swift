import Foundation

enum HistoryTextFormatting {
    static func activeDisplay(seconds: TimeInterval, resolver: AppTextResolver) -> String {
        let completedSeconds = max(Int(seconds), 0)
        let days = completedSeconds / (24 * 60 * 60)
        let hours = completedSeconds % (24 * 60 * 60) / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60
        let seconds = completedSeconds % 60

        if days > 0 {
            let dayAbbreviation = resolver(.historyCopy(.durationDayAbbreviation))
            return "\(days)\(dayAbbreviation) \(twoDigits(hours)):"
                + "\(twoDigits(minutes)):\(twoDigits(seconds))"
        }

        return "\(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(seconds))"
    }

    static func dateTime(
        _ date: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var style = Date.FormatStyle.dateTime
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
            .locale(locale)
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    static func date(
        _ date: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var style = Date.FormatStyle.dateTime
            .month(.abbreviated)
            .day()
            .year()
            .locale(locale)
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    static func time(
        _ date: Date,
        calendar: Calendar,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        var style = Date.FormatStyle.dateTime
            .hour()
            .minute()
            .locale(locale)
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    static func duration(
        from startDate: Date,
        to endDate: Date,
        resolver: AppTextResolver
    ) -> String {
        duration(seconds: endDate.timeIntervalSince(startDate), resolver: resolver)
    }

    static func duration(seconds: TimeInterval, resolver: AppTextResolver) -> String {
        let completedMinutes = max(Int(seconds / 60), 0)
        guard completedMinutes > 0 else {
            return resolver(.historyCopy(.durationLessThanMinute))
        }

        let days = completedMinutes / (24 * 60)
        let hours = completedMinutes % (24 * 60) / 60
        let minutes = completedMinutes % 60
        var components: [String] = []

        if days > 0 {
            components.append(resolver(.durationComponent(value: days, unit: .day)))
        }
        if hours > 0 {
            components.append(resolver(.durationComponent(value: hours, unit: .hour)))
        }
        if minutes > 0 {
            components.append(resolver(.durationComponent(value: minutes, unit: .minute)))
        }

        return components.joined(separator: resolver(.historyCopy(.separatorSpace)))
    }

    static func activeAccessibility(seconds: TimeInterval, resolver: AppTextResolver) -> String {
        let completedSeconds = max(Int(seconds), 0)
        let days = completedSeconds / (24 * 60 * 60)
        let hours = completedSeconds % (24 * 60 * 60) / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60
        let seconds = completedSeconds % 60
        var components: [String] = []

        if days > 0 {
            components.append(resolver(.durationComponent(value: days, unit: .day)))
        }
        if hours > 0 || days > 0 {
            components.append(resolver(.durationComponent(value: hours, unit: .hour)))
        }
        if minutes > 0 || hours > 0 || days > 0 {
            components.append(resolver(.durationComponent(value: minutes, unit: .minute)))
        }
        components.append(resolver(.durationComponent(value: seconds, unit: .second)))

        return components.joined(separator: resolver(.historyCopy(.separatorSpace)))
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
