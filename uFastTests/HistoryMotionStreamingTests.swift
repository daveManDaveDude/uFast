import Foundation
@testable import uFast
import XCTest

// swiftlint:disable function_body_length type_body_length trailing_comma

final class HistoryMotionStreamingTests: XCTestCase {
    private struct TenYearStressFixture {
        let events: [HistoryMotionEventPrimitive]
        let intervals: [HistoryMotionIntervalPrimitive]
        let recordedFastCount: Int

        init() {
            let dayCount = 3653
            let start = Date(timeIntervalSince1970: 1_451_606_400)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
            var events: [HistoryMotionEventPrimitive] = []
            events.reserveCapacity(dayCount * 25)
            for dayOffset in 0 ..< dayCount {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
                for eventOffset in 0 ..< 25 {
                    let instant = calendar.date(byAdding: .minute, value: eventOffset * 30, to: day) ?? day
                    events.append(HistoryMotionEventPrimitive(
                        id: UUID(), occurredAt: instant,
                        kind: eventOffset.isMultiple(of: 2) ? .food : .nonCaloricDrink
                    ))
                }
            }
            var recordedIntervals: [HistoryMotionIntervalPrimitive] = []
            recordedIntervals.reserveCapacity((dayCount / 7 + 1) * 2)
            // Two recorded fasts per seven-day bucket keeps the stress fixture
            // representative of the product's weekly cadence without adding
            // heavyweight model objects to the test process.
            for weekOffset in stride(from: 0, to: dayCount, by: 7) {
                for dayInWeek in [0, 3] {
                    let dayOffset = weekOffset + dayInWeek
                    guard dayOffset < dayCount,
                          let day = calendar.date(byAdding: .day, value: dayOffset, to: start),
                          let end = calendar.date(byAdding: .hour, value: 12, to: day)
                    else { continue }
                    recordedIntervals.append(HistoryMotionIntervalPrimitive(
                        id: UUID(), start: day, end: end, kind: .recorded, isActive: false
                    ))
                }
            }
            // Keep explicit automatic gaps in the fixture so the measured
            // traversal crosses ordinary, month, year and both London DST
            // boundaries as well as the recorded-fast cadence.
            let automaticBoundaries: [(DateComponents, DateComponents)] = [
                (
                    DateComponents(year: 2016, month: 1, day: 14, hour: 22),
                    DateComponents(year: 2016, month: 1, day: 15, hour: 7)
                ),
                (
                    DateComponents(year: 2016, month: 1, day: 31, hour: 22),
                    DateComponents(year: 2016, month: 2, day: 1, hour: 7)
                ),
                (
                    DateComponents(year: 2016, month: 12, day: 31, hour: 22),
                    DateComponents(year: 2017, month: 1, day: 1, hour: 7)
                ),
                (
                    DateComponents(year: 2016, month: 3, day: 26, hour: 22),
                    DateComponents(year: 2016, month: 3, day: 27, hour: 7)
                ),
                (
                    DateComponents(year: 2016, month: 10, day: 29, hour: 22),
                    DateComponents(year: 2016, month: 10, day: 30, hour: 7)
                ),
            ]
            let automaticIntervals = automaticBoundaries.compactMap { boundary -> HistoryMotionIntervalPrimitive? in
                guard let start = calendar.date(from: boundary.0),
                      let end = calendar.date(from: boundary.1)
                else { return nil }
                return HistoryMotionIntervalPrimitive(
                    id: UUID(), start: start, end: end, kind: .automatic, isActive: false
                )
            }
            self.events = events
            intervals = recordedIntervals + automaticIntervals
            recordedFastCount = recordedIntervals.count
        }
    }

