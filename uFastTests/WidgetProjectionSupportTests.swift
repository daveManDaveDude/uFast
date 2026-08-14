import Foundation
import SwiftData
@testable import uFast
import XCTest

@MainActor
final class WidgetProjectionSupportTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoActiveFastClearsProjectionAndReloads() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: makeProjection(), events: events)
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        XCTAssertNil(try store.read())
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertEqual(events.values, ["clear", "reload"])
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FastRecord>()).isEmpty)
    }

    func testOneActiveFastAndOneSettingsAuthorityPublishNormally() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let fast = FastRecord(
            startDate: now.addingTimeInterval(-60 * 60),
            goalAtStart: .default
        )
        let settings = try AppSettingsRecord(
            fastingGoal: XCTUnwrap(FastingGoal(hours: 16)),
            hasCompletedOnboarding: true
        )
        context.insert(fast)
        context.insert(settings)
        try context.save()
        let originalID = fast.id
        let originalStart = fast.startDate
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(events: events)
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        let projection = try XCTUnwrap(store.projection)
        XCTAssertEqual(projection.activeRecordIdentifier, originalID)
        XCTAssertEqual(projection.startDate, originalStart)
        XCTAssertEqual(projection.goalHours, 16)
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertEqual(events.values, ["write", "reload"])
        XCTAssertTrue(fast.isActive)
        XCTAssertFalse(context.hasChanges)
    }

    func testTwoActiveFastsClearProjectionPreserveBothRecordsAndReload() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let first = FastRecord(
            startDate: now.addingTimeInterval(-2 * 60 * 60),
            goalAtStart: .default
        )
        let second = FastRecord(
            startDate: now.addingTimeInterval(-60 * 60),
            goalAtStart: .default
        )
        context.insert(first)
        context.insert(second)
        try context.save()
        let originalRecords = try context.fetch(FetchDescriptor<FastRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { ($0.id, $0.startDate, $0.endDate) }
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: makeProjection(), events: events)
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        XCTAssertNil(try store.read())
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertEqual(events.values, ["clear", "reload"])
        let persistedRecords = try context.fetch(FetchDescriptor<FastRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { ($0.id, $0.startDate, $0.endDate) }
        XCTAssertEqual(persistedRecords.map(\.0), originalRecords.map(\.0))
        XCTAssertEqual(persistedRecords.map(\.1), originalRecords.map(\.1))
        XCTAssertEqual(persistedRecords.map(\.2), originalRecords.map(\.2))
        XCTAssertFalse(context.hasChanges)
    }

    func testAmbiguousAuthorityUsesInvalidationWhenClearFails() throws {
        let container = try containerWithTwoActiveFasts()
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: makeProjection(), events: events)
        store.shouldFailClear = true
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        XCTAssertTrue(store.isInvalidated)
        XCTAssertNil(try store.read())
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertEqual(events.values, ["clear", "invalidate", "reload"])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<FastRecord>()).count, 2)
    }

    func testAmbiguousAuthorityWithTotalProjectionFailureDoesNotReloadOrMutateRecords() throws {
        let container = try containerWithTwoActiveFasts()
        let context = container.mainContext
        let originalRecords = try context.fetch(FetchDescriptor<FastRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { ($0.id, $0.startDate, $0.endDate) }
        let oldProjection = makeProjection()
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: oldProjection, events: events)
        store.shouldFailClear = true
        store.shouldFailInvalidation = true
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        XCTAssertFalse(store.isInvalidated)
        XCTAssertEqual(store.projection, oldProjection)
        XCTAssertEqual(reloader.reloadCount, 0)
        XCTAssertEqual(events.values, ["clear", "invalidate"])
        let persistedRecords = try context.fetch(FetchDescriptor<FastRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { ($0.id, $0.startDate, $0.endDate) }
        XCTAssertEqual(persistedRecords.map(\.0), originalRecords.map(\.0))
        XCTAssertEqual(persistedRecords.map(\.1), originalRecords.map(\.1))
        XCTAssertEqual(persistedRecords.map(\.2), originalRecords.map(\.2))
        XCTAssertFalse(context.hasChanges)
    }

    func testSettingsAmbiguityLeavesProjectionUnchanged() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let fast = FastRecord(
            startDate: now.addingTimeInterval(-60 * 60),
            goalAtStart: .default
        )
        let firstSettings = AppSettingsRecord(fastingGoal: .default)
        let secondSettings = AppSettingsRecord(fastingGoal: .default)
        context.insert(fast)
        context.insert(firstSettings)
        context.insert(secondSettings)
        try context.save()
        let oldProjection = makeProjection()
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: oldProjection, events: events)
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        WidgetProjectionSupport.synchronize(
            in: container,
            now: now,
            projectionCoordinator: coordinator
        )

        XCTAssertEqual(store.projection, oldProjection)
        XCTAssertEqual(reloader.reloadCount, 0)
        XCTAssertTrue(events.values.isEmpty)
        XCTAssertTrue(fast.isActive)
    }

    func testFailedPersistenceBeforeSynchronizationLeavesProjectionUnchanged() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let oldProjection = makeProjection()
        let events = LaunchProjectionEventLog()
        let store = LaunchProjectionStoreSpy(projection: oldProjection, events: events)
        let reloader = LaunchProjectionReloaderSpy(events: events)
        let repository = SwiftDataActiveFastRepository(
            modelContext: context,
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(
            try repository.saveNewActiveFast(
                FastRecord(
                    startDate: now.addingTimeInterval(-60 * 60),
                    goalAtStart: .default
                )
            )
        )

        XCTAssertEqual(store.projection, oldProjection)
        XCTAssertEqual(reloader.reloadCount, 0)
        XCTAssertTrue(events.values.isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    private func containerWithTwoActiveFasts() throws -> ModelContainer {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(
            FastRecord(
                startDate: now.addingTimeInterval(-2 * 60 * 60),
                goalAtStart: .default
            )
        )
        context.insert(
            FastRecord(
                startDate: now.addingTimeInterval(-60 * 60),
                goalAtStart: .default
            )
        )
        try context.save()
        return container
    }

    private func makeProjection() -> ActiveFastWidgetProjection {
        let start = now.addingTimeInterval(-60 * 60)
        return ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: start,
            targetDate: start.addingTimeInterval(12 * 60 * 60),
            goalHours: 12,
            generatedAt: now
        )
    }
}

