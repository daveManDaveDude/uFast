import Foundation
@testable import uFast
import XCTest

final class AutomaticLiveActivityPreferenceTests: XCTestCase {
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
        XCTAssertNil(migrated.lastAutomaticAttemptDate)
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
                lastRequestDate: now.addingTimeInterval(-7 * 60 * 60 - 59 * 60 - 59)
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
        preference: AutomaticLiveActivityPreference
    ) -> ActiveFastLiveActivityCoordinator {
        ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: { sourceBox.value },
            resolveAutomaticPreference: { preference }
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
