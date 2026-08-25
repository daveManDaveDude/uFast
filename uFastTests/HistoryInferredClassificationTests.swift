import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistoryInferredClassificationTests: XCTestCase {
    func testSettledAndMotionInferenceTreatCompatibilityFoodAsCaloric() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sourceDate = Date(timeIntervalSince1970: 2_210_000_000)
        let window = DateInterval(start: sourceDate.addingTimeInterval(9 * 60 * 60), duration: 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        let nonCaloricBefore = nonCaloricFood(
            description: "Non-caloric drink",
            occurredAt: sourceDate.addingTimeInterval(8.5 * 60 * 60),
            createdAt: sourceDate
        )
        let nonCaloricLater = nonCaloricFood(
            description: "Non-caloric snack",
            occurredAt: sourceDate.addingTimeInterval(20 * 60 * 60),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(nonCaloricBefore)
        context.insert(nonCaloricLater)
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true, inferredFastDetectionEnabled: true))
        try context.save()

        let referenceNow = sourceDate.addingTimeInterval(20 * 60 * 60)
        let settledData = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        let settled = build(settledData, referenceNow: referenceNow)
        let settledInferred = try XCTUnwrap(
            settled.fastItems.first {
                $0.kind == .inferred
                    && $0.inferredInterval?.sourceFoodID == nonCaloricBefore.id
            }?.inferredInterval
        )
        XCTAssertEqual(settledInferred.sourceFoodID, nonCaloricBefore.id)
        XCTAssertEqual(settledInferred.nextFoodID, nonCaloricLater.id)

        let motionData = try SwiftDataHistoryMotionDataProvider(modelContext: context)
            .fetch(window: window, calendar: utcCalendar)
        let motion = HistoryMotionPresentation(
            build(motionData, referenceNow: referenceNow),
            inferredContext: HistoryMotionInferredContext(data: motionData)
        )
        let motionCandidate = try XCTUnwrap(
            motion.ribbonIntervals(activeEndingAt: referenceNow)
                .compactMap { motion.inferredInterval(for: $0.id, at: referenceNow) }
                .first { $0.sourceFoodID == nonCaloricBefore.id }
        )
        XCTAssertEqual(motionCandidate.sourceFoodID, nonCaloricBefore.id)
        XCTAssertEqual(motionCandidate.nextFoodID, nonCaloricLater.id)
    }

    func testHydrationInferredSourceUsesDrinkAccessibilitySemantics() {
        let sourceID = UUID()
        let sourceDate = Date(timeIntervalSince1970: 2_210_000_000)
        let interval = InferredFastInterval(
            sourceBoundaryReference: .init(kind: .hydration, id: sourceID),
            sourceDate: sourceDate,
            sourceDescription: "Juice",
            nextBoundaryReference: nil,
            nextBoundaryDate: nil,
            startDate: sourceDate,
            endDate: sourceDate.addingTimeInterval(12 * 60 * 60),
            goal: .default,
            state: .historical
        )

        let item = HistoryVisibleFastItem.inferred(interval)
        XCTAssertTrue(item.accessibilityLabel.contains("source drink Juice"))
        XCTAssertFalse(item.accessibilityLabel.contains("source food Juice"))
        XCTAssertEqual(item.ribbonItem.kind, .inferred)
        XCTAssertEqual(item.ribbonItem.title, "Inferred fast")
    }

    func testCompatibilityFoodRowsRemainCaloricPersistenceBoundaries() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let now = Date(timeIntervalSince1970: 2_100_000_000)
        let record = FoodEntryRecord(
            draft: .init(description: "Legacy dinner", occurredAt: now),
            createdAt: now
        )
        record.restore(from: FoodEntryRecordSnapshot(
            draft: record.draft,
            isCaloric: false,
            updatedAt: now
        ))
        container.mainContext.insert(record)
        try container.mainContext.save()

        let boundaries = try CaloricBoundaryPersistencePlanner(
            modelContext: container.mainContext
        ).allBoundaries()

        XCTAssertEqual(
            boundaries.map(\.reference),
            [CaloricBoundaryReference(kind: .food, id: record.id)]
        )
    }

    func testCompatibilityFoodPresentationRemainsCaloricAcrossTodayAndHistory() throws {
        let now = Date(timeIntervalSince1970: 2_100_000_000)
        let record = FoodEntryRecord(
            draft: .init(description: "Legacy dinner", occurredAt: now),
            createdAt: now
        )
        record.restore(from: FoodEntryRecordSnapshot(
            draft: record.draft,
            isCaloric: false,
            updatedAt: now
        ))

        let snapshot = FoodEntrySnapshot(record)
        XCTAssertTrue(snapshot.isCaloric)
        let timeline = TodayTimeline.entries(
            food: [snapshot],
            drinks: [],
            now: now,
            calendar: utcCalendar
        )
        let timelineEntry = try XCTUnwrap(timeline.first)
        guard case let .food(_, _, isCaloric) = timelineEntry.kind else {
            return XCTFail("Expected a food timeline entry")
        }
        XCTAssertTrue(isCaloric)

        let window = DateInterval(start: now.addingTimeInterval(-60), duration: 120)
        let presentation = build(
            HistoryDataSlice(
                window: window,
                completedFasts: [],
                activeFast: nil,
                foods: [snapshot],
                drinks: [],
                settings: nil
            ),
            referenceNow: now
        )
        let event = try XCTUnwrap(presentation.events.first)
        XCTAssertTrue(event.detail.contains("Caloric"))
        XCTAssertTrue(event.accessibilityLabel.contains("caloric"))
        XCTAssertFalse(event.detail.contains("Non-caloric"))
        XCTAssertFalse(event.accessibilityLabel.contains("non-caloric"))
    }

    func testReviewedLegacyFastIdentifiesItsUnavailableBoundaryInSettledAndMotion() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 2_100_000_000)
        let end = start.addingTimeInterval(12 * 60 * 60)
        let startFood = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: start),
            createdAt: start
        )
        let endDrink = HydrationEntryRecord(
            type: .custom,
            customName: "Juice",
            volumeMillilitres: 250,
            occurredAt: end,
            isCaloric: true,
            createdAt: end
        )
        let endReference = CaloricBoundaryReference(kind: .hydration, id: endDrink.id)
        let fast = FastRecord(
            reconstructedStart: start,
            endDate: end,
            boundaries: ReconstructionBoundaryPair(
                start: .init(kind: .food, id: startFood.id),
                end: endReference
            ),
            adjustedByUser: false
        )
        fast.retainReviewBoundary(endReference)
        fast.markNeedsReview()
        context.insert(startFood)
        context.insert(endDrink)
        context.insert(fast)
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true))
        try context.save()

        let window = DateInterval(start: start, end: end.addingTimeInterval(60))
        let data = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        let settled = build(data, referenceNow: window.end)
        let settledItem = try XCTUnwrap(settled.fastItems.first)
        XCTAssertEqual(settledItem.title, "Previously saved fast · Needs review")
        XCTAssertTrue(settledItem.detail.contains("former drink boundary unavailable"))
        XCTAssertTrue(settledItem.accessibilityLabel.contains("former drink boundary unavailable"))

        let motion = HistoryMotionPresentation(settled)
        let motionItem = try XCTUnwrap(motion.intervals.first)
        XCTAssertEqual(motionItem.title, settledItem.title)
        XCTAssertTrue(motionItem.detail?.contains("former drink boundary unavailable") == true)
        XCTAssertTrue(motionItem.accessibilityLabel?.contains("former drink boundary unavailable") == true)
    }

    private func build(
        _ data: HistoryDataSlice,
        referenceNow: Date
    ) -> HistoryPresentationSnapshot {
        HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: referenceNow
        )
    }

    private func nonCaloricFood(
        description: String,
        occurredAt: Date,
        createdAt: Date
    ) -> FoodEntryRecord {
        let record = FoodEntryRecord(
            draft: .init(description: description, occurredAt: occurredAt),
            createdAt: createdAt
        )
        record.restore(from: FoodEntryRecordSnapshot(
            draft: record.draft,
            isCaloric: false,
            updatedAt: createdAt
        ))
        return record
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
