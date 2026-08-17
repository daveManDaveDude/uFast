import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistoryCaloricNeighbourOrderingTests: XCTestCase {
    private struct Fixture {
        let container: ModelContainer
        let provider: SwiftDataHistoryMotionDataProvider
        let boundaryTime: Date
        let nextBoundaryTime: Date
        let latestDrinkID: UUID
    }

    func testEqualTimeNeighboursKeepAutomaticFastIdentityAcrossMotionChunkSeam() throws {
        let fixture = try makeFixture()
        let seam = fixture.boundaryTime.addingTimeInterval(60 * 60)
        let first = try presentation(
            provider: fixture.provider,
            window: DateInterval(
                start: fixture.boundaryTime.addingTimeInterval(-60 * 60),
                end: seam
            ),
            referenceNow: fixture.nextBoundaryTime
        )
        let second = try presentation(
            provider: fixture.provider,
            window: DateInterval(
                start: seam,
                end: fixture.nextBoundaryTime.addingTimeInterval(60 * 60)
            ),
            referenceNow: fixture.nextBoundaryTime
        )

        XCTAssertEqual(first.intervals.map(\.id), [fixture.latestDrinkID])
        XCTAssertEqual(second.intervals.map(\.id), [fixture.latestDrinkID])
        XCTAssertEqual(first.intervals, second.intervals)
    }

    func testEqualTimeCaloricFoodNeighbourUsesProjectorUUIDTieBreak() throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let sourceDate = Date(timeIntervalSince1970: 2_100_000_000)
        let window = DateInterval(
            start: sourceDate.addingTimeInterval(9 * 60 * 60),
            duration: 60 * 60
        )
        let firstID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000002"))
        context.insert(FoodEntryRecord(
            id: secondID,
            draft: .init(description: "Second source", occurredAt: sourceDate),
            createdAt: sourceDate
        ))
        context.insert(FoodEntryRecord(
            id: firstID,
            draft: .init(description: "First source", occurredAt: sourceDate),
            createdAt: sourceDate
        ))
        context.insert(AppSettingsRecord(
            hasCompletedOnboarding: true,
            inferredFastDetectionEnabled: true
        ))
        try context.save()

        let settledData = try SwiftDataHistoryDataProvider(modelContext: context).fetch(window: window)
        XCTAssertEqual(settledData.foods.map(\.id), [firstID])
        XCTAssertEqual(try inferredID(in: settledData, at: window.end), firstID)

        let motionData = try SwiftDataHistoryMotionDataProvider(modelContext: context).fetch(
            window: window,
            calendar: utcCalendar
        )
        XCTAssertEqual(motionData.foods.map(\.id), [firstID])
        XCTAssertEqual(try inferredID(in: motionData, at: window.end), firstID)
    }

    func testMotionInferredIntervalRefreshesItsEndAndSaveOnlyLifecycle() throws {
        let source = Date(timeIntervalSince1970: 2_000_000_000)
        let interval = InferredFastInterval(
            sourceFoodID: UUID(), sourceDate: source, sourceDescription: "Dinner",
            nextFoodID: nil, nextFoodDate: nil, startDate: source,
            endDate: source.addingTimeInterval(8 * 60 * 60), goal: .default, state: .inProgress
        )
        let motion = HistoryMotionPresentation(
            window: DateInterval(start: source, duration: 24 * 60 * 60),
            intervals: [HistoryMotionIntervalPrimitive(
                id: interval.id, start: interval.startDate, end: interval.endDate,
                kind: .automatic, isActive: false, semanticKind: .inferred,
                inferredInterval: interval
            )],
            events: []
        )

        let live = try XCTUnwrap(motion.inferredInterval(
            for: interval.id, at: source.addingTimeInterval(10 * 60 * 60)
        ))
        XCTAssertEqual(live.endDate, source.addingTimeInterval(10 * 60 * 60))
        XCTAssertEqual(live.state, .inProgress)
        XCTAssertTrue(live.offersStart)

        let capped = try XCTUnwrap(motion.inferredInterval(
            for: interval.id, at: source.addingTimeInterval(24 * 60 * 60)
        ))
        XCTAssertEqual(capped.endDate, source.addingTimeInterval(24 * 60 * 60))
        XCTAssertEqual(capped.state, .historical)
        XCTAssertTrue(capped.offersSave)
        XCTAssertFalse(capped.offersStart)
        XCTAssertTrue(try XCTUnwrap(motion.ribbonIntervals(activeEndingAt: capped.endDate).first)
            .accessibilityLabel.contains("Inferred fast"))
    }

    private func makeFixture() throws -> Fixture {
        let container = try PersistenceContainer.make(inMemory: true)
        let context = container.mainContext
        let boundaryTime = Date(timeIntervalSince1970: 2_000_000_000)
        let nextBoundaryTime = boundaryTime.addingTimeInterval(10 * 60 * 60)
        let foodID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000030"))
        let earlierDrinkID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000010"))
        let latestDrinkID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000020"))
        context.insert(FoodEntryRecord(
            id: foodID,
            draft: .init(description: "Dinner", occurredAt: boundaryTime),
            createdAt: boundaryTime
        ))
        for id in [earlierDrinkID, latestDrinkID] {
            context.insert(HydrationEntryRecord(
                id: id,
                type: .custom,
                customName: "Caloric drink",
                volumeMillilitres: 250,
                occurredAt: boundaryTime,
                isCaloric: true,
                createdAt: boundaryTime
            ))
        }
        context.insert(FoodEntryRecord(
            draft: .init(description: "Breakfast", occurredAt: nextBoundaryTime),
            createdAt: nextBoundaryTime
        ))
        try context.save()
        return Fixture(
            container: container,
            provider: SwiftDataHistoryMotionDataProvider(modelContext: context),
            boundaryTime: boundaryTime,
            nextBoundaryTime: nextBoundaryTime,
            latestDrinkID: latestDrinkID
        )
    }

    private func presentation(
        provider: SwiftDataHistoryMotionDataProvider,
        window: DateInterval,
        referenceNow: Date
    ) throws -> HistoryMotionPresentation {
        let calendar = utcCalendar
        let data = try provider.fetch(window: window, calendar: calendar)
        return HistoryMotionPresentation(HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: calendar,
            timeZone: .gmt,
            referenceNow: referenceNow
        ))
    }

    private func inferredID(in data: HistoryDataSlice, at referenceNow: Date) throws -> UUID {
        let presentation = HistoryPresentationBuilder.build(
            data: data,
            locale: Locale(identifier: "en_GB"),
            calendar: utcCalendar,
            timeZone: .gmt,
            referenceNow: referenceNow
        )
        return try XCTUnwrap(presentation.fastItems.first(where: { $0.kind == .inferred })).id
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
