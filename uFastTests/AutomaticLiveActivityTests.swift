import Foundation
@testable import uFast
import XCTest

// swiftlint:disable file_length function_body_length type_body_length large_tuple trailing_comma

final class AutomaticLiveActivityPreferenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testPreferenceDefaultsAndUnknownValuesFailClosed() {
        XCTAssertEqual(AutomaticLiveActivityPreference.notAsked.rawValue, "notAsked")
        XCTAssertTrue(
            AutomaticLiveActivityPreference(persistedRawValue: "notAsked")
                .shouldOfferContextualChoice
        )
        XCTAssertTrue(
            AutomaticLiveActivityPreference(persistedRawValue: "enabled")
                .permitsAutomaticRequests
        )
        XCTAssertEqual(
            AutomaticLiveActivityPreference(persistedRawValue: "future-value"),
            .disabled
        )
    }

    func testActivityWindowUsesAbsoluteSevenFiftyNineAndEightHourBoundaries() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let common: (Date) -> AutomaticLiveActivityEligibilityReason = { lastRequest in
            AutomaticLiveActivityPolicy.eligibilityReason(
                AutomaticLiveActivityEligibilityInput(
                    preference: .enabled,
                    hasActiveFast: true,
                    availability: .enabled,
                    hasMatchingRunningActivity: false,
                    requestInFlight: false,
                    hiddenForThisFast: false,
                    lastSuccessfulRequestDate: lastRequest,
                    now: now
                )
            )
        }

        XCTAssertEqual(
            common(now.addingTimeInterval(-7 * 60 * 60 - 59 * 60 - 59)),
            .activityWindowStillOpen
        )
        XCTAssertEqual(
            common(now.addingTimeInterval(-AutomaticLiveActivityPolicy.activityWindow)),
            .eligible
        )
    }

    func testChangedBuildAllowsOneForegroundRecoveryInsideTheActivityWindow() {
        let previousBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "A")
        let currentBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "B")
        let input = AutomaticLiveActivityEligibilityInput(
            preference: .enabled,
            hasActiveFast: true,
            availability: .enabled,
            hasMatchingRunningActivity: false,
            requestInFlight: false,
            hiddenForThisFast: false,
            lastSuccessfulRequestDate: now.addingTimeInterval(-60),
            now: now,
            installedBuildIdentity: currentBuild,
            lastRequestBuildIdentity: previousBuild,
            allowsUpdateRecovery: true
        )

        XCTAssertEqual(AutomaticLiveActivityPolicy.eligibilityReason(input), .eligible)
    }

    func testSameBuildStillHonoursTheEightHourWindow() {
        let build = LiveActivityBuildIdentity.deterministic(buildNumber: "A")
        let input = AutomaticLiveActivityEligibilityInput(
            preference: .enabled,
            hasActiveFast: true,
            availability: .enabled,
            hasMatchingRunningActivity: false,
            requestInFlight: false,
            hiddenForThisFast: false,
            lastSuccessfulRequestDate: now.addingTimeInterval(-60),
            now: now,
            installedBuildIdentity: build,
            lastRequestBuildIdentity: build,
            allowsUpdateRecovery: true
        )

        XCTAssertEqual(
            AutomaticLiveActivityPolicy.eligibilityReason(input),
            .activityWindowStillOpen
        )
    }

    func testChangedBuildRecoveryNeverBypassesExistingEligibilityGates() {
        let currentBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "B")
        let previousBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "A")
        let makeInput: (
            AutomaticLiveActivityPreference,
            LiveActivityAvailability,
            Bool,
            Bool,
            Bool
        ) -> AutomaticLiveActivityEligibilityInput = { preference, availability, matching, inFlight, hidden in
            AutomaticLiveActivityEligibilityInput(
                preference: preference,
                hasActiveFast: true,
                availability: availability,
                hasMatchingRunningActivity: matching,
                requestInFlight: inFlight,
                hiddenForThisFast: hidden,
                lastSuccessfulRequestDate: self.now.addingTimeInterval(-60),
                now: self.now,
                installedBuildIdentity: currentBuild,
                lastRequestBuildIdentity: previousBuild,
                allowsUpdateRecovery: true
            )
        }
        let cases: [(String, AutomaticLiveActivityEligibilityInput, AutomaticLiveActivityEligibilityReason)] = [
            ("notAsked", makeInput(.notAsked, .enabled, false, false, false), .preferenceOff),
            ("disabled", makeInput(.disabled, .enabled, false, false, false), .preferenceOff),
            ("unavailable", makeInput(.enabled, .unsupported, false, false, false), .unavailable),
            ("matching", makeInput(.enabled, .enabled, true, false, false), .matchingActivity),
            ("inFlight", makeInput(.enabled, .enabled, false, true, false), .requestInFlight),
            ("suppressed", makeInput(.enabled, .enabled, false, false, true), .hiddenForThisFast),
        ]

        for (name, input, expected) in cases {
            XCTAssertEqual(
                AutomaticLiveActivityPolicy.eligibilityReason(input),
                expected,
                name
            )
        }
    }

    func testSettingsRecordAddsNotAskedWithoutChangingExistingValues() throws {
        let settings = try AppSettingsRecord(
            fastingGoal: XCTUnwrap(FastingGoal(hours: 16)),
            hasCompletedOnboarding: true,
            waterFavouriteMillilitres: 700
        )

        XCTAssertEqual(settings.fastingGoal.hours, 16)
        XCTAssertEqual(settings.waterFavouriteMillilitres, 700)
        XCTAssertEqual(settings.automaticLiveActivityPreference, .notAsked)
    }

    @MainActor
    func testLifecycleStoreMigratesVersionOneHiddenState() throws {
        struct VersionOneMetadata: Codable {
            let schemaVersion: Int
            let activeRecordIdentifier: UUID
            let hasRequested: Bool
            let lastRequestDate: Date?
            let lastKnownActivityIdentifier: String?
            let lastIntent: LiveActivityLifecycleIntent?
            let lastTerminalReason: LiveActivityTerminalReason?
        }

        let recordIdentifier = try XCTUnwrap(UUID(uuidString: "10600000-0000-0000-0000-000000000002"))
        let suiteName = "uFast.automatic-live-activity-migration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try defaults.set(
            JSONEncoder().encode(
                VersionOneMetadata(
                    schemaVersion: 1,
                    activeRecordIdentifier: recordIdentifier,
                    hasRequested: true,
                    lastRequestDate: Date(timeIntervalSince1970: 1_800_000_000),
                    lastKnownActivityIdentifier: "legacy-activity",
                    lastIntent: .hidden,
                    lastTerminalReason: .userHidden
                )
            ),
            forKey: "uFast.liveActivity.lifecycle.v1"
        )

        let store = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        let migrated = try XCTUnwrap(try store.metadata(for: recordIdentifier))

        XCTAssertEqual(migrated.schemaVersion, LiveActivityLifecycleMetadata.currentSchemaVersion)
        XCTAssertEqual(migrated.lastKnownActivityIdentifier, "legacy-activity")
        XCTAssertTrue(migrated.automaticSuppressed)
        XCTAssertNil(migrated.lastRequestBuildIdentity)
        XCTAssertNil(migrated.lastAutomaticAttemptDate)
    }

    func testLifecycleMetadataUsesCanonicalBuildIdentityEncoding() throws {
        let activeRecordIdentifier = try XCTUnwrap(
            UUID(uuidString: "10600000-0000-0000-0000-000000000006")
        )
        let metadata = LiveActivityLifecycleMetadata(
            activeRecordIdentifier: activeRecordIdentifier,
            hasRequested: true,
            lastRequestDate: now,
            lastRequestBuildIdentity: .deterministic(buildNumber: "B")
        )
        let encodedMetadata = try JSONEncoder().encode(metadata)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(
                with: encodedMetadata
            ) as? [String: Any]
        )

        XCTAssertNotNil(object["lastRequestBuildIdentity"])
        XCTAssertNil(object["lastSuccessfulRequestBuildIdentity"])
    }

    @MainActor
    func testLifecycleStoreRejectsUnsupportedBuildIdentityAndRetainsItForFailClosedReads() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordIdentifier = try XCTUnwrap(UUID(uuidString: "10600000-0000-0000-0000-000000000003"))
        let suiteName = "uFast.automatic-live-activity-invalid-build.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let corrupt = Data((
            "{\"schemaVersion\":3,\"activeRecordIdentifier\":\"\(recordIdentifier.uuidString)\","
                + "\"hasRequested\":true,\"lastRequestDate\":\(now.timeIntervalSince1970),"
                + "\"lastRequestBuildIdentity\":{\"releaseVersion\":\"\",\"buildNumber\":\"B\"}}"
        ).utf8)
        defaults.set(corrupt, forKey: "uFast.liveActivity.lifecycle.v1")

        let store = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        XCTAssertNil(try store.metadata(for: recordIdentifier))
        XCTAssertNotNil(defaults.data(forKey: "uFast.liveActivity.lifecycle.v1"))
        XCTAssertTrue(store.hasUnreadableMetadata())
    }

    @MainActor
    func testCorruptLifecycleMetadataBlocksAutomaticRecoveryWithoutLooping() async throws {
        let recordIdentifier = try XCTUnwrap(UUID(uuidString: "10600000-0000-0000-0000-000000000004"))
        let suiteName = "uFast.automatic-live-activity-corrupt-coordinator.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            Data((
                "{\"schemaVersion\":999,\"activeRecordIdentifier\":\"\(recordIdentifier.uuidString)\","
                    + "\"hasRequested\":true}"
            ).utf8),
            forKey: "uFast.liveActivity.lifecycle.v1"
        )

        let sourceBox = SourceBox(value: ActiveFastActivitySource(
            activeRecordIdentifier: recordIdentifier,
            startDate: now.addingTimeInterval(-60 * 60),
            targetDate: now.addingTimeInterval(11 * 60 * 60),
            goalHours: 12
        ))
        let client = DeterministicLiveActivityClient()
        let store = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: { sourceBox.value },
            resolveAutomaticPreference: { .enabled },
            installedBuildIdentity: .deterministic(buildNumber: "B")
        )

        let firstResult = await coordinator.didBecomeActive()
        XCTAssertEqual(firstResult, .reconciled)
        coordinator.didBecomeInactive()
        let secondResult = await coordinator.didBecomeActive()
        XCTAssertEqual(secondResult, .reconciled)
        XCTAssertTrue(client.requestedContents.isEmpty)

        let recreatedStore = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        let recreatedCoordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: recreatedStore,
            resolveActiveFast: { sourceBox.value },
            resolveAutomaticPreference: { .enabled },
            installedBuildIdentity: .deterministic(buildNumber: "B")
        )
        let recreatedResult = await recreatedCoordinator.didBecomeActive()
        XCTAssertEqual(recreatedResult, .reconciled)
        XCTAssertTrue(client.requestedContents.isEmpty)

        let explicitResult = await recreatedCoordinator.show()
        XCTAssertEqual(explicitResult, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertFalse(recreatedStore.hasUnreadableMetadata())
        XCTAssertEqual(client.requestedContents.count, 1)
    }

    @MainActor
    func testAutomaticPreferenceEnableReadsCorruptMetadataBeforeRequesting() async throws {
        let recordIdentifier = try XCTUnwrap(UUID(uuidString: "10600000-0000-0000-0000-000000000007"))
        let suiteName = "uFast.automatic-live-activity-corrupt-preference.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            Data((
                "{\"schemaVersion\":999,\"activeRecordIdentifier\":\"\(recordIdentifier.uuidString)\","
                    + "\"hasRequested\":true}"
            ).utf8),
            forKey: "uFast.liveActivity.lifecycle.v1"
        )

        let sourceBox = SourceBox(value: ActiveFastActivitySource(
            activeRecordIdentifier: recordIdentifier,
            startDate: now.addingTimeInterval(-60 * 60),
            targetDate: now.addingTimeInterval(11 * 60 * 60),
            goalHours: 12
        ))
        let client = DeterministicLiveActivityClient()
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: UserDefaultsLiveActivityLifecycleStore(defaults: defaults),
            resolveActiveFast: { sourceBox.value },
            resolveAutomaticPreference: { .enabled },
            installedBuildIdentity: .deterministic(buildNumber: "B")
        )

        let firstResult = await coordinator.didCommitAutomaticPreference(.enabled)
        XCTAssertEqual(firstResult, .reconciled)
        XCTAssertTrue(client.requestedContents.isEmpty)

        let repeatedResult = await coordinator.didCommitAutomaticPreference(.enabled)
        XCTAssertEqual(repeatedResult, .coalesced)
        XCTAssertTrue(client.requestedContents.isEmpty)
    }

    @MainActor
    func testSemanticallyInvalidSuccessfulMetadataIsUnreadable() throws {
        let recordIdentifier = try XCTUnwrap(UUID(uuidString: "10600000-0000-0000-0000-000000000005"))
        let suiteName = "uFast.automatic-live-activity-invalid-state.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            Data((
                "{\"schemaVersion\":3,\"activeRecordIdentifier\":\"\(recordIdentifier.uuidString)\","
                    + "\"hasRequested\":true,\"lastRequestBuildIdentity\":{"
                    + "\"releaseVersion\":\"1.0.0\",\"buildNumber\":\"A\"}}"
            ).utf8),
            forKey: "uFast.liveActivity.lifecycle.v1"
        )

        let store = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        XCTAssertNil(try store.metadata(for: recordIdentifier))
        XCTAssertTrue(store.hasUnreadableMetadata())
    }
}

