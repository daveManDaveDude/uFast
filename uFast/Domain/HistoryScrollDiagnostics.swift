import Foundation

// swiftlint:disable file_length trailing_comma

/// The opt-in boundary for BF-106 diagnostics.  The second launch argument is
/// deliberately required so ordinary UI tests and every production launch stay
/// on the no-op path.
struct HistoryScrollDiagnosticConfiguration: Equatable, Sendable {
    static let diagnosticArgument = "--ui-testing-history-scroll-diagnostics"
    static let maxEventsArgument = "--bf106-max-events"
    static let defaultMaxEvents = 512
    static let maximumEventCapacity = 16384

    let isEnabled: Bool
    let maxEvents: Int

    init(arguments: [String], maxEvents: Int = Self.defaultMaxEvents) {
        isEnabled = arguments.contains("--ui-testing")
            && arguments.contains(Self.diagnosticArgument)
        let requestedMaxEvents = if isEnabled {
            Self.integer(after: Self.maxEventsArgument, in: arguments) ?? maxEvents
        } else {
            maxEvents
        }
        self.maxEvents = min(max(requestedMaxEvents, 1), Self.maximumEventCapacity)
    }

    var usesPeriodicWork: Bool {
        false
    }

    var keepsBF105VerboseProbesDisabled: Bool {
        isEnabled
    }

    private static func integer(after option: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: option), arguments.indices.contains(index + 1) else {
            return nil
        }
        return Int(arguments[index + 1])
    }
}

enum HistoryScrollDiagnosticNativePhase: Equatable, Sendable {
    case tracking
    case decelerating
    case idle
}

enum HistoryScrollDiagnosticPhase: String, CaseIterable, Equatable, Sendable {
    case outsideWindow
    case nativeDecelerationTail
    case idleBoundary
    case postIdle
}

enum HistoryScrollDiagnosticWork: String, CaseIterable, Hashable, Sendable {
    case fractionalMotion
    case followerUpdate
    case coarseInputGeneration
    case chipWindowPreparation
    case labelInputs
    case labelMetrics
    case labelProjection
    case pageEventPreparation
    case pageLanePreparation
    case runwayPublication
    case exactWindowFetch
    case exactWindowProjection
    case settlementReconciliation
}

enum HistoryScrollDiagnosticReason: String, Equatable, Sendable {
    case emptyCapture
    case nativeIdleNotObserved
    case nativeDecelerationNotObserved
    case nativePhaseOrderInvalid
    case postIdleObservationIncomplete
    case invalidCaptureEnd
}

enum HistoryScrollDiagnosticOutcome: Equatable, Sendable {
    case disabled
    case captured
    case inconclusive(HistoryScrollDiagnosticReason)
}

enum HistoryScrollDiagnosticEventKind: Equatable, Sendable {
    case nativePhase(HistoryScrollDiagnosticNativePhase)
    case geometry(offset: Double)
    case work(HistoryScrollDiagnosticWork)
    case workEnd(HistoryScrollDiagnosticWork)
    case coarseInputGeneration(Int)
}

struct HistoryScrollDiagnosticEvent: Equatable, Sendable {
    let sequence: Int
    let timestamp: TimeInterval
    let kind: HistoryScrollDiagnosticEventKind
}

struct HistoryScrollDiagnosticPhaseSegment: Equatable, Sendable {
    let phase: HistoryScrollDiagnosticPhase
    let start: TimeInterval
    let end: TimeInterval
    let isShorterThanRequestedWindow: Bool

    var duration: TimeInterval {
        max(end - start, 0)
    }
}

struct HistoryScrollDiagnosticWorkCount: Equatable, Sendable {
    let total: Int
    let byPhase: [HistoryScrollDiagnosticPhase: Int]
}

struct HistoryScrollDiagnosticReport: Equatable, Sendable {
    static let tailWindow: TimeInterval = 0.5
    static let postIdleWindow: TimeInterval = 0.25

    let outcome: HistoryScrollDiagnosticOutcome
    let events: [HistoryScrollDiagnosticEvent]
    let phases: [HistoryScrollDiagnosticPhaseSegment]
    let workCounts: [HistoryScrollDiagnosticWork: HistoryScrollDiagnosticWorkCount]
    let nativeMotionStartAt: TimeInterval?
    let nativeDecelerationStartAt: TimeInterval?
    let nativeIdleAt: TimeInterval?
    let captureEndAt: TimeInterval?
    let captureStartUptime: TimeInterval?
    let captureStartWallClockEpoch: TimeInterval?
    let captureEndWallClockEpoch: TimeInterval?
    let decelerationDuration: TimeInterval?
    let geometryCallbackCount: Int
    let coarseInputDeliveryCount: Int
    let distinctCoarseInputGenerationCount: Int
    let nativeIdleCount: Int
    let droppedEventCount: Int

