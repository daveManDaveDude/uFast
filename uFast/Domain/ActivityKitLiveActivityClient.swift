@preconcurrency import ActivityKit
import Foundation

@MainActor
final class ActivityKitLiveActivityClient: LiveActivityClient {
    var availability: LiveActivityAvailability {
        ActivityAuthorizationInfo().areActivitiesEnabled ? .enabled : .disabled
    }

    func request(
        attributes: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws -> LiveActivityRecord {
        switch availability {
        case .enabled:
            break
        case .disabled:
            throw LiveActivityClientError.disabled
        case .unsupported:
            throw LiveActivityClientError.unavailable
        }

        do {
            let activity = try Activity<ActiveFastActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil
            )
            return record(from: activity)
        } catch {
            throw LiveActivityClientError.requestFailed
        }
    }

    func activities() async -> [LiveActivityRecord] {
        Activity<ActiveFastActivityAttributes>.activities.map(record(from:))
    }

    func update(
        activityID: String,
        contentState: ActiveFastActivityAttributes.ContentState
    ) async throws {
        guard let activity = activity(withID: activityID) else {
            throw LiveActivityClientError.activityNotFound
        }
        await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }

    func end(
        activityID: String,
        dismissalPolicy: LiveActivityDismissalPolicy
    ) async throws {
        guard let activity = activity(withID: activityID) else {
            throw LiveActivityClientError.activityNotFound
        }
        switch dismissalPolicy {
        case .immediate:
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private func activity(withID id: String) -> Activity<ActiveFastActivityAttributes>? {
        Activity<ActiveFastActivityAttributes>.activities.first { $0.id == id }
    }

    private func record(
        from activity: Activity<ActiveFastActivityAttributes>
    ) -> LiveActivityRecord {
        LiveActivityRecord(
            id: activity.id,
            activeRecordIdentifier: activity.attributes.activeRecordIdentifier,
            state: state(from: activity.activityState),
            contentState: activity.content.state
        )
    }

    private func state(from state: ActivityState) -> LiveActivityRecordState {
        switch state {
        case .pending: .pending
        case .active: .active
        case .ended: .ended
        case .dismissed: .dismissed
        case .stale: .stale
        @unknown default: .ended
        }
    }
}
