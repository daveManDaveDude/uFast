import Foundation

struct ActiveFastPresentation: Equatable, Sendable {
    let elapsedAccessibilityText: String?
    let elapsedText: String?
    let targetDate: Date
    let progress: Double
    let progressPercentage: Int
    let hasReachedGoal: Bool

    init(
        startDate: Date,
        targetDate: Date,
        now: Date
    ) {
        let goalDuration = targetDate.timeIntervalSince(startDate)
        let elapsedDuration = now.timeIntervalSince(startDate)

        self.targetDate = targetDate

        guard elapsedDuration >= 0 else {
            elapsedAccessibilityText = nil
            elapsedText = nil
            progress = 0
            progressPercentage = 0
            hasReachedGoal = false
            return
        }

        let clampedProgress = min(max(elapsedDuration / goalDuration, 0), 1)
        elapsedAccessibilityText = ActiveElapsedTimeFormatter.accessibilityString(
            from: elapsedDuration
        )
        elapsedText = ActiveElapsedTimeFormatter.string(from: elapsedDuration)
        progress = clampedProgress
        progressPercentage = Int((clampedProgress * 100).rounded(.down))
        hasReachedGoal = elapsedDuration >= goalDuration
    }

    func progressAccessibilityValue(goal: FastingGoal) -> String {
        "\(progressPercentage) percent of \(goal.hours)-hour goal"
    }
}

enum ActiveElapsedTimeFormatter {
    static func string(from duration: TimeInterval) -> String {
        let completedSeconds = max(Int(duration), 0)
        let days = completedSeconds / (24 * 60 * 60)
        let hours = completedSeconds % (24 * 60 * 60) / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60
        let seconds = completedSeconds % 60

        if days > 0 {
            return "\(days)d \(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(seconds))"
        }

        return "\(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(seconds))"
    }

    static func accessibilityString(from duration: TimeInterval) -> String {
        let completedSeconds = max(Int(duration), 0)
        let days = completedSeconds / (24 * 60 * 60)
        let hours = completedSeconds % (24 * 60 * 60) / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60
        let seconds = completedSeconds % 60
        var components: [String] = []

        if days > 0 {
            components.append(component(days, singular: "day", plural: "days"))
        }
        if hours > 0 || days > 0 {
            components.append(component(hours, singular: "hour", plural: "hours"))
        }
        if minutes > 0 || hours > 0 || days > 0 {
            components.append(component(minutes, singular: "minute", plural: "minutes"))
        }
        components.append(component(seconds, singular: "second", plural: "seconds"))

        return components.joined(separator: " ")
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private static func component(
        _ value: Int,
        singular: String,
        plural: String
    ) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}

enum ElapsedTimeFormatter {
    static func string(from duration: TimeInterval) -> String {
        let completedMinutes = max(Int(duration / 60), 0)

        guard completedMinutes > 0 else {
            return "Less than 1 minute"
        }

        let days = completedMinutes / (24 * 60)
        let hours = completedMinutes % (24 * 60) / 60
        let minutes = completedMinutes % 60
        var components: [String] = []

        if days > 0 {
            components.append(component(days, singular: "day", plural: "days"))
        }
        if hours > 0 {
            components.append(component(hours, singular: "hour", plural: "hours"))
        }
        if minutes > 0 {
            components.append(component(minutes, singular: "minute", plural: "minutes"))
        }

        return components.joined(separator: " ")
    }

    private static func component(
        _ value: Int,
        singular: String,
        plural: String
    ) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}
