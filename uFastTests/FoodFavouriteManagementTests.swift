import SwiftData
@testable import uFast
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

@MainActor
final class FoodFavouriteManagementTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshStoreIsEmptyAndValidationIsTrimmedNormalizedAndFieldSpecific() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataFoodFavouriteStore(modelContext: container.mainContext)
        XCTAssertTrue(try store.snapshots().isEmpty)
        XCTAssertEqual(FoodFavouriteValidator.trimmedDescription("  Breakfast  "), "Breakfast")
        let existing = FoodFavouriteSnapshot(description: "Café", createdAt: now)
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(
                description: "ｃａｆｅ́", nutrition: FoodNutrition(), existing: [existing]
            ),
            .duplicateDescription
        )
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(
                description: "Meal",
                nutrition: FoodNutrition(proteinGrams: .infinity),
                existing: []
            ),
            .invalidNutrition(.proteinGrams)
        )
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(
                description: "\u{200D}\u{200C}", nutrition: FoodNutrition(), existing: []
            ),
            .blankDescription
        )
    }

    func testNutritionValueParserUsesLocaleDecimalSeparator() {
        XCTAssertEqual(
            FoodNutritionValueParser.value("1,5", locale: Locale(identifier: "fr_FR")),
            1.5
        )
        XCTAssertNil(
            FoodNutritionValueParser.value("not-a-number", locale: Locale(identifier: "fr_FR"))
        )
    }

    func testNutritionValueFormatterRoundTripsInCommaDecimalLocale() {
        let locale = Locale(identifier: "fr_FR")
        let formatted = FoodNutritionValueFormatter.string(420, locale: locale)

        XCTAssertEqual(formatted, "420")
        XCTAssertEqual(FoodNutritionValueParser.value(formatted, locale: locale), 420)

        let decimal = FoodNutritionValueFormatter.string(12.5, locale: locale)
        XCTAssertEqual(decimal, "12,5")
        XCTAssertEqual(FoodNutritionValueParser.value(decimal, locale: locale), 12.5)
    }

    func testCreateUpdateKeepsOrderIdentityRevisionAndZeroValues() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataFoodFavouriteStore(modelContext: container.mainContext)
        let first = try store.create(
            description: "  Breakfast ",
            nutrition: FoodNutrition(energyKilocalories: 0, saltGrams: 0),
            at: now
        )
        let second = try store.create(description: "Lunch", nutrition: FoodNutrition(), at: now)
        XCTAssertEqual(first.description, "Breakfast")
        XCTAssertEqual(first.revision, 0)
        XCTAssertEqual(first.nutrition.energyKilocalories, 0)
        XCTAssertEqual(try store.snapshots().map(\.id), [first.id, second.id])

        let updated = try store.update(
            id: first.id,
            expectedRevision: first.revision,
            description: "Breakfast and fruit",
            nutrition: FoodNutrition(energyKilocalories: 420),
            at: now
        )
        XCTAssertEqual(updated.id, first.id)
        XCTAssertEqual(updated.creationOrder, first.creationOrder)
        XCTAssertEqual(updated.revision, 1)
        XCTAssertThrowsError(
            try store.update(
                id: first.id,
                expectedRevision: first.revision,
                description: "Lost update",
                nutrition: FoodNutrition(),
                at: now
            )
        ) { XCTAssertEqual($0 as? FoodFavouriteStoreError, .stale) }
    }

    func testFailedWritesAndRemovalStaleChecksPreserveCommittedState() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let good = SwiftDataFoodFavouriteStore(modelContext: container.mainContext)
        let created = try good.create(description: "Dinner", nutrition: FoodNutrition(), at: now)
        let failing = SwiftDataFoodFavouriteStore(modelContext: container.mainContext, simulateSaveFailure: true)
        XCTAssertThrowsError(
            try failing.update(
                id: created.id, expectedRevision: created.revision, description: "Changed",
                nutrition: FoodNutrition(), at: now
            )
        )
        XCTAssertEqual(try good.resolve(id: created.id).description, "Dinner")
        XCTAssertThrowsError(try failing.delete(id: created.id, expectedRevision: created.revision))
        XCTAssertEqual(try good.snapshots().count, 1)
        XCTAssertThrowsError(try good.delete(id: created.id, expectedRevision: 1)) {
            XCTAssertEqual($0 as? FoodFavouriteStoreError, .stale)
        }
    }

    func testRevisionOverflowRejectsWithoutChangingCommittedRecord() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let record = FoodFavouriteRecord(
            description: "Dinner", nutrition: FoodNutrition(), createdAt: now, revision: .max
        )
        container.mainContext.insert(record)
        try container.mainContext.save()
        let store = SwiftDataFoodFavouriteStore(modelContext: container.mainContext)

        XCTAssertThrowsError(
            try store.update(
                id: record.id, expectedRevision: .max, description: "Changed",
                nutrition: FoodNutrition(), at: now
            )
        ) { XCTAssertEqual($0 as? FoodFavouriteStoreError, .revisionOverflow) }
        XCTAssertEqual(try store.resolve(id: record.id).description, "Dinner")
        XCTAssertEqual(try store.resolve(id: record.id).revision, .max)
    }

    func testProjectionIsResolvedByIDAndEventSnapshotIsIsolatedFromTemplateEdit() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let commands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(widgetEffect: { _ in }, activityEffect: { _ in nil })
        )
        let created = try commands.createFoodFavourite(
            description: "Oats", nutrition: FoodNutrition(energyKilocalories: 300)
        )
        let draft = try commands.foodDraft(for: created, occurredAt: now)
        try commands.saveFood(draft, replacing: nil, goal: .default, endingActiveFast: false)
        let updated = try commands.updateFoodFavourite(
            id: created.id, expectedRevision: created.revision, description: "Oats with berries",
            nutrition: FoodNutrition(energyKilocalories: 450)
        )
        XCTAssertEqual(updated.revision, 1)
        let event = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).first)
        XCTAssertEqual(event.foodDescription, "Oats")
        XCTAssertEqual(event.energyKilocalories, 300)
    }

    func testQuickAddUsesOneFoodEventAndActiveFastRequiresExplicitEnding() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let commands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: PostCommitProjectionCoordinator(widgetEffect: { _ in }, activityEffect: { _ in nil })
        )
        let favourite = try commands.createFoodFavourite(description: "Toast", nutrition: FoodNutrition())
        let operation = FoodFavouriteQuickAddOperation(id: UUID(), favouriteID: favourite.id, occurredAt: now)
        try commands.todayAddFoodFavourite(operation, endingActiveFast: false)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).first?.isCaloric == true)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).first?.occurredAt, now)
    }

    func testQuickAddOperationReplayIsIdempotentAndDistinctOperationsCreateDistinctEvents() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let commands = makeCommands(container)
        let favourite = try commands.createFoodFavourite(
            description: "Toast", nutrition: FoodNutrition(energyKilocalories: 120)
        )
        let operationID = UUID()
        let operation = FoodFavouriteQuickAddOperation(
            id: operationID, favouriteID: favourite.id, occurredAt: now
        )

        try commands.todayAddFoodFavourite(operation, endingActiveFast: false)
        try commands.todayAddFoodFavourite(operation, endingActiveFast: false)

        let distinctOperation = FoodFavouriteQuickAddOperation(
            id: UUID(), favouriteID: favourite.id, occurredAt: now
        )
        try commands.todayAddFoodFavourite(distinctOperation, endingActiveFast: false)

        let events = try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>())
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(Set(events.map(\.id)), Set([operationID, distinctOperation.id]))
        XCTAssertTrue(events.allSatisfy { $0.occurredAt == now && $0.isCaloric })
    }

    func testFailedQuickAddLeavesOperationRetryableAndActiveFastRollbackIsAtomic() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let goodCommands = makeCommands(container)
        let favourite = try goodCommands.createFoodFavourite(description: "Dinner", nutrition: FoodNutrition())
        let operation = FoodFavouriteQuickAddOperation(
            id: UUID(), favouriteID: favourite.id, occurredAt: now
        )
        let failingCommands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(container),
            configuration: .init(simulateFoodSaveFailure: true)
        )

        XCTAssertThrowsError(
            try failingCommands.todayAddFoodFavourite(operation, endingActiveFast: false)
        )
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
        XCTAssertFalse(container.mainContext.hasChanges)
        try goodCommands.todayAddFoodFavourite(operation, endingActiveFast: false)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)

        let activeFast = FastRecord(startDate: now.addingTimeInterval(-3600), goalAtStart: .default)
        container.mainContext.insert(activeFast)
        try container.mainContext.save()
        let activeOperation = FoodFavouriteQuickAddOperation(
            id: UUID(), favouriteID: favourite.id, occurredAt: now
        )
        let failingActiveCommands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(container),
            configuration: .init(simulateFoodSaveFailure: true)
        )

        XCTAssertThrowsError(
            try failingActiveCommands.todayAddFoodFavourite(activeOperation, endingActiveFast: true)
        )
        XCTAssertTrue(activeFast.isActive)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertFalse(container.mainContext.hasChanges)
        try goodCommands.todayAddFoodFavourite(activeOperation, endingActiveFast: true)
        XCTAssertEqual(activeFast.endDate, now)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<FoodEntryRecord>()), 2)
    }

    func testQuickAddRemovedIDAndExactActiveStartRejectWithoutGhostEvent() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let commands = makeCommands(container)
        let favourite = try commands.createFoodFavourite(description: "Snack", nutrition: FoodNutrition())
        try commands.deleteFoodFavourite(id: favourite.id, expectedRevision: favourite.revision)

        let removedOperation = FoodFavouriteQuickAddOperation(
            id: UUID(), favouriteID: favourite.id, occurredAt: now
        )
        XCTAssertThrowsError(
            try commands.todayAddFoodFavourite(removedOperation, endingActiveFast: false)
        ) { XCTAssertEqual($0 as? FoodFavouriteStoreError, .recordNotFound) }
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)

        let activeFavourite = try commands.createFoodFavourite(description: "Breakfast", nutrition: FoodNutrition())
        let activeFast = FastRecord(startDate: now, goalAtStart: .default)
        container.mainContext.insert(activeFast)
        try container.mainContext.save()
        let exactStart = FoodFavouriteQuickAddOperation(
            id: UUID(), favouriteID: activeFavourite.id, occurredAt: now
        )
        XCTAssertThrowsError(
            try commands.todayAddFoodFavourite(exactStart, endingActiveFast: true)
        ) { XCTAssertEqual($0 as? FoodEntrySaveError, .eventAtActiveFastStart) }
        XCTAssertTrue(activeFast.isActive)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
    }
}

