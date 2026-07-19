@testable import uFast
import XCTest

final class AppDestinationTests: XCTestCase {
    func testFoundationExposesFourPrimaryDestinationsInProductOrder() {
        XCTAssertEqual(
            AppDestination.allCases,
            [.today, .history, .progress, .settings]
        )
    }

    func testDestinationsHaveUniqueAccessibilityIdentifiers() {
        let identifiers = AppDestination.allCases.map(\.accessibilityIdentifier)

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }
}
