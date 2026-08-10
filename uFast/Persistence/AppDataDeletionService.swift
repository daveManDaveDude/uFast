import SwiftData

enum AppDataDeletionError: Error {
    case simulated
}

enum AppDataDeletionService {
    @MainActor
    static func deleteEverything(
        in context: ModelContext,
        simulateFailure: Bool = false
    ) throws {
        let saveAction: PersistenceTransaction.Save? = simulateFailure ? {
            throw AppDataDeletionError.simulated
        } : nil
        let transaction = PersistenceTransaction(
            modelContext: context,
            saveAction: saveAction
        )
        try context.fetch(FetchDescriptor<AppSettingsRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<FastRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<FoodEntryRecord>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<HydrationEntryRecord>()).forEach(context.delete)
        try LegacyHistoryDeletion.deleteSchemaOnlyRecords(in: context)
        try transaction.save()
    }
}
