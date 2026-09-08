import Foundation
import os

/// UI adapter for the pure BF-106 capture model.  It is inert unless both the
/// existing UI-test marker and the explicit diagnostic marker are present.
/// The snapshot is an opt-in test surface and never participates in hit
/// testing or product accessibility.
@MainActor
enum HistoryScrollDiagnosticProbe {
    private static let log = OSLog(
        subsystem: "com.davidmcgrath.uFast",
        category: "HistoryScrollDiagnostics"
    )
    private static let configuration = HistoryScrollDiagnosticConfiguration(
        arguments: ProcessInfo.processInfo.arguments
    )
    private static var capture = HistoryScrollDiagnosticCapture(configuration: configuration)
    private static var isCapturing = false
    private static let emitsWorkSignposts = !ProcessInfo.processInfo.arguments.contains("--bf106-no-work-signposts")
    private static var geometry = (offset: 0.0, width: 0.0, contentWidth: 0.0)
    private static var window: DateInterval?
    private static var startGeometry = (offset: 0.0, width: 0.0, contentWidth: 0.0)
    private static var startWindow: DateInterval?

    static func startCapture() {
        guard isEnabled else { return }
        capture = HistoryScrollDiagnosticCapture(configuration: configuration)
        startGeometry = geometry
        startWindow = window
        let startUptime = ProcessInfo.processInfo.systemUptime
        let startWallClockEpoch = Date().timeIntervalSince1970
        capture.beginCapture(at: startUptime, wallClockEpoch: startWallClockEpoch)
        isCapturing = true
        emitBoundarySignpost(
            "capture-start",
            uptime: startUptime,
            wallClockEpoch: startWallClockEpoch
        )
        capture.recordGeometry(offset: geometry.offset, at: startUptime)
    }

    static var isEnabled: Bool {
        configuration.isEnabled
    }

    static func recordNativePhase(_ phase: HistoryScrollDiagnosticNativePhase) {
        guard isEnabled, isCapturing else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        let wallClockEpoch = Date().timeIntervalSince1970
        capture.recordNativePhase(phase, at: uptime)
        emitBoundarySignpost(
            "native-\(nativePhaseName(phase))",
            uptime: uptime,
            wallClockEpoch: wallClockEpoch
        )
    }

    static func recordGeometry(offset: Double, width: Double, contentWidth: Double) {
        guard isEnabled else { return }
        geometry = (offset, width, contentWidth)
        guard isCapturing else { return }
        capture.recordGeometry(offset: offset, at: ProcessInfo.processInfo.systemUptime)
    }

    static func recordWindow(_ interval: DateInterval) {
        guard isEnabled else { return }
        window = interval
    }

    static func recordFractionalMotion() {
        recordWork(.fractionalMotion)
    }

    static func recordCoarseInputGeneration(_ generation: Int) {
        guard isEnabled, isCapturing else { return }
        capture.recordCoarseInputGeneration(
            generation,
            at: ProcessInfo.processInfo.systemUptime
        )
    }

    static func recordWork(_ work: HistoryScrollDiagnosticWork) {
        guard isEnabled, isCapturing else { return }
        capture.recordWork(work, at: ProcessInfo.processInfo.systemUptime)
    }

    static func withWork<T>(
        _ work: HistoryScrollDiagnosticWork,
        _ operation: () throws -> T
    ) rethrows -> T {
        guard isEnabled, isCapturing else { return try operation() }
        recordWork(work)
        let signpostID = OSSignpostID(log: log)
        if emitsWorkSignposts {
            os_signpost(
                .begin,
                log: log,
                name: "BF-106 work",
                signpostID: signpostID,
                "%{public}s",
                work.rawValue
            )
        }
        defer {
            capture.recordWorkEnd(work, at: ProcessInfo.processInfo.systemUptime)
            if emitsWorkSignposts {
                os_signpost(.end, log: log, name: "BF-106 work", signpostID: signpostID)
            }
        }
        return try operation()
    }

    /// Finishing is explicit so a consumer controls the end of the 250 ms
    /// post-idle observation window.  No timer or display-link is installed.
    @discardableResult
    static func finishCapture() -> HistoryScrollDiagnosticReport? {
        guard isEnabled else { return nil }
        let endUptime = ProcessInfo.processInfo.systemUptime
        let endWallClockEpoch = Date().timeIntervalSince1970
        emitBoundarySignpost(
            "capture-end",
            uptime: endUptime,
            wallClockEpoch: endWallClockEpoch
        )
        isCapturing = false
        return capture.endCapture(at: endUptime, wallClockEpoch: endWallClockEpoch)
    }

    private static func emitBoundarySignpost(
        _ name: String,
        uptime: TimeInterval,
        wallClockEpoch: TimeInterval
    ) {
        let signpostID = OSSignpostID(log: log)
        os_signpost(
            .event,
            log: log,
            name: "BF-106 boundary",
            signpostID: signpostID,
            "%{public}s uptime=%{public}.9f wall=%{public}.9f",
            name,
            uptime,
            wallClockEpoch
        )
    }

    private static func nativePhaseName(_ phase: HistoryScrollDiagnosticNativePhase) -> String {
        switch phase {
        case .tracking:
            "tracking"
        case .decelerating:
            "decelerating"
        case .idle:
            "idle"
        }
    }

    static func rawSnapshot() -> String {
        guard !isCapturing, let report = capture.report else { return "capture-active" }
        guard var object = try? JSONSerialization.jsonObject(with: Data(report.rawJSON.utf8)) as? [String: Any]
        else { return "export-error" }
        object["startOffset"] = startGeometry.offset
        object["workSignpostsEnabled"] = emitsWorkSignposts
        object["viewportWidth"] = startGeometry.width
        object["contentWidth"] = startGeometry.contentWidth
        object["startWindowEpoch"] = startWindow.map { [$0.start.timeIntervalSince1970, $0.end.timeIntervalSince1970] }
        object["endWindowEpoch"] = window.map { [$0.start.timeIntervalSince1970, $0.end.timeIntervalSince1970] }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return "export-error" }
        return String(data: data, encoding: .utf8) ?? "export-error"
    }
}
