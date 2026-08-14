import Foundation

/// The installed app identity used to distinguish a deployed update from a
/// same-build relaunch. It is presentation lifecycle metadata only; it never
/// participates in fasting authority or persistence.
struct LiveActivityBuildIdentity: Codable, Equatable, Sendable {
    let releaseVersion: String
    let buildNumber: String

    init(releaseVersion: String, buildNumber: String) {
        self.releaseVersion = releaseVersion
        self.buildNumber = buildNumber
    }

    /// Production identity comes from the main app bundle's version fields.
    /// An unreadable or malformed bundle fails closed by returning `nil`.
    static func production(bundle: Bundle = .main) -> Self? {
        guard let releaseVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
            let buildNumber = bundle.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String
        else {
            return nil
        }

        let identity = Self(releaseVersion: releaseVersion, buildNumber: buildNumber)
        return identity.isValid ? identity : nil
    }

    /// Deterministic identity for unit and UI-test fixtures.
    static func deterministic(
        releaseVersion: String = "1.0.0",
        buildNumber: String = "test"
    ) -> Self {
        Self(releaseVersion: releaseVersion, buildNumber: buildNumber)
    }

    var isValid: Bool {
        Self.isValidComponent(releaseVersion) && Self.isValidComponent(buildNumber)
    }

    private static func isValidComponent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value == trimmed, !trimmed.isEmpty, trimmed.count <= 256 else { return false }
        return trimmed.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case releaseVersion
        case buildNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let identity = try Self(
            releaseVersion: container.decode(String.self, forKey: .releaseVersion),
            buildNumber: container.decode(String.self, forKey: .buildNumber)
        )
        guard identity.isValid else {
            throw DecodingError.dataCorruptedError(
                forKey: .releaseVersion,
                in: container,
                debugDescription: "Invalid Live Activity build identity."
            )
        }
        self = identity
    }
}
