import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HydrationFavouriteManagementTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testValidationTrimsCountsGraphemesAndRejectsReservedAndNormalizedDuplicates() {
        let first = HydrationFavouriteSnapshot(
            id: UUID(),
            name: "Café",
            volumeMillilitres: 250,
            isCaloric: false,
            createdAt: now,
            updatedAt: now
        )
        XCTAssertNil(HydrationFavouriteValidator.validationError(
            name: "  Sparkling water  ", amount: "330", existing: []
        ))
        XCTAssertEqual(
            HydrationFavouriteValidator.trimmedName("  Sparkling water  "),
            "Sparkling water"
        )
        XCTAssertEqual("👩‍💻".count, 1)
        XCTAssertEqual(
            HydrationFavouriteValidator.validationError(
                name: String(repeating: "👩‍💻", count: 81), amount: "330", existing: []
            ),
            .nameTooLong
        )
        XCTAssertEqual(
            HydrationFavouriteValidator.validationError(
                name: "ｃａｆｅ́", amount: "250", existing: [first]
            ),
            .duplicateName
        )
        let sparkling = HydrationFavouriteSnapshot(
            id: UUID(),
            name: "Sparkling water",
            volumeMillilitres: 330,
            isCaloric: false,
            createdAt: now,
            updatedAt: now
        )
        XCTAssertEqual(
            HydrationFavouriteValidator.validationError(
                name: "Ｓｐａｒｋｌｉｎｇ　ｗａｔｅｒ",
                amount: "330",
                existing: [sparkling]
            ),
            .duplicateName
        )
        XCTAssertEqual(
            HydrationFavouriteValidator.validationError(
                name: " WATER ", amount: "250", existing: []
            ),
            .reservedName
        )
    }

    func testProjectionPreservesCustomNameVolumeClassificationAndInstant() {
        let id = UUID()
        let favourite = HydrationFavourite(
            id: id,
            name: "Juice",
            volumeMillilitres: 250,
            isCaloric: true,
            createdAt: now,
            updatedAt: now
        )
        let draft = HydrationFavouriteProjection.hydrationDraft(
            from: favourite,
            occurredAt: now.addingTimeInterval(42)
        )
        XCTAssertEqual(draft.type, .custom)
        XCTAssertEqual(draft.customName, "Juice")
        XCTAssertEqual(draft.volumeMillilitres, 250)
        XCTAssertTrue(draft.isCaloric)
        XCTAssertEqual(draft.occurredAt, now.addingTimeInterval(42))
    }

    func testStoreCreateEditDeleteKeepsOrderingAndIdentifier() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataHydrationFavouriteStore(modelContext: container.mainContext)
        let first = try store.create(
            name: "Sparkling water", volumeMillilitres: 330, isCaloric: false, at: now
        )
        let second = try store.create(
            name: "Juice", volumeMillilitres: 250, isCaloric: true, at: now.addingTimeInterval(1)
        )

        let updated = try store.update(
            id: first.id, name: "Soda water", volumeMillilitres: 355, isCaloric: false,
            at: now.addingTimeInterval(2)
        )
        XCTAssertEqual(updated.id, first.id)
        XCTAssertEqual(try store.snapshots().map(\.name), ["Soda water", "Juice"])
        XCTAssertEqual(try store.resolve(id: second.id).isCaloric, true)

        try store.delete(id: first.id)
        XCTAssertEqual(try store.snapshots().map(\.id), [second.id])
    }

    func testStoreKeepsCreationOrderWhenClockInstantsMatch() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataHydrationFavouriteStore(modelContext: container.mainContext)
        _ = try store.create(
            name: "First", volumeMillilitres: 250, isCaloric: false, at: now
        )
        _ = try store.create(
            name: "Second", volumeMillilitres: 300, isCaloric: false, at: now
        )

        XCTAssertEqual(try store.snapshots().map(\.name), ["First", "Second"])
    }

    func testDuplicateCommitAndConcurrentRenameConflictDoNotCreateOrRewriteRecords() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataHydrationFavouriteStore(modelContext: container.mainContext)
        let first = try store.create(
            name: "Sparkling water", volumeMillilitres: 330, isCaloric: false, at: now
        )
        let second = try store.create(
            name: "Juice", volumeMillilitres: 250, isCaloric: true, at: now.addingTimeInterval(1)
        )

        XCTAssertThrowsError(
            try store.create(
                name: " sparkling WATER ", volumeMillilitres: 330, isCaloric: false, at: now
            )
        ) { error in
            XCTAssertEqual(error as? HydrationFavouriteStoreError, .duplicateName)
        }
        XCTAssertThrowsError(
            try store.update(
                id: first.id, name: "JUICE", volumeMillilitres: 355, isCaloric: false,
                at: now.addingTimeInterval(2)
            )
        ) { error in
            XCTAssertEqual(error as? HydrationFavouriteStoreError, .duplicateName)
        }
        XCTAssertEqual(try store.snapshots().map(\.name), ["Sparkling water", "Juice"])
        XCTAssertEqual(try store.resolve(id: second.id).volumeMillilitres, 250)
    }

    func testStoreCreateUpdateAndDeleteFailuresRollbackCommittedList() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let normalStore = SwiftDataHydrationFavouriteStore(modelContext: context)
        let existing = try normalStore.create(
            name: "Sparkling water", volumeMillilitres: 330, isCaloric: false, at: now
        )

        let failingStore = SwiftDataHydrationFavouriteStore(
            modelContext: context, simulateSaveFailure: true
        )
        XCTAssertThrowsError(
            try failingStore.create(
                name: "Juice", volumeMillilitres: 250, isCaloric: true, at: now
            )
        )
        XCTAssertEqual(try normalStore.snapshots().map(\.name), ["Sparkling water"])
        XCTAssertThrowsError(
            try failingStore.update(
                id: existing.id, name: "Soda water", volumeMillilitres: 355,
                isCaloric: false, at: now.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(try normalStore.resolve(id: existing.id).name, "Sparkling water")
        XCTAssertThrowsError(try failingStore.delete(id: existing.id))
        XCTAssertEqual(try normalStore.snapshots().count, 1)
    }

    func testEmptyStoreAndStaleIdentifierFailClosed() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataHydrationFavouriteStore(modelContext: container.mainContext)
        XCTAssertTrue(try store.snapshots().isEmpty)
        XCTAssertThrowsError(try store.resolve(id: UUID())) { error in
            XCTAssertEqual(error as? HydrationFavouriteStoreError, .recordNotFound)
        }
        XCTAssertThrowsError(try store.delete(id: UUID())) { error in
            XCTAssertEqual(error as? HydrationFavouriteStoreError, .recordNotFound)
        }
    }

    func testCommandResolvesAuthoritativeValuesAndRejectsRemovedOrCorruptSnapshots() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
        let commands = ApplicationCommands(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let created = try commands.createFavourite(
            name: "Juice", volumeMillilitres: 250, isCaloric: true
        )
        let stale = HydrationFavourite(
            id: created.id,
            name: "Old name",
            volumeMillilitres: 1,
            isCaloric: false,
            createdAt: created.createdAt,
            updatedAt: created.updatedAt
        )

        let draft = try commands.hydrationDraft(for: stale, occurredAt: now)
        XCTAssertEqual(draft.customName, "Juice")
        XCTAssertEqual(draft.volumeMillilitres, 250)
        XCTAssertTrue(draft.isCaloric)

        try commands.deleteFavourite(id: created.id)
        XCTAssertThrowsError(try commands.hydrationDraft(for: stale, occurredAt: now))

        let corrupt = HydrationFavouriteRecord(
            name: "Corrupt", volumeMillilitres: 0, isCaloric: false, createdAt: now
        )
        container.mainContext.insert(corrupt)
        try container.mainContext.save()
        let corruptSnapshot = corrupt.snapshot.hydrationFavourite
        XCTAssertThrowsError(try commands.hydrationDraft(for: corruptSnapshot, occurredAt: now))
    }

    func testConflictingSettingsAuthorityRejectsFavouriteMutationWithoutChangingCommittedData() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in },
            activityEffect: { _ in nil }
        )
        let commands = ApplicationCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection
        )
        let favourite = try commands.createFavourite(
            name: "Sparkling water", volumeMillilitres: 330, isCaloric: false
        )
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        context.insert(
            HydrationEntryRecord(
                type: .custom,
                customName: "Earlier drink",
                volumeMillilitres: 250,
                occurredAt: now,
                isCaloric: false,
                createdAt: now
            )
        )
        try context.save()

        assertConflictingFavouriteMutation {
            _ = try commands.createFavourite(
                name: "Juice", volumeMillilitres: 250, isCaloric: true
            )
        }
        assertConflictingFavouriteMutation {
            _ = try commands.updateFavourite(
                id: favourite.id, name: "Soda water", volumeMillilitres: 355, isCaloric: false
            )
        }
        assertConflictingFavouriteMutation { try commands.deleteFavourite(id: favourite.id) }
        assertConflictingFavouriteMutation {
            _ = try commands.hydrationDraft(for: favourite.hydrationFavourite, occurredAt: now)
        }

        let store = SwiftDataHydrationFavouriteStore(modelContext: context)
        XCTAssertEqual(try store.snapshots().map(\.name), ["Sparkling water"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
    }

    private func assertConflictingFavouriteMutation(_ operation: () throws -> Void) {
        XCTAssertThrowsError(try operation()) { error in
            XCTAssertEqual(error as? HydrationFavouriteStoreError, .conflictingAuthorities)
        }
    }
}
