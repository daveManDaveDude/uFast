// swiftlint:disable trailing_comma

import Foundation

/// The process-local diagnostic vocabulary.  These values deliberately carry
/// no record, presentation or error payload.
enum DiagnosticSubsystem: String, CaseIterable, Codable, Sendable {
    case persistence
    case command
    case history
    case widgetProjection
    case liveActivity
}

enum DiagnosticOutcome: String, CaseIterable, Codable, Sendable {
    case storeOpenFailed
    case migrationFailed
    case authorityConflict
    case commitFailed
    case rollbackApplied
    case postCommitProjectionFailed
    case initialLoadFailed
    case extensionLoadFailed
    case containerUnavailable
    case publishFailed
    case clearFailed
    case unavailable
    case requestFailed
    case updateFailed
    case endFailed
}

enum DiagnosticSeverity: String, CaseIterable, Codable, Sendable {
    case warning
    case error
}

/// Version values are declared source values, not caller-supplied strings.
/// New release/schema values require an explicit source change before they can
/// cross the diagnostic boundary.
enum DiagnosticAppVersion: String, CaseIterable, Codable, Sendable {
    case current = "1.0.0"
}

enum DiagnosticBuildNumber: String, CaseIterable, Codable, Sendable {
    case current = "10"
}

enum DiagnosticSchemaVersion: String, CaseIterable, Codable, Sendable {
    case current = "1"
}

// SwiftLint's analyzer does not attribute references from the separate test
// target back to this shared source file.
// swiftlint:disable:next unused_declaration
struct DiagnosticVersionSource: Equatable, Sendable {
    let appVersion: DiagnosticAppVersion
    let buildNumber: DiagnosticBuildNumber
    let schemaVersion: DiagnosticSchemaVersion

    // SwiftLint's analyzer does not attribute references from the separate
    // test target back to this shared source file.
    // swiftlint:disable:next unused_declaration
    static let current = Self(
        appVersion: .current,
        buildNumber: .current,
        schemaVersion: .current
    )
}

enum DiagnosticCountBucket: String, CaseIterable, Codable, Sendable {
    case zero
    case one
    case multiple

    init(count: Int) {
        switch count {
        case ...0: self = .zero
        case 1: self = .one
        default: self = .multiple
        }
    }
}

/// A closed, metadata-only diagnostic value.  The failable initializer is the
/// construction boundary: an outcome cannot be paired with undocumented
/// fields, and unknown values cannot be decoded into this type.
struct DiagnosticEvent: Codable, Equatable, Sendable {
    let subsystem: DiagnosticSubsystem
    let outcome: DiagnosticOutcome
    let severity: DiagnosticSeverity
    let appVersion: DiagnosticAppVersion?
    let buildNumber: DiagnosticBuildNumber?
    let schemaVersion: DiagnosticSchemaVersion?
    let countBucket: DiagnosticCountBucket?
    let isRetry: Bool?
    let isForeground: Bool?

    init?(
        subsystem: DiagnosticSubsystem,
        outcome: DiagnosticOutcome,
        severity: DiagnosticSeverity,
        appVersion: DiagnosticAppVersion? = nil,
        buildNumber: DiagnosticBuildNumber? = nil,
        schemaVersion: DiagnosticSchemaVersion? = nil,
        countBucket: DiagnosticCountBucket? = nil,
        isRetry: Bool? = nil,
        isForeground: Bool? = nil
    ) {
        guard Self.metadataIsPermitted(
            subsystem: subsystem,
            outcome: outcome,
            countBucket: countBucket,
            isRetry: isRetry,
            isForeground: isForeground
        )
        else {
            return nil
        }

        self.subsystem = subsystem
        self.outcome = outcome
        self.severity = severity
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.schemaVersion = schemaVersion
        self.countBucket = countBucket
        self.isRetry = isRetry
        self.isForeground = isForeground
    }

