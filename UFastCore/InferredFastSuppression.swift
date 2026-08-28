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
        // The pure domain decision retains the complete current projection,
        // including an open end that follows the clock. Persistence decides
        // separately whether that presentation-only change is durable.
        guard self != Self(
            candidate: candidate,
            createdAt: createdAt,
            updatedAt: self.updatedAt
        ) else { return self }
        return Self(
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
}

/// A deterministic lookup of the complete inferred projection by its
/// source-bound identity. Suppression reconciliation builds this once and
/// reuses it for every stored suppression.
public struct InferredFastProjectionIndex: Equatable, Sendable {
    public let candidates: [InferredFastInterval]
    private let candidatesBySource: [CaloricBoundaryReference: InferredFastInterval]

    public init(candidates: [InferredFastInterval]) {
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.sourceDate != rhs.sourceDate {
                return lhs.sourceDate < rhs.sourceDate
            }
            if lhs.sourceBoundaryReference.kind != rhs.sourceBoundaryReference.kind {
                return lhs.sourceBoundaryReference.kind.rawValue
                    < rhs.sourceBoundaryReference.kind.rawValue
            }
            return lhs.sourceBoundaryReference.id.uuidString
                < rhs.sourceBoundaryReference.id.uuidString
        }
        var index: [CaloricBoundaryReference: InferredFastInterval] = [:]
        self.candidates = ordered.filter { candidate in
            guard index[candidate.sourceBoundaryReference] == nil else { return false }
            index[candidate.sourceBoundaryReference] = candidate
            return true
        }
        candidatesBySource = index
    }

    public func candidate(
        for sourceBoundaryReference: CaloricBoundaryReference
    ) -> InferredFastInterval? {
        candidatesBySource[sourceBoundaryReference]
    }
}

/// Framework-independent inputs for one source-bound suppression pass.
public struct InferredFastSuppressionBatchInput: Sendable {
    public let suppressions: [InferredFastSuppression]
    public let projection: InferredFastProjectionIndex
    public let currentGoal: FastingGoal
    public let enabled: Bool
    public let mode: InferredFastSuppressionMode
    public let updatedAt: Date

    public init(
        suppressions: [InferredFastSuppression],
        projection: InferredFastProjectionIndex,
        currentGoal: FastingGoal,
        enabled: Bool,
        mode: InferredFastSuppressionMode,
        updatedAt: Date
    ) {
        self.suppressions = suppressions
        self.projection = projection
        self.currentGoal = currentGoal
        self.enabled = enabled
        self.mode = mode
        self.updatedAt = updatedAt
    }
}

public struct InferredFastSuppressionBatchResult: Equatable, Sendable {
    public let decisions: [InferredFastSuppressionDecision]

    public init(decisions: [InferredFastSuppressionDecision]) {
        self.decisions = decisions
    }
}

public enum InferredFastSuppressionBatchReconciler {
    public static func reconcile(
        input: InferredFastSuppressionBatchInput
    ) -> InferredFastSuppressionBatchResult {
        InferredFastSuppressionBatchResult(
            decisions: input.suppressions.map { suppression in
                InferredFastSuppressionDecider.decide(
                    suppression: suppression,
                    projection: input.projection,
                    enabled: input.enabled,
                    mode: input.mode,
                    updatedAt: input.updatedAt
                )
            }
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
        recordedFasts _: [RecordedFastInterval] = [],
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
        let projection = shouldReconcile
            ? InferredFastProjectionIndex(candidates: InferredFastProjector.project(
                boundaries: boundaries,
                // Recorded-fast overlap changes presentation eligibility, not
                // the user's explicit suppression decision. Keep the source
                // row indexed so it can reappear when that overlap ends.
                recordedFasts: [],
                currentGoal: currentGoal,
                enabled: true,
                now: now
            ))
            : InferredFastProjectionIndex(candidates: [])
        return decide(
            suppression: suppression,
            projection: projection,
            enabled: enabled,
            mode: mode,
            updatedAt: updatedAt
        )
    }

    public static func decide(
        suppression: InferredFastSuppression,
        projection: InferredFastProjectionIndex,
        enabled: Bool,
        mode: InferredFastSuppressionMode,
        updatedAt: Date
    ) -> InferredFastSuppressionDecision {
        let shouldReconcile = enabled || mode == .authoritativeMutation
        guard shouldReconcile else { return .retain(suppression) }
        guard let candidate = projection.candidate(
            for: suppression.sourceBoundaryReference
        ) else { return .remove }
        return .retain(suppression.updating(from: candidate, at: updatedAt))
    }

    public static func make(
        candidate: InferredFastInterval,
        at date: Date
    ) -> InferredFastSuppression {
        InferredFastSuppression(candidate: candidate, createdAt: date, updatedAt: date)
    }
}
