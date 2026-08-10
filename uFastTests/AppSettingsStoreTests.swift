import SwiftData
@testable import uFast
import XCTest

@MainActor
final class AppSettingsStoreTests: XCTestCase {
    func testRepeatedOnboardingSubmissionKeepsOneOriginalAuthorityAndValues() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let store = SwiftDataSettingsStore(modelContext: container.mainContext)
        let firstGoal = try XCTUnwrap(FastingGoal(hours: 16))
        let repeatedGoal = try XCTUnwrap(FastingGoal(hours: 20))

        let first = try store.completeOnboarding(goal: firstGoal)
        let repeated = try store.completeOnboarding(goal: repeatedGoal)

        XCTAssertEqual(first.id, repeated.id)
        XCTAssertEqual(repeated.fastingGoal, firstGoal)
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<AppSettingsRecord>()),
            1
        )
    }

    func testEquivalentDuplicatesRetainDeterministicCanonicalRow() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        context.insert(AppSettingsRecord(id: higherID, hasCompletedOnboarding: true))
        context.insert(AppSettingsRecord(id: lowerID, hasCompletedOnboarding: true))
        try context.save()
        let store = SwiftDataSettingsStore(modelContext: context)

        try store.prepareForUse()

        let stored = try context.fetch(FetchDescriptor<AppSettingsRecord>())
        XCTAssertEqual(stored.map(\.id), [lowerID])
        XCTAssertEqual(stored[0].userVisibleSnapshot, AppSettingsRecord(
            id: lowerID,
            hasCompletedOnboarding: true
        ).userVisibleSnapshot)
    }

    func testConflictingDuplicatesArePreservedAndReturnTypedFailure() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(fastingGoal: .default, hasCompletedOnboarding: true))
        try context.insert(
            AppSettingsRecord(
                fastingGoal: XCTUnwrap(FastingGoal(hours: 18)),
                hasCompletedOnboarding: true
            )
        )
        try context.save()
        let store = SwiftDataSettingsStore(modelContext: context)

        XCTAssertThrowsError(try store.prepareForUse()) { error in
            XCTAssertEqual(error as? SettingsStoreError, .conflictingAuthorities(count: 2))
        }
        XCTAssertThrowsError(try store.authoritativeRecord()) { error in
            XCTAssertEqual(error as? SettingsStoreError, .conflictingAuthorities(count: 2))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppSettingsRecord>()), 2)
        XCTAssertFalse(context.hasChanges)
    }

    func testZeroAndOneSettingsRowsResolveExactly() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let store = SwiftDataSettingsStore(modelContext: context)
        XCTAssertNil(try store.authoritativeRecord())

        let settings = AppSettingsRecord(hasCompletedOnboarding: true)
        context.insert(settings)
        try context.save()

        XCTAssertEqual(try store.authoritativeRecord()?.id, settings.id)
    }
}
