import Foundation

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

/// The catalog-owned presentation vocabulary shared by the app's system
/// surfaces and the WidgetKit extension.
///
/// This type deliberately contains presentation copy only. Projection fields,
/// validation and ActivityKit lifecycle decisions remain in their existing
/// boundaries.
enum SystemSurfaceText: Equatable, Sendable {
    case brand
    case compactBrand
    case elapsed
    case elapsedTime
    case inProgress
    case target(value: String)
    case targetLowercased(value: String)
    case goal(hours: Int)
    case goalReached
    case goalReachedShort
    case percentage(value: Int)
    case progress(percent: Int, goalHours: Int)
    case noActiveFast
    case unavailableSummary
    case open
    case openToStart
    case widgetActiveFast
    case widgetActiveFastDescription
    case widgetToday
    case widgetHomeDescription
    case identitySummary
    case lockSummary(elapsed: String, progress: String)
    case activitySummary(elapsed: String, goal: String, target: String, reachedGoal: Bool)
    case activityElapsedPrefix
    case activityDetail(goal: String, target: String)
    case activityGoalOnlyDetail(goal: String)
    case activityGoalReachedSuffix
    case opensSuffix
    case duration(value: Int, unit: DurationUnit)

    enum DurationUnit: String, CaseIterable, Sendable {
        case day
        case hour
        case minute
        case second
    }

    var resource: LocalizedStringResource {
        switch self {
        case .brand:
            resource(
                "system-surface.brand",
                "uFast",
                "uFast system-surface brand name"
            )
        case .compactBrand:
            resource(
                "system-surface.brand.compact",
                "uF",
                "Compact uFast system-surface brand name"
            )
        case .elapsed:
            resource(
                "system-surface.elapsed",
                "Elapsed",
                "System-surface elapsed label"
            )
        case .elapsedTime:
            resource(
                "fast.elapsed",
                "Elapsed time",
                "System-surface elapsed-time label"
            )
        case .inProgress:
            resource(
                "fast.in-progress",
                "Fast in progress",
                "System-surface active-fast label"
            )
        case let .target(value):
            resource(
                "system-surface.target",
                "Target \(value)",
                "System-surface target detail"
            )
        case let .targetLowercased(value):
            resource(
                "system-surface.target.lowercase",
                "target \(value)",
                "Live Activity accessibility target detail"
            )
        case let .goal(hours):
            resource(
                "system-surface.goal",
                "\(hours)-hour goal",
                "System-surface fasting goal detail"
            )
        case .goalReached:
            resource(
                "fast.goal-reached",
                "Goal time reached",
                "System-surface goal-reached label"
            )
        case .goalReachedShort:
            resource(
                "system-surface.goal-reached.short",
                "Goal reached",
                "Compact system-surface goal-reached label"
            )
        case let .percentage(value):
            resource(
                "system-surface.percentage",
                "\(value)%",
                "System-surface progress percentage"
            )
        case let .progress(percent, goalHours):
            resource(
                "fast.progress.value",
                "\(percent) percent of \(goalHours)-hour goal",
                "System-surface progress accessibility value"
            )
        case .noActiveFast:
            resource(
                "system-surface.no-active-fast",
                "No active fast",
                "System-surface unavailable-state heading"
            )
        case .unavailableSummary:
            resource(
                "system-surface.unavailable-summary",
                "uFast. No active fast. Opens uFast.",
                "Unavailable system-surface accessibility summary"
            )
        case .open:
            resource(
                "system-surface.open",
                "Open uFast",
                "System-surface destination action"
            )
        case .openToStart:
            resource(
                "system-surface.open-to-start",
                "Open uFast to start one.",
                "System-surface unavailable-state destination message"
            )
        case .widgetActiveFast:
            resource(
                "system-surface.widget.active-fast",
                "Active fast",
                "Widget configuration display name"
            )
        case .widgetActiveFastDescription:
            resource(
                "system-surface.widget.active-fast.description",
                "Shows elapsed time for your active uFast record.",
                "Widget configuration description"
            )
        case .widgetToday:
            resource(
                "today.title",
                "Today",
                "Home Screen widget configuration display name"
            )
        case .widgetHomeDescription:
            resource(
                "system-surface.widget.home.description",
                "Shows your active fast progress at a glance.",
                "Home Screen widget configuration description"
            )
        case .identitySummary:
            resource(
                "system-surface.identity-summary",
                "uFast. Opens uFast.",
                "Privacy-redacted or unavailable system-surface accessibility summary"
            )
        case let .lockSummary(elapsed, progress):
            resource(
                "system-surface.lock.summary",
                "uFast, elapsed \(elapsed), \(progress). Opens uFast.",
                "Lock Screen accessibility summary"
            )
        case let .activitySummary(elapsed, goal, target, reachedGoal):
            resource(
                reachedGoal
                    ? "system-surface.activity.summary.goal-reached"
                    : "system-surface.activity.summary",
                reachedGoal
                    ? "uFast, elapsed \(elapsed), \(goal), target \(target), Goal time reached. Opens uFast."
                    : "uFast, elapsed \(elapsed), \(goal), target \(target). Opens uFast.",
                "Live Activity accessibility summary"
            )
        case .activityElapsedPrefix:
            resource(
                "system-surface.activity.elapsed-prefix",
                "Elapsed ",
                "Live Activity accessibility elapsed prefix"
            )
        case let .activityDetail(goal, target):
            resource(
                "system-surface.activity.detail",
                ", \(goal), target \(target)",
                "Live Activity accessibility goal and target detail"
            )
        case let .activityGoalOnlyDetail(goal):
            resource(
                "system-surface.activity.goal-only-detail",
                ", \(goal)",
                "Dynamic Island accessibility goal detail"
            )
        case .activityGoalReachedSuffix:
            resource(
                "system-surface.activity.goal-reached-suffix",
                ", Goal time reached",
                "Live Activity accessibility goal-reached suffix"
            )
        case .opensSuffix:
            resource(
                "system-surface.opens-suffix",
                ". Opens uFast.",
                "System-surface accessibility destination suffix"
            )
        case let .duration(value, unit):
            switch unit {
            case .day:
                resource(
                    "duration.day",
                    "\(value) day",
                    "System-surface duration day component"
                )
            case .hour:
                resource(
                    "duration.hour",
                    "\(value) hour",
                    "System-surface duration hour component"
                )
            case .minute:
                resource(
                    "duration.minute",
                    "\(value) minute",
                    "System-surface duration minute component"
                )
            case .second:
                resource(
                    "duration.second",
                    "\(value) second",
                    "System-surface duration second component"
                )
            }
        }
    }

