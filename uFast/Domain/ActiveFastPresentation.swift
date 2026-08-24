import Foundation

struct ActiveFastPresentation: Equatable, Sendable {
    let elapsedDuration: TimeInterval?
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
            self.elapsedDuration = nil
            elapsedText = nil
            progress = 0
            progressPercentage = 0
            hasReachedGoal = false
            return
        }

        let clampedProgress = min(max(elapsedDuration / goalDuration, 0), 1)
        self.elapsedDuration = elapsedDuration
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

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
