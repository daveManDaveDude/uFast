import Foundation
import SwiftData

enum HealthAuthorizationFixtureState: CaseIterable {
    case unavailable
    case notDetermined
    case denied
    case authorized
    case revoked
}

enum PreviewFixtures {
    static let utc = TimeZone(secondsFromGMT: 0) ?? .current
    static let london = TimeZone(identifier: "Europe/London") ?? utc
    static let newYork = TimeZone(identifier: "America/New_York") ?? utc

    static let beforeLondonSpringClockChange = Date(
        timeIntervalSince1970: 1_774_742_200
    )
    static let afterLondonSpringClockChange = Date(
        timeIntervalSince1970: 1_774_749_400
    )

    @MainActor
    static var modelContainer: ModelContainer {
        do {
            let container = try PersistenceContainer.make(inMemory: true)
            container.mainContext.insert(AppSettingsRecord(hasCompletedOnboarding: true))
            return container
        } catch {
            fatalError("Unable to create preview persistence: \(error)")
        }
    }
}