    var retainedEventCount: Int {
        events.count
    }

    func phase(for timestamp: TimeInterval) -> HistoryScrollDiagnosticPhase {
        guard let nativeDecelerationStartAt,
              let nativeIdleAt,
              timestamp.isFinite
        else {
            return .outsideWindow
        }
        let tailStart = max(
            nativeDecelerationStartAt,
            nativeIdleAt - Self.tailWindow
        )
        guard timestamp >= tailStart else { return .outsideWindow }
        if timestamp < nativeIdleAt {
            return .nativeDecelerationTail
        }
        if timestamp == nativeIdleAt {
            return .idleBoundary
        }
        guard let captureEndAt,
              timestamp <= min(nativeIdleAt + Self.postIdleWindow, captureEndAt)
        else {
            return .outsideWindow
        }
        return .postIdle
    }

    /// Formatting is intentionally performed only when a finished capture is
    /// requested by a diagnostic consumer, never while an event is appended.
    var snapshot: String {
        let phaseSummary = phases.map {
            "\($0.phase.rawValue):\(format($0.duration))"
        }.joined(separator: ",")
        let workSummary = HistoryScrollDiagnosticWork.allCases.map { work in
            let count = workCounts[work]?.total ?? 0
            return "\(work.rawValue)=\(count)"
        }.joined(separator: ",")
        return [
            "outcome=\(outcome.description)",
            "deceleration=\(format(decelerationDuration ?? 0))",
            "phases=\(phaseSummary)",
            "work=\(workSummary)",
            "geometryCallbacks=\(geometryCallbackCount)",
            "coarseGenerations=\(distinctCoarseInputGenerationCount)",
            "retained=\(retainedEventCount)",
            "dropped=\(droppedEventCount)",
        ].joined(separator: ";")
    }

    private func format(_ value: TimeInterval) -> String {
        String(format: "%.3f", value)
    }
}

private extension HistoryScrollDiagnosticOutcome {
    var description: String {
        switch self {
        case .disabled:
            "disabled"
        case .captured:
            "captured"
        case let .inconclusive(reason):
            "inconclusive.\(reason.rawValue)"
        }
    }
}

/// A bounded raw event capture.  Aggregate work totals survive ring-buffer
/// truncation, while phase attribution is explicitly limited to retained raw
/// events and reports the dropped count alongside it.
private struct HistoryScrollDiagnosticRetainedSummary {
    let workCounts: [HistoryScrollDiagnosticWork: HistoryScrollDiagnosticWorkCount]
    let geometryCallbackCount: Int
    let coarseInputDeliveryCount: Int
    let nativeIdleCount: Int
}

struct HistoryScrollDiagnosticCapture: Equatable, Sendable {
    let configuration: HistoryScrollDiagnosticConfiguration

    private var slots: [HistoryScrollDiagnosticEvent?]
    private var writeIndex = 0
    private var retainedCount = 0
    /// Materialized only by an explicit reader/endCapture, never on append.
    var events: [HistoryScrollDiagnosticEvent] {
        let start = retainedCount == slots.count ? writeIndex : 0
        return (0 ..< retainedCount).compactMap { slots[(start + $0) % slots.count] }
    }

    private(set) var droppedEventCount = 0
    private(set) var nativeMotionStartAt: TimeInterval?
    private(set) var nativeDecelerationStartAt: TimeInterval?
    private(set) var nativeIdleAt: TimeInterval?
    private(set) var captureEndAt: TimeInterval?
    private(set) var captureStartUptime: TimeInterval?
    private(set) var captureStartWallClockEpoch: TimeInterval?
    private(set) var captureEndWallClockEpoch: TimeInterval?

    private var nextSequence = 0
    private var totalWorkCounts: [HistoryScrollDiagnosticWork: Int] = [:]
    private var terminalReport: HistoryScrollDiagnosticReport?

    init(configuration: HistoryScrollDiagnosticConfiguration) {
        self.configuration = configuration
        slots = Array(repeating: nil, count: configuration.isEnabled ? configuration.maxEvents : 0)
    }

