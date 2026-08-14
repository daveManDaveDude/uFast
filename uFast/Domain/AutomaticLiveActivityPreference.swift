import Foundation

// swiftlint:disable opening_brace

/// The one app-owned setting that controls automatic Live Activity requests.
///
/// The raw value is persisted so adding this setting remains a lightweight,
/// additive SwiftData migration. Unknown values intentionally fail closed to
/// `disabled` when read.
enum AutomaticLiveActivityPreference: String, Codable, Equatable, Sendable {
    case notAsked
    case enabled
    case disabled

    init(persistedRawValue: String) {
        self = Self(rawValue: persistedRawValue) ?? .disabled
    }

    var permitsAutomaticRequests: Bool {
        self == .enabled
    }

    var shouldOfferContextualChoice: Bool {
        self == .notAsked
    }
}

enum AutomaticLiveActivityAttemptKind: Equatable, Sendable {
    case committedStart
    case preferenceEnabled
    case foreground
}

enum AutomaticLiveActivityEligibilityReason: Equatable, Sendable {
    case eligible
    case preferenceOff
    case noActiveFast
    case unavailable
    case matchingActivity
    case requestInFlight
    case hiddenForThisFast
    case activityWindowStillOpen
}

struct AutomaticLiveActivityEligibilityInput: Equatable, Sendable {
    let preference: AutomaticLiveActivityPreference
    let hasActiveFast: Bool
    let availability: LiveActivityAvailability
    let hasMatchingRunningActivity: Bool
    let requestInFlight: Bool
    let hiddenForThisFast: Bool
    let lastSuccessfulRequestDate: Date?
    let now: Date
    let installedBuildIdentity: LiveActivityBuildIdentity?
    let lastRequestBuildIdentity: LiveActivityBuildIdentity?
    let allowsUpdateRecovery: Bool
    let hasSuccessfulRequest: Bool

    init(
        preference: AutomaticLiveActivityPreference,
        hasActiveFast: Bool,
        availability: LiveActivityAvailability,
        hasMatchingRunningActivity: Bool,
        requestInFlight: Bool,
        hiddenForThisFast: Bool,
        lastSuccessfulRequestDate: Date?,
        now: Date,
        installedBuildIdentity: LiveActivityBuildIdentity? = nil,
        lastRequestBuildIdentity: LiveActivityBuildIdentity? = nil,
        allowsUpdateRecovery: Bool = false,
        hasSuccessfulRequest: Bool = true
    ) {
        self.preference = preference
        self.hasActiveFast = hasActiveFast
        self.availability = availability
        self.hasMatchingRunningActivity = hasMatchingRunningActivity
        self.requestInFlight = requestInFlight
        self.hiddenForThisFast = hiddenForThisFast
        self.lastSuccessfulRequestDate = lastSuccessfulRequestDate
        self.now = now
        self.installedBuildIdentity = installedBuildIdentity
        self.lastRequestBuildIdentity = lastRequestBuildIdentity
        self.allowsUpdateRecovery = allowsUpdateRecovery
        self.hasSuccessfulRequest = hasSuccessfulRequest
    }
}

enum AutomaticLiveActivityPolicy {
    static let activityWindow: TimeInterval = 8 * 60 * 60

    static func eligibilityReason(
        _ input: AutomaticLiveActivityEligibilityInput
    ) -> AutomaticLiveActivityEligibilityReason {
        guard input.preference.permitsAutomaticRequests else { return .preferenceOff }
        guard input.hasActiveFast else { return .noActiveFast }
        guard input.availability == .enabled else { return .unavailable }
        guard !input.hasMatchingRunningActivity else { return .matchingActivity }
        guard !input.requestInFlight else { return .requestInFlight }
        guard !input.hiddenForThisFast else { return .hiddenForThisFast }

        if let lastSuccessfulRequestDate = input.lastSuccessfulRequestDate,
           input.now.timeIntervalSince(lastSuccessfulRequestDate) < activityWindow
        {
            if input.allowsUpdateRecovery,
               input.hasSuccessfulRequest,
               input.installedBuildIdentity != nil,
               input.lastRequestBuildIdentity != input.installedBuildIdentity
            {
                return .eligible
            }
            return .activityWindowStillOpen
        }

        return .eligible
    }
}

enum AutomaticLiveActivityCopy {
    static let title = "See your fast at a glance?"
    static let showAutomatically = "Show Automatically"
    static let notNow = "Not Now"
    static let message =
        "uFast can automatically show elapsed time, goal progress and target on the "
            + "Lock Screen and Dynamic Island when you start a fast. Each Live Activity "
            + "stays active for up to 8 hours. If your fast continues, uFast can show a "
            + "new one the next time you open the app. You can hide it or turn this off "
            + "at any time in Settings."
    static let settingsSupportingCopy =
        "Show elapsed time, goal progress and target on the Lock Screen and Dynamic "
            + "Island when a fast starts. Each Live Activity stays active for up to 8 "
            + "hours. If your fast is still active, uFast can show a new one the next "
            + "time you open the app."
    static let settingsExplanation =
        "Turn this off to hide the current Live Activity and prevent new ones. You can "
            + "also choose Hide for this fast without changing the setting for future "
            + "fasts."
    static let settingsSaveFailure =
        "Your Live Activities setting couldn’t be saved. Please try again."
}
