@testable import uFast
import XCTest

final class AppDestinationTests: XCTestCase {
    func testFoundationExposesThreePrimaryDestinationsInProductOrder() {
        XCTAssertEqual(
            AppDestination.allCases,
            [.today, .history, .settings]
        )
    }

    func testDestinationsHaveUniqueAccessibilityIdentifiers() {
        let identifiers = AppDestination.allCases.map(\.accessibilityIdentifier)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }
}
