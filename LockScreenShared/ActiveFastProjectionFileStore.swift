import Foundation
import OSLog

protocol ActiveFastProjectionStore: Sendable {
    func read() throws -> ActiveFastWidgetProjection?
    func write(_ projection: ActiveFastWidgetProjection) throws
    func clear() throws
    func invalidate() throws
}

struct ActiveFastProjectionFileStore: ActiveFastProjectionStore, Sendable {
    static let appGroupIdentifier = "group.com.davidmcgrath.uFast.widgets"
    static let fileName = "active-fast-widget-projection.json"
    static let invalidationFileName = "active-fast-widget-projection.invalidated"
    static let widgetKind = "UFastLockScreenWidget"
    static let protectionType = FileProtectionType.completeUntilFirstUserAuthentication

    let fileURL: URL
    let invalidationFileURL: URL

    init(containerURL: URL) {
        fileURL = containerURL.appendingPathComponent(Self.fileName, isDirectory: false)
        invalidationFileURL = containerURL.appendingPathComponent(
            Self.invalidationFileName,
            isDirectory: false
        )
    }

    func read() throws -> ActiveFastWidgetProjection? {
        guard !FileManager.default.fileExists(atPath: invalidationFileURL.path) else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(ActiveFastWidgetProjection.self, from: data)
        } catch {
            throw ActiveFastWidgetProjectionError.unreadable
        }
    }

    func write(_ projection: ActiveFastWidgetProjection) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(projection)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: Self.protectionType],
            ofItemAtPath: fileURL.path
        )
        try removeInvalidationMarkerIfPresent()
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        // A previous failed clear can leave the fail-closed marker behind
        // after the JSON has already gone. Always remove both pieces together
        // so a later successful publish cannot be hidden by stale state.
        try removeInvalidationMarkerIfPresent()
    }

    func invalidate() throws {
        try Data().write(to: invalidationFileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: Self.protectionType],
            ofItemAtPath: invalidationFileURL.path
        )
    }

    private func removeInvalidationMarkerIfPresent() throws {
        guard FileManager.default.fileExists(atPath: invalidationFileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: invalidationFileURL)
    }
}

protocol ActiveFastProjectionReloading: Sendable {
    func reloadTimelines()
}

/// Keeps the widget's disposable projection strictly downstream of committed
/// fasting changes. Errors are intentionally reported to the caller but do not
/// affect the already-committed source record.
struct ActiveFastProjectionCoordinator: Sendable {
    private static let logger = Logger(
        subsystem: "com.davidmcgrath.uFast",
        category: "WidgetProjection"
    )

    let store: any ActiveFastProjectionStore
    let reloader: any ActiveFastProjectionReloading

    func publish(
        activeRecordIdentifier: UUID,
        startDate: Date,
        goalHours: Int,
        generatedAt: Date
    ) {
        let targetDate = startDate.addingTimeInterval(TimeInterval(goalHours * 60 * 60))
        let projection = ActiveFastWidgetProjection(
            activeRecordIdentifier: activeRecordIdentifier,
            startDate: startDate,
            targetDate: targetDate,
            goalHours: goalHours,
            generatedAt: generatedAt
        )
        do {
            try store.write(projection)
            Self.logger.notice("Active fast projection written; requesting widget reload")
            reloader.reloadTimelines()
        } catch {
            Self.logger.error("Active fast projection publish failed: \(String(describing: error), privacy: .public)")
            // The SwiftData commit is authoritative and must never be rolled back.
        }
    }

    func clear() {
        do {
            try store.clear()
            Self.logger.notice("Active fast projection cleared; requesting widget reload")
            reloader.reloadTimelines()
        } catch {
            Self.logger.error("Active fast projection clear failed: \(String(describing: error), privacy: .public)")
            // If removal fails after a committed end, hide any old JSON before
            // reloading. This keeps the Lock Screen projection fail-closed.
            do {
                try store.invalidate()
                Self.logger.notice("Projection invalidation marker written; requesting widget reload")
                reloader.reloadTimelines()
            } catch {
                Self.logger.error("Projection invalidation failed: \(String(describing: error), privacy: .public)")
                // The authoritative SwiftData record remains unchanged either way.
            }
        }
    }
}