    var isFinished: Bool {
        terminalReport != nil
    }

    mutating func recordNativePhase(
        _ phase: HistoryScrollDiagnosticNativePhase,
        at timestamp: TimeInterval
    ) {
        guard canRecord(timestamp) else { return }
        switch phase {
        case .tracking:
            if nativeMotionStartAt == nil {
                nativeMotionStartAt = timestamp
            }
        case .decelerating:
            if nativeDecelerationStartAt == nil {
                nativeDecelerationStartAt = timestamp
            }
        case .idle:
            if nativeIdleAt == nil {
                nativeIdleAt = timestamp
            }
        }
        append(.nativePhase(phase), at: timestamp)
    }

    mutating func recordGeometry(offset: Double, at timestamp: TimeInterval) {
        guard offset.isFinite else { return }
        append(.geometry(offset: offset), at: timestamp)
    }

    mutating func recordCoarseInputGeneration(_ generation: Int, at timestamp: TimeInterval) {
        guard canRecord(timestamp) else { return }
        append(.coarseInputGeneration(generation), at: timestamp)
        totalWorkCounts[.coarseInputGeneration, default: 0] += 1
    }

    mutating func recordWork(_ work: HistoryScrollDiagnosticWork, at timestamp: TimeInterval) {
        guard canRecord(timestamp) else { return }
        totalWorkCounts[work, default: 0] += 1
        append(.work(work), at: timestamp)
    }

    @discardableResult
    mutating func endCapture(
        at timestamp: TimeInterval,
        wallClockEpoch: TimeInterval? = nil
    ) -> HistoryScrollDiagnosticReport {
        if let terminalReport {
            return terminalReport
        }
        if configuration.isEnabled {
            captureEndAt = timestamp
            if let wallClockEpoch, wallClockEpoch.isFinite {
                captureEndWallClockEpoch = wallClockEpoch
            }
        }
        let report = makeReport()
        terminalReport = report
        return report
    }

    mutating func recordWorkEnd(_ work: HistoryScrollDiagnosticWork, at timestamp: TimeInterval) {
        append(.workEnd(work), at: timestamp)
    }

    var report: HistoryScrollDiagnosticReport? {
        terminalReport
    }

    private func canRecord(_ timestamp: TimeInterval) -> Bool {
        configuration.isEnabled
            && terminalReport == nil
            && timestamp.isFinite
    }

    private mutating func append(
        _ kind: HistoryScrollDiagnosticEventKind,
        at timestamp: TimeInterval
    ) {
        guard canRecord(timestamp) else { return }
        nextSequence += 1
        if retainedCount == slots.count {
            droppedEventCount += 1
        } else {
            retainedCount += 1
        }
        slots[writeIndex] = HistoryScrollDiagnosticEvent(
            sequence: nextSequence,
            timestamp: timestamp,
            kind: kind
        )
        writeIndex = (writeIndex + 1) % slots.count
    }

    private func makeReport() -> HistoryScrollDiagnosticReport {
        guard configuration.isEnabled else {
            return disabledReport()
        }

        let summary = retainedSummary()
        let duration = validDecelerationDuration
        return HistoryScrollDiagnosticReport(
            outcome: captureOutcome,
            events: events,
            phases: phaseSegments(),
            workCounts: summary.workCounts,
            nativeMotionStartAt: nativeMotionStartAt,
            nativeDecelerationStartAt: nativeDecelerationStartAt,
            nativeIdleAt: nativeIdleAt,
            captureEndAt: captureEndAt,
            captureStartUptime: captureStartUptime,
            captureStartWallClockEpoch: captureStartWallClockEpoch,
            captureEndWallClockEpoch: captureEndWallClockEpoch,
            decelerationDuration: duration,
            geometryCallbackCount: summary.geometryCallbackCount,
            coarseInputDeliveryCount: summary.coarseInputDeliveryCount,
            distinctCoarseInputGenerationCount: Set(events.compactMap { event -> Int? in
                if case let .coarseInputGeneration(generation) = event.kind {
                    return generation
                }
                return nil
            }).count,
            nativeIdleCount: summary.nativeIdleCount,
            droppedEventCount: droppedEventCount
        )
    }

    private var validDecelerationDuration: TimeInterval? {
        guard let nativeDecelerationStartAt,
              let nativeIdleAt,
              nativeDecelerationStartAt < nativeIdleAt
        else {
            return nil
        }
        return nativeIdleAt - nativeDecelerationStartAt
    }