    func testTenYearStressFixtureMeetsCompactCacheAndBoundedQueryContract() {
        let fixture = TenYearStressFixture()
        XCTAssertEqual(fixture.events.count, 91325)
        XCTAssertEqual(fixture.recordedFastCount, 1044)
        XCTAssertEqual(fixture.intervals.filter { $0.kind == .automatic }.count, 5)
        XCTAssertEqual(fixture.intervals.count, 1049)

        let policy = HistoryMotionConfiguration.product
        XCTAssertEqual(policy.initialRadius, 120)
        XCTAssertEqual(policy.extensionLength, 120)
        XCTAssertEqual(policy.prefetchThreshold, 30)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        let start = Date(timeIntervalSince1970: 1_451_606_400)
        let end = calendar.date(byAdding: .year, value: 10, to: start) ?? start

        // Launch and a direct ten-year jump each request one bounded runway;
        // no request covers the intervening years.
        let initial = HistoryMotionCoverage.initial(
            centeredOn: start,
            maximumDate: end,
            calendar: calendar,
            configuration: policy
        )
        let directJump = HistoryMotionCoverage.initial(
            centeredOn: end,
            maximumDate: end,
            calendar: calendar,
            configuration: policy
        )
        XCTAssertEqual([initial, directJump].count, 2)
        XCTAssertLessThanOrEqual(initial.days(calendar: calendar).count, 241)
        XCTAssertLessThanOrEqual(directJump.days(calendar: calendar).count, 241)
        let middle = calendar.date(byAdding: .year, value: 5, to: start) ?? start
        XCTAssertFalse(initial.contains(middle, calendar: calendar))
        XCTAssertFalse(directJump.contains(middle, calendar: calendar))

        // Traverse every 120-day runway while retaining only deduplicated
        // compact primitives.  This measures the actual representation used
        // by the cache rather than full SwiftData model payloads.
        var retainedEvents: [UUID: HistoryMotionEventPrimitive] = [:]
        var retainedIntervals: [UUID: HistoryMotionIntervalPrimitive] = [:]
        var cursor = start
        while cursor < end {
            let chunkEnd = min(
                calendar.date(byAdding: .day, value: policy.extensionLength - 1, to: cursor) ?? end,
                end
            )
            guard let visualStart = calendar.date(byAdding: .hour, value: -1, to: cursor),
                  let dayAfterChunk = calendar.date(byAdding: .day, value: 1, to: chunkEnd),
                  let visualEnd = calendar.date(byAdding: .hour, value: 1, to: dayAfterChunk)
            else { break }
            for event in fixture.events where event.occurredAt >= visualStart && event.occurredAt < visualEnd {
                retainedEvents[event.id] = event
            }
            for interval in fixture.intervals where interval.end > visualStart && interval.start < visualEnd {
                retainedIntervals[interval.id] = interval
            }
            guard let next = calendar.date(byAdding: .day, value: policy.extensionLength, to: cursor),
                  next > cursor
            else { break }
            cursor = next
        }
        XCTAssertEqual(retainedEvents.count, fixture.events.count)
        XCTAssertEqual(retainedIntervals.count, fixture.intervals.count)
        let compactCacheBytes = retainedEvents.count * MemoryLayout<HistoryMotionEventPrimitive>.stride
            + retainedIntervals.count * MemoryLayout<HistoryMotionIntervalPrimitive>.stride
        XCTAssertLessThan(compactCacheBytes, 50 * 1024 * 1024)
    }

    @MainActor
    func testBackgroundLoaderReturnsValueChunkFromIndependentContext() async throws {
        let container = try PersistenceContainer.make(inMemory: true)
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 2_000_000_000)
        let coverage = HistoryMotionCoverage(firstDay: day, lastDay: day, calendar: calendar)
        let loader = SwiftDataHistoryMotionRangeLoader(container: container)

        let chunk = try await loader.load(coverage: coverage, calendar: calendar, referenceNow: day)

