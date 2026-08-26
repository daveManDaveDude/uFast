import Foundation
import SwiftData

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

@MainActor
final class SwiftDataFoodFavouriteStore {
    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction
    private let diagnosticSink: any DiagnosticEventSink

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink()
    ) {
        self.modelContext = modelContext
        self.diagnosticSink = diagnosticSink
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw FoodFavouriteStoreError.simulatedSaveFailure
            } : nil
        )
    }

    func snapshots() throws -> [FoodFavouriteSnapshot] {
        try records().map(\.snapshot)
    }

    func create(
        description: String,
        nutrition: FoodNutrition,
        at date: Date
    ) throws -> FoodFavouriteSnapshot {
        let existing = try snapshots()
        let values = try validated(description: description, nutrition: nutrition, existing: existing)
        let nextOrder = (existing.map(\.creationOrder).max() ?? -1) + 1
        let record = FoodFavouriteRecord(
            description: values.description,
            nutrition: values.nutrition,
            createdAt: date,
            creationOrder: nextOrder
        )
        modelContext.insert(record)
        try saveTransaction()
        return record.snapshot
    }

    func update(
        id: UUID,
        expectedRevision: Int64,
        description: String,
        nutrition: FoodNutrition,
        at date: Date
    ) throws -> FoodFavouriteSnapshot {
        let allRecords = try records()
        guard let record = allRecords.first(where: { $0.id == id }) else {
            throw FoodFavouriteStoreError.recordNotFound
        }
        guard record.revision == expectedRevision else {
            throw FoodFavouriteStoreError.stale
        }
        let values = try validated(
            description: description,
            nutrition: nutrition,
            existing: allRecords.filter { $0.id != id }.map(\.snapshot),
            excluding: id
        )
        let old = record.snapshot
        guard old.revision < .max else {
            throw FoodFavouriteStoreError.revisionOverflow
        }
        let nextRevision = old.revision + 1
        record.update(
            description: values.description,
            nutrition: values.nutrition,
            updatedAt: date,
            revision: nextRevision
        )
        try saveTransaction {
            record.update(
                description: old.description,
                nutrition: old.nutrition,
                updatedAt: old.updatedAt,
                revision: old.revision
            )
        }
        return record.snapshot
    }

    func delete(id: UUID, expectedRevision: Int64) throws {
        guard let record = try records().first(where: { $0.id == id }) else {
            throw FoodFavouriteStoreError.recordNotFound
        }
        guard record.revision == expectedRevision else {
            throw FoodFavouriteStoreError.stale
        }
        modelContext.delete(record)
        try saveTransaction()
    }

    func resolve(id: UUID) throws -> FoodFavouriteSnapshot {
        guard let snapshot = try snapshots().first(where: { $0.id == id }) else {
            throw FoodFavouriteStoreError.recordNotFound
        }
        return snapshot
    }

    private func validated(
        description: String,
        nutrition: FoodNutrition,
        existing: [FoodFavouriteSnapshot],
        excluding: UUID? = nil
    ) throws -> FoodFavouriteValidatedValues {
        do {
            return try FoodFavouriteValidator.validated(
                description: description,
                nutrition: nutrition,
                existing: existing,
                excluding: excluding
            )
        } catch let error as FoodFavouriteValidationError {
            throw FoodFavouriteValidator.storeError(for: error)
        }
    }

    private func records() throws -> [FoodFavouriteRecord] {
        try modelContext.fetch(
            FetchDescriptor<FoodFavouriteRecord>(
                sortBy: [
                    SortDescriptor(\FoodFavouriteRecord.creationOrder),
                    SortDescriptor(\FoodFavouriteRecord.createdAt),
                    SortDescriptor(\FoodFavouriteRecord.id),
                ]
            )
        )
    }

    private func saveTransaction(recovering recovery: @escaping () -> Void = {}) throws {
        do {
            try transaction.save(recovering: recovery)
        } catch {
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
    }
}
