import Foundation
import SwiftData

enum ActiveFastIntegrityError: Error, Equatable {
    case multipleActiveFasts(count: Int)
}

enum ActiveFastAuthority {
    static func resolve(_ records: [FastRecord]) throws -> FastRecord? {
        guard records.count <= 1 else {
            throw ActiveFastIntegrityError.multipleActiveFasts(count: records.count)
        }
        return records.first
    }

    @MainActor
    static func fetch(
        in modelContext: ModelContext,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) throws -> FastRecord? {
        let records = try modelContext.fetch(
            FetchDescriptor<FastRecord>(predicate: #Predicate { $0.endDate == nil })
        )
        do {
            return try resolve(records)
        } catch let ActiveFastIntegrityError.multipleActiveFasts(count) {
            recordAuthorityConflict(count: count, to: diagnosticSink)
            throw ActiveFastIntegrityError.multipleActiveFasts(count: count)
        }
    }

    private static func recordAuthorityConflict(
        count: Int,
        to sink: any DiagnosticEventSink
    ) {
        guard let event = DiagnosticEvent(
            subsystem: .persistence,
            outcome: .authorityConflict,
            severity: .error,
            countBucket: DiagnosticCountBucket(count: count)
        ) else {
            return
        }
        sink.record(event)
    }
}
