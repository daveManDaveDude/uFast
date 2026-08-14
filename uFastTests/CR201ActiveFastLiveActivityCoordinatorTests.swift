import Foundation
import SwiftData
@testable import uFast
import XCTest

@MainActor
final class CRActivityCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testResolverFailureEndsEveryActivityClearsMetadataAndDoesNotRequestOrUpdate() async throws {
        let firstIdentifier = try XCTUnwrap(
            UUID(uuidString: "10500000-0000-0000-0000-000000000010")
        )
        let secondIdentifier = try XCTUnwrap(
            UUID(uuidString: "10500000-0000-0000-0000-000000000011")
        )
        let sources = [source(identifier: firstIdentifier), source(identifier: secondIdentifier)]
        let originalSources = sources
        let client = DeterministicLiveActivityClient()
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(LiveActivityLifecycleMetadata(
            activeRecordIdentifier: firstIdentifier,
            hasRequested: true,
            lastRequestDate: now,
            lastKnownActivityIdentifier: "first",
            lastIntent: .shown
        ))
        client.seed(record(id: "first", source: sources[0], content: content(for: sources[0])))
        client.seed(record(id: "second", source: sources[1], content: content(for: sources[1])))
        client.seed(record(id: "orphan", source: source(identifier: UUID()), content: content(for: sources[0])))
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: {
                _ = sources
                throw ActiveFastIntegrityError.multipleActiveFasts(count: sources.count)
            }
        )

        let result = await coordinator.reconcile()

        XCTAssertEqual(result, .reconciled)
        XCTAssertEqual(
            client.endAttemptedActivityIDs,
            ["first", "second", "orphan"],
            "Ambiguous authority cleanup must attempt every observed activity."
        )
        XCTAssertEqual(Set(client.endedActivityIDs), Set(["first", "second", "orphan"]))
        XCTAssertTrue(client.requestedContents.isEmpty)
        XCTAssertTrue(client.updatedContents.isEmpty)
        XCTAssertNil(store.storedMetadata)
        XCTAssertEqual(sources, originalSources)
    }

    func testProductionResolverFailureLeavesAmbiguousSwiftDataRowsUntouched() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let records = try makeDistinctActiveRecords(in: context)
        let originalStates = Dictionary(uniqueKeysWithValues: records.map { ($0.id, state(of: $0)) })
        try context.save()

        let client = DeterministicLiveActivityClient()
        client.seed(record(id: "swiftdata-first", source: source(for: records[0])))
        client.seed(record(id: "swiftdata-second", source: source(for: records[1])))
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(LiveActivityLifecycleMetadata(
            activeRecordIdentifier: records[0].id,
            hasRequested: true,
            lastRequestDate: now,
            lastKnownActivityIdentifier: "swiftdata-first"
        ))
        let resolver = productionResolver(for: container)
        XCTAssertThrowsError(try resolver()) { error in
            XCTAssertEqual(error as? ActiveFastIntegrityError, .multipleActiveFasts(count: 2))
        }
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: resolver
        )

        let result = await coordinator.reconcile()

        XCTAssertEqual(result, .reconciled)
        XCTAssertEqual(client.endAttemptedActivityIDs, ["swiftdata-first", "swiftdata-second"])
        XCTAssertEqual(Set(client.endedActivityIDs), Set(["swiftdata-first", "swiftdata-second"]))
        XCTAssertTrue(client.requestedAttributes.isEmpty)
        XCTAssertTrue(client.requestedContents.isEmpty)
        XCTAssertTrue(client.updatedContents.isEmpty)
        XCTAssertNil(store.storedMetadata)
        let stored = try context.fetch(FetchDescriptor<FastRecord>())
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: stored.map { ($0.id, state(of: $0)) }),
            originalStates
        )
        XCTAssertFalse(context.hasChanges)
    }

    func testResolverFailureContinuesAfterAnEndFailure() async throws {
        let firstIdentifier = try XCTUnwrap(
            UUID(uuidString: "10500000-0000-0000-0000-000000000012")
        )
        let secondIdentifier = try XCTUnwrap(
            UUID(uuidString: "10500000-0000-0000-0000-000000000013")
        )
        let first = source(identifier: firstIdentifier)
        let second = source(identifier: secondIdentifier)
        let client = DeterministicLiveActivityClient()
        client.failEnds = true
        let store = InMemoryLiveActivityLifecycleStore()
        try store.save(LiveActivityLifecycleMetadata(
            activeRecordIdentifier: first.activeRecordIdentifier,
            hasRequested: true,
            lastRequestDate: now,
            lastKnownActivityIdentifier: "first"
        ))
        client.seed(record(id: "first", source: first, content: content(for: first)))
        client.seed(record(id: "second", source: second, content: content(for: second)))
        let coordinator = ActiveFastLiveActivityCoordinator(
            clock: FixedAppClock(now: now),
            client: client,
            lifecycleStore: store,
            resolveActiveFast: {
                throw ActiveFastIntegrityError.multipleActiveFasts(count: 2)
            }
        )

        let result = await coordinator.reconcile()

        XCTAssertEqual(result, .reconciled)
        XCTAssertEqual(client.endAttemptedActivityIDs, ["first", "second"])
        XCTAssertTrue(client.endedActivityIDs.isEmpty)
        XCTAssertTrue(client.requestedContents.isEmpty)
        XCTAssertTrue(client.updatedContents.isEmpty)
        XCTAssertNil(store.storedMetadata)
    }

    private func source(
        identifier: UUID,
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

    private func source(for record: FastRecord) -> ActiveFastActivitySource {
        let goalHours = record.historicalGoal?.hours ?? FastingGoal.default.hours
        return ActiveFastActivitySource(
            activeRecordIdentifier: record.id,
            startDate: record.startDate,
            targetDate: record.startDate.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours
        )
    }

    private func makeDistinctActiveRecords(in context: ModelContext) throws -> [FastRecord] {
        let firstID = try uuid("20500000-0000-0000-0000-000000000010")
        let secondID = try uuid("20500000-0000-0000-0000-000000000011")
        let firstGoal = try goal(hours: 14)
        let secondGoal = try goal(hours: 18)
        let startBoundaryID = try uuid("30500000-0000-0000-0000-000000000010")
        let endBoundaryID = try uuid("30500000-0000-0000-0000-000000000011")
        let first = FastRecord(
            id: firstID,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            goalAtStart: firstGoal
        )
        let second = FastRecord(
            id: secondID,
            startDate: Date(timeIntervalSince1970: 1_700_003_600),
            goalAtStart: secondGoal
        )
        second.restoreProvenance(FastRecordProvenanceSnapshot(
            originRaw: FastOrigin.reconstructed.rawValue,
            reviewStateRaw: FastReviewState.needsReview.rawValue,
            wasAdjustedByUser: true,
            hasHistoricalGoal: false,
            startBoundaryKindRaw: CaloricBoundaryKind.food.rawValue,
            startBoundaryID: startBoundaryID,
            endBoundaryKindRaw: CaloricBoundaryKind.hydration.rawValue,
            endBoundaryID: endBoundaryID
        ))
        second.restorePersistedHistoricalGoal(rawHours: 18, isCaptured: false)
        context.insert(first)
        context.insert(second)
        return [first, second]
    }

    private func uuid(_ string: String) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: string))
    }

    private func goal(hours: Int) throws -> FastingGoal {
        try XCTUnwrap(FastingGoal(hours: hours))
    }

    private func productionResolver(
        for container: ModelContainer
    ) -> ActiveFastLiveActivityCoordinator.ActiveFastResolver {
        {
            let context = container.mainContext
            guard let fast = try ActiveFastAuthority.fetch(in: context) else {
                return nil
            }
            let goal = try SwiftDataSettingsStore(modelContext: context)
                .authoritativeRecord()?.fastingGoal ?? .default
            return ActiveFastActivitySource(
                activeRecordIdentifier: fast.id,
                startDate: fast.startDate,
                targetDate: fast.startDate.addingTimeInterval(
                    TimeInterval(goal.hours * 60 * 60)
                ),
                goalHours: goal.hours
            )
        }
    }

    private func state(of record: FastRecord) -> PersistedFastRecordState {
        PersistedFastRecordState(
            id: record.id,
            startDate: record.startDate,
            endDate: record.endDate,
            historicalGoal: record.historicalGoal,
            capturedHistoricalGoal: record.capturedHistoricalGoal,
            provenance: record.provenanceSnapshot
        )
    }

    private func content(for source: ActiveFastActivitySource) -> ActiveFastActivityAttributes.ContentState {
        .init(source: source, generatedAt: now)
    }

    private func record(
        id: String,
        source: ActiveFastActivitySource,
        content: ActiveFastActivityAttributes.ContentState? = nil
    ) -> LiveActivityRecord {
        let content = content ?? self.content(for: source)
        return LiveActivityRecord(
            id: id,
            activeRecordIdentifier: source.activeRecordIdentifier,
            state: .active,
            contentState: content
        )
    }
}

private struct PersistedFastRecordState: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let historicalGoal: FastingGoal?
    let capturedHistoricalGoal: FastingGoal?
    let provenance: FastRecordProvenanceSnapshot
}
