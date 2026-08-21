import SwiftData
@testable import uFast
import XCTest

// swiftlint:disable function_body_length type_body_length

@MainActor
final class CaloricBoundaryNeighborhoodTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testPureScaleNeighbourhoodMatchesFullHistoryOracle() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let insertionDate = now.addingTimeInterval(-4 * 60 * 60)
        let source = try FoodBoundarySnapshot(
            id: XCTUnwrap(UUID(uuidString: "50000000-0000-0000-0000-000000000001")),
            occurredAt: sourceDate,
            description: "Source",
            isCaloric: true
        )
        let later = try HydrationBoundarySnapshot(
            id: XCTUnwrap(UUID(uuidString: "50000000-0000-0000-0000-000000000002")),
            occurredAt: now.addingTimeInterval(-2 * 60 * 60),
            description: "Later",
            isCaloric: true
        )
        let unrelatedFood = (0 ..< 2000).map { index in
            FoodBoundarySnapshot(
                id: deterministicID(1000 + index),
                occurredAt: now.addingTimeInterval(-Double(index + 100) * 86400),
                description: "Old (index)",
                isCaloric: true
            )
        }
        let unrelatedHydration = (0 ..< 2000).map { index in
            HydrationBoundarySnapshot(
                id: deterministicID(3000 + index),
                occurredAt: now.addingTimeInterval(-Double(index + 200) * 86400),
                description: "Old drink (index)",
                isCaloric: index.isMultiple(of: 2)
            )
        }
        let food = unrelatedFood + [source]
        let hydration = unrelatedHydration + [later]
        let fast = BoundaryFastSnapshot(
            id: deterministicID(5000),
            startDate: sourceDate.addingTimeInterval(-60),
            endDate: now,
            isReconstructed: false
        )
        let unrelatedFast = BoundaryFastSnapshot(
            id: deterministicID(5001),
            startDate: now.addingTimeInterval(-10 * 86400),
            endDate: now.addingTimeInterval(-9 * 86400),
            isReconstructed: false
        )
        let sink = RecordingBoundaryQueryObservationSink()
        let neighborhood = CaloricBoundaryNeighborhoodSelector.eventNeighborhood(
            oldReference: nil,
            oldOccurredAt: nil,
            newBoundary: CaloricBoundary(
                reference: .init(kind: .food, id: deterministicID(5002)),
                occurredAt: insertionDate,
                description: "New"
            ),
            goal: .default,
            food: food,
            hydration: hydration,
            fasts: [fast, unrelatedFast],
            sink: sink
        )
        let mutation = CaloricBoundaryMutation(
            oldReference: nil,
            oldOccurredAt: nil,
            oldIsCaloric: false,
            newBoundary: neighborhood.boundaries.first(where: {
                $0.occurredAt == insertionDate
            }),
            resultingBoundaries: CaloricBoundaryExtractor.boundaries(
                food: food,
                hydration: hydration
            )
        )
        let oracle = CaloricBoundaryImpactAnalyzer.impact(
            for: mutation,
            fasts: [fast, unrelatedFast].map {
                PersistedFastBoundarySnapshot(
                    id: $0.id,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    origin: .recorded,
                    reviewState: .confirmed,
                    boundaryPair: nil
                )
            }
        )
        let bounded = CaloricBoundaryImpactAnalyzer.impact(
            for: CaloricBoundaryMutation(
                oldReference: mutation.oldReference,
                oldOccurredAt: mutation.oldOccurredAt,
                oldIsCaloric: mutation.oldIsCaloric,
                newBoundary: mutation.newBoundary,
                resultingBoundaries: neighborhood.boundaries
            ),
            fasts: neighborhood.fasts.map {
                PersistedFastBoundarySnapshot(
                    id: $0.id,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    origin: $0.isReconstructed ? .reconstructed : .recorded,
                    reviewState: .confirmed,
                    boundaryPair: nil
                )
            }
        )
        XCTAssertEqual(bounded, oracle)
        XCTAssertTrue(neighborhood.fasts.contains { $0.id == fast.id })
        XCTAssertFalse(neighborhood.fasts.contains { $0.id == unrelatedFast.id })
        XCTAssertTrue(sink.observations.contains { $0.fetchLimit == 1 })
    }

    func testIDLookupUsesPredicateLimitAndReportsDuplicate() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let id = try XCTUnwrap(UUID(uuidString: "50000000-0000-0000-0000-000000000099"))
        context.insert(FoodEntryRecord(
            id: id,
            draft: .init(description: "One", occurredAt: .now),
            createdAt: .now
        ))
        context.insert(FoodEntryRecord(
            id: id,
            draft: .init(description: "Two", occurredAt: .now.addingTimeInterval(1)),
            createdAt: .now
        ))
        try context.save()
        let sink = RecordingBoundaryQueryObservationSink()
        let result = try SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: context,
            observationSink: sink
        ).food(id: id)
        guard case .duplicate = result else {
            return XCTFail("Expected explicit duplicate resolution")
        }
        XCTAssertEqual(sink.observations.last?.fetchLimit, 2)
        XCTAssertEqual(sink.observations.last?.returnedCount, 2)
    }

    func testScaleFixtureMutationRecordsBoundedStructuralRequests() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let clock = FixedAppClock(now: Date(timeIntervalSince1970: 1_900_000_000))
        UITestSeedFixtures.seedCaloricBoundaryMultiYear(in: context, clock: clock)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 2001)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 2001)
        let sink = RecordingBoundaryQueryObservationSink()
        let repository = SwiftDataFoodEntryRepository(
            modelContext: context,
            clock: clock,
            observationSink: sink
        )
        try repository.saveCaloricEvent(
            .init(description: "New event", occurredAt: clock.now.addingTimeInterval(-3600)),
            replacing: nil,
            goal: .default
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodEntryRecord>()), 2002)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HydrationEntryRecord>()), 2001)
        XCTAssertTrue(sink.observations.contains { $0.entity == .food && $0.fetchLimit == 1 })
        XCTAssertTrue(sink.observations.contains { $0.entity == .hydration && $0.fetchLimit == 1 })
        XCTAssertFalse(sink.observations.contains {
            ($0.entity == .food || $0.entity == .hydration)
                && $0.fetchLimit == nil
                && $0.lowerBound == nil
                && $0.upperBound == nil
        })
    }

    // swiftlint:disable:next function_body_length
    func testStoragePredecessorOverlapMatchesFullHistoryOracle() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let sourceDate = now.addingTimeInterval(-25 * 60 * 60)
        let insertionDate = now.addingTimeInterval(-4 * 60 * 60)
        let sourceID = deterministicID(6000)
        let insertionID = deterministicID(6001)
        let fastID = deterministicID(6002)
        let source = FoodEntryRecord(
            id: sourceID,
            draft: .init(description: "Source", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        let fast = FastRecord(
            id: fastID,
            startDate: sourceDate.addingTimeInterval(-30 * 60),
            endDate: insertionDate.addingTimeInterval(-30 * 60),
            goalAtStart: .default
        )
        context.insert(source)
        context.insert(fast)
        try context.save()

        let newBoundary = CaloricBoundary(
            reference: .init(kind: .food, id: insertionID),
            occurredAt: insertionDate,
            description: "Inserted"
        )
        let fullFood = [FoodBoundarySnapshot(
            id: sourceID,
            occurredAt: sourceDate,
            description: "Source",
            isCaloric: true
        )]
        let fullFasts = [PersistedFastBoundarySnapshot(
            id: fastID,
            startDate: fast.startDate,
            endDate: fast.endDate,
            origin: .recorded,
            reviewState: .confirmed,
            boundaryPair: nil
        )]
        let fullMutation = CaloricBoundaryMutation(
            oldReference: nil,
            oldOccurredAt: nil,
            oldIsCaloric: false,
            newBoundary: newBoundary,
            resultingBoundaries: CaloricBoundaryOrdering.sorted(
                CaloricBoundaryExtractor.boundaries(food: fullFood, hydration: []) + [newBoundary]
            )
        )
        let oracle = CaloricBoundaryImpactAnalyzer.impact(
            for: fullMutation,
            fasts: fullFasts
        )
        let sink = RecordingBoundaryQueryObservationSink()
        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: context,
            observationSink: sink
        )
        let bounded = try planner.boundedMutation(
            for: fullMutation,
            currentGoal: .default
        )
        let boundedImpact = planner.impact(for: bounded.mutation, fasts: bounded.fasts)

        XCTAssertEqual(boundedImpact, oracle)
        XCTAssertTrue(bounded.fasts.contains { $0.id == fastID })
        XCTAssertTrue(sink.observations.contains {
            $0.entity == .fast
                && $0.upperBound == sourceDate
                && $0.lowerBound == nil
        })
    }

    // swiftlint:disable:next function_body_length
    func testStorageEqualTimeUUIDOrderingMatchesFullHistoryOracleForBothEntityKinds() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let timestamp = Date(timeIntervalSince1970: 1_900_000_000 - 10 * 60 * 60)
        let foodLowID = deterministicID(6100)
        let foodHighID = deterministicID(6101)
        let hydrationLowID = deterministicID(6110)
        let hydrationHighID = deterministicID(6111)
        let insertionID = deterministicID(6120)
        let fastID = deterministicID(6130)
        context.insert(FoodEntryRecord(
            id: foodHighID,
            draft: .init(description: "Food high", occurredAt: timestamp),
            createdAt: timestamp
        ))
        context.insert(FoodEntryRecord(
            id: foodLowID,
            draft: .init(description: "Food low", occurredAt: timestamp),
            createdAt: timestamp
        ))
        context.insert(HydrationEntryRecord(
            id: hydrationHighID,
            type: .custom,
            customName: "Drink high",
            volumeMillilitres: 250,
            occurredAt: timestamp,
            isCaloric: true,
            createdAt: timestamp
        ))
        context.insert(HydrationEntryRecord(
            id: hydrationLowID,
            type: .custom,
            customName: "Drink low",
            volumeMillilitres: 250,
            occurredAt: timestamp,
            isCaloric: true,
            createdAt: timestamp
        ))
        let fast = FastRecord(
            id: fastID,
            startDate: timestamp.addingTimeInterval(-60 * 60),
            endDate: timestamp.addingTimeInterval(8 * 60 * 60),
            goalAtStart: .default
        )
        context.insert(fast)
        try context.save()

        let query = SwiftDataCaloricBoundaryQueryAdapter(modelContext: context)
        let foodGroup = try query.exactFood(at: timestamp)
        let hydrationGroup = try query.exactCaloricHydration(at: timestamp)
        XCTAssertEqual(foodGroup.map(\.id), [foodLowID, foodHighID])
        XCTAssertEqual(hydrationGroup.map(\.id), [hydrationLowID, hydrationHighID])

        let newBoundary = CaloricBoundary(
            reference: .init(kind: .food, id: insertionID),
            occurredAt: timestamp,
            description: "Inserted"
        )
        let fullFood = foodGroup.map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: true
            )
        }
        let fullHydration = hydrationGroup.map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: true
            )
        }
        let fullResult = CaloricBoundaryOrdering.sorted(
            CaloricBoundaryExtractor.boundaries(food: fullFood, hydration: fullHydration)
                + [newBoundary]
        )
        let mutation = CaloricBoundaryMutation(
            oldReference: nil,
            oldOccurredAt: nil,
            oldIsCaloric: false,
            newBoundary: newBoundary,
            resultingBoundaries: fullResult
        )
        let planner = CaloricBoundaryPersistencePlanner(modelContext: context)
        let bounded = try planner.boundedMutation(for: mutation, currentGoal: .default)
        let oracle = CaloricBoundaryImpactAnalyzer.impact(
            for: mutation,
            fasts: [PersistedFastBoundarySnapshot(
                id: fast.id,
                startDate: fast.startDate,
                endDate: fast.endDate,
                origin: .recorded,
                reviewState: .confirmed,
                boundaryPair: nil
            )]
        )

        XCTAssertEqual(bounded.mutation.resultingBoundaries, fullResult)
        XCTAssertEqual(planner.impact(for: bounded.mutation, fasts: bounded.fasts), oracle)
        XCTAssertEqual(
            bounded.mutation.resultingBoundaries.filter { $0.occurredAt == timestamp }
                .map(\.reference.id),
            [foodLowID, foodHighID, insertionID, hydrationLowID, hydrationHighID]
        )
    }

    private func deterministicID(_ value: Int) -> UUID {
        let suffix = String(value, radix: 16)
        let padded = String(repeating: "0", count: max(0, 12 - suffix.count)) + suffix
        guard let id = UUID(uuidString: "50000000-0000-0000-0000-\(padded)") else {
            preconditionFailure("Invalid deterministic test UUID")
        }
        return id
    }
}