    private var captureOutcome: HistoryScrollDiagnosticOutcome {
        if events.isEmpty {
            return .inconclusive(.emptyCapture)
        }
        if nativeIdleAt == nil {
            return .inconclusive(.nativeIdleNotObserved)
        }
        if nativeDecelerationStartAt == nil {
            return .inconclusive(.nativeDecelerationNotObserved)
        }
        guard let nativeDecelerationStartAt,
              let nativeIdleAt,
              nativeDecelerationStartAt < nativeIdleAt
        else {
            return .inconclusive(.nativePhaseOrderInvalid)
        }
        guard let captureEndAt, captureEndAt.isFinite, captureEndAt >= nativeIdleAt else {
            return .inconclusive(.invalidCaptureEnd)
        }
        guard captureEndAt - nativeIdleAt >= HistoryScrollDiagnosticReport.postIdleWindow else {
            return .inconclusive(.postIdleObservationIncomplete)
        }
        return .captured
    }

    private func disabledReport() -> HistoryScrollDiagnosticReport {
        HistoryScrollDiagnosticReport(
            outcome: .disabled,
            events: [],
            phases: [],
            workCounts: [:],
            nativeMotionStartAt: nil,
            nativeDecelerationStartAt: nil,
            nativeIdleAt: nil,
            captureEndAt: nil,
            captureStartUptime: nil,
            captureStartWallClockEpoch: nil,
            captureEndWallClockEpoch: nil,
            decelerationDuration: nil,
            geometryCallbackCount: 0,
            coarseInputDeliveryCount: 0,
            distinctCoarseInputGenerationCount: 0,
            nativeIdleCount: 0,
            droppedEventCount: 0
        )
    }

    private func retainedSummary() -> HistoryScrollDiagnosticRetainedSummary {
        var retainedCounts: [HistoryScrollDiagnosticWork: [HistoryScrollDiagnosticPhase: Int]] = [:]
        var geometryCallbackCount = 0
        var coarseInputDeliveryCount = 0
        var nativeIdleCount = 0
        for event in events {
            let eventPhase = phase(for: event.timestamp)
            switch event.kind {
            case .workEnd:
                break
            case .geometry:
                geometryCallbackCount += 1
            case .coarseInputGeneration:
                coarseInputDeliveryCount += 1
                retainedCounts[.coarseInputGeneration, default: [:]][eventPhase, default: 0] += 1
            case let .work(work):
                retainedCounts[work, default: [:]][eventPhase, default: 0] += 1
            case let .nativePhase(nativePhase):
                if nativePhase == .idle {
                    nativeIdleCount += 1
                }
            }
        }
        let workCounts = Dictionary(uniqueKeysWithValues: HistoryScrollDiagnosticWork.allCases.map { work in
            (
                work,
                HistoryScrollDiagnosticWorkCount(
                    total: totalWorkCounts[work, default: 0],
                    byPhase: retainedCounts[work, default: [:]]
                )
            )
        })
        return HistoryScrollDiagnosticRetainedSummary(
            workCounts: workCounts,
            geometryCallbackCount: geometryCallbackCount,
            coarseInputDeliveryCount: coarseInputDeliveryCount,
            nativeIdleCount: nativeIdleCount
        )
    }

    private func phaseSegments() -> [HistoryScrollDiagnosticPhaseSegment] {
        guard let nativeIdleAt,
              let nativeDecelerationStartAt,
              nativeDecelerationStartAt < nativeIdleAt,
              let captureEndAt,
              captureEndAt.isFinite
        else { return [] }
        let decelerationDuration = nativeIdleAt - nativeDecelerationStartAt
        let tailStart = max(
            nativeDecelerationStartAt,
            nativeIdleAt - HistoryScrollDiagnosticReport.tailWindow
        )
        let postIdleEnd = min(
            captureEndAt,
            nativeIdleAt + HistoryScrollDiagnosticReport.postIdleWindow
        )
        return [
            HistoryScrollDiagnosticPhaseSegment(
                phase: .nativeDecelerationTail,
                start: tailStart,
                end: nativeIdleAt,
                isShorterThanRequestedWindow: decelerationDuration
                    < HistoryScrollDiagnosticReport.tailWindow
            ),
            HistoryScrollDiagnosticPhaseSegment(
                phase: .idleBoundary,
                start: nativeIdleAt,
                end: nativeIdleAt,
                isShorterThanRequestedWindow: false
            ),
            HistoryScrollDiagnosticPhaseSegment(
                phase: .postIdle,
                start: nativeIdleAt,
                end: max(postIdleEnd, nativeIdleAt),
                isShorterThanRequestedWindow: postIdleEnd - nativeIdleAt
                    < HistoryScrollDiagnosticReport.postIdleWindow
            ),
        ]
    }

