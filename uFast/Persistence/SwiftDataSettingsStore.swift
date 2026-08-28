import Foundation
import SwiftData

struct AppSettingsUserVisibleSnapshot: Equatable, Sendable {
    let fastingGoalHours: Int
    let hasCompletedOnboarding: Bool
    let automaticLiveActivityPreferenceRawValue: String
    let inferredFastDetectionEnabled: Bool
}

enum SettingsStoreError: Error, Equatable {
    case conflictingAuthorities(count: Int)
    case missingAuthority
    case simulatedSaveFailure
}

@MainActor
final class SwiftDataSettingsStore {
    typealias NewStoreSeeder = (ModelContext, Date) throws -> Void

    private let modelContext: ModelContext
    private let transaction: PersistenceTransaction
    private let diagnosticSink: any DiagnosticEventSink
    private let now: Date
    private let newStoreSeeder: NewStoreSeeder

    init(
        modelContext: ModelContext,
        simulateSaveFailure: Bool = false,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        now: Date = .now,
        newStoreSeeder: @escaping NewStoreSeeder = HydrationFavouriteMigration.seedNewStore
    ) {
        self.modelContext = modelContext
        self.diagnosticSink = diagnosticSink
        self.now = now
        self.newStoreSeeder = newStoreSeeder
        transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: simulateSaveFailure ? {
                throw SettingsStoreError.simulatedSaveFailure
            } : nil
        )
    }

    func prepareForUse() throws {
        let records = try sortedRecords()
        guard records.count > 1 else { return }
        guard records.dropFirst().allSatisfy({ $0.userVisibleSnapshot == records[0].userVisibleSnapshot }) else {
            recordAuthorityConflict(count: records.count)
            throw SettingsStoreError.conflictingAuthorities(count: records.count)
        }
        records.dropFirst().forEach(modelContext.delete)
        try saveTransaction(recordFailure: false)
    }

    func authoritativeRecord() throws -> AppSettingsRecord? {
        let records = try sortedRecords()
        guard records.count <= 1 else {
            recordAuthorityConflict(count: records.count)
            throw SettingsStoreError.conflictingAuthorities(count: records.count)
        }
        return records.first
    }

    func completeOnboarding(goal: FastingGoal) throws -> AppSettingsRecord {
        if let existing = try authoritativeRecord() {
            guard !existing.hasCompletedOnboarding else { return existing }
            let snapshot = existing.userVisibleSnapshot
            existing.setFastingGoal(goal)
            existing.completeOnboarding()
            try saveTransaction {
                existing.restore(from: snapshot)
            }
            return existing
        }
        let settings = AppSettingsRecord(fastingGoal: goal, hasCompletedOnboarding: true)
        modelContext.insert(settings)
        do {
            try newStoreSeeder(modelContext, now)
            modelContext.insert(
                HydrationFavouriteMigrationRecord(
                    migrationVersion: HydrationFavouriteMigration.migrationVersion,
                    completedAt: now
                )
            )
            try transaction.save()
        } catch {
            modelContext.rollback()
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
        return settings
    }

    func updateGoal(
        _ goal: FastingGoal,
        additionalChanges: (() throws -> Void)? = nil,
        additionalRecovery: (() -> Void)? = nil
    ) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        do {
            settings.setFastingGoal(goal)
            try additionalChanges?()
            try saveTransaction {
                settings.restore(from: snapshot)
                additionalRecovery?()
            }
        } catch {
            // PersistenceTransaction has already restored and rolled back
            // save failures. For a preparation failure, perform the same
            // rollback here without writing a second restoration afterward.
            modelContext.rollback()
            throw error
        }
    }

    func updateAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference
    ) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        settings.setAutomaticLiveActivityPreference(preference)
        try saveTransaction {
            settings.restore(from: snapshot)
        }
    }

    func updateInferredFastDetectionEnabled(
        _ enabled: Bool,
        additionalChanges: (() throws -> Void)? = nil,
        additionalRecovery: (() -> Void)? = nil
    ) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        do {
            settings.setInferredFastDetectionEnabled(enabled)
            try additionalChanges?()
            try saveTransaction {
                settings.restore(from: snapshot)
                additionalRecovery?()
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func requiredAuthority() throws -> AppSettingsRecord {
        guard let settings = try authoritativeRecord() else {
            throw SettingsStoreError.missingAuthority
        }
        return settings
    }

    private func sortedRecords() throws -> [AppSettingsRecord] {
        try modelContext.fetch(FetchDescriptor<AppSettingsRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func saveTransaction(
        recovering recovery: @escaping () -> Void = {},
        recordFailure: Bool = true
    ) throws {
        do {
            try transaction.save(recovering: recovery)
        } catch {
            if recordFailure {
                PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            }
            throw error
        }
    }

    private func recordAuthorityConflict(count: Int) {
        guard let event = DiagnosticEvent(
            subsystem: .persistence,
            outcome: .authorityConflict,
            severity: .error,
            countBucket: DiagnosticCountBucket(count: count)
        ) else {
            return
        }
        diagnosticSink.record(event)
    }
}
