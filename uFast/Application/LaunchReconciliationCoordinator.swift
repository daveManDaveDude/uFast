import SwiftData

struct LaunchReconciliationResult: Equatable, Sendable {
    let boundary: CaloricBoundaryReconciliationResult
    let suppression: SuppressionReconciliationResult
}

/// Owns the one launch reconciliation boundary. The production initializer
/// wires the persisted-fast and source-bound suppression passes; the action
/// initializer keeps bootstrap behavior testable without constructing an App.
@MainActor
struct LaunchReconciliationCoordinator {
    typealias BoundaryReconciliation = () throws -> CaloricBoundaryReconciliationResult
    typealias SuppressionReconciliation = () throws -> SuppressionReconciliationResult

    private let boundaryReconciliation: BoundaryReconciliation
    private let suppressionReconciliation: SuppressionReconciliation

    init(
        boundaryReconciliation: @escaping BoundaryReconciliation,
        suppressionReconciliation: @escaping SuppressionReconciliation
    ) {
        self.boundaryReconciliation = boundaryReconciliation
        self.suppressionReconciliation = suppressionReconciliation
    }

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        diagnosticSink: any DiagnosticEventSink = NoOpDiagnosticEventSink(),
        boundarySaveAction: PersistenceTransaction.Save? = nil,
        suppressionSaveAction: PersistenceTransaction.Save? = nil,
        projector: @escaping InferredFastProjection = { boundaries, goal, enabled, now in
            InferredFastProjector.project(
                boundaries: boundaries,
                currentGoal: goal,
                enabled: enabled,
                now: now
            )
        }
    ) {
        let launchNow = clock.now
        boundaryReconciliation = {
            let currentGoal = try SwiftDataSettingsStore(modelContext: modelContext)
                .authoritativeRecord()?.fastingGoal ?? .default
            return try CaloricBoundaryReconciler(
                modelContext: modelContext,
                currentGoal: currentGoal,
                saveAction: boundarySaveAction
            ).reconcile()
        }
        suppressionReconciliation = {
            let settings = try SwiftDataSettingsStore(modelContext: modelContext)
                .authoritativeRecord()
            return try InferredFastSuppressionStore(
                modelContext: modelContext,
                diagnosticSink: diagnosticSink,
                projector: projector
            ).reconcile(
                currentGoal: settings?.fastingGoal ?? .default,
                enabled: settings?.inferredFastDetectionEnabled ?? false,
                mode: .presentation,
                now: launchNow,
                updatedAt: launchNow,
                saveAction: suppressionSaveAction
            )
        }
    }

    func reconcile() throws -> LaunchReconciliationResult {
        let boundary = try boundaryReconciliation()
        let suppression = try suppressionReconciliation()
        return LaunchReconciliationResult(boundary: boundary, suppression: suppression)
    }
}
