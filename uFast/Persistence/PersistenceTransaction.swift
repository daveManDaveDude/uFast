import SwiftData

@MainActor
struct PersistenceTransaction {
    typealias Save = () throws -> Void

    private let modelContext: ModelContext
    private let saveAction: Save

    init(
        modelContext: ModelContext,
        saveAction: Save? = nil
    ) {
        self.modelContext = modelContext
        self.saveAction = saveAction ?? { try modelContext.save() }
    }

    func save(recovering recovery: () -> Void = {}) throws {
        do {
            try saveAction()
        } catch {
            recovery()
            modelContext.rollback()
            throw error
        }
    }

    /// Applies the transaction's changes and commits them within one rollback boundary.
    func perform(_ changes: () throws -> Void) throws {
        do {
            try changes()
            try saveAction()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

enum PersistenceTransactionDiagnostics {
    static func recordFailure(to sink: any DiagnosticEventSink) {
        record(.commitFailed, severity: .error, to: sink)
        record(.rollbackApplied, severity: .warning, to: sink)
    }

    private static func record(
        _ outcome: DiagnosticOutcome,
        severity: DiagnosticSeverity,
        to sink: any DiagnosticEventSink
    ) {
        guard let event = DiagnosticEvent(
            subsystem: .command,
            outcome: outcome,
            severity: severity
        ) else {
            return
        }
        sink.record(event)
    }
}
