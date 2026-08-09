import Foundation

enum LiveActivityControlState: Equatable, Sendable {
    case show
    case showAgain
    case hide
    case unavailable
}

enum ActiveFastLiveActivityResult: Equatable, Sendable {
    case shown(activityIdentifier: String)
    case alreadyShown(activityIdentifier: String)
    case hidden
    case updated
    case reconciled
    case noActiveFast
    case unavailable(LiveActivityAvailability)
    case requestFailed
    case hideFailed
    case coalesced
}

enum ActiveFastLiveActivityStatusCopy {
    static let unsupported = "Live Activities aren’t available on this iPhone."
    static let disabled = "Live Activities are turned off for uFast in iPhone Settings."
    static let requestFailure = "The Live Activity couldn’t be started. Please try again."
    static let hideFailure =
        "The Live Activity couldn’t be hidden. You can remove it from the Lock Screen."
    static let endedWhileFastContinues =
        "The Live Activity has ended. Your fast is still active, and the Lock Screen widget "
            + "can keep showing it."
    static let disclosure =
        "Shows uFast, elapsed time, goal progress and target on the Lock Screen and Dynamic Island "
            + "for up to 8 hours. You can hide it at any time. Your fast continues if the activity ends."
}

@MainActor
final class ActiveFastLiveActivityCoordinator {
    typealias ActiveFastResolver = @MainActor () throws -> ActiveFastActivitySource?

    private let clock: any AppClock
    private let client: any LiveActivityClient
    private let lifecycleStore: any LiveActivityLifecycleStore
    private let resolveActiveFast: ActiveFastResolver
    private var mutationInFlight = false

    init(
        clock: any AppClock,
        client: any LiveActivityClient,
        lifecycleStore: any LiveActivityLifecycleStore,
        resolveActiveFast: @escaping ActiveFastResolver
    ) {
        self.clock = clock
        self.client = client
        self.lifecycleStore = lifecycleStore
        self.resolveActiveFast = resolveActiveFast
    }

    func controlState() async -> LiveActivityControlState {
        guard let activeFast = try? resolveActiveFast() else {
            return .show
        }
        let activities = await client.activities()
        if activities.contains(where: {
            $0.activeRecordIdentifier == activeFast.activeRecordIdentifier && $0.state.isRunning
        }) {
            return .hide
        }
        let hasRequested = (try? lifecycleStore.metadata(
            for: activeFast.activeRecordIdentifier
        ))?.hasRequested ?? false
        return hasRequested ? .showAgain : .show
    }

    func show() async -> ActiveFastLiveActivityResult {
        guard !mutationInFlight else { return .coalesced }
        mutationInFlight = true
        defer { mutationInFlight = false }

        guard let activeFast = activeFast() else {
            return .noActiveFast
        }
        let now = clock.now
        let attributes = ActiveFastActivityAttributes(
            activeRecordIdentifier: activeFast.activeRecordIdentifier
        )
        let contentState = ActiveFastActivityAttributes.ContentState(
            source: activeFast,
            generatedAt: now
        )
        guard (try? contentState.validate(now: now)) != nil else {
            return .noActiveFast
        }

        switch client.availability {
        case .enabled:
            break
        case .disabled, .unsupported:
            return .unavailable(client.availability)
        }

        let activities = await client.activities()
        if let existing = runningActivities(for: activeFast, in: activities).first {
            return .alreadyShown(activityIdentifier: existing.id)
        }

        return await requestActivity(
            for: activeFast,
            attributes: attributes,
            contentState: contentState,
            now: now
        )
    }

    private func requestActivity(
        for activeFast: ActiveFastActivitySource,
        attributes: ActiveFastActivityAttributes,
        contentState: ActiveFastActivityAttributes.ContentState,
        now: Date
    ) async -> ActiveFastLiveActivityResult {
        do {
            let activity = try await client.request(
                attributes: attributes,
                contentState: contentState
            )
            var metadata = lifecycleMetadata(for: activeFast)
            metadata.hasRequested = true
            metadata.lastRequestDate = now
            metadata.lastKnownActivityIdentifier = activity.id
            metadata.lastIntent = .shown
            metadata.lastTerminalReason = nil
            save(metadata)
            return .shown(activityIdentifier: activity.id)
        } catch LiveActivityClientError.disabled {
            return .unavailable(.disabled)
        } catch LiveActivityClientError.unavailable {
            return .unavailable(.unsupported)
        } catch {
            var metadata = lifecycleMetadata(for: activeFast)
            metadata.hasRequested = true
            metadata.lastRequestDate = now
            metadata.lastIntent = nil
            metadata.lastTerminalReason = .requestFailed
            save(metadata)
            return .requestFailed
        }
    }

