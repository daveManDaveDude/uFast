import ActivityKit
import Foundation

/// The only local identifier carried as immutable ActivityKit attributes.
/// Everything else is disposable, presentation-only content state.
struct ActiveFastActivityAttributes: ActivityAttributes, Equatable, Hashable, Sendable {
    let activeRecordIdentifier: UUID

    struct ContentState: Codable, Equatable, Hashable, Sendable {
        static let currentSchemaVersion = 1
        static let supportedGoalHours = 8 ... 24
        static let maximumEncodedByteCount = 4 * 1024

        let schemaVersion: Int
        let startDate: Date
        let targetDate: Date
        let goalHours: Int
        let generatedAt: Date

        init(
            schemaVersion: Int = Self.currentSchemaVersion,
            startDate: Date,
            targetDate: Date,
            goalHours: Int,
            generatedAt: Date
        ) {
            self.schemaVersion = schemaVersion
            self.startDate = startDate
            self.targetDate = targetDate
            self.goalHours = goalHours
            self.generatedAt = generatedAt
        }

        init(source: ActiveFastActivitySource, generatedAt: Date) {
            self.init(
                startDate: source.startDate,
                targetDate: source.targetDate,
                goalHours: source.goalHours,
                generatedAt: generatedAt
            )
        }

        func validate(now: Date) throws {
            guard schemaVersion == Self.currentSchemaVersion else {
                throw ActiveFastActivityContentError.incompatibleSchema
            }
            guard Self.supportedGoalHours.contains(goalHours) else {
                throw ActiveFastActivityContentError.invalidGoal
            }
            guard targetDate > startDate else {
                throw ActiveFastActivityContentError.invalidTarget
            }

            let expectedTarget = startDate.addingTimeInterval(
                TimeInterval(goalHours * 60 * 60)
            )
            guard abs(targetDate.timeIntervalSince(expectedTarget)) < 0.001 else {
                throw ActiveFastActivityContentError.inconsistentTarget
            }
            guard startDate <= now else {
                throw ActiveFastActivityContentError.futureStart
            }
            guard generatedAt <= now else {
                throw ActiveFastActivityContentError.futureGeneration
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            guard try encoder.encode(self).count < Self.maximumEncodedByteCount else {
                throw ActiveFastActivityContentError.encodedContentTooLarge
            }
        }

        var hasLegitimateGoalReachedObservation: Bool {
            generatedAt >= targetDate
        }
    }
}

struct ActiveFastActivitySource: Equatable, Sendable {
    let activeRecordIdentifier: UUID
    let startDate: Date
    let targetDate: Date
    let goalHours: Int
}

enum ActiveFastActivityContentError: Error, Equatable, Sendable {
    case incompatibleSchema
    case invalidGoal
    case invalidTarget
    case inconsistentTarget
    case futureStart
    case futureGeneration
    case encodedContentTooLarge
}

enum ActiveFastActivityPrivacyState: Equatable, Sendable {
    case visible
    case redacted

    static func make(isPrivacyRedacted: Bool) -> Self {
        isPrivacyRedacted ? .redacted : .visible
    }
}

struct ActiveFastActivityPresentation: Equatable, Sendable {
    let elapsedText: String?
    let elapsedAccessibilityValue: String?
    let progress: Double?
    /// The sampled percentage remains available to pure projection tests and
    /// validation. Live Activity views must not render this value because a
    /// request-time `now` cannot keep ordinary text current while suspended.
    let progressPercentage: Int?
    /// The sampled percentage wording is retained for projection parity only;
    /// the Live Activity uses `stableGoalText` for visible and spoken copy.
    let progressAccessibilityValue: String?
    let stableGoalText: String?
    let targetText: String?
    let hasReachedGoal: Bool
    let accessibilitySummary: String

