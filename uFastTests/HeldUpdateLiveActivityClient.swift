@testable import uFast

@MainActor
final class HeldUpdateLiveActivityClient: LiveActivityClient {
    private let base: DeterministicLiveActivityClient
    private var updateWaiter: CheckedContinuation<Void, Never>?

    private(set) var updateHasStarted = false

    init(base: DeterministicLiveActivityClient) {
        self.base = base
    }

    var availability: LiveActivityAvailability {
        base.availability
    }

    func request(
        attributes: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws -> LiveActivityRecord {
        try await base.request(attributes: attributes, contentState: contentState)
    }

    func activities() async -> [LiveActivityRecord] {
        await base.activities()
    }

    func update(
        activityID: String,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws {
        updateHasStarted = true
        await withCheckedContinuation { continuation in
            updateWaiter = continuation
        }
        try await base.update(activityID: activityID, contentState: contentState)
    }

    func end(
        activityID: String,
        dismissalPolicy: LiveActivityDismissalPolicy
    ) async throws {
        try await base.end(activityID: activityID, dismissalPolicy: dismissalPolicy)
    }

    func releaseHeldUpdate() {
        updateWaiter?.resume()
        updateWaiter = nil
    }
}
