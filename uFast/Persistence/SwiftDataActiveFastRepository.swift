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
            try failIfRequested()
            try modelContext.save()
        } catch {
            modelContext.delete(fast)
            throw error
        }
    }

    func updateStartDate(of fast: FastRecord, to startDate: Date) throws {
        let originalStartDate = fast.startDate
        fast.correctStartDate(to: startDate)

        do {
            try failIfRequested()
            try modelContext.save()
        } catch {
            fast.correctStartDate(to: originalStartDate)
            throw error
        }
    }

    private func failIfRequested() throws {
        if simulateSaveFailure {
            throw ActiveFastPersistenceError.simulatedSaveFailure
        }
    }
}
