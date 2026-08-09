import Foundation

enum LiveActivityLifecycleIntent: String, Codable, Equatable, Sendable {
    case shown
    case hidden
}

enum LiveActivityTerminalReason: String, Codable, Equatable, Sendable {
    case userHidden
    case requestFailed
    case dismissedOrSystemEnded
}

struct LiveActivityLifecycleMetadata: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let activeRecordIdentifier: UUID
    var hasRequested: Bool
    var lastRequestDate: Date?
    var lastKnownActivityIdentifier: String?
    var lastIntent: LiveActivityLifecycleIntent?
    var lastTerminalReason: LiveActivityTerminalReason?

    init(
        activeRecordIdentifier: UUID,
        hasRequested: Bool = false,
        lastRequestDate: Date? = nil,
        lastKnownActivityIdentifier: String? = nil,
        lastIntent: LiveActivityLifecycleIntent? = nil,
        lastTerminalReason: LiveActivityTerminalReason? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.activeRecordIdentifier = activeRecordIdentifier
        self.hasRequested = hasRequested
        self.lastRequestDate = lastRequestDate
        self.lastKnownActivityIdentifier = lastKnownActivityIdentifier
        self.lastIntent = lastIntent
        self.lastTerminalReason = lastTerminalReason
    }
}

@MainActor
protocol LiveActivityLifecycleStore: AnyObject {
    func metadata(for activeRecordIdentifier: UUID) throws -> LiveActivityLifecycleMetadata?
    func save(_ metadata: LiveActivityLifecycleMetadata) throws
    func clear(for activeRecordIdentifier: UUID) throws
    func clearAll() throws
}

@MainActor
final class UserDefaultsLiveActivityLifecycleStore: LiveActivityLifecycleStore {
    private static let key = "uFast.liveActivity.lifecycle.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for activeRecordIdentifier: UUID) throws -> LiveActivityLifecycleMetadata? {
        guard let data = defaults.data(forKey: Self.key) else {
            return nil
        }
        do {
            let metadata = try JSONDecoder().decode(LiveActivityLifecycleMetadata.self, from: data)
            guard metadata.schemaVersion == LiveActivityLifecycleMetadata.currentSchemaVersion,
                  metadata.activeRecordIdentifier == activeRecordIdentifier
            else {
                return nil
            }
            return metadata
        } catch {
            defaults.removeObject(forKey: Self.key)
            return nil
        }
    }

    func save(_ metadata: LiveActivityLifecycleMetadata) throws {
        let data = try JSONEncoder().encode(metadata)
        defaults.set(data, forKey: Self.key)
    }

    func clear(for activeRecordIdentifier: UUID) throws {
        guard let metadata = try metadata(for: activeRecordIdentifier) else {
            return
        }
        guard metadata.activeRecordIdentifier == activeRecordIdentifier else {
            return
        }
        defaults.removeObject(forKey: Self.key)
    }

    func clearAll() throws {
        defaults.removeObject(forKey: Self.key)
    }
}

@MainActor
final class InMemoryLiveActivityLifecycleStore: LiveActivityLifecycleStore {
    private(set) var storedMetadata: LiveActivityLifecycleMetadata?

    var saveError: Error?
    var clearError: Error?

    func metadata(for activeRecordIdentifier: UUID) throws -> LiveActivityLifecycleMetadata? {
        guard storedMetadata?.activeRecordIdentifier == activeRecordIdentifier else {
            return nil
        }
        return storedMetadata
    }

    func save(_ metadata: LiveActivityLifecycleMetadata) throws {
        if let saveError {
            throw saveError
        }
        storedMetadata = metadata
    }

    func clear(for _: UUID) throws {
        if let clearError {
            throw clearError
        }
        storedMetadata = nil
    }

    func clearAll() throws {
        if let clearError {
            throw clearError
        }
        storedMetadata = nil
    }
}