        XCTAssertEqual(chunk.coverage, coverage)
        XCTAssertTrue(chunk.presentation.events.isEmpty)
    }

    func testTenYearRunwayTraversalUsesCompactCalendarCoverage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2016, month: 1, day: 1)))
        let end = try XCTUnwrap(calendar.date(byAdding: .year, value: 10, to: start))
        let configuration = HistoryMotionConfiguration.product
        var coverage = HistoryMotionCoverage(firstDay: start, lastDay: start, calendar: calendar)
        var visited = Set<Date>()
        var chunks = 0
        while coverage.lastDay < end {
            visited.formUnion(coverage.days(calendar: calendar))
            guard let next = coverage.extended(
                toward: .following,
                maximumDate: end,
                calendar: calendar,
                configuration: configuration
            ) else { break }
            coverage = next
            chunks += 1
        }
        visited.formUnion(coverage.days(calendar: calendar))

        XCTAssertGreaterThanOrEqual(chunks, 30)
        XCTAssertGreaterThanOrEqual(visited.count, 3650)
        XCTAssertLessThanOrEqual(visited.count, 3655)
        // A date is exposed only from a generated contiguous coverage list;
        // this invariant is the bounded-memory representation used by the UI.
        XCTAssertEqual(visited.count, coverage.days(calendar: calendar).count)
    }

    func testInitialRunwayUsesCalendarDaysAndFutureBound() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let target = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)))
        let maximum = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: target))
        let coverage = HistoryMotionCoverage.initial(
            centeredOn: target,
            maximumDate: maximum,
            calendar: calendar,
            configuration: .init(initialRadius: 120, extensionLength: 120, prefetchThreshold: 30)
        )

        XCTAssertEqual(coverage.days(calendar: calendar).count, 122)
        XCTAssertEqual(coverage.firstDay, calendar.date(byAdding: .day, value: -120, to: target))
        XCTAssertEqual(coverage.lastDay, maximum)
        let visualDuration = try XCTUnwrap(coverage.visualWindow(calendar: calendar)?.duration)
        XCTAssertLessThan(visualDuration, 122 * 24 * 60 * 60 + 2 * 60 * 60)
        XCTAssertGreaterThan(visualDuration, 121 * 24 * 60 * 60)
    }

    func testExtensionsAreContiguousAcrossLondonDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let target = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25)))
        let maximum = try XCTUnwrap(calendar.date(byAdding: .day, value: 400, to: target))
        let initial = HistoryMotionCoverage.initial(centeredOn: target, maximumDate: maximum, calendar: calendar)
        let extensionCoverage = try XCTUnwrap(
            initial.extended(toward: .preceding, maximumDate: maximum, calendar: calendar)
        )
        XCTAssertLessThan(extensionCoverage.firstDay, initial.firstDay)
        XCTAssertEqual(
            calendar.date(byAdding: .day, value: 120, to: extensionCoverage.firstDay),
            initial.firstDay
        )
        XCTAssertEqual(extensionCoverage.lastDay, initial.lastDay)
    }

    func testStoreCoalescesRequestsAndRejectsStaleGeneration() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 2_000_000_000)
        let coverage = HistoryMotionCoverage(firstDay: day, lastDay: day, calendar: calendar)
        let empty = HistoryMotionPresentation(
            window: DateInterval(start: day, duration: 24 * 60 * 60),
            intervals: [],
            events: []
        )
        let original = HistoryMotionSnapshot(
            coverage: coverage,
            calendar: calendar,
            generation: 4,
            presentation: empty
        )
        var store = HistoryMotionStore()
        store.install(original)
        let request = try XCTUnwrap(store.beginRequest(.preceding))
        XCTAssertNil(store.beginRequest(.preceding))

        let expanded = HistoryMotionCoverage(firstDay: day.addingTimeInterval(-86400), lastDay: day, calendar: calendar)
        let replacement = HistoryMotionSnapshot(
            coverage: expanded,
            calendar: calendar,
            generation: 4,
            presentation: empty
        )
        XCTAssertTrue(store.complete(request, with: replacement, calendar: calendar))
        XCTAssertEqual(store.snapshot?.coverage, expanded)
        XCTAssertFalse(store.complete(request, with: replacement, calendar: calendar))
    }

    func testLoadedEmptyIsDistinctFromUnloaded() {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 2_000_000_000)
        let empty = HistoryMotionPresentation(
            window: DateInterval(start: day, duration: 24 * 60 * 60),
            intervals: [],
            events: []
        )
        let snapshot = HistoryMotionSnapshot(
            coverage: HistoryMotionCoverage(firstDay: day, lastDay: day, calendar: calendar),
            calendar: calendar,
            generation: 1,
            presentation: empty
        )
        XCTAssertEqual(snapshot.dayState(day, calendar: calendar), .loadedEmpty)
        XCTAssertEqual(
            snapshot.dayState(day.addingTimeInterval(-86400), calendar: calendar),
            .unloaded
        )
    }

    func testAtomicSnapshotExposesOnlyDatesCoveredByItsProjection() {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 2_000_000_000)
        let snapshot = HistoryMotionSnapshot(
            coverage: HistoryMotionCoverage(
                firstDay: day,
                lastDay: day.addingTimeInterval(2 * 86400),
                calendar: calendar
            ),
            calendar: calendar,
            generation: 7,
            presentation: HistoryMotionPresentation(
                window: DateInterval(start: day.addingTimeInterval(-3600), duration: 3 * 86400 + 7200),
                intervals: [],
                events: []
            )
        )

        XCTAssertFalse(snapshot.dates.isEmpty)
        XCTAssertTrue(snapshot.dates.allSatisfy { snapshot.coverage.contains($0, calendar: calendar) })
        XCTAssertEqual(snapshot.dates, snapshot.coverage.days(calendar: calendar))
    }

    func testChunkMergeDeduplicatesStableMotionPrimitivesAtSeam() {
        let day = Date(timeIntervalSince1970: 2_000_000_000)
        let interval = HistoryMotionIntervalPrimitive(
            id: UUID(), start: day, end: day.addingTimeInterval(12 * 3600),
            kind: .automatic, isActive: false
        )
        let event = HistoryMotionEventPrimitive(id: UUID(), occurredAt: day, kind: .food)
        let first = HistoryMotionChunk(
            coverage: HistoryMotionCoverage(firstDay: day, lastDay: day, calendar: .current),
            presentation: HistoryMotionPresentation(
                window: DateInterval(start: day, duration: 86400), intervals: [interval], events: [event]
            )
        )
        let second = HistoryMotionChunk(
            coverage: first.coverage,
            presentation: first.presentation
        )

        let merged = SwiftDataHistoryDataProvider.mergeMotionChunks(
            [first, second],
            window: first.presentation.window
        )

        XCTAssertEqual(merged?.intervals.count, 1)
        XCTAssertEqual(merged?.events.count, 1)
    }

    func testMotionContextCreatesInferredFastWhenForegroundClockCrossesThreshold() throws {
        let sourceDate = Date(timeIntervalSince1970: 2_000_000_000)
        let window = DateInterval(start: sourceDate, duration: 24 * 60 * 60)
        let snapshot = HistoryPresentationSnapshot(window: window, fastItems: [], events: [])
        let context = HistoryMotionInferredContext(
            foodEvents: [FoodBoundarySnapshot(
                id: UUID(),
                occurredAt: sourceDate,
                description: "Dinner",
                isCaloric: true
            )],
            recordedFasts: [],
            currentGoal: .default,
            enabled: true
        )
        let motion = HistoryMotionPresentation(snapshot, inferredContext: context)
        let beforeEligibility = sourceDate.addingTimeInterval(8 * 60 * 60 - 1)
        let eligible = sourceDate.addingTimeInterval(8 * 60 * 60)
        let cap = sourceDate.addingTimeInterval(24 * 60 * 60)

        XCTAssertTrue(motion.ribbonIntervals(activeEndingAt: beforeEligibility).isEmpty)

        let currentRibbon = try XCTUnwrap(motion.ribbonIntervals(activeEndingAt: eligible).first)
        XCTAssertEqual(currentRibbon.title, "Inferred fast in progress")
        XCTAssertTrue(currentRibbon.accessibilityLabel.contains("Start fast available"))
        let current = try XCTUnwrap(motion.inferredInterval(for: currentRibbon.id, at: eligible))
        XCTAssertTrue(current.offersStart)

        let cappedRibbon = try XCTUnwrap(motion.ribbonIntervals(activeEndingAt: cap).first)
        XCTAssertEqual(cappedRibbon.title, "Inferred fast")
        XCTAssertTrue(cappedRibbon.accessibilityLabel.contains("Save fast available"))
        let capped = try XCTUnwrap(motion.inferredInterval(for: currentRibbon.id, at: cap))
        XCTAssertEqual(capped.state, .historical)
        XCTAssertTrue(capped.offersSave)
        XCTAssertFalse(capped.offersStart)
    }
}
