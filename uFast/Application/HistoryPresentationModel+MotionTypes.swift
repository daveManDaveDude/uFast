import Foundation

struct HistoryMotionExtensionRequest {
    let edge: HistoryMotionEdge
    let coverage: HistoryMotionCoverage
    let chunkCoverage: HistoryMotionCoverage
    let generation: Int
    let calendar: Calendar
    let expectedCoverage: HistoryMotionCoverage
    let existingChunks: [HistoryMotionChunk]
    let referenceNow: Date
    let isRetry: Bool
}

struct HistoryMotionExtensionApplication {
    let chunk: HistoryMotionChunk
    let edge: HistoryMotionEdge
    let coverage: HistoryMotionCoverage
    let generation: Int
    let calendar: Calendar
    let expectedCoverage: HistoryMotionCoverage
    let presentation: HistoryMotionPresentation
}

struct HistoryMotionRefreshApplication {
    let refreshed: [HistoryMotionChunk]
    let revision: Int
    let generation: Int
    let oldCoverage: HistoryMotionCoverage
    let oldChunks: [HistoryMotionChunk]
    let expectedCalendar: Calendar
    let presentation: HistoryMotionPresentation
    let wasInitial: Bool
}
