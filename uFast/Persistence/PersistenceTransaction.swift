import SwiftData

@MainActor
struct PersistenceTransaction {
    typealias Save = () throws -> Void

    private let modelContext: ModelContext
    private let saveAction: Save

    init(modelContext: ModelContext, saveAction: Save? = nil) {
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
}
