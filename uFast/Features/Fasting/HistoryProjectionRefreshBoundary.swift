import Foundation
import SwiftData

// swiftlint:disable function_body_length function_parameter_count

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

/// The complete pair that History replaces after a committed invalidation.
/// Keeping this value separate from the SwiftUI state makes the replacement
/// boundary deterministic and ensures a failed refresh leaves the prior pair
/// untouched.
@MainActor
struct HistoryProjectionState: Equatable {
    var data: HistoryDataSlice?
    var presentation: HistoryPresentationSnapshot?
    var motionSnapshot: HistoryMotionSnapshot?
    var motionChunks: [HistoryMotionChunk]
    var generation: Int
}

@MainActor
enum HistoryProjectionRefreshBoundary {
    @discardableResult
    static func refresh(
        state: inout HistoryProjectionState,
        source: any HistoryProjectionDataSource,
        window: DateInterval,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        referenceNow: Date,
        nextGeneration: Int
    ) -> Bool {
        do {
            let data = try source.fetchSettled(window: window)
            let presentation = HistoryPresentationBuilder.build(
                data: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                referenceNow: referenceNow
            )
            var refreshedChunks: [HistoryMotionChunk] = []
            var refreshedSnapshot: HistoryMotionSnapshot?

            if let currentMotionSnapshot = state.motionSnapshot {
                guard !state.motionChunks.isEmpty,
                      let mergedWindow = currentMotionSnapshot.coverage.visualWindow(calendar: calendar)
                else { throw HistoryMotionChunkError.invalidCoverage }

                refreshedChunks = try state.motionChunks.map { chunk in
                    guard let chunkWindow = chunk.coverage.visualWindow(calendar: calendar) else {
                        throw HistoryMotionChunkError.invalidCoverage
                    }
                    let motionData = try source.fetchMotion(
                        window: chunkWindow,
                        calendar: calendar
                    )
                    let exact = HistoryPresentationBuilder.build(
                        data: motionData,
                        locale: calendar.locale ?? Locale(identifier: "en_GB"),
                        calendar: calendar,
                        timeZone: calendar.timeZone,
                        referenceNow: referenceNow
                    )
                    return HistoryMotionChunk(
                        coverage: chunk.coverage,
                        presentation: HistoryMotionPresentation(exact)
                    )
                }
                guard let merged = SwiftDataHistoryDataProvider.mergeMotionChunks(
                    refreshedChunks,
                    window: mergedWindow
                ) else { throw HistoryMotionChunkError.invalidCoverage }
                refreshedSnapshot = HistoryMotionSnapshot(
                    coverage: currentMotionSnapshot.coverage,
                    calendar: calendar,
                    generation: nextGeneration,
                    presentation: merged,
                    isInitial: currentMotionSnapshot.isInitial,
                    precedingState: .idle,
                    followingState: .idle
                )
            }

            // Assign only after settled and motion projections both succeed.
            state = HistoryProjectionState(
                data: data,
                presentation: presentation,
                motionSnapshot: refreshedSnapshot,
                motionChunks: refreshedChunks,
                generation: nextGeneration
            )
            return true
        } catch {
            return false
        }
    }
}
