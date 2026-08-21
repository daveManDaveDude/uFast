import SwiftData
@testable import uFast
import XCTest

@MainActor
final class CaloricEventCommandsTests: XCTestCase {
    func testOwnerKeepsFoodAndHydrationMutationsOnTheSharedCommitPath() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.save()
        let invalidation = HistoryPresentationInvalidation()
        let projection = PostCommitProjectionCoordinator(
            widgetEffect: { _ in XCTAssertFalse(context.hasChanges) },
            activityEffect: { _ in nil },
            historyPresentationInvalidation: invalidation
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let owner = CaloricEventCommands(
            modelContext: context,
            clock: FixedAppClock(now: now),
            projectionCoordinator: projection,
            configuration: .init(),
            observationSink: NoOpBoundaryQueryObservationSink(),
            recordIDProvider: { UUID() }
        )

        try owner.saveFood(
            .init(description: "Lunch", occurredAt: now),
            replacing: nil,
            goal: .default,
            endingActiveFast: false
        )
        try owner.saveHydration(
            .init(
                type: .water,
                customName: nil,
                volumeMillilitres: 500,
                occurredAt: now.addingTimeInterval(60),
                isCaloric: false
            ),
            replacing: nil,
            goal: .default,
            endingActiveFast: false
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 1)
        XCTAssertEqual(invalidation.revision, 2)
        XCTAssertFalse(context.hasChanges)
    }

    func testPresentationCategorySharesCopyWithoutWeakeningExactDomainEquality() {
        let active = CaloricEventConfirmationContext(
            persistedImpact: CaloricEventImpact(
                activeFastIDs: [UUID()],
                completedFastIDs: [],
                reconstructedFastIDs: [],
                reconstructedReviewIDs: []
            )
        )
        let completed = CaloricEventConfirmationContext(
            persistedImpact: CaloricEventImpact(
                activeFastIDs: [],
                completedFastIDs: [UUID()],
                reconstructedFastIDs: [],
                reconstructedReviewIDs: [UUID()]
            ),
            includesInferredInterval: true
        )
        let foodError = FoodEntrySaveError.confirmationRequiredWithImpact(active)
        let differentFoodError = FoodEntrySaveError.confirmationRequiredWithImpact(completed)
        let hydrationError = HydrationEntrySaveError.confirmationRequiredWithImpact(active)

        XCTAssertNotEqual(foodError, differentFoodError)
        XCTAssertEqual(
            foodError.presentation,
            CaloricEventErrorPresentation.confirmation(active)
        )
        XCTAssertEqual(
            hydrationError.presentation,
            CaloricEventErrorPresentation.confirmation(active)
        )
        XCTAssertNotEqual(foodError.presentation, differentFoodError.presentation)
    }
}