@MainActor
final class AutomaticLiveActivityCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let recordIdentifier = UUID(
        uuidString: "10600000-0000-0000-0000-000000000001"
    ) ?? UUID()

    func testEnabledCommittedStartRequestsAfterTheFastIsAuthoritative() async {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled
        )

        let result = await coordinator.didCommitActiveFastStart()

        XCTAssertEqual(result, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertEqual(client.requestedContents.count, 1)
        XCTAssertEqual(client.requestedAttributes.first?.activeRecordIdentifier, recordIdentifier)
        XCTAssertEqual(client.requestedContents.first?.startDate, source().startDate)
        XCTAssertEqual(store.storedMetadata?.lastRequestDate, now)
        XCTAssertEqual(store.storedMetadata?.lastAutomaticAttemptSucceeded, true)
    }

    func testFailedAutomaticRequestDoesNotCreateSuccessWindowAndRetriesLater() async {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.failRequests = true
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled
        )

        let firstResult = await coordinator.didCommitActiveFastStart()
        XCTAssertEqual(firstResult, .requestFailed)
        XCTAssertEqual(store.storedMetadata?.hasRequested, false)
        XCTAssertNil(store.storedMetadata?.lastRequestDate)
        XCTAssertEqual(store.storedMetadata?.lastAutomaticAttemptSucceeded, false)

        client.failRequests = false
        _ = await coordinator.didBecomeActive()
        XCTAssertEqual(client.requestedContents.count, 1)
    }

    func testForegroundContinuationUsesOriginalStartAtSeventeenHours() async throws {
        let start = now.addingTimeInterval(-17 * 60 * 60)
        let sourceBox = SourceBox(value: source(startDate: start, goalHours: 16))
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-AutomaticLiveActivityPolicy.activityWindow)
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled
        )

        let result = await coordinator.didBecomeActive()
        let requested = try XCTUnwrap(client.requestedContents.first)

        XCTAssertEqual(result, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertEqual(requested.startDate, start)
        XCTAssertEqual(requested.targetDate, start.addingTimeInterval(16 * 60 * 60))
        XCTAssertEqual(requested.generatedAt, now)
    }

    func testForegroundBeforeEightHoursDoesNotRecreateDismissedActivity() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-7 * 60 * 60 - 59 * 60 - 59),
                lastRequestBuildIdentity: .deterministic()
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled
        )

        let result = await coordinator.didBecomeActive()

        XCTAssertEqual(result, .reconciled)
        XCTAssertTrue(client.requestedContents.isEmpty)
    }

    func testChangedBuildRecoversOnceAndPreservesAuthoritativeFastProjection() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let previousBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "A")
        let currentBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "B")
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60),
                lastRequestBuildIdentity: previousBuild
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: currentBuild
        )

        let result = await coordinator.didBecomeActive()
        XCTAssertEqual(result, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertEqual(client.requestedContents.count, 1)
        XCTAssertEqual(client.requestedContents.first?.startDate, source().startDate)
        XCTAssertEqual(client.requestedContents.first?.targetDate, source().targetDate)
        XCTAssertEqual(store.storedMetadata?.lastRequestDate, now)
        XCTAssertEqual(store.storedMetadata?.lastRequestBuildIdentity, currentBuild)

        _ = await coordinator.didBecomeActive()
        XCTAssertEqual(client.requestedContents.count, 1)
        coordinator.didBecomeInactive()
        _ = await coordinator.didBecomeActive()
        XCTAssertEqual(client.requestedContents.count, 1)
    }

    func testChangedBuildRetainsAValidSurvivingActivityAndRecordsCurrentBuild() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let previousBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "A")
        let currentBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "B")
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60),
                lastRequestBuildIdentity: previousBuild
            )
        )
        client.seed(
            LiveActivityRecord(
                id: "surviving",
                activeRecordIdentifier: recordIdentifier,
                state: .active,
                contentState: .init(source: source(), generatedAt: now)
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: currentBuild
        )

        _ = await coordinator.didBecomeActive()
        XCTAssertTrue(client.requestedContents.isEmpty)
        XCTAssertEqual(store.storedMetadata?.lastKnownActivityIdentifier, "surviving")
        XCTAssertEqual(store.storedMetadata?.lastRequestBuildIdentity, currentBuild)
    }

    func testLegacyMetadataWithoutBuildIdentityCanRecoverOnFirstForeground() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60)
            )
        )
        let currentBuild = LiveActivityBuildIdentity.deterministic(buildNumber: "fixed")
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: currentBuild
        )

        _ = await coordinator.didBecomeActive()
        XCTAssertEqual(client.requestedContents.count, 1)
        XCTAssertEqual(store.storedMetadata?.lastRequestBuildIdentity, currentBuild)
    }

    func testFailedRecoveryDoesNotRetryUntilDistinctForegroundActivation() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.failRequests = true
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60),
                lastRequestBuildIdentity: .deterministic(buildNumber: "A")
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: .deterministic(buildNumber: "B")
        )

        let firstResult = await coordinator.didBecomeActive()
        XCTAssertEqual(firstResult, .requestFailed)
        let churnResult = await coordinator.didBecomeActive()
        XCTAssertEqual(churnResult, .coalesced)
        XCTAssertTrue(client.requestedContents.isEmpty)
        coordinator.didBecomeInactive()
        client.failRequests = false
        let retryResult = await coordinator.didBecomeActive()
        XCTAssertEqual(retryResult, .shown(activityIdentifier: "ufast-activity-1"))
        XCTAssertEqual(client.requestedContents.count, 1)
    }

    func testEndRaceEndsLateRecoveryAndClearsLifecycleMetadata() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.holdRequests = true
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60),
                lastRequestBuildIdentity: .deterministic(buildNumber: "A")
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: .deterministic(buildNumber: "B")
        )
        let foreground = Task { @MainActor in await coordinator.didBecomeActive() }
        while !client.requestHasStarted {
            await Task.yield()
        }
        sourceBox.value = nil
        _ = await coordinator.didCommitFastEndOrDeletion()
        client.releaseHeldRequest()
        _ = await foreground.value

        XCTAssertNil(store.storedMetadata)
        let activities = await client.activities()
        XCTAssertTrue(activities.allSatisfy { !$0.state.isRunning })
    }

    func testFailedEndRaceDoesNotRecreateLifecycleFailureMetadata() async throws {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.holdRequests = true
        client.failRequests = true
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(
            LiveActivityLifecycleMetadata(
                activeRecordIdentifier: recordIdentifier,
                hasRequested: true,
                lastRequestDate: now.addingTimeInterval(-60),
                lastRequestBuildIdentity: .deterministic(buildNumber: "A")
            )
        )
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled,
            buildIdentity: .deterministic(buildNumber: "B")
        )

        let foreground = Task { @MainActor in await coordinator.didBecomeActive() }
        while !client.requestHasStarted {
            await Task.yield()
        }
        sourceBox.value = nil
        _ = await coordinator.didCommitFastEndOrDeletion()
        client.releaseHeldRequest()
        _ = await foreground.value

        XCTAssertNil(store.storedMetadata)
        let activities = await client.activities()
        XCTAssertTrue(activities.allSatisfy { !$0.state.isRunning })
    }

    func testHideSuppressesAutomaticContinuationWithoutChangingGlobalPreference() async {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: store,
            preference: .enabled
        )

        _ = await coordinator.didCommitActiveFastStart()
        let hideResult = await coordinator.hide()
        XCTAssertEqual(hideResult, .hidden)
        coordinator.didBecomeInactive()
        let foregroundResult = await coordinator.didBecomeActive()
        XCTAssertEqual(foregroundResult, .reconciled)
        XCTAssertEqual(client.requestedContents.count, 1)
        XCTAssertTrue(store.storedMetadata?.automaticSuppressed == true)
    }

    func testSceneChurnMakesAtMostOneAutomaticAttemptPerActivation() async {
        let sourceBox = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.failRequests = true
        let coordinator = makeCoordinator(
            sourceBox: sourceBox,
            client: client,
            store: InMemoryLiveActivityLifecycleStore(),
            preference: .enabled
        )

        let firstResult = await coordinator.didBecomeActive()
        XCTAssertEqual(firstResult, .requestFailed)
        let churnResult = await coordinator.didBecomeActive()
        XCTAssertEqual(churnResult, .coalesced)
        XCTAssertEqual(client.requestedContents.count, 0)
        coordinator.didBecomeInactive()
        let secondActivationResult = await coordinator.didBecomeActive()
        XCTAssertEqual(secondActivationResult, .requestFailed)
    }

    private func makeCoordinator(
        sourceBox: SourceBox,
        client: DeterministicLiveActivityClient,
        store: InMemoryLiveActivityLifecycleStore,
        preference: AutomaticLiveActivityPreference,
        buildIdentity: LiveActivityBuildIdentity? = .deterministic()
    ) -> ActiveFastLiveActivityCoordinator {
        ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: { sourceBox.value },
            resolveAutomaticPreference: { preference },
            installedBuildIdentity: buildIdentity
        )
    }

    private func source(
        startDate: Date? = nil,
        goalHours: Int = 12
    ) -> ActiveFastActivitySource {
        let start = startDate ?? now.addingTimeInterval(-6 * 60 * 60)
        return ActiveFastActivitySource(
            activeRecordIdentifier: recordIdentifier,
            startDate: start,
            targetDate: start.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours
        )
    }
}

@MainActor
private final class SourceBox {
    var value: ActiveFastActivitySource?

    init(value: ActiveFastActivitySource?) {
        self.value = value
    }
}
