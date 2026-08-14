import Foundation

enum LiveActivityAvailability: Equatable, Sendable {
    case enabled
    case disabled
    case unsupported
}

enum LiveActivityRecordState: Equatable, Sendable {
    case pending
    case active
    case ended
    case dismissed
    case stale

    var isRunning: Bool {
        self == .pending || self == .active
    }
}

enum LiveActivityDismissalPolicy: Equatable, Sendable {
    case immediate
}

struct LiveActivityRecord: Equatable, Sendable {
    let id: String
    let activeRecordIdentifier: UUID
    let state: LiveActivityRecordState
    let contentState: ActiveFastActivityAttributes.ContentState
}

enum LiveActivityClientError: Error, Equatable, Sendable {
    case unavailable
    case disabled
    case requestFailed
    case operationFailed
    case activityNotFound
}

@MainActor
protocol LiveActivityClient: AnyObject {
    var availability: LiveActivityAvailability { get }

    func request(
        attributes: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws -> LiveActivityRecord

    func activities() async -> [LiveActivityRecord]

    func update(
        activityID: String,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws

    func end(
        activityID: String,
        dismissalPolicy: LiveActivityDismissalPolicy
    ) async throws
}