extension FoodFavouriteManagementTests {
    func testValidatorCoversInvisibleLengthDuplicateNumericBoundsAndOptionalZero() throws {
        let existing = [FoodFavouriteSnapshot(description: "Café", createdAt: now)]
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(description: "\u{200B}", nutrition: .init(), existing: []),
            .blankDescription
        )
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(
                description: String(repeating: "a", count: 201), nutrition: .init(), existing: []
            ),
            .descriptionTooLong
        )
        XCTAssertEqual(
            FoodFavouriteValidator.validationError(
                description: "ｃａｆｅ́", nutrition: .init(), existing: existing
            ),
            .duplicateDescription
        )
        for nutrition in [
            FoodNutrition(energyKilocalories: -1),
            FoodNutrition(energyKilocalories: .infinity),
            FoodNutrition(energyKilocalories: -.infinity),
            FoodNutrition(energyKilocalories: 1_000_001),
        ] {
            XCTAssertEqual(
                FoodFavouriteValidator.validationError(description: "Meal", nutrition: nutrition, existing: []),
                .invalidNutrition(.energyKilocalories)
            )
        }
        let valid = try FoodFavouriteValidator.validated(
            description: " Meal ",
            nutrition: FoodNutrition(energyKilocalories: 0, saltGrams: 0),
            existing: []
        )
        XCTAssertEqual(valid.description, "Meal")
        XCTAssertEqual(valid.nutrition.energyKilocalories, 0)
        XCTAssertEqual(valid.nutrition.saltGrams, 0)
    }

    func testRevisionMismatchOnUpdateAndRemovePreservesNewerTemplateAndNoEvent() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataFoodFavouriteStore(modelContext: container.mainContext)
        let created = try store.create(description: "Original", nutrition: .init(), at: now)
        let newer = try store.update(
            id: created.id, expectedRevision: created.revision,
            description: "Newer", nutrition: .init(energyKilocalories: 1), at: now
        )

        XCTAssertThrowsError(
            try store.update(
                id: created.id, expectedRevision: created.revision,
                description: "Stale", nutrition: .init(), at: now
            )
        ) { XCTAssertEqual($0 as? FoodFavouriteStoreError, .stale) }
        XCTAssertThrowsError(
            try store.delete(id: created.id, expectedRevision: created.revision)
        ) { XCTAssertEqual($0 as? FoodFavouriteStoreError, .stale) }
        XCTAssertEqual(try store.resolve(id: created.id), newer)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<FoodEntryRecord>()).isEmpty)
    }

    func testProjectionUsesSelectedHistoricalInstantAndRetainsTemplateSnapshot() throws {
        let selectedInstant = now.addingTimeInterval(-2 * 24 * 60 * 60 + 15 * 60)
        let container = try PersistenceContainer.make(inMemory: true)
        let commands = makeCommands(container)
        let favourite = try commands.createFoodFavourite(
            description: "Old recipe",
            nutrition: FoodNutrition(energyKilocalories: 300)
        )
        let draft = try commands.foodDraft(for: favourite.id, occurredAt: selectedInstant)
        XCTAssertEqual(draft.occurredAt, selectedInstant)
        XCTAssertEqual(draft.description, "Old recipe")
        XCTAssertEqual(draft.nutrition.energyKilocalories, 300)

        let changed = FoodFavouriteSnapshot(
            id: favourite.id,
            description: "New recipe",
            nutrition: FoodNutrition(energyKilocalories: 500),
            createdAt: favourite.createdAt,
            updatedAt: now,
            creationOrder: favourite.creationOrder,
            revision: favourite.revision + 1
        )
        XCTAssertEqual(draft.description, "Old recipe")
        XCTAssertNotEqual(draft.description, changed.description)
        XCTAssertNotEqual(draft.nutrition, changed.nutrition)
    }

    private func makeCommands(_ container: ModelContainer) -> ApplicationCommands {
        ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: makeProjectionCoordinator(container)
        )
    }

    private func makeProjectionCoordinator(_ container: ModelContainer) -> PostCommitProjectionCoordinator {
        PostCommitProjectionCoordinator(
            widgetEffect: { _ in XCTAssertFalse(container.mainContext.hasChanges) },
            activityEffect: { _ in nil }
        )
    }
}
