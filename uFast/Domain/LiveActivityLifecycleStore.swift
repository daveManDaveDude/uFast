import Foundation

// swiftlint:disable function_body_length

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
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    let activeRecordIdentifier: UUID
    var hasRequested: Bool
    var lastRequestDate: Date?
    var lastKnownActivityIdentifier: String?
    /// The installed release/build identity that made the last successful
    /// ActivityKit request. `nil` is retained for migration from older data.
    var lastRequestBuildIdentity: LiveActivityBuildIdentity?

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
        lastRequestBuildIdentity: LiveActivityBuildIdentity? = nil,
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
        self.lastRequestBuildIdentity = lastRequestBuildIdentity
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
        case lastRequestBuildIdentity
        case lastSuccessfulRequestBuildIdentity
        case lastIntent
        case lastTerminalReason
        case automaticSuppressed
        case lastAutomaticAttemptDate
        case lastAutomaticAttemptSucceeded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 || schemaVersion == 2 || schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported Live Activity lifecycle schema."
            )
        }

        let activeRecordIdentifier = try container.decode(UUID.self, forKey: .activeRecordIdentifier)
        let hasRequested = try container.decode(Bool.self, forKey: .hasRequested)
        let lastRequestDate = try container.decodeIfPresent(Date.self, forKey: .lastRequestDate)
        guard !hasRequested || lastRequestDate != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastRequestDate,
                in: container,
                debugDescription: "A successful Live Activity request requires a request date."
            )
        }

        let lastIntent = try container.decodeIfPresent(
            LiveActivityLifecycleIntent.self,
            forKey: .lastIntent
        )
        try self.init(
            activeRecordIdentifier: activeRecordIdentifier,
            hasRequested: hasRequested,
            lastRequestDate: lastRequestDate,
            lastKnownActivityIdentifier: container.decodeIfPresent(
                String.self,
                forKey: .lastKnownActivityIdentifier
            ),
            lastRequestBuildIdentity: schemaVersion >= 3
                ? container.decodeIfPresent(
                    LiveActivityBuildIdentity.self,
                    forKey: .lastRequestBuildIdentity
                ) ?? container.decodeIfPresent(
                    LiveActivityBuildIdentity.self,
                    forKey: .lastSuccessfulRequestBuildIdentity
                )
                : nil,
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(activeRecordIdentifier, forKey: .activeRecordIdentifier)
        try container.encode(hasRequested, forKey: .hasRequested)
        try container.encodeIfPresent(lastRequestDate, forKey: .lastRequestDate)
        try container.encodeIfPresent(lastKnownActivityIdentifier, forKey: .lastKnownActivityIdentifier)
        try container.encodeIfPresent(lastRequestBuildIdentity, forKey: .lastRequestBuildIdentity)
        try container.encodeIfPresent(lastIntent, forKey: .lastIntent)
        try container.encodeIfPresent(lastTerminalReason, forKey: .lastTerminalReason)
        try container.encode(automaticSuppressed, forKey: .automaticSuppressed)
        try container.encodeIfPresent(lastAutomaticAttemptDate, forKey: .lastAutomaticAttemptDate)
        try container.encodeIfPresent(lastAutomaticAttemptSucceeded, forKey: .lastAutomaticAttemptSucceeded)
    }
}

@MainActor
protocol LiveActivityLifecycleStore: AnyObject {
    func metadata(for activeRecordIdentifier: UUID) throws -> LiveActivityLifecycleMetadata?
    func save(_ metadata: LiveActivityLifecycleMetadata) throws
    func clear(for activeRecordIdentifier: UUID) throws
    func clearAll() throws

    /// True when lifecycle bytes were present but failed schema, identity or
    /// invariant validation. A genuinely absent record returns false.
    func hasUnreadableMetadata() -> Bool
}

extension LiveActivityLifecycleStore {
    func hasUnreadableMetadata() -> Bool {
        false
    }
}

@MainActor
final class UserDefaultsLiveActivityLifecycleStore: LiveActivityLifecycleStore {
    private static let key = "uFast.liveActivity.lifecycle.v1"
    private let defaults: UserDefaults
    private var unreadableMetadata = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for activeRecordIdentifier: UUID) throws -> LiveActivityLifecycleMetadata? {
        guard let data = defaults.data(forKey: Self.key) else {
            return nil
        }
        do {
            let storedSchemaVersion = try JSONDecoder().decode(
                SchemaVersionEnvelope.self,
                from: data
            ).schemaVersion
            let metadata = try JSONDecoder().decode(LiveActivityLifecycleMetadata.self, from: data)
            guard metadata.activeRecordIdentifier == activeRecordIdentifier
            else {
                return nil
            }
            if storedSchemaVersion != LiveActivityLifecycleMetadata.currentSchemaVersion {
                // Preserve the decoded state even if this best-effort write is
                // unavailable (for example, a transient protected-data state).
                try? save(metadata)
            }
            unreadableMetadata = false
            return metadata
        } catch {
            unreadableMetadata = true
            return nil
        }
    }

    func save(_ metadata: LiveActivityLifecycleMetadata) throws {
        let data = try JSONEncoder().encode(metadata)
        defaults.set(data, forKey: Self.key)
        unreadableMetadata = false
    }

    func clear(for activeRecordIdentifier: UUID) throws {
        guard let metadata = try metadata(for: activeRecordIdentifier) else {
            return
        }
        guard metadata.activeRecordIdentifier == activeRecordIdentifier else {
            return
        }
        defaults.removeObject(forKey: Self.key)
        unreadableMetadata = false
    }

    func clearAll() throws {
        defaults.removeObject(forKey: Self.key)
        unreadableMetadata = false
    }

    func hasUnreadableMetadata() -> Bool {
        unreadableMetadata
    }

    private struct SchemaVersionEnvelope: Decodable {
        let schemaVersion: Int
    }
}

@MainActor
final class InMemoryLiveActivityLifecycleStore: LiveActivityLifecycleStore {
    private(set) var storedMetadata: LiveActivityLifecycleMetadata?

    var saveError: Error?
    var clearError: Error?
    var unreadableMetadata = false

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
        unreadableMetadata = false
    }

    func clear(for _: UUID) throws {
        if let clearError {
            throw clearError
        }
        storedMetadata = nil
        unreadableMetadata = false
    }

    func clearAll() throws {
        if let clearError {
            throw clearError
        }
        storedMetadata = nil
        unreadableMetadata = false
    }

    func hasUnreadableMetadata() -> Bool {
        unreadableMetadata
    }
}