    static func make(
        attributes _: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState,
        now: Date,
        privacyState: ActiveFastActivityPrivacyState = .visible,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        textResolver: SystemSurfaceTextResolver? = nil
    ) -> Self {
        guard (try? contentState.validate(now: now)) != nil else { return redacted() }

        guard privacyState == .visible else { return redacted() }

        let textResolver = textResolver ?? SystemSurfaceTextResolver(locale: locale)

        let elapsed = now.timeIntervalSince(contentState.startDate)
        let duration = contentState.targetDate.timeIntervalSince(contentState.startDate)
        let progress = min(max(elapsed / duration, 0), 1)
        let percentage = Int((progress * 100).rounded(.down))
        let elapsedAccessibility = ActiveFastActivityElapsedFormatter.accessibilityString(
            from: elapsed,
            resolver: textResolver
        )
        let progressAccessibility = textResolver(
            .progress(percent: percentage, goalHours: contentState.goalHours)
        )
        let stableGoalText = ActiveFastActivityGoalFormatter.string(
            hours: contentState.goalHours,
            resolver: textResolver
        )
        let target = ActiveFastActivityTargetFormatter.string(
            from: contentState.targetDate,
            locale: locale,
            timeZone: timeZone
        )
        let reached = now >= contentState.targetDate
            && contentState.hasLegitimateGoalReachedObservation
        let summary = textResolver(
            .activitySummary(
                elapsed: elapsedAccessibility,
                goal: stableGoalText,
                target: target,
                reachedGoal: reached
            )
        )

        return Self(
            elapsedText: ActiveFastActivityElapsedFormatter.string(from: elapsed),
            elapsedAccessibilityValue: elapsedAccessibility,
            progress: progress,
            progressPercentage: percentage,
            progressAccessibilityValue: progressAccessibility,
            stableGoalText: stableGoalText,
            targetText: target,
            hasReachedGoal: reached,
            accessibilitySummary: summary
        )
    }

    private static func redacted() -> Self {
        Self(
            elapsedText: nil,
            elapsedAccessibilityValue: nil,
            progress: nil,
            progressPercentage: nil,
            progressAccessibilityValue: nil,
            stableGoalText: nil,
            targetText: nil,
            hasReachedGoal: false,
            accessibilitySummary: SystemSurfaceTextResolver()(.identitySummary)
        )
    }
}

enum ActiveFastActivityGoalFormatter {
    static func string(
        hours: Int,
        resolver: SystemSurfaceTextResolver = .init()
    ) -> String {
        resolver(.goal(hours: hours))
    }
}

enum ActiveFastActivityElapsedFormatter {
    static func string(from duration: TimeInterval) -> String {
        let seconds = max(Int(duration), 0)
        let days = seconds / (24 * 60 * 60)
        let hours = seconds % (24 * 60 * 60) / (60 * 60)
        let minutes = seconds % (60 * 60) / 60
        let remainingSeconds = seconds % 60

        if days > 0 {
            return "\(days)d \(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
        }
        return "\(twoDigits(hours)):\(twoDigits(minutes)):\(twoDigits(remainingSeconds))"
    }

    static func accessibilityString(
        from duration: TimeInterval,
        resolver: SystemSurfaceTextResolver = .init()
    ) -> String {
        let seconds = max(Int(duration), 0)
        let days = seconds / (24 * 60 * 60)
        let hours = seconds % (24 * 60 * 60) / (60 * 60)
        let minutes = seconds % (60 * 60) / 60
        let remainingSeconds = seconds % 60
        var components: [String] = []

        if days > 0 {
            components.append(resolver(.duration(value: days, unit: .day)))
        }
        if hours > 0 || days > 0 {
            components.append(resolver(.duration(value: hours, unit: .hour)))
        }
        if minutes > 0 || hours > 0 || days > 0 {
            components.append(resolver(.duration(value: minutes, unit: .minute)))
        }
        components.append(resolver(.duration(value: remainingSeconds, unit: .second)))
        return components.joined(separator: " ")
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

enum ActiveFastActivityTargetFormatter {
    static func string(from date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum ActiveFastActivityRoute {
    static let currentFastURL = URL(string: "ufast://fast/current")!

    static func isCurrentFastURL(_ url: URL) -> Bool {
        url.absoluteString == currentFastURL.absoluteString
            && url.scheme == "ufast"
            && url.host == "fast"
            && url.path == "/current"
            && url.query == nil
            && url.fragment == nil
    }
}
