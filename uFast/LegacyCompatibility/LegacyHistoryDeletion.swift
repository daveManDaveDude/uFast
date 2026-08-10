import SwiftData

enum LegacyHistoryDeletion {
    @MainActor
    static func deleteSchemaOnlyRecords(in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).forEach(context.delete)
    }
}
