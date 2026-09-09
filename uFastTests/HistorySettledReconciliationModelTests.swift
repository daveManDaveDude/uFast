import SwiftData
@testable import uFast
import XCTest

@MainActor
final class HistorySettledReconciliationModelTests: XCTestCase {
    func testLifecycleInvalidationDiscardsInFlightSettlement() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let scheduler = ManualHistorySettlementScheduler()
        let source = SuspendedSettledProjectionSource()
        let model = makeModel(container: container, scheduler: scheduler, source: source)
        let window = makeWindow(offset: 0, fractionalStart: 0.35)

        XCTAssertEqual(
            model.scheduleSettledReconciliation(for: window),
            .scheduled(generation: 1)
        )
        let operation = Task { @MainActor in
            await scheduler.runNext()
        }
        await source.waitForRequestCount(1)

        model.cancelOutstandingTasks()
        source.resumeNext()
        await operation.value

        XCTAssertNil(model.historyData)
        XCTAssertFalse(model.settledReconciliationPending)
        XCTAssertFalse(model.hasMatchingSettledProjection)
    }

    func testFailedChangedWindowRetainsProjectionAndGatesSettledInteraction() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let scheduler = ManualHistorySettlementScheduler()
        let source = RecordingSettledProjectionSource()
        let model = makeModel(container: container, scheduler: scheduler, source: source)
        let firstWindow = makeWindow(offset: 0, fractionalStart: 0.2)
        let changedWindow = makeWindow(offset: 1, fractionalStart: 0.8)

        _ = model.scheduleSettledReconciliation(for: firstWindow)
        await scheduler.runNext()
        let retainedData = try XCTUnwrap(model.historyData)

        source.shouldFail = true
        _ = model.scheduleSettledReconciliation(for: changedWindow)
        await scheduler.runNext()

        XCTAssertEqual(model.historyData, retainedData)
        XCTAssertFalse(model.settledReconciliationPending)
        XCTAssertFalse(model.hasMatchingSettledProjection)
        let gated = settledDetailsAreAvailable(for: model)
        XCTAssertFalse(gated)
        let interaction = TemporalHistoryCarousel.timelineInteractionState(
            movementPhase: .settled,
            allowsRecordActivation: gated,
            allowsEmptySelection: gated
        )
        XCTAssertFalse(interaction.allowsRecordActivation)
        XCTAssertFalse(interaction.allowsEmptySelection)

        source.shouldFail = false
        model.invalidateSettledReconciliation()
        _ = model.scheduleSettledReconciliation(for: changedWindow)
        await scheduler.runNext()

        XCTAssertTrue(model.hasMatchingSettledProjection)
        let restored = settledDetailsAreAvailable(for: model)
        XCTAssertTrue(restored)
        let restoredInteraction = TemporalHistoryCarousel.timelineInteractionState(
            movementPhase: .settled,
            allowsRecordActivation: restored,
            allowsEmptySelection: restored
        )
        XCTAssertTrue(restoredInteraction.allowsRecordActivation)
        XCTAssertTrue(restoredInteraction.allowsEmptySelection)
    }

    func testModelPostCompletionDuplicateDoesNotLeaveDetailsHidden() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let scheduler = ManualHistorySettlementScheduler()
        let model = makeModel(
            container: container,
            scheduler: scheduler,
            source: RecordingSettledProjectionSource()
        )
        let window = makeWindow(offset: 0, fractionalStart: 0.45)

        XCTAssertEqual(
            model.scheduleSettledReconciliation(for: window),
            .scheduled(generation: 1)
        )
        await scheduler.runNext()
        XCTAssertFalse(model.settledReconciliationPending)

        XCTAssertEqual(
            model.scheduleSettledReconciliation(for: window),
            .alreadyCompleted(generation: 1)
        )
        XCTAssertFalse(model.settledReconciliationPending)
        XCTAssertTrue(model.hasMatchingSettledProjection)
        XCTAssertTrue(settledDetailsAreAvailable(for: model))
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "GMT") ?? .gmt
        return calendar
    }

    private var locale: Locale {
        Locale(identifier: "en_GB")
    }

    private func makeModel(
        container: ModelContainer,
        scheduler: ManualHistorySettlementScheduler,
        source: any HistorySettledProjectionSource
    ) -> HistoryPresentationModel {
        HistoryPresentationModel(
            modelContext: container.mainContext,
            clock: FixedAppClock(now: now),
            calendar: calendar,
            locale: locale,
            timeZone: calendar.timeZone,
            settlementScheduler: scheduler,
            settledProjectionSource: source
        )
    }

    private func makeWindow(offset: Int, fractionalStart: Double) -> TemporalRibbonWindow {
        let selectedDay = calendar.startOfDay(for: now)
            .addingTimeInterval(TimeInterval(offset * 86400))
        let selectedDayInterval = DateInterval(start: selectedDay, duration: 86400)
        let intervalStart = selectedDay.addingTimeInterval(-3600)
            .addingTimeInterval(fractionalStart * 60)
        return TemporalRibbonWindow(
            selectedDay: selectedDay,
            selectedDayInterval: selectedDayInterval,
            interval: DateInterval(start: intervalStart, duration: 90000),
            midnightMarkers: [selectedDay]
        )
    }

    private func settledDetailsAreAvailable(for model: HistoryPresentationModel) -> Bool {
        HistoryView.settledHistoryDetailsAreAvailable(
            movementPhase: .settled,
            isDateRailMoving: false,
            isReconciliationPending: model.settledReconciliationPending,
            hasMatchingProjection: model.hasMatchingSettledProjection
        )
    }
}
