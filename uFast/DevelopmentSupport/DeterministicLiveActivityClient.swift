@MainActor
final class DeterministicLiveActivityClient: LiveActivityClient {
    private(set) var requestedAttributes: [ActiveFastActivityAttributes] = []
    private(set) var requestedContents: [ActiveFastActivityAttributes.ContentState] = []
    private(set) var updatedContents: [(String, ActiveFastActivityAttributes.ContentState)] = []
    private(set) var endAttemptedActivityIDs: [String] = []
    private(set) var endedActivityIDs: [String] = []

    var availability: LiveActivityAvailability
    var failRequests = false
    var failUpdates = false
    var failEnds = false
    var holdRequests = false
    private(set) var requestHasStarted = false
    private var requestWaiter: CheckedContinuation<Void, Never>?

    private var storedActivities: [LiveActivityRecord] = []
    private var nextIdentifier = 1

    init(availability: LiveActivityAvailability = .enabled) {
        self.availability = availability
    }

    func request(
        attributes: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws -> LiveActivityRecord {
        requestHasStarted = true
        if holdRequests {
            await withCheckedContinuation { continuation in
                requestWaiter = continuation
            }
        }
        guard availability == .enabled else {
            throw availability == .disabled
                ? LiveActivityClientError.disabled
                : LiveActivityClientError.unavailable
        }
        guard !failRequests else {
            throw LiveActivityClientError.requestFailed
        }

        let record = LiveActivityRecord(
            id: "ufast-activity-\(nextIdentifier)",
            activeRecordIdentifier: attributes.activeRecordIdentifier,
            state: .active,
            contentState: contentState
        )
        nextIdentifier += 1
        storedActivities.append(record)
        requestedAttributes.append(attributes)
        requestedContents.append(contentState)
        return record
    }

    func activities() async -> [LiveActivityRecord] {
        storedActivities
    }

    func update(
        activityID: String,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws {
        guard !failUpdates else {
            throw LiveActivityClientError.operationFailed
        }
        guard let index = storedActivities.firstIndex(where: { $0.id == activityID }) else {
            throw LiveActivityClientError.activityNotFound
        }
        let existing = storedActivities[index]
        storedActivities[index] = LiveActivityRecord(
            id: existing.id,
            activeRecordIdentifier: existing.activeRecordIdentifier,
            state: existing.state,
            contentState: contentState
        )
        updatedContents.append((activityID, contentState))
    }

    func end(
        activityID: String,
        dismissalPolicy _: LiveActivityDismissalPolicy
    ) async throws {
        endAttemptedActivityIDs.append(activityID)
        guard !failEnds else {
            throw LiveActivityClientError.operationFailed
        }
        guard let index = storedActivities.firstIndex(where: { $0.id == activityID }) else {
            throw LiveActivityClientError.activityNotFound
        }
        let existing = storedActivities[index]
        storedActivities[index] = LiveActivityRecord(
            id: existing.id,
            activeRecordIdentifier: existing.activeRecordIdentifier,
            state: .ended,
            contentState: existing.contentState
        )
        endedActivityIDs.append(activityID)
    }

    func seed(_ record: LiveActivityRecord) {
        storedActivities.append(record)
    }

    func releaseHeldRequest() {
        holdRequests = false
        requestWaiter?.resume()
        requestWaiter = nil
    }

    func dismiss(activityID: String) {
        guard let index = storedActivities.firstIndex(where: { $0.id == activityID }) else {
            return
        }
        let existing = storedActivities[index]
        storedActivities[index] = LiveActivityRecord(
            id: existing.id,
            activeRecordIdentifier: existing.activeRecordIdentifier,
            state: .dismissed,
            contentState: existing.contentState
        )
    }
}
