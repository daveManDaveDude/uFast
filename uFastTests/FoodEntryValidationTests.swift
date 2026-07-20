@testable import uFast
import XCTest

final class FoodEntryValidationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTrimsDescriptionDefaultsCaloricAndPreservesAbsentNutrition() throws {
        let draft = try validated(description: "  Soup and bread \n").get()

        XCTAssertEqual(draft.description, "Soup and bread")
        XCTAssertTrue(draft.isCaloric)
        XCTAssertEqual(draft.occurredAt, now)
        XCTAssertTrue(draft.nutrition.values.isEmpty)
    }

    func testWhitespaceAndOverTwoHundredUserPerceivedCharactersAreRejected() {
        XCTAssertEqual(
            failure(description: " \n "),
            .emptyDescription
        )
        XCTAssertEqual(
            failure(description: String(repeating: "🍲", count: 201)),
            .descriptionTooLong
        )
        XCTAssertNoThrow(try validated(description: String(repeating: "🍲", count: 200)).get())
    }

    func testPartialNutritionRemainsPartial() throws {
        let nutrition = FoodNutrition(
            energyKilocalories: 320,
            proteinGrams: 12.5,
            saltGrams: 0
        )
        let draft = try validated(nutrition: nutrition).get()

        XCTAssertEqual(draft.nutrition.energyKilocalories, 320)
        XCTAssertEqual(draft.nutrition.proteinGrams, 12.5)
        XCTAssertEqual(draft.nutrition.saltGrams, 0)
        XCTAssertNil(draft.nutrition.carbohydrateGrams)
        XCTAssertNil(draft.nutrition.fatGrams)
        XCTAssertNil(draft.nutrition.fibreGrams)
        XCTAssertNil(draft.nutrition.sugarGrams)
    }

    func testNegativeNonFiniteAndDefensivelyOutOfRangeNutritionAreRejected() {
        for value in [-1, .infinity, .nan, FoodEntryValidator.maximumNutritionValue + 1] {
            XCTAssertEqual(
                failure(nutrition: FoodNutrition(energyKilocalories: value)),
                .invalidNutrition
            )
        }
        XCTAssertNoThrow(
            try validated(
                nutrition: FoodNutrition(
                    energyKilocalories: FoodEntryValidator.maximumNutritionValue
                )
            ).get()
        )
    }

    func testOnlyCurrentLocalDayAndNonFutureInstantsAreAccepted() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let startOfToday = calendar.startOfDay(for: now)

        XCTAssertNoThrow(try validated(occurredAt: startOfToday, calendar: calendar).get())
        XCTAssertEqual(
            failure(occurredAt: startOfToday.addingTimeInterval(-1), calendar: calendar),
            .beforeToday
        )
        XCTAssertEqual(
            failure(occurredAt: now.addingTimeInterval(1), calendar: calendar),
            .futureTime
        )
    }

    private func validated(
        description: String = "Lunch",
        occurredAt: Date? = nil,
        nutrition: FoodNutrition = FoodNutrition(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Result<FoodEntryDraft, FoodEntryValidationError> {
        FoodEntryValidator.validated(
            description: description,
            occurredAt: occurredAt ?? now,
            nutrition: nutrition,
            now: now,
            calendar: calendar
        )
    }

    private func failure(
        description: String = "Lunch",
        occurredAt: Date? = nil,
        nutrition: FoodNutrition = FoodNutrition(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> FoodEntryValidationError? {
        switch validated(
            description: description,
            occurredAt: occurredAt,
            nutrition: nutrition,
            calendar: calendar
        ) {
        case .success:
            nil
        case let .failure(error):
            error
        }
    }
}
