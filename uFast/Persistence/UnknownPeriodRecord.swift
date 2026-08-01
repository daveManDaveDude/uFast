import Foundation
import SwiftData

enum UnknownPeriodReason: String, Equatable, Sendable {
    case userChoice
    case insufficientEvidence
    case savedHistoryConflict

    var explanation: String {
        switch self {
        case .userChoice:
            "You chose to leave this period unknown."
        case .insufficientEvidence:
            "Not enough confirmed information."
        case .savedHistoryConflict:
            "A saved fast overlaps this period."
        }
    }
}

@Model
final class UnknownPeriodRecord {
    var id: UUID = UUID()
    private(set) var startDate: Date = Date.now
    private(set) var endDate: Date = Date.now
    private(set) var startBoundaryKindRaw: String = CaloricBoundaryKind.food.rawValue
    private(set) var startBoundaryID: UUID = UUID()
    private(set) var endBoundaryKindRaw: String = CaloricBoundaryKind.food.rawValue
    private(set) var endBoundaryID: UUID = UUID()
    private(set) var reasonRaw: String = UnknownPeriodReason.insufficientEvidence.rawValue
    private(set) var createdAt: Date = Date.now
    private(set) var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        boundaries: ReconstructionBoundaryPair,
        reason: UnknownPeriodReason,
        createdAt: Date
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        startBoundaryKindRaw = boundaries.start.kind.rawValue
        startBoundaryID = boundaries.start.id
        endBoundaryKindRaw = boundaries.end.kind.rawValue
        endBoundaryID = boundaries.end.id
        reasonRaw = reason.rawValue
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var reason: UnknownPeriodReason {
        UnknownPeriodReason(rawValue: reasonRaw) ?? .insufficientEvidence
    }

    var boundaryPair: ReconstructionBoundaryPair {
        ReconstructionBoundaryPair(
            start: CaloricBoundaryReference(
                kind: CaloricBoundaryKind(rawValue: startBoundaryKindRaw) ?? .food,
                id: startBoundaryID
            ),
            end: CaloricBoundaryReference(
                kind: CaloricBoundaryKind(rawValue: endBoundaryKindRaw) ?? .food,
                id: endBoundaryID
            )
        )
    }
}
