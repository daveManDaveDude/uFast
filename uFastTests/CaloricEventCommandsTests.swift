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

    func testConfirmationErrorsDistinguishEachAssociatedContextField() {
        let activeFastID = UUID()
        let active = makeConfirmationContext(activeFastIDs: [activeFastID])
        let differentKind = makeConfirmationContext(completedFastIDs: [UUID()])
        let differentAffectedPersistedFastCount = makeConfirmationContext(
            activeFastIDs: [activeFastID, UUID()]
        )
        let differentReconstructedReview = makeConfirmationContext(
            activeFastIDs: [activeFastID],
            reconstructedReviewIDs: [activeFastID]
        )
        let differentInferredInterval = makeConfirmationContext(
            activeFastIDs: [activeFastID],
            includesInferredInterval: true
        )

        let foodError: (CaloricEventConfirmationContext) -> FoodEntrySaveError = {
            .confirmationRequiredWithImpact($0)
        }
        let hydrationError: (CaloricEventConfirmationContext) -> HydrationEntrySaveError = {
            .confirmationRequiredWithImpact($0)
        }

        XCTAssertNotEqual(foodError(active), foodError(differentKind))
        XCTAssertNotEqual(hydrationError(active), hydrationError(differentKind))
        XCTAssertNotEqual(
            foodError(active),
            foodError(differentAffectedPersistedFastCount)
        )
        XCTAssertNotEqual(
            hydrationError(active),
            hydrationError(differentAffectedPersistedFastCount)
        )
        XCTAssertNotEqual(foodError(active), foodError(differentReconstructedReview))
        XCTAssertNotEqual(hydrationError(active), hydrationError(differentReconstructedReview))
        XCTAssertNotEqual(foodError(active), foodError(differentInferredInterval))
        XCTAssertNotEqual(hydrationError(active), hydrationError(differentInferredInterval))
    }

    func testPresentationCategoryGroupsSameContextWithoutWeakeningExactEquality() {
        let active = makeConfirmationContext(activeFastIDs: [UUID()])
        let differentFoodError = FoodEntrySaveError.confirmationRequiredWithImpact(
            makeConfirmationContext(activeFastIDs: [UUID(), UUID()])
        )
        let foodError = FoodEntrySaveError.confirmationRequiredWithImpact(active)
        let hydrationError = HydrationEntrySaveError.confirmationRequiredWithImpact(active)

        XCTAssertEqual(
            foodError.presentation,
            CaloricEventErrorPresentation.confirmation(active)
        )
        XCTAssertEqual(
            hydrationError.presentation,
            CaloricEventErrorPresentation.confirmation(active)
        )
        XCTAssertEqual(foodError.presentation, hydrationError.presentation)
        XCTAssertNotEqual(foodError.presentation, differentFoodError.presentation)
    }
}

private func makeConfirmationContext(
    activeFastIDs: [UUID] = [],
    completedFastIDs: [UUID] = [],
    reconstructedFastIDs: [UUID] = [],
    reconstructedReviewIDs: [UUID] = [],
    includesInferredInterval: Bool = false
) -> CaloricEventConfirmationContext {
    CaloricEventConfirmationContext(
        persistedImpact: CaloricEventImpact(
            activeFastIDs: activeFastIDs,
            completedFastIDs: completedFastIDs,
            reconstructedFastIDs: reconstructedFastIDs,
            reconstructedReviewIDs: reconstructedReviewIDs
        ),
        includesInferredInterval: includesInferredInterval
    )
}
