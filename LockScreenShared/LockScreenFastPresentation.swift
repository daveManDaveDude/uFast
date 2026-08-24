import Foundation

enum LockScreenPrivacyState: Equatable, Sendable {
    case protected
    case authenticated
}

enum LockScreenUnavailableReason: Equatable, Sendable {
    case noActiveFast
    case invalidProjection
    case unreadableProjection
    case futureStart
}

struct LockScreenActivePresentation: Equatable, Sendable {
    let startDate: Date
    let targetDate: Date
    let elapsedText: String
    let elapsedAccessibilityValue: String
    let progress: Double
    let progressPercentage: Int
    let progressAccessibilityValue: String
    let accessibilitySummary: String
    let targetText: String?
    let hasReachedGoal: Bool?
}

enum LockScreenFastPresentation: Equatable, Sendable {
    case active(LockScreenActivePresentation)
    case unavailable(reason: LockScreenUnavailableReason)

    static func make(
        projectionResult: Result<ActiveFastWidgetProjection?, Error>,
        now: Date,
        privacyState: LockScreenPrivacyState,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        textResolver: SystemSurfaceTextResolver? = nil
    ) -> Self {
        let projection: ActiveFastWidgetProjection

        switch projectionResult {
        case let .success(value):
            guard let value else {
                return .unavailable(reason: .noActiveFast)
            }
            projection = value
        case .failure:
            return .unavailable(reason: .unreadableProjection)
        }

        do {
            try projection.validate(now: now)
        } catch ActiveFastWidgetProjectionError.futureStart {
            return .unavailable(reason: .futureStart)
        } catch {
            return .unavailable(reason: .invalidProjection)
        }

        return .active(
            activePresentation(
                projection: projection,
                now: now,
                privacyState: privacyState,
                locale: locale,
                timeZone: timeZone,
                textResolver: textResolver
            )
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func activePresentation(
        projection: ActiveFastWidgetProjection,
        now: Date,
        privacyState: LockScreenPrivacyState,
        locale: Locale,
        timeZone: TimeZone,
        textResolver: SystemSurfaceTextResolver?
    ) -> LockScreenActivePresentation {
        let textResolver = textResolver ?? SystemSurfaceTextResolver(locale: locale)
        let elapsed = now.timeIntervalSince(projection.startDate)
        let goalDuration = projection.targetDate.timeIntervalSince(projection.startDate)
        let progress = min(max(elapsed / goalDuration, 0), 1)
        let percentage = Int((progress * 100).rounded(.down))
        let elapsedAccessibilityValue = LockScreenElapsedFormatter.accessibilityString(
            from: elapsed,
            privacyState: privacyState,
            resolver: textResolver
        )
        let progressAccessibilityValue = textResolver(
            .progress(percent: percentage, goalHours: projection.goalHours)
        )
        let accessibilitySummary = textResolver(
            .lockSummary(
                elapsed: elapsedAccessibilityValue,
                progress: progressAccessibilityValue
            )
        )

        return LockScreenActivePresentation(
            startDate: projection.startDate,
            targetDate: projection.targetDate,
            elapsedText: LockScreenElapsedFormatter.string(
                from: elapsed,
                privacyState: privacyState
            ),
            elapsedAccessibilityValue: elapsedAccessibilityValue,
            progress: progress,
            progressPercentage: percentage,
            progressAccessibilityValue: progressAccessibilityValue,
            accessibilitySummary: accessibilitySummary,
            targetText: privacyState == .authenticated
                ? LockScreenTargetFormatter.string(
                    from: projection.targetDate,
                    locale: locale,
                    timeZone: timeZone
                )
                : nil,
            hasReachedGoal: privacyState == .authenticated
                ? now >= projection.targetDate
                : nil
        )
    }
}

enum LockScreenElapsedFormatter {
    static func string(
        from duration: TimeInterval,
        privacyState: LockScreenPrivacyState
    ) -> String {
        let completedSeconds = max(Int(duration), 0)
        let hours = completedSeconds / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60

        if privacyState == .protected {
            return "\(hours) h \(minutes) min"
        }

        let seconds = completedSeconds % 60
        return "\(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(seconds))"
    }

    static func accessibilityString(
        from duration: TimeInterval,
        privacyState: LockScreenPrivacyState,
        resolver: SystemSurfaceTextResolver = .init()
    ) -> String {
        let completedSeconds = max(Int(duration), 0)
        let hours = completedSeconds / (60 * 60)
        let minutes = completedSeconds % (60 * 60) / 60
        var components = [resolver(.duration(value: hours, unit: .hour))]
        components.append(resolver(.duration(value: minutes, unit: .minute)))

        if privacyState == .authenticated {
            components.append(
                resolver(
                    .duration(value: completedSeconds % 60, unit: .second)
                )
            )
        }

        return components.joined(separator: " ")
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

enum LockScreenTargetFormatter {
    static func string(
        from date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
