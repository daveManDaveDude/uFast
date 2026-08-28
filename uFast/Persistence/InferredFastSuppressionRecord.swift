import Foundation
import SwiftData

// swiftlint:disable opening_brace line_length

@Model
final class InferredFastSuppressionRecord {
    var id: UUID = UUID()
    private(set) var sourceBoundaryKindRaw: String = CaloricBoundaryKind.food.rawValue
    private(set) var sourceBoundaryID: UUID = UUID()
    private(set) var projectedStartDate: Date = Date.now
    private(set) var projectedEndDate: Date = Date.now
    private(set) var nextBoundaryKindRaw: String?
    private(set) var nextBoundaryID: UUID?
    private(set) var nextBoundaryDate: Date?
    private(set) var goalHoursSnapshot: Int = FastingGoal.default.hours
    private(set) var createdAt: Date = Date.now
    private(set) var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        suppression: InferredFastSuppression
    ) {
        self.id = id
        restore(from: suppression)
    }

    var suppression: InferredFastSuppression? {
        guard let sourceKind = CaloricBoundaryKind(rawValue: sourceBoundaryKindRaw),
              projectedStartDate < projectedEndDate,
              goalHoursSnapshot > 0
        else {
            return nil
        }

        let nextReference: CaloricBoundaryReference? = if let nextBoundaryKindRaw,
                                                          let nextBoundaryID,
                                                          let nextKind = CaloricBoundaryKind(rawValue: nextBoundaryKindRaw)
        {
            CaloricBoundaryReference(kind: nextKind, id: nextBoundaryID)
        } else {
            nil
        }
        return InferredFastSuppression(
            sourceBoundaryReference: CaloricBoundaryReference(
                kind: sourceKind,
                id: sourceBoundaryID
            ),
            projectedStartDate: projectedStartDate,
            projectedEndDate: projectedEndDate,
            nextBoundaryReference: nextReference,
            nextBoundaryDate: nextBoundaryDate,
            goalHoursSnapshot: goalHoursSnapshot,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func restore(from suppression: InferredFastSuppression) {
        sourceBoundaryKindRaw = suppression.sourceBoundaryReference.kind.rawValue
        sourceBoundaryID = suppression.sourceBoundaryReference.id
        projectedStartDate = suppression.projectedStartDate
        projectedEndDate = suppression.projectedEndDate
        nextBoundaryKindRaw = suppression.nextBoundaryReference?.kind.rawValue
        nextBoundaryID = suppression.nextBoundaryReference?.id
        nextBoundaryDate = suppression.nextBoundaryDate
        goalHoursSnapshot = suppression.goalHoursSnapshot
        createdAt = suppression.createdAt
        updatedAt = suppression.updatedAt
    }
}