    // The app test target consumes this catalog inventory across the target boundary.
    // swiftlint:disable:next unused_declaration
    static let catalogKeys: Set<String> = Set(catalogRepresentatives.map(\.resource.key))

    private static let catalogRepresentatives: [SystemSurfaceText] = [
        .brand,
        .compactBrand,
        .elapsed,
        .elapsedTime,
        .inProgress,
        .target(value: "10:30"),
        .targetLowercased(value: "10:30"),
        .goal(hours: 12),
        .goalReached,
        .goalReachedShort,
        .percentage(value: 50),
        .progress(percent: 50, goalHours: 12),
        .noActiveFast,
        .unavailableSummary,
        .open,
        .openToStart,
        .widgetActiveFast,
        .widgetActiveFastDescription,
        .widgetToday,
        .widgetHomeDescription,
        .identitySummary,
        .lockSummary(elapsed: "6 hours 0 minutes", progress: "50 percent of 12-hour goal"),
        .activitySummary(
            elapsed: "6 hours 0 minutes 0 seconds",
            goal: "12-hour goal",
            target: "10:30",
            reachedGoal: false
        ),
        .activitySummary(
            elapsed: "12 hours 0 minutes 0 seconds",
            goal: "12-hour goal",
            target: "10:30",
            reachedGoal: true
        ),
        .activityElapsedPrefix,
        .activityDetail(goal: "12-hour goal", target: "10:30"),
        .activityGoalOnlyDetail(goal: "12-hour goal"),
        .activityGoalReachedSuffix,
        .opensSuffix,
        .duration(value: 1, unit: .day),
        .duration(value: 1, unit: .hour),
        .duration(value: 1, unit: .minute),
        .duration(value: 1, unit: .second),
    ]

    private func resource(
        _ key: StaticString,
        _ value: String.LocalizationValue,
        _ comment: StaticString
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, defaultValue: value, comment: comment)
    }
}

struct SystemSurfaceTextResolver: Equatable, Sendable {
    let locale: Locale
    let pseudolocalizationEnabled: Bool

    init(
        locale: Locale = .autoupdatingCurrent,
        pseudolocalizationEnabled: Bool = false
    ) {
        self.locale = locale
        self.pseudolocalizationEnabled = pseudolocalizationEnabled
    }

    func callAsFunction(_ text: SystemSurfaceText) -> String {
        let localized = String(localized: text.resource)
        guard pseudolocalizationEnabled else { return localized }
        return SystemSurfaceTextPseudolocalizer.resolve(
            localized,
            preserving: text.interpolationValues
        )
    }
}

private extension SystemSurfaceText {
    var interpolationValues: [String] {
        switch self {
        case let .target(value), let .targetLowercased(value): [value]
        case let .goal(hours): [String(hours)]
        case let .percentage(value): [String(value)]
        case let .progress(percent, goalHours): [String(percent), String(goalHours)]
        case let .lockSummary(elapsed, progress): [elapsed, progress]
        case let .activitySummary(elapsed, goal, target, _): [elapsed, goal, target]
        case let .activityDetail(goal, target): [goal, target]
        case let .activityGoalOnlyDetail(goal): [goal]
        case let .duration(value, _): [String(value)]
        default: []
        }
    }
}

enum SystemSurfaceTextPseudolocalizer {
    private static let replacements: [Character: String] = [
        "a": "ȧ", "A": "Ȧ", "e": "ë", "E": "Ë", "i": "ï", "I": "Ï",
        "o": "õ", "O": "Õ", "u": "ü", "U": "Ü", "c": "ç", "C": "Ç",
        "n": "ñ", "N": "Ñ", "s": "š", "S": "Š",
    ]

    static func resolve(_ value: String, preserving tokens: [String] = []) -> String {
        var protected = value
        let protectedTokens = tokens
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .enumerated()
            .compactMap { index, token -> (String, String)? in
                guard let range = protected.range(of: token) else { return nil }
                let marker = "\u{E000}\(index)\u{E001}"
                protected.replaceSubrange(range, with: marker)
                return (marker, token)
            }
        let expanded = protected.map { character in
            replacements[character] ?? String(character)
        }.joined()
        var restored = "［\(expanded) ··］"
        for (marker, token) in protectedTokens {
            restored = restored.replacingOccurrences(of: marker, with: token)
        }
        return restored
    }
}
