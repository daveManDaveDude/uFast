@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length

final class HydrationFavouriteSettingsTests: XCTestCase {
    func testSettingsStoreIndependentFavouriteAmounts() {
        let settings = AppSettingsRecord()
        settings.setHydrationFavourites(water: 650, tea: 275, coffee: 180)
        XCTAssertEqual(HydrationFavouriteProvider.favourites(settings: settings).map(\.volumeMillilitres), [650, 275, 180])
    }
}