    private func phase(for timestamp: TimeInterval) -> HistoryScrollDiagnosticPhase {
        guard let nativeDecelerationStartAt,
              let nativeIdleAt,
              nativeDecelerationStartAt < nativeIdleAt,
              timestamp.isFinite
        else {
            return .outsideWindow
        }
        let tailStart = max(
            nativeDecelerationStartAt,
            nativeIdleAt - HistoryScrollDiagnosticReport.tailWindow
        )
        guard timestamp >= tailStart else { return .outsideWindow }
        if timestamp < nativeIdleAt {
            return .nativeDecelerationTail
        }
        if timestamp == nativeIdleAt {
            return .idleBoundary
        }
        guard let captureEndAt,
              timestamp <= min(
                  nativeIdleAt + HistoryScrollDiagnosticReport.postIdleWindow,
                  captureEndAt
              )
        else {
            return .outsideWindow
        }
        return .postIdle
    }
}

extension HistoryScrollDiagnosticCapture {
    mutating func recordFractionalMotion(at timestamp: TimeInterval) {
        recordWork(.fractionalMotion, at: timestamp)
    }

    mutating func beginCapture(at uptime: TimeInterval, wallClockEpoch: TimeInterval) {
        guard configuration.isEnabled,
              terminalReport == nil,
              captureStartUptime == nil,
              uptime.isFinite,
              wallClockEpoch.isFinite
        else { return }
        captureStartUptime = uptime
        captureStartWallClockEpoch = wallClockEpoch
    }
}

struct HistoryScrollGeometryReplaySample: Equatable, Sendable {
    let timestamp: TimeInterval
    let offset: Double
}

struct HistoryScrollGeometryReplayResult: Equatable, Sendable {
    let samples: [HistoryScrollGeometryReplaySample]
    let maximumStep: Double
    let discontinuityCount: Int
    let hasStrictlyIncreasingTime: Bool
    let representsNativeDeceleration: Bool

    var isSpatiallyContinuous: Bool {
        discontinuityCount == 0 && hasStrictlyIncreasingTime && !samples.isEmpty
    }
}

enum HistoryScrollGeometryReplay {
    static func analyze(
        _ samples: [HistoryScrollGeometryReplaySample],
        maximumAllowedStep: Double = 30
    ) -> HistoryScrollGeometryReplayResult {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        var maximumStep = 0.0
        var discontinuityCount = 0
        var strictlyIncreasing = true
        for pair in zip(ordered, ordered.dropFirst()) {
            let timeDelta = pair.1.timestamp - pair.0.timestamp
            let offsetDelta = abs(pair.1.offset - pair.0.offset)
            strictlyIncreasing = strictlyIncreasing && timeDelta > 0
            maximumStep = max(maximumStep, offsetDelta)
            let isDiscontinuous = !pair.0.timestamp.isFinite
                || !pair.1.timestamp.isFinite
                || !pair.0.offset.isFinite
                || !pair.1.offset.isFinite
                || offsetDelta > maximumAllowedStep
            if isDiscontinuous {
                discontinuityCount += 1
            }
        }
        if ordered.contains(where: { !$0.timestamp.isFinite || !$0.offset.isFinite }) {
            discontinuityCount += 1
        }
        return HistoryScrollGeometryReplayResult(
            samples: ordered,
            maximumStep: maximumStep,
            discontinuityCount: discontinuityCount,
            hasStrictlyIncreasingTime: strictlyIncreasing,
            // A scripted replay never establishes native deceleration.
            representsNativeDeceleration: false
        )
    }
}

struct HistoryScrollSyntheticProtocolFixture: Equatable, Sendable {
    let samples: [HistoryScrollGeometryReplaySample]

    static let gentleRelease = Self(samples: [
        .init(timestamp: 0.00, offset: 0),
        .init(timestamp: 0.016, offset: 18),
        .init(timestamp: 0.032, offset: 34),
        .init(timestamp: 0.048, offset: 48),
        .init(timestamp: 0.064, offset: 59),
        .init(timestamp: 0.080, offset: 67),
    ])
}
