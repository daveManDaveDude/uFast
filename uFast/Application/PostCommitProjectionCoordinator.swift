import Foundation

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

@MainActor
final class PostCommitProjectionCoordinator {
    typealias WidgetEffect = (PostCommitProjectionEvent) throws -> Void
    typealias ActivityEffect = @MainActor (PostCommitProjectionEvent) async -> ActiveFastLiveActivityResult?

    private let widgetEffect: WidgetEffect
    private let activityEffect: ActivityEffect
    private var pendingEffect: Task<Void, Never>?

    init(
        widgetEffect: @escaping WidgetEffect,
        activityEffect: @escaping ActivityEffect
    ) {
        self.widgetEffect = widgetEffect
        self.activityEffect = activityEffect
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

    func waitForPendingEffects() async {
        await pendingEffect?.value
    }
}
