import Foundation

// swiftlint:disable file_length function_body_length type_body_length

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

@MainActor
final class ActiveFastLiveActivityCoordinator {
    typealias ActiveFastResolver = @MainActor () throws -> ActiveFastActivitySource?

    private struct ActivityRequest {
        let activeFast: ActiveFastActivitySource
        let attributes: ActiveFastActivityAttributes
        let contentState: ActiveFastActivityAttributes.ContentState
        let now: Date
        let automaticAttempt: Bool
        let clearsSuppression: Bool
    }

    private let clock: any AppClock
    private let client: any LiveActivityClient
    private let lifecycleStore: any LiveActivityLifecycleStore
    private let installedBuildIdentity: LiveActivityBuildIdentity?
    private let resolveActiveFast: ActiveFastResolver
    private let resolveAutomaticPreference: @MainActor () -> AutomaticLiveActivityPreference
    private var mutationInFlight = false
    private var foregroundIsActive = false
    private var foregroundAutomaticAttempted = false
    private var committedStartAttempts = Set<UUID>()
    private var preferenceEnableAttempts = Set<UUID>()
    private var lifecycleGeneration = 0

    init(
        clock: any AppClock,
        client: any LiveActivityClient,
        lifecycleStore: any LiveActivityLifecycleStore,
        resolveActiveFast: @escaping ActiveFastResolver,
        resolveAutomaticPreference: @escaping @MainActor () -> AutomaticLiveActivityPreference = { .disabled },
        installedBuildIdentity: LiveActivityBuildIdentity? = LiveActivityBuildIdentity.production()
    ) {
        self.clock = clock
        self.client = client
        self.lifecycleStore = lifecycleStore
        self.installedBuildIdentity = installedBuildIdentity
        self.resolveActiveFast = resolveActiveFast
        self.resolveAutomaticPreference = resolveAutomaticPreference
    }

    func availability() -> LiveActivityAvailability {
        client.availability
    }

