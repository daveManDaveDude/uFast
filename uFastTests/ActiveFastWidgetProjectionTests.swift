import Foundation
@testable import uFast
import XCTest

final class ActiveFastWidgetProjectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let identifier = UUID()

    func testValidProjectionContainsOnlyAcceptedFieldsAndRoundTrips() throws {
        let projection = makeProjection()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActiveFastProjectionFileStore(containerURL: directory)

        try store.write(projection)

        XCTAssertEqual(try store.read(), projection)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: store.fileURL)) as? [String: Any]
        )
        XCTAssertEqual(object.keys.count, 6)
        XCTAssertNotNil(object["schemaVersion"])
        XCTAssertNotNil(object["activeRecordIdentifier"])
        XCTAssertNotNil(object["startDate"])
        XCTAssertNotNil(object["targetDate"])
        XCTAssertNotNil(object["goalHours"])
        XCTAssertNotNil(object["generatedAt"])
    }

    func testValidationRejectsIncompatibleCorruptAndFutureValues() {
        XCTAssertThrowsError(try makeProjection(schemaVersion: 2).validate(now: now)) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .incompatibleSchema)
        }
        XCTAssertThrowsError(try makeProjection(goalHours: 7).validate(now: now)) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .invalidGoal)
        }
        XCTAssertThrowsError(
            try makeProjection(targetDate: now.addingTimeInterval(-2 * 60 * 60)).validate(now: now)
        ) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .invalidTarget)
        }
        XCTAssertThrowsError(
            try makeProjection(targetDate: now.addingTimeInterval(9 * 60 * 60)).validate(now: now)
        ) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .inconsistentTarget)
        }
        XCTAssertThrowsError(
            try makeProjection(startDate: now.addingTimeInterval(1)).validate(now: now)
        ) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .futureStart)
        }
    }

    func testGenerationAgeAloneDoesNotInvalidateProjection() throws {
        let oldGenerationDate = now.addingTimeInterval(-90 * 24 * 60 * 60)
        try makeProjection(generatedAt: oldGenerationDate).validate(now: now)
    }

    func testMissingAndCorruptFilesFailClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActiveFastProjectionFileStore(containerURL: directory)

        XCTAssertNil(try store.read())
        try Data("not-json".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.read()) {
            XCTAssertEqual($0 as? ActiveFastWidgetProjectionError, .unreadable)
        }
    }

    func testClearIsIdempotentAndRemovesProjection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActiveFastProjectionFileStore(containerURL: directory)
        try store.write(makeProjection())

        try store.clear()
        try store.clear()

        XCTAssertNil(try store.read())
    }

    func testInvalidationMarkerHidesExistingProjectionUntilNextSuccessfulWrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActiveFastProjectionFileStore(containerURL: directory)
        let projection = makeProjection()

        try store.write(projection)
        try store.invalidate()
        XCTAssertNil(try store.read())

        try store.write(projection)
        XCTAssertEqual(try store.read(), projection)
    }

    func testClearRemovesAStaleInvalidationMarkerWhenProjectionIsAlreadyMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActiveFastProjectionFileStore(containerURL: directory)

        try store.invalidate()
        try store.clear()
        try store.write(makeProjection())

        XCTAssertEqual(try store.read(), makeProjection())
    }

    func testCoordinatorWritesThenReloadsAndNeverReloadsAfterAWriteFailure() {
        let store = ProjectionStoreSpy()
        let reloader = ProjectionReloaderSpy()
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)

        coordinator.publish(
            activeRecordIdentifier: identifier,
            startDate: now.addingTimeInterval(-60 * 60),
            goalHours: 12,
            generatedAt: now
        )

        XCTAssertEqual(store.projection?.activeRecordIdentifier, identifier)
        XCTAssertEqual(store.projection?.goalHours, 12)
        XCTAssertEqual(reloader.reloadCount, 1)

        store.shouldFail = true
        coordinator.clear()

        XCTAssertTrue(store.isInvalidated)
        XCTAssertEqual(reloader.reloadCount, 2)
    }

    func testPublishFailureLeavesPreviousProjectionAndDoesNotReload() {
        let store = ProjectionStoreSpy()
        let reloader = ProjectionReloaderSpy()
        let coordinator = ActiveFastProjectionCoordinator(store: store, reloader: reloader)
        coordinator.publish(
            activeRecordIdentifier: identifier,
            startDate: now.addingTimeInterval(-60 * 60),
            goalHours: 12,
            generatedAt: now
        )
        let previous = store.projection

        store.shouldFail = true
        coordinator.publish(
            activeRecordIdentifier: UUID(),
            startDate: now.addingTimeInterval(-2 * 60 * 60),
            goalHours: 16,
            generatedAt: now
        )

        XCTAssertEqual(store.projection, previous)
        XCTAssertEqual(reloader.reloadCount, 1)
    }

    private func makeProjection(
        schemaVersion: Int = ActiveFastWidgetProjection.currentSchemaVersion,
        startDate: Date? = nil,
        targetDate: Date? = nil,
        goalHours: Int = 8,
        generatedAt: Date? = nil
    ) -> ActiveFastWidgetProjection {
        let start = startDate ?? now.addingTimeInterval(-60 * 60)
        return ActiveFastWidgetProjection(
            schemaVersion: schemaVersion,
            activeRecordIdentifier: identifier,
            startDate: start,
            targetDate: targetDate ?? start.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours,
            generatedAt: generatedAt ?? now
        )
    }
}

private final class ProjectionStoreSpy: ActiveFastProjectionStore, @unchecked Sendable {
    var projection: ActiveFastWidgetProjection?
    var shouldFail = false
    var isInvalidated = false

    func read() throws -> ActiveFastWidgetProjection? {
        projection
    }

    func write(_ projection: ActiveFastWidgetProjection) throws {
        if shouldFail {
            throw ActiveFastWidgetProjectionError.unreadable
        }
        self.projection = projection
    }

    func clear() throws {
        if shouldFail {
            throw ActiveFastWidgetProjectionError.unreadable
        }
        projection = nil
    }

    func invalidate() throws {
        isInvalidated = true
    }
}

private final class ProjectionReloaderSpy: ActiveFastProjectionReloading, @unchecked Sendable {
    var reloadCount = 0

    func reloadTimelines() {
        reloadCount += 1
    }
}
