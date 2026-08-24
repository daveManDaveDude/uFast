import SwiftData

struct PersistenceBootstrapFailure: Equatable, Sendable {
    let diagnosticDescription: String
}

enum PersistenceBootstrapError: Error {
    case migrationFailed(Error)
}

enum PersistenceBootstrapResult {
    case ready(ModelContainer)
    case unavailable(PersistenceBootstrapFailure)

    static func open(
        containerFactory: () throws -> ModelContainer = { try PersistenceContainer.make() },
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) -> Self {
        do {
            return try .ready(containerFactory())
        } catch let error as PersistenceBootstrapError {
            switch error {
            case let .migrationFailed(underlyingError):
                return .unavailable(
                    PersistenceBootstrapFailure(
                        diagnosticDescription: String(describing: underlyingError)
                    )
                )
            }
        } catch {
            record(.storeOpenFailed, to: diagnosticSink)
            return .unavailable(
                PersistenceBootstrapFailure(
                    diagnosticDescription: String(describing: error)
                )
            )
        }
    }

    private static func record(
        _ outcome: DiagnosticOutcome,
        to sink: any DiagnosticEventSink
    ) {
        guard let event = DiagnosticEvent(
            subsystem: .persistence,
            outcome: outcome,
            severity: .error
        ) else {
            return
        }
        sink.record(event)
    }
}
