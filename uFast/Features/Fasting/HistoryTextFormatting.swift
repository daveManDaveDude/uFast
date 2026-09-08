import Foundation

enum HistoryTextFormatting {
    static func activeDisplay(seconds: TimeInterval, resolver: AppTextResolver) -> String {
        let value = HistoryDurationValue(totalSeconds: completedSecondCount(seconds))

        if value.days > 0 {
            let dayAbbreviation = resolver(.historyCopy(.durationDayAbbreviation))
            return "\(value.days)\(dayAbbreviation) \(twoDigits(value.hours)):"
                + "\(twoDigits(value.minutes)):\(twoDigits(value.seconds))"
        }

        return "\(twoDigits(value.hours)):\(twoDigits(value.minutes)):\(twoDigits(value.seconds))"
    }

    static func compactDuration(
        _ spec: HistoryDurationSpec,
        at now: Date,
        resolver: AppTextResolver
    ) -> String {
        let seconds = spec.completedSeconds(at: now)
        guard spec.isCurrent else {
            return compactCompleted(seconds: seconds, resolver: resolver)
        }
        return activeDisplay(seconds: TimeInterval(seconds), resolver: resolver)
    }

    static func activeTemplate(dayDigits: Int, resolver: AppTextResolver) -> String {
        let day = dayDigits > 0
            ? String(repeating: "8", count: dayDigits)
            + resolver(.historyCopy(.durationDayAbbreviation)) + " "
            : ""
        return day + "88:88:88"
    }

    static func compactCompletedTemplate(dayDigits: Int, resolver: AppTextResolver) -> String {
        let day = dayDigits > 0
            ? String(repeating: "8", count: dayDigits)
            + " " + resolver(.historyCopy(.durationDayAbbreviation)) + " "
            : ""
        return day + "88 "
            + resolver(.historyCopy(.durationHourAbbreviation)) + " 88 "
            + resolver(.historyCopy(.durationMinuteAbbreviation))
    }

    private static func compactCompleted(seconds: Int, resolver: AppTextResolver) -> String {
        let completedMinutes = seconds / 60
        guard completedMinutes > 0 else {
            return resolver(.historyCopy(.durationLessThanMinute))
        }

        let days = completedMinutes / (24 * 60)
        let hours = completedMinutes % (24 * 60) / 60
        let minutes = completedMinutes % 60
        var components: [String] = []
        if days > 0 {
            components.append("\(days) \(resolver(.historyCopy(.durationDayAbbreviation)))")
        }
        if hours > 0 {
            components.append("\(hours) \(resolver(.historyCopy(.durationHourAbbreviation)))")
        }
        if minutes > 0 {
            components.append("\(minutes) \(resolver(.historyCopy(.durationMinuteAbbreviation)))")
        }
        return components.joined(separator: resolver(.historyCopy(.separatorSpace)))
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
        let completedMinutes = completedSecondCount(seconds) / 60
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
        let value = HistoryDurationValue(totalSeconds: completedSecondCount(seconds))
        var components: [String] = []

        if value.days > 0 {
            components.append(resolver(.durationComponent(value: value.days, unit: .day)))
        }
        if value.hours > 0 || value.days > 0 {
            components.append(resolver(.durationComponent(value: value.hours, unit: .hour)))
        }
        if value.minutes > 0 || value.hours > 0 || value.days > 0 {
            components.append(resolver(.durationComponent(value: value.minutes, unit: .minute)))
        }
        components.append(resolver(.durationComponent(value: value.seconds, unit: .second)))

        return components.joined(separator: resolver(.historyCopy(.separatorSpace)))
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private static func completedSecondCount(_ seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let completed = seconds.rounded(.down)
        guard completed < TimeInterval(Int.max) else { return Int.max }
        return Int(completed)
    }
}