    func isAvailableForAutomaticConsent() -> Bool {
        client.availability == .enabled
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
        let metadata = try? lifecycleStore.metadata(
            for: activeFast.activeRecordIdentifier
        )
        return metadata?.hasRequested == true || metadata?.lastTerminalReason != nil
            ? .showAgain
            : .show
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
            ActivityRequest(
                activeFast: activeFast,
                attributes: attributes,
                contentState: contentState,
                now: now,
                automaticAttempt: false,
                clearsSuppression: true
            )
        )
    }

    /// Call only after a normal or backdated active fast has committed and its
    /// WidgetKit projection has been published.
    func didCommitActiveFastStart() async -> ActiveFastLiveActivityResult {
        _ = await reconcile()
        return await attemptAutomaticRequest(kind: .committedStart)
    }

    /// Call after a preference commit. Enabling may request the current active
    /// fast; disabling ends matching derived state after the preference is off.
    func didCommitAutomaticPreference(
        _ preference: AutomaticLiveActivityPreference
    ) async -> ActiveFastLiveActivityResult {
        switch preference {
        case .enabled:
            return await attemptAutomaticRequest(kind: .preferenceEnabled)
        case .notAsked, .disabled:
            preferenceEnableAttempts.removeAll()
            return await disableAutomaticLiveActivities()
        }
    }

    /// Reconcile once for a genuine cold launch or inactive/background-to-active
    /// transition. Scene churn while already active is intentionally coalesced.
    func didBecomeActive() async -> ActiveFastLiveActivityResult {
        guard !foregroundIsActive else { return .coalesced }
        foregroundIsActive = true
        foregroundAutomaticAttempted = false

        _ = await reconcile()
        foregroundAutomaticAttempted = true
        return await attemptAutomaticRequest(kind: .foreground)
    }

    func didBecomeInactive() {
        foregroundIsActive = false
        foregroundAutomaticAttempted = false
    }

    private func requestActivity(
        _ request: ActivityRequest
    ) async -> ActiveFastLiveActivityResult {
        let requestGeneration = lifecycleGeneration
        var attemptMetadata = lifecycleMetadata(for: request.activeFast)
        if request.automaticAttempt {
            attemptMetadata.lastAutomaticAttemptDate = request.now
            attemptMetadata.lastAutomaticAttemptSucceeded = nil
            save(attemptMetadata)
        }

        do {
            let activity = try await client.request(
                attributes: request.attributes,
                contentState: request.contentState
            )

            // A committed end or Delete All Data may race an ActivityKit
            // request. Never let a response from the old authority recreate a
            // projection or lifecycle metadata after that authoritative
            // transaction has completed.
            let stillAuthoritative = lifecycleGeneration == requestGeneration
                && activeFast()?.activeRecordIdentifier == request.activeFast.activeRecordIdentifier
            guard stillAuthoritative else {
                try? await client.end(
                    activityID: activity.id,
                    dismissalPolicy: .immediate
                )
                try? lifecycleStore.clear(for: request.activeFast.activeRecordIdentifier)
                return .reconciled
            }

            var metadata = lifecycleMetadata(for: request.activeFast)
            metadata.hasRequested = true
            metadata.lastRequestDate = request.now
            metadata.lastKnownActivityIdentifier = activity.id
            metadata.lastRequestBuildIdentity = installedBuildIdentity
            metadata.lastIntent = .shown
            metadata.lastTerminalReason = nil
            if request.clearsSuppression {
                metadata.automaticSuppressed = false
            }
            if request.automaticAttempt {
                metadata.lastAutomaticAttemptDate = request.now
                metadata.lastAutomaticAttemptSucceeded = true
            }
            save(metadata)
            return .shown(activityIdentifier: activity.id)
        } catch LiveActivityClientError.disabled {
            return .unavailable(.disabled)
        } catch LiveActivityClientError.unavailable {
            return .unavailable(.unsupported)
        } catch {
            let stillAuthoritative = lifecycleGeneration == requestGeneration
                && activeFast()?.activeRecordIdentifier == request.activeFast.activeRecordIdentifier
            guard stillAuthoritative else {
                try? lifecycleStore.clear(for: request.activeFast.activeRecordIdentifier)
                return .reconciled
            }
            var metadata = lifecycleMetadata(for: request.activeFast)
            if request.automaticAttempt {
                metadata.lastAutomaticAttemptDate = request.now
                metadata.lastAutomaticAttemptSucceeded = false
            }
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
        metadata.automaticSuppressed = !didFail
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
        lifecycleGeneration &+= 1
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
        committedStartAttempts.removeAll()
        preferenceEnableAttempts.removeAll()
        return didFail ? .hideFailed : .hidden
    }

    /// Call only after Delete All Data commits and after the widget projection
    /// has been cleared. This intentionally never requests a replacement.
    func didCommitDeleteAllData() async -> ActiveFastLiveActivityResult {
        await didCommitFastEndOrDeletion()
    }

    private func disableAutomaticLiveActivities() async -> ActiveFastLiveActivityResult {
        let activities = await client.activities()
        let matching: [LiveActivityRecord] = if let activeFast = activeFast() {
            runningActivities(for: activeFast, in: activities)
        } else {
            activities.filter(\.state.isRunning)
        }

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
        return didFail ? .hideFailed : .hidden
    }

    /// Idempotent cleanup for cold launch and foreground activation. It only
    /// changes derived ActivityKit state and presentation metadata.
    func reconcile() async -> ActiveFastLiveActivityResult {
        let resolvedActiveFast: ActiveFastActivitySource?
        do {
            resolvedActiveFast = try resolveActiveFast()
        } catch {
            let activities = await client.activities()
            await endAll(activities)
            try? lifecycleStore.clearAll()
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
            // Do not repair unreadable bytes as an incidental side effect of
            // reconciliation. Automatic recovery must remain fail-closed;
            // explicit Show or authoritative cleanup is the repair path.
            let persistedMetadata = try? lifecycleStore.metadata(
                for: activeFast.activeRecordIdentifier
            )
            guard !lifecycleStore.hasUnreadableMetadata() else {
                return .reconciled
            }
            var metadata = persistedMetadata ?? LiveActivityLifecycleMetadata(
                activeRecordIdentifier: activeFast.activeRecordIdentifier
            )
            metadata.hasRequested = true
            // A surviving ActivityKit record is itself evidence of a prior
            // request. If lifecycle metadata was absent, use this
            // reconciliation instant as the conservative request-window
            // anchor rather than persisting an incoherent success state.
            metadata.lastRequestDate = metadata.lastRequestDate ?? now
            metadata.lastKnownActivityIdentifier = winner.id
            if installedBuildIdentity != nil {
                metadata.lastRequestBuildIdentity = installedBuildIdentity
            }
            metadata.lastIntent = .shown
            metadata.lastTerminalReason = nil
            save(metadata)
        } else if var metadata = try? lifecycleStore.metadata(
            for: activeFast.activeRecordIdentifier
        ) {
            if !metadata.automaticSuppressed {
                metadata.lastTerminalReason = metadata.hasRequested
                    ? .dismissedOrSystemEnded
                    : metadata.lastTerminalReason
            }
            try? lifecycleStore.save(metadata)
        }

        return .reconciled
    }

    private func attemptAutomaticRequest(
        kind: AutomaticLiveActivityAttemptKind
    ) async -> ActiveFastLiveActivityResult {
        guard !mutationInFlight else { return .coalesced }
        guard let activeFast = activeFast() else { return .noActiveFast }
        guard markAutomaticAttempt(kind, for: activeFast.activeRecordIdentifier) else {
            return .coalesced
        }

        mutationInFlight = true
        defer { mutationInFlight = false }

        let now = clock.now
        let metadata = lifecycleMetadata(for: activeFast)
        guard !lifecycleStore.hasUnreadableMetadata() else {
            return .reconciled
        }

        let activities = await client.activities()
        let matching = runningActivities(for: activeFast, in: activities)
        let reason = automaticEligibilityReason(
            metadata: metadata,
            matching: matching,
            now: now,
            allowsUpdateRecovery: kind == .foreground
        )
        guard reason == .eligible else {
            if let existing = matching.first {
                return .alreadyShown(activityIdentifier: existing.id)
            }
            return .reconciled
        }

        let contentState = ActiveFastActivityAttributes.ContentState(
            source: activeFast,
            generatedAt: now
        )
        guard (try? contentState.validate(now: now)) != nil else {
            return .noActiveFast
        }

        return await requestActivity(
            ActivityRequest(
                activeFast: activeFast,
                attributes: ActiveFastActivityAttributes(
                    activeRecordIdentifier: activeFast.activeRecordIdentifier
                ),
                contentState: contentState,
                now: now,
                automaticAttempt: true,
                clearsSuppression: false
            )
        )
    }

    private func markAutomaticAttempt(
        _ kind: AutomaticLiveActivityAttemptKind,
        for activeRecordIdentifier: UUID
    ) -> Bool {
        switch kind {
        case .committedStart:
            committedStartAttempts.insert(activeRecordIdentifier).inserted
        case .foreground:
            foregroundAutomaticAttempted
        case .preferenceEnabled:
            preferenceEnableAttempts.insert(activeRecordIdentifier).inserted
        }
    }

    private func automaticEligibilityReason(
        metadata: LiveActivityLifecycleMetadata,
        matching: [LiveActivityRecord],
        now: Date,
        allowsUpdateRecovery: Bool
    ) -> AutomaticLiveActivityEligibilityReason {
        AutomaticLiveActivityPolicy.eligibilityReason(
            AutomaticLiveActivityEligibilityInput(
                preference: resolveAutomaticPreference(),
                hasActiveFast: true,
                availability: client.availability,
                hasMatchingRunningActivity: !matching.isEmpty,
                requestInFlight: false,
                hiddenForThisFast: metadata.automaticSuppressed,
                lastSuccessfulRequestDate: metadata.lastRequestDate,
                now: now,
                installedBuildIdentity: installedBuildIdentity,
                lastRequestBuildIdentity: metadata.lastRequestBuildIdentity,
                allowsUpdateRecovery: allowsUpdateRecovery,
                hasSuccessfulRequest: metadata.hasRequested
            )
        )
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
