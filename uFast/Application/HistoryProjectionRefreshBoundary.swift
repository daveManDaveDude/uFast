import Foundation
import SwiftData

@MainActor
protocol HistoryProjectionDataSource {
    func fetchSettled(window: DateInterval) throws -> HistoryDataSlice
    func fetchMotion(window: DateInterval, calendar: Calendar) throws -> HistoryDataSlice
}

@MainActor
final class SwiftDataHistoryProjectionDataSource: HistoryProjectionDataSource {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSettled(window: DateInterval) throws -> HistoryDataSlice {
        try SwiftDataHistoryDataProvider(modelContext: modelContext).fetch(window: window)
    }

    func fetchMotion(window: DateInterval, calendar: Calendar) throws -> HistoryDataSlice {
        try SwiftDataHistoryMotionDataProvider(modelContext: modelContext)
            .fetch(window: window, calendar: calendar)
    }
}

/// Settled and motion projections are replaced together after a committed
/// mutation. A failed source query leaves the prior complete pair untouched.
@MainActor
struct HistoryProjectionState: Equatable {
    var data: HistoryDataSlice?
    var presentation: HistoryPresentationSnapshot?
    var motionSnapshot: HistoryMotionSnapshot?
    var motionChunks: [HistoryMotionChunk]
    var generation: Int
}

struct HistoryProjectionRefreshRequest {
    let window: DateInterval
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
    let referenceNow: Date
    let nextGeneration: Int
}

@MainActor
enum HistoryProjectionRefreshBoundary {
    @discardableResult
    static func refresh(
        state: inout HistoryProjectionState,
        source: any HistoryProjectionDataSource,
        request: HistoryProjectionRefreshRequest
    ) -> Bool {
        do {
            let data = try source.fetchSettled(window: request.window)
            let presentation = HistoryPresentationBuilder.build(
                data: data, locale: request.locale, calendar: request.calendar,
                timeZone: request.timeZone, referenceNow: request.referenceNow
            )
            var refreshedChunks: [HistoryMotionChunk] = []
            var refreshedSnapshot: HistoryMotionSnapshot?
            if let currentMotionSnapshot = state.motionSnapshot {
                guard !state.motionChunks.isEmpty,
                      let mergedWindow = currentMotionSnapshot.coverage.visualWindow(calendar: request.calendar)
                else { throw HistoryMotionChunkError.invalidCoverage }
                refreshedChunks = try state.motionChunks.map { chunk in
                    guard let chunkWindow = chunk.coverage.visualWindow(calendar: request.calendar) else {
                        throw HistoryMotionChunkError.invalidCoverage
                    }
                    let motionData = try source.fetchMotion(window: chunkWindow, calendar: request.calendar)
                    let exact = HistoryPresentationBuilder.build(
                        data: motionData,
                        locale: request.calendar.locale ?? Locale(identifier: "en_GB"),
                        calendar: request.calendar,
                        timeZone: request.calendar.timeZone,
                        referenceNow: request.referenceNow
                    )
                    return HistoryMotionChunk(
                        coverage: chunk.coverage,
                        presentation: HistoryMotionPresentation(
                            exact, inferredContext: HistoryMotionInferredContext(data: motionData)
                        )
                    )
                }
                guard let merged = SwiftDataHistoryDataProvider.mergeMotionChunks(
                    refreshedChunks, window: mergedWindow
                ) else { throw HistoryMotionChunkError.invalidCoverage }
                refreshedSnapshot = HistoryMotionSnapshot(
                    coverage: currentMotionSnapshot.coverage, calendar: request.calendar,
                    generation: request.nextGeneration, presentation: merged,
                    isInitial: currentMotionSnapshot.isInitial,
                    precedingState: .idle, followingState: .idle
                )
            }
            state = HistoryProjectionState(
                data: data, presentation: presentation,
                motionSnapshot: refreshedSnapshot, motionChunks: refreshedChunks,
                generation: request.nextGeneration
            )
            return true
        } catch {
            return false
        }
    }
}
