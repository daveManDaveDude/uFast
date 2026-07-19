import Foundation
import SwiftData

enum ActiveFastPersistenceError: Error {
    case simulatedSaveFailure
}

@MainActor
final class SwiftDataActiveFastRepository: ActiveFastRepository {
    private let modelContext: ModelContext
    private let simulateSaveFailure: Bool

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false
    ) {
        self.modelContext = modelContext
        self.simulateSaveFailure = simulateSaveFailure
    }

    func activeFast() throws -> FastRecord? {
        var descriptor = FetchDescriptor<FastRecord>(
            predicate: #Predicate { $0.endDate == nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func saveNewActiveFast(_ fast: FastRecord) throws {
        modelContext.insert(fast)

        do {
            if simulateSaveFailure {
                throw ActiveFastPersistenceError.simulatedSaveFailure
            }
            try modelContext.save()
        } catch {
            modelContext.delete(fast)
            throw error
        }
    }
}
