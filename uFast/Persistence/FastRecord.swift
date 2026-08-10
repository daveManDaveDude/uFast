import Foundation
import SwiftData

enum FastOrigin: String, Equatable, Sendable {
    case recorded
    case reconstructed
}

enum FastReviewState: String, Equatable, Sendable {
    case confirmed
    case needsReview
}

enum FastRecordIntegrityError: Error, Equatable {
    case invalidHistoricalGoal(rawHours: Int)
}

enum FastRecordPresentationIntegrity: Equatable, Sendable {
    case available
    case unavailable
}

struct FastRecordProvenanceSnapshot: Equatable, Sendable {
    let originRaw: String
    let reviewStateRaw: String
    let wasAdjustedByUser: Bool
    let hasHistoricalGoal: Bool
    let startBoundaryKindRaw: String?
    let startBoundaryID: UUID?
    let endBoundaryKindRaw: String?
    let endBoundaryID: UUID?
}

@Model
final class FastRecord {
    var id: UUID = UUID()
    private(set) var startDate: Date = Date.now
    private(set) var endDate: Date?
    private(set) var goalHoursAtStart: Int = FastingGoal.default.hours
    private(set) var originRaw: String = FastOrigin.recorded.rawValue
    private(set) var reviewStateRaw: String = FastReviewState.confirmed.rawValue
    private(set) var wasAdjustedByUser: Bool = false
    private(set) var hasHistoricalGoal: Bool = true
    private(set) var startBoundaryKindRaw: String?
    private(set) var startBoundaryID: UUID?
    private(set) var endBoundaryKindRaw: String?
    private(set) var endBoundaryID: UUID?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        goalAtStart: FastingGoal
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        goalHoursAtStart = goalAtStart.hours
        originRaw = FastOrigin.recorded.rawValue
        reviewStateRaw = FastReviewState.confirmed.rawValue
        hasHistoricalGoal = true
    }

    init(
        id: UUID = UUID(),
        reconstructedStart: Date,
        endDate: Date,
        boundaries: ReconstructionBoundaryPair,
        adjustedByUser: Bool
    ) {
        self.id = id
        startDate = reconstructedStart
        self.endDate = endDate
        goalHoursAtStart = FastingGoal.default.hours
        originRaw = FastOrigin.reconstructed.rawValue
        reviewStateRaw = FastReviewState.confirmed.rawValue
        wasAdjustedByUser = adjustedByUser
        hasHistoricalGoal = false
        startBoundaryKindRaw = boundaries.start.kind.rawValue
        startBoundaryID = boundaries.start.id
        endBoundaryKindRaw = boundaries.end.kind.rawValue
        endBoundaryID = boundaries.end.id
    }

    var isActive: Bool {
        endDate == nil
    }

    var historicalGoal: FastingGoal? {
        FastingGoal(hours: goalHoursAtStart)
    }

    var capturedHistoricalGoal: FastingGoal? {
        hasHistoricalGoal ? historicalGoal : nil
    }

    var origin: FastOrigin? {
        FastOrigin(rawValue: originRaw)
    }

    var reviewState: FastReviewState? {
        FastReviewState(rawValue: reviewStateRaw)
    }

    var boundaryPair: ReconstructionBoundaryPair? {
        guard let startKindRaw = startBoundaryKindRaw,
              let startKind = CaloricBoundaryKind(rawValue: startKindRaw),
              let startBoundaryID,
              let endKindRaw = endBoundaryKindRaw,
              let endKind = CaloricBoundaryKind(rawValue: endKindRaw),
              let endBoundaryID
        else { return nil }
        return ReconstructionBoundaryPair(
            start: CaloricBoundaryReference(kind: startKind, id: startBoundaryID),
            end: CaloricBoundaryReference(kind: endKind, id: endBoundaryID)
        )
    }

    var provenanceSnapshot: FastRecordProvenanceSnapshot {
        FastRecordProvenanceSnapshot(
            originRaw: originRaw,
            reviewStateRaw: reviewStateRaw,
            wasAdjustedByUser: wasAdjustedByUser,
            hasHistoricalGoal: hasHistoricalGoal,
            startBoundaryKindRaw: startBoundaryKindRaw,
            startBoundaryID: startBoundaryID,
            endBoundaryKindRaw: endBoundaryKindRaw,
            endBoundaryID: endBoundaryID
        )
    }

    var presentationIntegrity: FastRecordPresentationIntegrity {
        guard origin != nil, reviewState != nil else { return .unavailable }
        guard !hasHistoricalGoal || historicalGoal != nil else { return .unavailable }
        return .available
    }

    var duration: TimeInterval? {
        endDate.map { $0.timeIntervalSince(startDate) }
    }

    func presentationGoal(currentGoal: FastingGoal) -> FastingGoal? {
        isActive ? currentGoal : historicalGoal
    }

    func targetDate(currentGoal: FastingGoal) -> Date? {
        presentationGoal(currentGoal: currentGoal).map {
            startDate.addingTimeInterval(TimeInterval($0.hours * 60 * 60))
        }
    }

    func correctStartDate(to startDate: Date) {
        self.startDate = startDate
    }

    func correctBoundaries(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }

    func markNeedsReview() {
        guard origin == .reconstructed else { return }
        reviewStateRaw = FastReviewState.needsReview.rawValue
    }

    func restoreProvenance(_ snapshot: FastRecordProvenanceSnapshot) {
        originRaw = snapshot.originRaw
        reviewStateRaw = snapshot.reviewStateRaw
        wasAdjustedByUser = snapshot.wasAdjustedByUser
        hasHistoricalGoal = snapshot.hasHistoricalGoal
        startBoundaryKindRaw = snapshot.startBoundaryKindRaw
        startBoundaryID = snapshot.startBoundaryID
        endBoundaryKindRaw = snapshot.endBoundaryKindRaw
        endBoundaryID = snapshot.endBoundaryID
    }

    func restorePersistedHistoricalGoal(rawHours: Int, isCaptured: Bool) {
        goalHoursAtStart = rawHours
        hasHistoricalGoal = isCaptured
    }

    @discardableResult
    func complete(at endDate: Date, goal: FastingGoal) -> Bool {
        guard isActive else {
            return false
        }

        self.endDate = endDate
        goalHoursAtStart = goal.hours
        return true
    }

    func restoreActive(goal: FastingGoal) {
        endDate = nil
        goalHoursAtStart = goal.hours
    }
}
