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
    static func fetch(in modelContext: ModelContext) throws -> FastRecord? {
        let records = try modelContext.fetch(
            FetchDescriptor<FastRecord>(predicate: #Predicate { $0.endDate == nil })
        )
        return try resolve(records)
    }
}
