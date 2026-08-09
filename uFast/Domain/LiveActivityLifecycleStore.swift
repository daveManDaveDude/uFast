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
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let activeRecordIdentifier: UUID
    var hasRequested: Bool
    var lastRequestDate: Date?
    var lastKnownActivityIdentifier: String?
    var lastIntent: LiveActivityLifecycleIntent?
    var lastTerminalReason: LiveActivityTerminalReason?
    var automaticSuppressed: Bool
    var lastAutomaticAttemptDate: Date?
    var lastAutomaticAttemptSucceeded: Bool?

    init(
        activeRecordIdentifier: UUID,
        hasRequested: Bool = false,
        lastRequestDate: Date? = nil,
        lastKnownActivityIdentifier: String? = nil,
        lastIntent: LiveActivityLifecycleIntent? = nil,
        lastTerminalReason: LiveActivityTerminalReason? = nil,
        automaticSuppressed: Bool = false,
        lastAutomaticAttemptDate: Date? = nil,
        lastAutomaticAttemptSucceeded: Bool? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.activeRecordIdentifier = activeRecordIdentifier
        self.hasRequested = hasRequested
        self.lastRequestDate = lastRequestDate
        self.lastKnownActivityIdentifier = lastKnownActivityIdentifier
        self.lastIntent = lastIntent
        self.lastTerminalReason = lastTerminalReason
        self.automaticSuppressed = automaticSuppressed
        self.lastAutomaticAttemptDate = lastAutomaticAttemptDate
        self.lastAutomaticAttemptSucceeded = lastAutomaticAttemptSucceeded
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case activeRecordIdentifier
        case hasRequested
        case lastRequestDate
        case lastKnownActivityIdentifier
        case lastIntent
        case lastTerminalReason
        case automaticSuppressed
        case lastAutomaticAttemptDate
        case lastAutomaticAttemptSucceeded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 || schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Live Activity lifecycle schema."
            )
        }

        let lastIntent = try container.decodeIfPresent(
            LiveActivityLifecycleIntent.self,
            forKey: .lastIntent
        )
        try self.init(
            activeRecordIdentifier: container.decode(UUID.self, forKey: .activeRecordIdentifier),
            hasRequested: container.decode(Bool.self, forKey: .hasRequested),
            lastRequestDate: container.decodeIfPresent(Date.self, forKey: .lastRequestDate),
            lastKnownActivityIdentifier: container.decodeIfPresent(
                String.self,
                forKey: .lastKnownActivityIdentifier
            ),
            lastIntent: lastIntent,
            lastTerminalReason: container.decodeIfPresent(
                LiveActivityTerminalReason.self,
                forKey: .lastTerminalReason
            ),
            // v1 represented Hide for this fast through the hidden intent.
            automaticSuppressed: container.decodeIfPresent(
                Bool.self,
                forKey: .automaticSuppressed
            ) ?? (lastIntent == .hidden),
            lastAutomaticAttemptDate: container.decodeIfPresent(
                Date.self,
                forKey: .lastAutomaticAttemptDate
            ),
            lastAutomaticAttemptSucceeded: container.decodeIfPresent(
                Bool.self,
                forKey: .lastAutomaticAttemptSucceeded
            )
        )
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
            guard metadata.activeRecordIdentifier == activeRecordIdentifier
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
