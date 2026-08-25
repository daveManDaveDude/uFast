@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command trailing_comma
// swiftlint:disable line_length

final class HydrationFavouriteSettingsTests: XCTestCase {
    func testRecordSnapshotsAreTheOnlyFavouriteProviderSource() {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshots = [
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Water",
                volumeMillilitres: 330,
                isCaloric: false,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            HydrationFavouriteSnapshot(
                id: UUID(),
                name: "Juice",
                volumeMillilitres: 250,
                isCaloric: true,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
        ]

        XCTAssertEqual(
            HydrationFavouriteProvider.favourites(records: snapshots).map(\.volumeMillilitres),
            [330, 250]
        )
    }
}
