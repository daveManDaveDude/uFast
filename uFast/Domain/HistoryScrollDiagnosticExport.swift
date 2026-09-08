import Foundation

// swiftlint:disable trailing_comma

extension HistoryScrollDiagnosticReport {
    /// Only finished reports exist. Numeric uptime timestamps and bounded raw
    /// geometry/work records are exported without health record identifiers.
    var rawJSON: String {
        let rows: [[String: Any]] = events.map { event in
            var row: [String: Any] = ["sequence": event.sequence, "uptime": event.timestamp]
            switch event.kind {
            case let .nativePhase(phase):
                row["nativePhase"] = String(describing: phase)
            case let .geometry(offset):
                row["offset"] = offset
            case let .work(work):
                row["workBegin"] = work.rawValue
            case let .workEnd(work):
                row["workEnd"] = work.rawValue
            case let .coarseInputGeneration(generation):
                row["generation"] = generation
            }
            return row
        }
        let native: [String: Any] = [
            "motionStartUptime": nativeMotionStartAt ?? NSNull(),
            "decelerationStartUptime": nativeDecelerationStartAt ?? NSNull(),
            "idleUptime": nativeIdleAt ?? NSNull(),
            "captureEndUptime": captureEndAt ?? NSNull(),
            "decelerationDuration": decelerationDuration ?? NSNull(),
        ]
        let phaseRows: [[String: Any]] = phases.map { segment in
            [
                "phase": segment.phase.rawValue,
                "startUptime": segment.start,
                "endUptime": segment.end,
                "duration": segment.duration,
                "shorterThanRequestedWindow": segment.isShorterThanRequestedWindow,
            ]
        }
        let phaseCounters: [String: Any] = Dictionary(uniqueKeysWithValues: workCounts.map { work, count in
            let byPhase = Dictionary(uniqueKeysWithValues: count.byPhase.map { phase, value in
                (phase.rawValue, value)
            })
            return (
                work.rawValue,
                [
                    "total": count.total,
                    "byPhase": byPhase,
                ] as [String: Any]
            )
        })
        let counters: [String: Any] = [
            "geometryCallbackCount": geometryCallbackCount,
            "coarseInputDeliveryCount": coarseInputDeliveryCount,
            "distinctCoarseInputGenerationCount": distinctCoarseInputGenerationCount,
            "nativeIdleCount": nativeIdleCount,
            "retainedEventCount": retainedEventCount,
            "droppedEventCount": droppedEventCount,
            "work": phaseCounters,
        ]
        let outcomeObject: [String: Any] = switch outcome {
        case .disabled:
            ["status": "disabled", "reason": NSNull()]
        case .captured:
            ["status": "captured", "reason": NSNull()]
        case let .inconclusive(reason):
            ["status": "inconclusive", "reason": reason.rawValue]
        }
        let object: [String: Any] = [
            "schema": 2,
            "summary": snapshot,
            "outcome": outcomeObject,
            "native": native,
            "phases": phaseRows,
            "counters": counters,
            "events": rows,
            "captureEndUptime": captureEndAt ?? NSNull(),
            "nativeMotionStartUptime": nativeMotionStartAt ?? NSNull(),
            "nativeDecelerationStartUptime": nativeDecelerationStartAt ?? NSNull(),
            "nativeIdleUptime": nativeIdleAt ?? NSNull(),
            "captureStartUptime": captureStartUptime ?? NSNull(),
            "captureStartWallClockEpoch": captureStartWallClockEpoch ?? NSNull(),
            "captureEndWallClockEpoch": captureEndWallClockEpoch ?? NSNull(),
            "dropped": droppedEventCount,
            "generationCountScope": "retained-events-only",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else { return "export-error" }
        return value
    }
}
