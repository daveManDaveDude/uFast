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
        do {
            try context.fetch(FetchDescriptor<AppSettingsRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<FastRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<FoodEntryRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<HydrationEntryRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<UnknownPeriodRecord>()).forEach(context.delete)

            if simulateFailure {
                throw AppDataDeletionError.simulated
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
