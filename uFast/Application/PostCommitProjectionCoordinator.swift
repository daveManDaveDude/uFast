import Foundation
import Observation

enum PostCommitProjectionEvent {
    case activeFastStarted(fast: FastRecord, goal: FastingGoal, now: Date)
    case activeFastChanged(fast: FastRecord, goal: FastingGoal, now: Date)
    case fastEndedOrDeleted
    case automaticPreferenceChanged(AutomaticLiveActivityPreference)
    case allDataDeleted
}

struct PostCommitProjectionOutcome {
    let widgetError: Error?
    let liveActivityResult: ActiveFastLiveActivityResult?
}

/// Publishes committed changes that affect already-created History projections.
/// The value is intentionally presentation-only: History reloads value
/// snapshots from its existing local store rather than receiving model objects.
@MainActor
@Observable
final class HistoryPresentationInvalidation {
    private(set) var revision = 0

    func publish() {
        revision += 1
    }

    func publish(for event: PostCommitProjectionEvent) {
        switch event {
        case .activeFastStarted, .activeFastChanged, .fastEndedOrDeleted:
            publish()
        case .automaticPreferenceChanged, .allDataDeleted:
            break
        }
    }
}

@MainActor
final class PostCommitProjectionCoordinator {
    typealias WidgetEffect = (PostCommitProjectionEvent) throws -> Void
    typealias ActivityEffect = @MainActor (PostCommitProjectionEvent) async -> ActiveFastLiveActivityResult?

    private let widgetEffect: WidgetEffect
    private let activityEffect: ActivityEffect
    let historyPresentationInvalidation: HistoryPresentationInvalidation
    private var pendingEffect: Task<Void, Never>?

    init(
        widgetEffect: @escaping WidgetEffect,
        activityEffect: @escaping ActivityEffect,
        historyPresentationInvalidation: HistoryPresentationInvalidation = HistoryPresentationInvalidation()
    ) {
        self.widgetEffect = widgetEffect
        self.activityEffect = activityEffect
        self.historyPresentationInvalidation = historyPresentationInvalidation
    }

    convenience init(liveActivityCoordinator: ActiveFastLiveActivityCoordinator?) {
        self.init(
            widgetEffect: { event in
                switch event {
                case let .activeFastStarted(fast, goal, now),
                     let .activeFastChanged(fast, goal, now):
                    WidgetProjectionSupport.publish(fast, goal: goal, now: now)
                case .fastEndedOrDeleted, .allDataDeleted:
                    WidgetProjectionSupport.clear()
                case .automaticPreferenceChanged:
                    break
                }
            },
            activityEffect: { event in
                guard let liveActivityCoordinator else { return nil }
                switch event {
                case .activeFastStarted:
                    return await liveActivityCoordinator.didCommitActiveFastStart()
                case .activeFastChanged:
                    return await liveActivityCoordinator.didCommitActiveFastChange()
                case .fastEndedOrDeleted:
                    return await liveActivityCoordinator.didCommitFastEndOrDeletion()
                case let .automaticPreferenceChanged(preference):
                    return await liveActivityCoordinator.didCommitAutomaticPreference(preference)
                case .allDataDeleted:
                    return await liveActivityCoordinator.didCommitDeleteAllData()
                }
            }
        )
    }

    func enqueue(
        _ event: PostCommitProjectionEvent,
        completion: ((PostCommitProjectionOutcome) -> Void)? = nil
    ) {
        let widgetError: Error?
        do {
            try widgetEffect(event)
            widgetError = nil
        } catch {
            widgetError = error
        }

        // Persistence has already committed before ApplicationCommands calls
        // enqueue. Publish even when an optional system projection fails so a
        // committed active-fast correction cannot leave History stale.
        historyPresentationInvalidation.publish(for: event)

        let precedingEffect = pendingEffect
        pendingEffect = Task { @MainActor [activityEffect] in
            await precedingEffect?.value
            let result = await activityEffect(event)
            completion?(
                PostCommitProjectionOutcome(
                    widgetError: widgetError,
                    liveActivityResult: result
                )
            )
        }
    }

    /// Publishes a committed local-data change that has no system projection
    /// effect. History observes this shared revision and reloads its existing
    /// value projections at the lifecycle boundary.
    func publishHistoryInvalidation() {
        historyPresentationInvalidation.publish()
    }

    func waitForPendingEffects() async {
        await pendingEffect?.value
    }
}