private final class LaunchProjectionStoreSpy: ActiveFastProjectionStore, @unchecked Sendable {
    var projection: ActiveFastWidgetProjection?
    var shouldFailClear = false
    var shouldFailInvalidation = false
    var isInvalidated = false
    private let events: LaunchProjectionEventLog?

    init(
        projection: ActiveFastWidgetProjection? = nil,
        events: LaunchProjectionEventLog? = nil
    ) {
        self.projection = projection
        self.events = events
    }

    func read() throws -> ActiveFastWidgetProjection? {
        isInvalidated ? nil : projection
    }

    func write(_ projection: ActiveFastWidgetProjection) throws {
        events?.values.append("write")
        self.projection = projection
        isInvalidated = false
    }

    func clear() throws {
        events?.values.append("clear")
        if shouldFailClear {
            throw ActiveFastWidgetProjectionError.unreadable
        }
        projection = nil
        isInvalidated = false
    }

    func invalidate() throws {
        events?.values.append("invalidate")
        if shouldFailInvalidation {
            throw ActiveFastWidgetProjectionError.unreadable
        }
        isInvalidated = true
    }
}

private final class LaunchProjectionEventLog: @unchecked Sendable {
    var values: [String] = []
}

private final class LaunchProjectionReloaderSpy: ActiveFastProjectionReloading, @unchecked Sendable {
    var reloadCount = 0
    private let events: LaunchProjectionEventLog?

    init(events: LaunchProjectionEventLog? = nil) {
        self.events = events
    }

    func reloadTimelines() {
        reloadCount += 1
        events?.values.append("reload")
    }
}
