import Foundation
@testable import uFast
import XCTest

@MainActor
final class ActiveFastLiveActivityCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let recordIdentifier = UUID(
        uuidString: "10500000-0000-0000-0000-000000000002"
    ) ?? UUID()

    func testShowIsExplicitAndSecondShowDoesNotCreateADuplicate() async {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(box: box, client: client, store: store)

        let initialControlState = await coordinator.controlState()
        XCTAssertEqual(initialControlState, .show)
        let firstShow = await coordinator.show()
        XCTAssertEqual(firstShow, .shown(activityIdentifier: "ufast-activity-1"))
        let activeControlState = await coordinator.controlState()
        XCTAssertEqual(activeControlState, .hide)
        let duplicateShow = await coordinator.show()
        XCTAssertEqual(duplicateShow, .alreadyShown(activityIdentifier: "ufast-activity-1"))
        let activitiesAfterDuplicate = await client.activities()
        XCTAssertEqual(activitiesAfterDuplicate.filter(\.state.isRunning).count, 1)
        XCTAssertEqual(store.storedMetadata?.lastIntent, .shown)
    }

    func testUnavailableAndRequestFailureArePresentedWithoutCreatingAnActivity() async {
        let box = SourceBox(value: source())
        let disabledClient = DeterministicLiveActivityClient(availability: .disabled)
        let disabledStore = InMemoryLiveActivityLifecycleStore()
        let disabledCoordinator = makeCoordinator(
            box: box,
            client: disabledClient,
            store: disabledStore
        )
        let disabledResult = await disabledCoordinator.show()
        XCTAssertEqual(disabledResult, .unavailable(.disabled))
        XCTAssertNil(disabledStore.storedMetadata)

        let failureClient = DeterministicLiveActivityClient()
        failureClient.failRequests = true
        let failureStore = InMemoryLiveActivityLifecycleStore()
        let failureCoordinator = makeCoordinator(
            box: box,
            client: failureClient,
            store: failureStore
        )
        let failureResult = await failureCoordinator.show()
        XCTAssertEqual(failureResult, .requestFailed)
        let failureControlState = await failureCoordinator.controlState()
        XCTAssertEqual(failureControlState, .showAgain)
        XCTAssertEqual(failureStore.storedMetadata?.lastTerminalReason, .requestFailed)
        let failedActivities = await failureClient.activities()
        XCTAssertTrue(failedActivities.isEmpty)
    }

    func testHideEndsMatchingActivitiesImmediatelyAndFailedHideLeavesThemRunning() async {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(box: box, client: client, store: store)

        _ = await coordinator.show()
        let hideResult = await coordinator.hide()
        XCTAssertEqual(hideResult, .hidden)
        XCTAssertEqual(client.endedActivityIDs, ["ufast-activity-1"])
        let hiddenControlState = await coordinator.controlState()
        XCTAssertEqual(hiddenControlState, .showAgain)
        XCTAssertEqual(store.storedMetadata?.lastIntent, .hidden)

        let failingClient = DeterministicLiveActivityClient()
        failingClient.failEnds = true
        let failingStore = InMemoryLiveActivityLifecycleStore()
        let failingCoordinator = makeCoordinator(
            box: box,
            client: failingClient,
            store: failingStore
        )
        _ = await failingCoordinator.show()
        let failedHideResult = await failingCoordinator.hide()
        XCTAssertEqual(failedHideResult, .hideFailed)
        let failedHideControlState = await failingCoordinator.controlState()
        XCTAssertEqual(failedHideControlState, .hide)
        XCTAssertEqual(failingStore.storedMetadata?.lastIntent, .shown)
    }

    func testDismissedActivityCanOnlyReturnAfterExplicitReshow() async {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(box: box, client: client, store: store)

        _ = await coordinator.show()
        client.dismiss(activityID: "ufast-activity-1")
        let dismissedControlState = await coordinator.controlState()
        XCTAssertEqual(dismissedControlState, .showAgain)
        let reshowResult = await coordinator.show()
        XCTAssertEqual(reshowResult, .shown(activityIdentifier: "ufast-activity-2"))
        let activitiesAfterReshow = await client.activities()
        XCTAssertEqual(activitiesAfterReshow.filter(\.state.isRunning).count, 1)
    }

    func testConcurrentExplicitShowsAreCoalesced() async {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        client.holdRequests = true
        let coordinator = makeCoordinator(
            box: box,
            client: client,
            store: InMemoryLiveActivityLifecycleStore()
        )

        let first = Task { @MainActor in await coordinator.show() }
        while !client.requestHasStarted {
            await Task.yield()
        }
        let coalescedResult = await coordinator.show()
        XCTAssertEqual(coalescedResult, .coalesced)
        client.releaseHeldRequest()
        let firstResult = await first.value
        XCTAssertEqual(firstResult, .shown(activityIdentifier: "ufast-activity-1"))
    }

    func testReconcileKeepsLexicographicallySmallestValidDuplicateUpdatesItAndEndsOrphans() async throws {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(box: box, client: client, store: store)
        let oldContent = ActiveFastActivityAttributes.ContentState(
            source: source(),
            generatedAt: now.addingTimeInterval(-60)
        )
        let orphanIdentifier = try XCTUnwrap(
            UUID(uuidString: "10500000-0000-0000-0000-000000000099")
        )
        let orphanContent = ActiveFastActivityAttributes.ContentState(
            source: source(identifier: orphanIdentifier),
            generatedAt: now
        )
        client.seed(record(id: "z-duplicate", source: source(), content: oldContent))
        client.seed(record(id: "a-winner", source: source(), content: oldContent))
        client.seed(
            record(
                id: "orphan",
                source: source(identifier: orphanIdentifier),
                content: orphanContent
            )
        )

        let reconcileResult = await coordinator.reconcile()
        XCTAssertEqual(reconcileResult, .reconciled)
        XCTAssertEqual(client.endedActivityIDs, ["z-duplicate", "orphan"])
        XCTAssertEqual(client.updatedContents.map(\.0), ["a-winner"])
        XCTAssertEqual(store.storedMetadata?.lastKnownActivityIdentifier, "a-winner")
        XCTAssertEqual(store.storedMetadata?.lastRequestDate, now)
        let reconciledActivities = await client.activities()
        XCTAssertEqual(
            reconciledActivities.first(where: { $0.id == "a-winner" })?.state,
            .active
        )
    }

    func testCommittedEndEndsEveryActivityAndClearsLifecycleMetadataWithoutRequestingAnother() async {
        let box = SourceBox(value: source())
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        let coordinator = makeCoordinator(box: box, client: client, store: store)

        _ = await coordinator.show()
        client.seed(record(id: "orphan", source: source(identifier: UUID()), content: content(for: source())))
        box.value = nil

        let endResult = await coordinator.didCommitFastEndOrDeletion()
        XCTAssertEqual(endResult, .hidden)
        XCTAssertEqual(Set(client.endedActivityIDs), Set(["ufast-activity-1", "orphan"]))
        XCTAssertNil(store.storedMetadata)
        XCTAssertEqual(client.requestedContents.count, 1)
    }

    func testBackdatedFastIsEligibleEvenWhenItStartedMoreThanEightHoursAgo() async throws {
        let start = now.addingTimeInterval(-24 * 60 * 60)
        let backdated = source(startDate: start, goalHours: 16)
        let box = SourceBox(value: backdated)
        let client = DeterministicLiveActivityClient()
        let coordinator = makeCoordinator(
            box: box,
            client: client,
            store: InMemoryLiveActivityLifecycleStore()
        )

        let backdatedResult = await coordinator.show()
        XCTAssertEqual(backdatedResult, .shown(activityIdentifier: "ufast-activity-1"))
        let requested = try XCTUnwrap(client.requestedContents.first)
        XCTAssertEqual(requested.startDate, start)
        XCTAssertEqual(requested.targetDate, start.addingTimeInterval(16 * 60 * 60))
        XCTAssertTrue(requested.hasLegitimateGoalReachedObservation)
    }

    func testLifecycleStoreRoundTripsAndClearsVersionedMetadata() throws {
        let suiteName = "uFast.tests.live-activity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let identifier = recordIdentifier
        let metadata = LiveActivityLifecycleMetadata(
            activeRecordIdentifier: identifier,
            hasRequested: true,
            lastRequestDate: now,
            lastKnownActivityIdentifier: "ufast-activity-9",
            lastIntent: .hidden,
            lastTerminalReason: .userHidden
        )
        let store = UserDefaultsLiveActivityLifecycleStore(defaults: defaults)
        try store.save(metadata)

        XCTAssertEqual(try store.metadata(for: identifier), metadata)
        try store.clear(for: identifier)
        XCTAssertNil(try store.metadata(for: identifier))
    }

    private func makeCoordinator(
        box: SourceBox,
        client: DeterministicLiveActivityClient,
        store: InMemoryLiveActivityLifecycleStore
    ) -> ActiveFastLiveActivityCoordinator {
        ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: { box.value }
        )
    }

    private func source(
        identifier: UUID = UUID(
            uuidString: "10500000-0000-0000-0000-000000000002"
        ) ?? UUID(),
        startDate: Date? = nil,
        goalHours: Int = 12
    ) -> ActiveFastActivitySource {
        let start = startDate ?? now.addingTimeInterval(-6 * 60 * 60)
        return ActiveFastActivitySource(
            activeRecordIdentifier: identifier,
            startDate: start,
            targetDate: start.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours
        )
    }

    private func content(for source: ActiveFastActivitySource) -> ActiveFastActivityAttributes.ContentState {
        .init(source: source, generatedAt: now)
    }

    private func record(
        id: String,
        source: ActiveFastActivitySource,
        content: ActiveFastActivityAttributes.ContentState
    ) -> LiveActivityRecord {
        LiveActivityRecord(
            id: id,
            activeRecordIdentifier: source.activeRecordIdentifier,
            state: .active,
            contentState: content
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
