import Foundation
import SwiftData

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

@MainActor
final class SwiftDataHydrationFavouriteStore {
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
                throw HydrationFavouriteStoreError.simulatedSaveFailure
            } : nil
        )
    }

    func snapshots() throws -> [HydrationFavouriteSnapshot] {
        try records().map(\.snapshot)
    }

    func create(
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        at date: Date
    ) throws -> HydrationFavouriteSnapshot {
        let existing = try snapshots()
        let values = try HydrationFavouriteValidator.validated(
            name: name,
            amount: volumeMillilitres,
            isCaloric: isCaloric,
            existing: existing
        )
        let record = HydrationFavouriteRecord(
            name: values.name,
            volumeMillilitres: values.amount,
            isCaloric: values.isCaloric,
            createdAt: date,
            creationOrder: (existing.map(\.creationOrder).max() ?? -1) + 1
        )
        modelContext.insert(record)
        try saveTransaction()
        return record.snapshot
    }

    func update(
        id: UUID,
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        at date: Date
    ) throws -> HydrationFavouriteSnapshot {
        let records = try records()
        guard let record = records.first(where: { $0.id == id }) else {
            throw HydrationFavouriteStoreError.recordNotFound
        }
        let values = try HydrationFavouriteValidator.validated(
            name: name,
            amount: volumeMillilitres,
            isCaloric: isCaloric,
            existing: records.filter { $0.id != id }.map(\.snapshot),
            excluding: id
        )
        let old = record.snapshot
        record.update(
            name: values.name,
            volumeMillilitres: values.amount,
            isCaloric: values.isCaloric,
            updatedAt: date
        )
        try saveTransaction {
            record.update(
                name: old.name,
                volumeMillilitres: old.volumeMillilitres,
                isCaloric: old.isCaloric,
                updatedAt: old.updatedAt
            )
        }
        return record.snapshot
    }

    func delete(id: UUID) throws {
        guard let record = try records().first(where: { $0.id == id }) else {
            throw HydrationFavouriteStoreError.recordNotFound
        }
        modelContext.delete(record)
        try saveTransaction()
    }

    func resolve(id: UUID) throws -> HydrationFavouriteSnapshot {
        guard let snapshot = try snapshots().first(where: { $0.id == id }) else {
            throw HydrationFavouriteStoreError.recordNotFound
        }
        return snapshot
    }

    private func records() throws -> [HydrationFavouriteRecord] {
        try modelContext.fetch(
            FetchDescriptor<HydrationFavouriteRecord>(
                sortBy: [
                    SortDescriptor(\HydrationFavouriteRecord.createdAt),
                    SortDescriptor(\HydrationFavouriteRecord.creationOrder),
                    SortDescriptor(\HydrationFavouriteRecord.id),
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

// swiftlint:enable trailing_comma
