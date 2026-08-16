import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistoryInferredClassificationTests: XCTestCase {
    func testSettledAndMotionInferencePreserveNonCaloricFoodClassification() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sourceDate = Date(timeIntervalSince1970: 2_210_000_000)
        let window = DateInterval(start: sourceDate.addingTimeInterval(9 * 60 * 60), duration: 60 * 60)
        let source = FoodEntryRecord(
            draft: .init(description: "Dinner", occurredAt: sourceDate),
            createdAt: sourceDate
        )
        let nonCaloricLater = nonCaloricFood(
            description: "Non-caloric snack",
            occurredAt: sourceDate.addingTimeInterval(20 * 60 * 60),
            createdAt: sourceDate
        )
        context.insert(source)
        context.insert(nonCaloricLater)
        context.insert(AppSettingsRecord(hasCompletedOnboarding: true, inferredFastDetectionEnabled: true))
        try context.save()

        let referenceNow = sourceDate.addingTimeInterval(20 * 60 * 60)
        let settledData = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        let settled = HistoryPresentationBuilder.build(
            data: settledData,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: referenceNow
        )
        let settledInferred = try XCTUnwrap(settled.fastItems.first(where: { $0.kind == .inferred })?.inferredInterval)
        XCTAssertEqual(settledInferred.sourceFoodID, source.id)
        XCTAssertNil(settledInferred.nextFoodID)

        let motionData = try SwiftDataHistoryMotionDataProvider(modelContext: context)
            .fetch(window: window, calendar: utcCalendar)
        let motion = HistoryMotionPresentation(
            HistoryPresentationBuilder.build(
                data: motionData,
                locale: Locale(identifier: "en_GB"),
                calendar: utcCalendar,
                timeZone: .gmt,
                referenceNow: referenceNow
            ),
            inferredContext: HistoryMotionInferredContext(data: motionData)
        )
        let motionInferred = try XCTUnwrap(
            motion.ribbonIntervals(activeEndingAt: referenceNow).first(where: { $0.kind == .inferred })
        )
        let motionCandidate = try XCTUnwrap(
            motion.inferredInterval(for: motionInferred.id, at: referenceNow)
        )
        XCTAssertEqual(motionCandidate.sourceFoodID, source.id)
        XCTAssertNil(motionCandidate.nextFoodID)
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
