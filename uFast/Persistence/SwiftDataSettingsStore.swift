import SwiftData

struct AppSettingsUserVisibleSnapshot: Equatable, Sendable {
    let fastingGoalHours: Int
    let hasCompletedOnboarding: Bool
    let waterFavouriteMillilitres: Int
    let teaFavouriteMillilitres: Int
    let coffeeFavouriteMillilitres: Int
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
        try saveTransaction()
        return settings
    }

    func updateGoal(_ goal: FastingGoal) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        settings.setFastingGoal(goal)
        try saveTransaction {
            settings.restore(from: snapshot)
        }
    }

    func updateHydrationFavourites(water: Int, tea: Int, coffee: Int) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        settings.setHydrationFavourites(water: water, tea: tea, coffee: coffee)
        try saveTransaction {
            settings.restore(from: snapshot)
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

    func updateInferredFastDetectionEnabled(_ enabled: Bool) throws {
        let settings = try requiredAuthority()
        let snapshot = settings.userVisibleSnapshot
        settings.setInferredFastDetectionEnabled(enabled)
        try saveTransaction {
            settings.restore(from: snapshot)
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
