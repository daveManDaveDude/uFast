// The adapter is intentionally compiled in the widget target; SwiftLint's
// cross-target analyzer does not attribute this OSLog use to the import.
// swiftlint:disable:next unused_import
import OSLog

// The widget composition root is intentionally deferred to the widget logging
// stories; this adapter remains the process-local target boundary.
// swiftlint:disable unused_declaration
/// The widget extension's process-local diagnostic adapter.  It deliberately
/// does not share an in-memory sink with the host app.
struct WidgetDiagnosticEventLogSink: DiagnosticEventSink, Sendable {
    private let logger = Logger(
        subsystem: "com.davidmcgrath.uFast",
        category: "Diagnostics"
    )

    func record(_ event: DiagnosticEvent) {
        logger.log(level: event.severity.osLogType, "\(event.logMessage, privacy: .public)")
    }
}

// swiftlint:enable unused_declaration

private extension DiagnosticSeverity {
    var osLogType: OSLogType {
        switch self {
        case .warning: .default
        case .error: .error
        }
    }
}