    /// A stable, field-only representation for the OSLog adapters.  It is
    /// intentionally not a serialized record and contains no free-form field.
    var logMessage: String {
        var fields = [
            "subsystem=\(subsystem.rawValue)",
            "outcome=\(outcome.rawValue)",
            "severity=\(severity.rawValue)",
        ]
        if let appVersion {
            fields.append("appVersion=\(appVersion.rawValue)")
        }
        if let buildNumber {
            fields.append("buildNumber=\(buildNumber.rawValue)")
        }
        if let schemaVersion {
            fields.append("schemaVersion=\(schemaVersion.rawValue)")
        }
        if let countBucket {
            fields.append("countBucket=\(countBucket.rawValue)")
        }
        if let isRetry {
            fields.append("isRetry=\(isRetry)")
        }
        if let isForeground {
            fields.append("isForeground=\(isForeground)")
        }
        return fields.joined(separator: " ")
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case subsystem
        case outcome
        case severity
        case appVersion
        case buildNumber
        case schemaVersion
        case countBucket
        case isRetry
        case isForeground
    }

    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    private static func metadataIsPermitted(
        subsystem: DiagnosticSubsystem,
        outcome: DiagnosticOutcome,
        countBucket: DiagnosticCountBucket?,
        isRetry: Bool?,
        isForeground: Bool?
    ) -> Bool {
        let hasCountBucket = countBucket != nil
        let hasRetry = isRetry != nil
        let hasForeground = isForeground != nil

        switch (subsystem, outcome) {
        case (.persistence, .storeOpenFailed),
             (.persistence, .migrationFailed),
             (.widgetProjection, .containerUnavailable),
             (.widgetProjection, .publishFailed),
             (.widgetProjection, .clearFailed):
            return !hasCountBucket && !hasRetry && !hasForeground
        case (.persistence, .authorityConflict),
             (.widgetProjection, .authorityConflict),
             (.liveActivity, .authorityConflict):
            return !hasRetry && !hasForeground
        case (.command, .commitFailed),
             (.command, .rollbackApplied),
             (.command, .postCommitProjectionFailed),
             (.history, .initialLoadFailed),
             (.history, .extensionLoadFailed):
            return !hasCountBucket && !hasForeground
        case (.liveActivity, .unavailable):
            return !hasCountBucket && !hasRetry
        case (.liveActivity, .requestFailed),
             (.liveActivity, .updateFailed),
             (.liveActivity, .endFailed):
            return !hasCountBucket
        default:
            return false
        }
    }

    init(from decoder: Decoder) throws {
        let allKeysContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let knownKeyNames = Set(CodingKeys.allCases.map(\.stringValue))
        let unknownKeys = allKeysContainer.allKeys
            .map(\.stringValue)
            .filter { !knownKeyNames.contains($0) }
            .sorted()
        guard unknownKeys.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Undocumented diagnostic fields: \(unknownKeys.joined(separator: ", "))"
                )
            )
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let subsystem = try container.decode(DiagnosticSubsystem.self, forKey: .subsystem)
        let outcome = try container.decode(DiagnosticOutcome.self, forKey: .outcome)
        let severity = try container.decode(DiagnosticSeverity.self, forKey: .severity)
        guard let event = try Self(
            subsystem: subsystem,
            outcome: outcome,
            severity: severity,
            appVersion: container.decodeIfPresent(DiagnosticAppVersion.self, forKey: .appVersion),
            buildNumber: container.decodeIfPresent(DiagnosticBuildNumber.self, forKey: .buildNumber),
            schemaVersion: container.decodeIfPresent(DiagnosticSchemaVersion.self, forKey: .schemaVersion),
            countBucket: container.decodeIfPresent(DiagnosticCountBucket.self, forKey: .countBucket),
            isRetry: container.decodeIfPresent(Bool.self, forKey: .isRetry),
            isForeground: container.decodeIfPresent(Bool.self, forKey: .isForeground)
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .outcome,
                in: container,
                debugDescription: "Diagnostic outcome has undocumented metadata or version values"
            )
        }
        self = event
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subsystem, forKey: .subsystem)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(buildNumber, forKey: .buildNumber)
        try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(countBucket, forKey: .countBucket)
        try container.encodeIfPresent(isRetry, forKey: .isRetry)
        try container.encodeIfPresent(isForeground, forKey: .isForeground)
    }
}

/// Synchronous and non-authoritative by contract.  Implementations must not
/// throw, persist, perform network work or return an operation decision.
protocol DiagnosticEventSink: Sendable {
    func record(_ event: DiagnosticEvent)
}

struct NoOpDiagnosticEventSink: DiagnosticEventSink, Sendable {
    func record(_: DiagnosticEvent) {}
}

// SwiftLint's analyzer does not attribute references from the separate test
// target back to this shared source file.
// swiftlint:disable unused_declaration
/// Test-only in-memory evidence.  It intentionally has no persistence or
/// transport and is safe for synchronous test calls and concurrent inspection.
final class RecordingDiagnosticEventSink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [DiagnosticEvent] = []

    init() {}

    var count: Int {
        lock.withLock { storage.count }
    }

    var events: [DiagnosticEvent] {
        lock.withLock { storage }
    }

    func record(_ event: DiagnosticEvent) {
        lock.withLock {
            storage.append(event)
        }
    }
}

// swiftlint:enable unused_declaration

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