    func hide() async -> ActiveFastLiveActivityResult {
        guard !mutationInFlight else { return .coalesced }
        mutationInFlight = true
        defer { mutationInFlight = false }

        guard let activeFast = activeFast() else {
            return .noActiveFast
        }
        let matching = await runningActivities(for: activeFast, in: client.activities())
        var didFail = false
        for activity in matching {
            do {
                try await client.end(
                    activityID: activity.id,
                    dismissalPolicy: .immediate
                )
            } catch {
                didFail = true
            }
        }

        var metadata = lifecycleMetadata(for: activeFast, defaultHasRequested: true)
        metadata.hasRequested = true
        metadata.lastIntent = didFail ? .shown : .hidden
        metadata.lastTerminalReason = didFail ? nil : .userHidden
        save(metadata)
        return didFail ? .hideFailed : .hidden
    }

    /// Call only after a successful active-start correction or goal commit and
    /// after the existing widget projection has been published.
    func didCommitActiveFastChange() async -> ActiveFastLiveActivityResult {
        await reconcile()
    }

    /// Call only after a successful fast end or active deletion and after the
    /// existing widget projection has been cleared.
    func didCommitFastEndOrDeletion() async -> ActiveFastLiveActivityResult {
        let activities = await client.activities()
        var didFail = false
        for activity in activities {
            do {
                try await client.end(
                    activityID: activity.id,
                    dismissalPolicy: .immediate
                )
            } catch {
                didFail = true
            }
        }
        try? lifecycleStore.clearAll()
        return didFail ? .hideFailed : .hidden
    }

    /// Call only after Delete All Data commits and after the widget projection
    /// has been cleared. This intentionally never requests a replacement.
    func didCommitDeleteAllData() async -> ActiveFastLiveActivityResult {
        await didCommitFastEndOrDeletion()
    }

    /// Idempotent cleanup for cold launch and foreground activation. It only
    /// changes derived ActivityKit state and presentation metadata.
    func reconcile() async -> ActiveFastLiveActivityResult {
        let resolvedActiveFast: ActiveFastActivitySource?
        do {
            resolvedActiveFast = try resolveActiveFast()
        } catch {
            return .reconciled
        }
        let activities = await client.activities()
        guard let activeFast = resolvedActiveFast else {
            await endAll(activities)
            try? lifecycleStore.clearAll()
            return .reconciled
        }

        let now = clock.now
        let expectedContent = ActiveFastActivityAttributes.ContentState(
            source: activeFast,
            generatedAt: now
        )
        let validMatching = runningActivities(for: activeFast, in: activities).filter {
            (try? $0.contentState.validate(now: now)) != nil
        }
        let winner = validMatching.sorted(by: { $0.id < $1.id }).first

        await endAll(activities.filter { $0.id != winner?.id })

        if let winner {
            if winner.contentState != expectedContent {
                try? await client.update(
                    activityID: winner.id,
                    contentState: expectedContent
                )
            }
            var metadata = lifecycleMetadata(for: activeFast)
            metadata.hasRequested = true
            metadata.lastKnownActivityIdentifier = winner.id
            metadata.lastIntent = .shown
            metadata.lastTerminalReason = nil
            save(metadata)
        } else if var metadata = try? lifecycleStore.metadata(
            for: activeFast.activeRecordIdentifier
        ) {
            metadata.lastTerminalReason = metadata.hasRequested
                ? .dismissedOrSystemEnded
                : nil
            try? lifecycleStore.save(metadata)
        }

        return .reconciled
    }

    private func activeFast() -> ActiveFastActivitySource? {
        try? resolveActiveFast()
    }

    private func runningActivities(
        for activeFast: ActiveFastActivitySource,
        in activities: [LiveActivityRecord]
    ) -> [LiveActivityRecord] {
        activities
            .filter {
                $0.activeRecordIdentifier == activeFast.activeRecordIdentifier
                    && $0.state.isRunning
            }
            .sorted { $0.id < $1.id }
    }

    private func lifecycleMetadata(
        for activeFast: ActiveFastActivitySource,
        defaultHasRequested: Bool = false
    ) -> LiveActivityLifecycleMetadata {
        (try? lifecycleStore.metadata(for: activeFast.activeRecordIdentifier))
            ?? LiveActivityLifecycleMetadata(
                activeRecordIdentifier: activeFast.activeRecordIdentifier,
                hasRequested: defaultHasRequested
            )
    }

    private func save(_ metadata: LiveActivityLifecycleMetadata) {
        try? lifecycleStore.save(metadata)
    }

    private func endAll(_ activities: [LiveActivityRecord]) async {
        for activity in activities {
            try? await client.end(
                activityID: activity.id,
                dismissalPolicy: .immediate
            )
        }
    }
}
