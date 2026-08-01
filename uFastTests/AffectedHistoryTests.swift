import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable force_unwrapping identifier_name large_tuple line_length type_body_length

@MainActor
final class AffectedHistoryTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 2_300_000_000)

    func testDetectorCombinesDirectAndStrictlyInsideEffectsWithoutDuplicates() {
        let shared = reference(.hydration, 1)
        let created = reference(.food, 9)
        let first = history(1, 0, 12, shared, reference(.food, 2))
        let second = history(2, 12, 24, reference(.food, 3), shared)
        let boundaryOnly = AffectedHistoryDetector.affectedIDs(
            mutation: .init(
                reference: shared,
                resultingOccurredAt: base.addingTimeInterval(18 * 3600),
                resultingIsCaloric: true
            ),
            reconstructed: [first, second]
        )
        XCTAssertEqual(boundaryOnly, [first.id, second.id])

        let interior = AffectedHistoryDetector.affectedIDs(
            mutation: .init(
                reference: created,
                resultingOccurredAt: base.addingTimeInterval(6 * 3600),
                resultingIsCaloric: true
            ),
            reconstructed: [first, second]
        )
        XCTAssertEqual(interior, [first.id])
    }

    func testDetectorIgnoresNonCaloricAndTouchingEventsUnlessReferenced() {
        let fast = history(1, 0, 12, reference(.food, 1), reference(.food, 2))
        for hour in [0, 6, 12, 20] {
            let affected = AffectedHistoryDetector.affectedIDs(
                mutation: .init(
                    reference: reference(.hydration, hour + 20),
                    resultingOccurredAt: base.addingTimeInterval(TimeInterval(hour * 3600)),
                    resultingIsCaloric: hour == 6 ? false : true
                ),
                reconstructed: [fast]
            )
            XCTAssertTrue(affected.isEmpty)
        }
    }

    func testEventMutationsRetainLegacyReconstructionState() throws {
        let fixture = try fixture()
        let foodRepository = SwiftDataFoodEntryRepository(modelContext: fixture.context)
        _ = try foodRepository.create(
            FoodEntryDraft(description: "Lunch", occurredAt: date(6)),
            at: date(30)
        )
        XCTAssertEqual(fixture.first.reviewState, .confirmed)
        XCTAssertEqual(fixture.second.reviewState, .confirmed)

        let hydrationRepository = SwiftDataHydrationEntryRepository(modelContext: fixture.context)
        let nonCaloric = HydrationEntryDraft(
            type: .tea,
            customName: nil,
            volumeMillilitres: 300,
            occurredAt: fixture.shared.occurredAt.addingTimeInterval(60),
            isCaloric: false
        )
        try hydrationRepository.update(fixture.shared, with: nonCaloric, at: date(31))
        XCTAssertEqual(fixture.first.reviewState, .confirmed)
        XCTAssertEqual(fixture.second.reviewState, .confirmed)
    }

    func testEventEditAndDeleteRetainLegacyReconstructionState() throws {
        let foodFixture = try fixture()
        let start = try XCTUnwrap(
            foodFixture.context.fetch(FetchDescriptor<FoodEntryRecord>())
                .first { $0.occurredAt == date(0) }
        )
        try SwiftDataFoodEntryRepository(modelContext: foodFixture.context).update(
            start,
            with: .init(description: "Corrected dinner", occurredAt: date(1)),
            at: date(31)
        )
        XCTAssertEqual(foodFixture.first.reviewState, .confirmed)
        XCTAssertEqual(foodFixture.second.reviewState, .confirmed)

        let hydrationFixture = try fixture()
        try SwiftDataHydrationEntryRepository(modelContext: hydrationFixture.context)
            .delete(hydrationFixture.shared)
        XCTAssertEqual(hydrationFixture.first.reviewState, .confirmed)
        XCTAssertEqual(hydrationFixture.second.reviewState, .confirmed)
        XCTAssertTrue(try hydrationFixture.context.fetch(FetchDescriptor<HydrationEntryRecord>()).isEmpty)
    }

    func testUnrelatedNonCaloricMutationLeavesReconstructionByteForByteUnchanged() throws {
        let fixture = try fixture()
        let before = fixture.first.provenanceSnapshot
        let repository = SwiftDataHydrationEntryRepository(modelContext: fixture.context)
        let water = try repository.create(
            HydrationEntryDraft(
                type: .water,
                customName: nil,
                volumeMillilitres: 500,
                occurredAt: date(30),
                isCaloric: false
            ),
            at: date(31)
        )
        try repository.update(
            water,
            with: .init(
                type: .water,
                customName: nil,
                volumeMillilitres: 600,
                occurredAt: date(29),
                isCaloric: false
            ),
            at: date(32)
        )
        try repository.delete(water)
        XCTAssertEqual(fixture.first.provenanceSnapshot, before)
    }

    func testFailedEventSaveRollsBackEventAndInvalidation() throws {
        let fixture = try fixture()
        let repository = SwiftDataHydrationEntryRepository(
            modelContext: fixture.context,
            simulateSaveFailure: true
        )
        let original = fixture.shared.draft
        XCTAssertThrowsError(
            try repository.update(
                fixture.shared,
                with: .init(
                    type: .tea,
                    customName: nil,
                    volumeMillilitres: 300,
                    occurredAt: date(14),
                    isCaloric: false
                ),
                at: date(31)
            )
        )
        XCTAssertEqual(fixture.shared.draft, original)
        XCTAssertEqual(fixture.first.reviewState, .confirmed)
        XCTAssertEqual(fixture.second.reviewState, .confirmed)
    }

    func testD013CombinedFailureRestoresActiveFastEventAndReviewState() throws {
        let fixture = try fixture()
        let active = FastRecord(startDate: date(25), goalAtStart: .default)
        fixture.context.insert(active)
        try fixture.context.save()
        let repository = SwiftDataHydrationEntryRepository(
            modelContext: fixture.context,
            simulateSaveFailure: true
        )
        let moved = HydrationEntryDraft(
            type: .coffee,
            customName: nil,
            volumeMillilitres: 250,
            occurredAt: date(27),
            isCaloric: true
        )
        let original = fixture.shared.draft
        XCTAssertThrowsError(
            try repository.update(
                fixture.shared,
                with: moved,
                at: date(31),
                ending: active,
                goal: .default
            )
        )
        XCTAssertEqual(fixture.shared.draft, original)
        XCTAssertTrue(active.isActive)
        XCTAssertEqual(fixture.first.reviewState, .confirmed)
        XCTAssertEqual(fixture.second.reviewState, .confirmed)
    }

    func testD013CombinedSuccessCommitsEventAndFastCompletionWithoutLegacyMutation() throws {
        let fixture = try fixture()
        let active = FastRecord(startDate: date(25), goalAtStart: .default)
        fixture.context.insert(active)
        try fixture.context.save()
        let moved = HydrationEntryDraft(
            type: .coffee,
            customName: nil,
            volumeMillilitres: 250,
            occurredAt: date(27),
            isCaloric: true
        )
        try SwiftDataHydrationEntryRepository(modelContext: fixture.context).update(
            fixture.shared,
            with: moved,
            at: date(31),
            ending: active,
            goal: .default
        )
        XCTAssertEqual(fixture.shared.draft, moved)
        XCTAssertEqual(active.endDate, moved.occurredAt)
        XCTAssertEqual(fixture.first.reviewState, .confirmed)
        XCTAssertEqual(fixture.second.reviewState, .confirmed)
    }

    func testUpdatedEvidenceResolverCoversAvailableConflictMissingAndAmbiguous() {
        let a = boundary(.food, 1, 0)
        let b = boundary(.food, 2, 12)
        let pair = ReconstructionBoundaryPair(start: a.reference, end: b.reference)
        let saved = date(0) ..< date(12)
        XCTAssertEqual(
            UpdatedReconstructionEvidenceResolver.resolve(
                savedInterval: saved,
                originalPair: pair,
                boundaries: [a, b],
                otherFasts: []
            ),
            .available(.init(pair: pair, startBoundary: a, endBoundary: b))
        )
        XCTAssertEqual(
            UpdatedReconstructionEvidenceResolver.resolve(
                savedInterval: saved,
                originalPair: pair,
                boundaries: [a, b],
                otherFasts: [.init(id: uuid(90), startDate: date(1), endDate: date(2))]
            ),
            .unavailable(.conflictingHistory)
        )
        XCTAssertEqual(
            UpdatedReconstructionEvidenceResolver.resolve(
                savedInterval: saved,
                originalPair: pair,
                boundaries: [],
                otherFasts: []
            ),
            .unavailable(.missingSupportingEntry)
        )
        XCTAssertEqual(
            UpdatedReconstructionEvidenceResolver.resolve(
                savedInterval: date(0) ..< date(24),
                originalPair: .init(start: a.reference, end: boundary(.food, 3, 24).reference),
                boundaries: [a, b, boundary(.food, 3, 24)],
                otherFasts: []
            ),
            .unavailable(.ambiguousEvidence)
        )
    }

    func testNeedsReviewResolutionUpdateKeepAndRemoveAreExplicitAndSingleUse() throws {
        let updateFixture = try fixture()
        updateFixture.first.markNeedsReview()
        try updateFixture.context.save()
        let reconstruction = SwiftDataReconstructionRepository(
            modelContext: updateFixture.context,
            clock: FixedAppClock(now: date(40))
        )
        try reconstruction.updateAndReconfirm(id: updateFixture.first.id)
        XCTAssertEqual(updateFixture.first.reviewState, .confirmed)
        XCTAssertEqual(updateFixture.first.origin, .reconstructed)
        XCTAssertNil(updateFixture.first.capturedHistoricalGoal)
        XCTAssertThrowsError(try reconstruction.updateAndReconfirm(id: updateFixture.first.id))

        updateFixture.second.markNeedsReview()
        try updateFixture.context.save()
        try reconstruction.keepAsRecordedFast(id: updateFixture.second.id)
        XCTAssertEqual(updateFixture.second.origin, .recorded)
        XCTAssertNil(updateFixture.second.boundaryPair)
        XCTAssertNil(updateFixture.second.capturedHistoricalGoal)

        let removeFixture = try fixture()
        removeFixture.first.markNeedsReview()
        try removeFixture.context.save()
        let removeRepository = SwiftDataReconstructionRepository(
            modelContext: removeFixture.context,
            clock: FixedAppClock(now: date(40))
        )
        try removeRepository.removeAndLeaveUnknown(id: removeFixture.first.id)
        XCTAssertEqual(try removeFixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).count, 1)
        XCTAssertThrowsError(try removeRepository.removeAndLeaveUnknown(id: removeFixture.first.id))
        XCTAssertEqual(try removeFixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).count, 1)
    }

    func testEveryFailedResolutionLeavesOneNeedsReviewFastAndNoUnknown() throws {
        let fixture = try fixture()
        fixture.first.markNeedsReview()
        try fixture.context.save()
        let repository = SwiftDataReconstructionRepository(
            modelContext: fixture.context,
            clock: FixedAppClock(now: date(40)),
            simulateSaveFailure: true
        )

        XCTAssertThrowsError(try repository.updateAndReconfirm(id: fixture.first.id))
        XCTAssertThrowsError(try repository.keepAsRecordedFast(id: fixture.first.id))
        XCTAssertThrowsError(try repository.removeAndLeaveUnknown(id: fixture.first.id))
        let matching = try fixture.context.fetch(FetchDescriptor<FastRecord>())
            .filter { $0.id == fixture.first.id }
        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.reviewState, .needsReview)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<UnknownPeriodRecord>()).isEmpty)
    }

    private func fixture() throws -> (
        container: ModelContainer,
        context: ModelContext,
        first: FastRecord,
        second: FastRecord,
        shared: HydrationEntryRecord
    ) {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = FoodEntryRecord(draft: .init(description: "Dinner", occurredAt: date(0)), createdAt: date(0))
        let shared = HydrationEntryRecord(
            type: .coffee,
            volumeMillilitres: 250,
            occurredAt: date(12),
            isCaloric: true,
            createdAt: date(12)
        )
        let end = FoodEntryRecord(draft: .init(description: "Breakfast", occurredAt: date(24)), createdAt: date(24))
        let firstPair = ReconstructionBoundaryPair(
            start: .init(kind: .food, id: start.id),
            end: .init(kind: .hydration, id: shared.id)
        )
        let secondPair = ReconstructionBoundaryPair(
            start: .init(kind: .hydration, id: shared.id),
            end: .init(kind: .food, id: end.id)
        )
        let first = FastRecord(reconstructedStart: date(0), endDate: date(12), boundaries: firstPair, adjustedByUser: false)
        let second = FastRecord(reconstructedStart: date(12), endDate: date(24), boundaries: secondPair, adjustedByUser: true)
        context.insert(start)
        context.insert(shared)
        context.insert(end)
        context.insert(first)
        context.insert(second)
        try context.save()
        return (container, context, first, second, shared)
    }

    private func history(
        _ id: Int,
        _ startHour: Int,
        _ endHour: Int,
        _ start: CaloricBoundaryReference,
        _ end: CaloricBoundaryReference
    ) -> ReconstructedHistorySnapshot {
        .init(
            id: uuid(id),
            interval: date(startHour) ..< date(endHour),
            boundaries: .init(start: start, end: end)
        )
    }

    private func boundary(_ kind: CaloricBoundaryKind, _ id: Int, _ hour: Int) -> CaloricBoundary {
        .init(reference: reference(kind, id), occurredAt: date(hour), description: "Entry \(id)")
    }

    private func reference(_ kind: CaloricBoundaryKind, _ id: Int) -> CaloricBoundaryReference {
        .init(kind: kind, id: uuid(id))
    }

    private func date(_ hour: Int) -> Date {
        base.addingTimeInterval(TimeInterval(hour * 3600))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", value))!
    }
}
