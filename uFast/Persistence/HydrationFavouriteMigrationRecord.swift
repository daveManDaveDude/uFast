import Foundation
import SwiftData

/// Persistent, non-user-visible marker for the one-time conversion of legacy
/// favourite amounts. Keeping the marker separate preserves the released V1–V4
/// model declarations while making an empty list a valid committed state.
@Model
final class HydrationFavouriteMigrationRecord {
    var id: UUID = UUID()
    var migrationVersion: Int = 1
    var completedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        migrationVersion: Int = 1,
        completedAt: Date
    ) {
        self.id = id
        self.migrationVersion = migrationVersion
        self.completedAt = completedAt
    }
}
