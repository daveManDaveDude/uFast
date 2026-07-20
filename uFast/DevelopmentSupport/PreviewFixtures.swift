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

    @MainActor
    static var emptyModelContainer: ModelContainer {
        do {
            return try PersistenceContainer.make(inMemory: true)
        } catch {
            fatalError("Unable to create empty preview persistence: \(error)")
        }
    }

    @MainActor
    static var completedFastModelContainer: ModelContainer {
        do {
            let container = try PersistenceContainer.make(inMemory: true)
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            container.mainContext.insert(
                AppSettingsRecord(hasCompletedOnboarding: true)
            )
            container.mainContext.insert(
                FastRecord(
                    startDate: now.addingTimeInterval(-13 * 60 * 60),
                    endDate: now,
                    goalAtStart: .default
                )
            )
            return container
        } catch {
            fatalError("Unable to create completed-fast preview persistence: \(error)")
        }
    }
}
