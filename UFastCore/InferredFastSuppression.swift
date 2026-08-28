import Foundation

/// The persisted visibility decision for one inferred-fast source. This is
/// deliberately separate from `FastRecord`: hiding a projection must never
/// turn it into an app-created fast or mutate the source event.
public struct InferredFastSuppression: Equatable, Hashable, Sendable {
    public let sourceBoundaryReference: CaloricBoundaryReference
    public let projectedStartDate: Date
    public let projectedEndDate: Date
    public let nextBoundaryReference: CaloricBoundaryReference?
    public let nextBoundaryDate: Date?
    public let goalHoursSnapshot: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        sourceBoundaryReference: CaloricBoundaryReference,
        projectedStartDate: Date,
        projectedEndDate: Date,
        nextBoundaryReference: CaloricBoundaryReference?,
        nextBoundaryDate: Date?,
        goalHoursSnapshot: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.sourceBoundaryReference = sourceBoundaryReference
        self.projectedStartDate = projectedStartDate
        self.projectedEndDate = projectedEndDate
        self.nextBoundaryReference = nextBoundaryReference
        self.nextBoundaryDate = nextBoundaryDate
        self.goalHoursSnapshot = goalHoursSnapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(
        candidate: InferredFastInterval,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.init(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            projectedStartDate: candidate.startDate,
            projectedEndDate: candidate.endDate,
            nextBoundaryReference: candidate.nextBoundaryReference,
            nextBoundaryDate: candidate.nextBoundaryDate,
            goalHoursSnapshot: candidate.goal.hours,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public var projectedInterval: Range<Date> {
        projectedStartDate ..< projectedEndDate
    }

    public func updating(
        from candidate: InferredFastInterval,
        at updatedAt: Date
    ) -> Self {
        let projectionChanged = projectedStartDate != candidate.startDate
            || projectedEndDate != candidate.endDate
            || nextBoundaryReference != candidate.nextBoundaryReference
            || nextBoundaryDate != candidate.nextBoundaryDate
            || goalHoursSnapshot != candidate.goal.hours
        return Self(
            sourceBoundaryReference: candidate.sourceBoundaryReference,
            projectedStartDate: candidate.startDate,
            projectedEndDate: candidate.endDate,
            nextBoundaryReference: candidate.nextBoundaryReference,
            nextBoundaryDate: candidate.nextBoundaryDate,
            goalHoursSnapshot: candidate.goal.hours,
            createdAt: createdAt,
            updatedAt: projectionChanged ? updatedAt : self.updatedAt
        )
    }
}

/// The framework-independent result used by persistence and motion/history
/// adapters when reconciling a source-bound suppression.
public enum InferredFastSuppressionDecision: Equatable, Sendable {
    case remove
    case retain(InferredFastSuppression)
}

public enum InferredFastSuppressionMode: Equatable, Sendable {
    case presentation
    case authoritativeMutation
}

public enum InferredFastSuppressionDecider {
    public static func decide(
        suppression: InferredFastSuppression,
        boundaries: [CaloricBoundary],
        recordedFasts: [RecordedFastInterval] = [],
        currentGoal: FastingGoal,
        enabled: Bool,
        mode: InferredFastSuppressionMode = .presentation,
        now: Date,
        updatedAt: Date = .now
    ) -> InferredFastSuppressionDecision {
        // Detection being disabled changes presentation eligibility, not the
        // user's explicit suppression decision. Preserve the row so turning
        // detection back on can reconcile it from current authoritative state.
        let shouldReconcile = enabled || mode == .authoritativeMutation
        guard shouldReconcile else { return .retain(suppression) }

        // Recorded-fast overlap changes presentation eligibility, not the
        // user's explicit suppression decision. Keep the row so it can
        // reappear when that overlap ends.
        _ = recordedFasts
        let candidate = InferredFastProjector.project(
            boundaries: boundaries,
            recordedFasts: [],
            currentGoal: currentGoal,
            enabled: shouldReconcile,
            now: now
        ).first { $0.sourceBoundaryReference == suppression.sourceBoundaryReference }

        guard let candidate else { return .remove }
        return .retain(suppression.updating(from: candidate, at: updatedAt))
    }

    public static func make(
        candidate: InferredFastInterval,
        at date: Date
    ) -> InferredFastSuppression {
        InferredFastSuppression(candidate: candidate, createdAt: date, updatedAt: date)
    }
}
