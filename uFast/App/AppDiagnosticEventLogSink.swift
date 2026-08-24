// The adapter is intentionally compiled in the app target; SwiftLint's
// cross-target analyzer does not attribute this OSLog use to the import.
// swiftlint:disable:next unused_import
import OSLog

/// The app process's local diagnostic adapter.  The event itself remains the
/// only payload crossing this boundary; no app state or underlying error is
/// handed to OSLog.
struct AppDiagnosticEventLogSink: DiagnosticEventSink, Sendable {
    private let logger = Logger(
        subsystem: "com.davidmcgrath.uFast",
        category: "Diagnostics"
    )

    func record(_ event: DiagnosticEvent) {
        logger.log(level: event.severity.osLogType, "\(event.logMessage, privacy: .public)")
    }
}

private extension DiagnosticSeverity {
    var osLogType: OSLogType {
        switch self {
        case .warning: .default
        case .error: .error
        }
    }
}
