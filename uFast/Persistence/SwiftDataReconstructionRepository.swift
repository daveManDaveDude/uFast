import Foundation
import SwiftData

enum ReconstructionPersistenceError: Error, Equatable {
    case staleEvidence
    case simulatedSaveFailure
    case recordNotFound
    case invalidAdjustment
}

@MainActor
final class SwiftDataReconstructionRepository {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private let simulateSaveFailure: Bool

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        simulateSaveFailure: Bool = false
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.simulateSaveFailure = simulateSaveFailure
    }

    func generation(range: Range<Date>) throws -> ReconstructionGeneration {
        let food = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>()).map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: $0.isCaloric
            )
        }
        let hydration = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>()).map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: $0.isCaloric
            )
        }
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        let unknowns = try modelContext.fetch(FetchDescriptor<UnknownPeriodRecord>())
        let representedPairs = Set(
            fasts.compactMap { fast in
                fast.origin == .reconstructed ? fast.boundaryPair : nil
            } + unknowns.map(\.boundaryPair)
        )

        return ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: CaloricBoundaryExtractor.boundaries(
                food: food,
                hydration: hydration
            ),
            savedFasts: fasts.map(\.recordedInterval),
            representedPairs: representedPairs
        )
    }

    func commit(
        reviewed: [ReviewedReconstruction],
        expectedGeneration: ReconstructionGeneration,
        range: Range<Date>
    ) throws {
        let currentGeneration = try generation(range: range)
        guard currentGeneration == expectedGeneration else {
            throw ReconstructionPersistenceError.staleEvidence
        }

        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        let outcomes = try ReconstructionReviewValidator.validate(
            reviewed: reviewed,
            expectedResults: expectedGeneration.results,
            savedFasts: fasts.map(\.recordedInterval)
        )
        var insertedFasts: [FastRecord] = []
        var insertedUnknowns: [UnknownPeriodRecord] = []

        for outcome in outcomes {
            switch outcome.kind {
            case let .fast(startDate, endDate, adjusted):
                let fast = FastRecord(
                    reconstructedStart: startDate,
                    endDate: endDate,
                    boundaries: outcome.candidate.pair,
                    adjustedByUser: adjusted
                )
                modelContext.insert(fast)
                insertedFasts.append(fast)
            case let .unknown(reason):
                let unknown = UnknownPeriodRecord(
                    startDate: outcome.candidate.startDate,
                    endDate: outcome.candidate.endDate,
                    boundaries: outcome.candidate.pair,
                    reason: reason,
                    createdAt: clock.now
                )
                modelContext.insert(unknown)
                insertedUnknowns.append(unknown)
            }
        }

        do {
            if simulateSaveFailure {
                throw ReconstructionPersistenceError.simulatedSaveFailure
            }
            try modelContext.save()
        } catch {
            insertedFasts.forEach(modelContext.delete)
            insertedUnknowns.forEach(modelContext.delete)
            modelContext.rollback()
            throw error
        }
    }

    func supportingCandidate(for fast: FastRecord) throws -> ReconstructionCandidate? {
        guard let pair = fast.boundaryPair,
              let start = try boundary(pair.start),
              let end = try boundary(pair.end),
              start.occurredAt < end.occurredAt
        else { return nil }
        return ReconstructionCandidate(
            pair: pair,
            startBoundary: start,
            endBoundary: end
        )
    }

    func updatedEvidence(for fast: FastRecord) throws -> UpdatedReconstructionEvidence {
        guard fast.origin == .reconstructed,
              fast.reviewState == .needsReview,
              let endDate = fast.endDate,
              let pair = fast.boundaryPair
        else { throw ReconstructionPersistenceError.recordNotFound }
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        return try UpdatedReconstructionEvidenceResolver.resolve(
            savedInterval: fast.startDate ..< endDate,
            originalPair: pair,
            boundaries: caloricBoundaries(),
            otherFasts: fasts.filter { $0.id != fast.id }.map(\.recordedInterval)
        )
    }

    func updateAndReconfirm(id: UUID) throws {
        try failIfRequested()
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        guard let fast = fasts.first(where: {
            $0.id == id && $0.origin == .reconstructed && $0.reviewState == .needsReview
        }),
            case let .available(candidate) = try updatedEvidence(for: fast)
        else { throw ReconstructionPersistenceError.invalidAdjustment }
        let oldStart = fast.startDate
        let oldEnd = fast.endDate
        let oldProvenance = fast.provenanceSnapshot
        fast.reconfirm(
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            boundaries: candidate.pair,
            adjustedByUser: fast.wasAdjustedByUser
        )
        do {
            try modelContext.save()
        } catch {
            if let oldEnd {
                fast.correctBoundaries(startDate: oldStart, endDate: oldEnd)
            }
            fast.restoreProvenance(oldProvenance)
            throw error
        }
    }

    func keepAsRecordedFast(id: UUID) throws {
        try failIfRequested()
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        guard let fast = fasts.first(where: {
            $0.id == id && $0.origin == .reconstructed && $0.reviewState == .needsReview
        }) else { throw ReconstructionPersistenceError.recordNotFound }
        let oldProvenance = fast.provenanceSnapshot
        fast.convertToRecordedWithoutHistoricalGoal()
        do {
            try modelContext.save()
        } catch {
            fast.restoreProvenance(oldProvenance)
            throw error
        }
    }

    func adjustReconstructedFast(
        id: UUID,
        startDate: Date,
        endDate: Date
    ) throws {
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        guard let fast = fasts.first(where: { $0.id == id && $0.origin == .reconstructed }),
              let candidate = try supportingCandidate(for: fast),
              startDate >= candidate.startDate,
              endDate <= candidate.endDate,
              startDate < endDate,
              !FastConflictChecker.hasConflict(
                  proposedStart: startDate,
                  proposedEnd: endDate,
                  excluding: fast.id,
                  among: fasts.map(\.recordedInterval)
              )
        else { throw ReconstructionPersistenceError.invalidAdjustment }

        let oldStart = fast.startDate
        let oldEnd = fast.endDate
        let oldProvenance = fast.provenanceSnapshot
        fast.reconfirm(
            startDate: startDate,
            endDate: endDate,
            boundaries: candidate.pair,
            adjustedByUser: true
        )
        do {
            try save()
        } catch {
            if let oldEnd {
                fast.correctBoundaries(startDate: oldStart, endDate: oldEnd)
            }
            fast.restoreProvenance(oldProvenance)
            throw error
        }
    }

    func removeAndLeaveUnknown(id: UUID) throws {
        try failIfRequested()
        let fasts = try modelContext.fetch(FetchDescriptor<FastRecord>())
        guard let fast = fasts.first(where: { $0.id == id && $0.origin == .reconstructed }),
              let endDate = fast.endDate,
              let pair = fast.boundaryPair
        else { throw ReconstructionPersistenceError.recordNotFound }
        let unknown = UnknownPeriodRecord(
            startDate: fast.startDate,
            endDate: endDate,
            boundaries: pair,
            reason: .userChoice,
            createdAt: clock.now
        )
        modelContext.insert(unknown)
        modelContext.delete(fast)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func removeUnknownMarker(id: UUID) throws {
        try failIfRequested()
        let unknowns = try modelContext.fetch(FetchDescriptor<UnknownPeriodRecord>())
        guard let unknown = unknowns.first(where: { $0.id == id }) else {
            throw ReconstructionPersistenceError.recordNotFound
        }
        modelContext.delete(unknown)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func boundary(_ reference: CaloricBoundaryReference) throws -> CaloricBoundary? {
        switch reference.kind {
        case .food:
            try modelContext.fetch(FetchDescriptor<FoodEntryRecord>())
                .first(where: { $0.id == reference.id && $0.isCaloric })
                .map {
                    CaloricBoundary(
                        reference: reference,
                        occurredAt: $0.occurredAt,
                        description: $0.foodDescription
                    )
                }
        case .hydration:
            try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>())
                .first(where: { $0.id == reference.id && $0.isCaloric })
                .map {
                    CaloricBoundary(
                        reference: reference,
                        occurredAt: $0.occurredAt,
                        description: $0.displayName
                    )
                }
        }
    }

    private func caloricBoundaries() throws -> [CaloricBoundary] {
        let food = try modelContext.fetch(FetchDescriptor<FoodEntryRecord>()).map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: $0.isCaloric
            )
        }
        let hydration = try modelContext.fetch(FetchDescriptor<HydrationEntryRecord>()).map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: $0.isCaloric
            )
        }
        return CaloricBoundaryExtractor.boundaries(food: food, hydration: hydration)
    }

    private func save() throws {
        try failIfRequested()
        try modelContext.save()
    }

    private func failIfRequested() throws {
        if simulateSaveFailure {
            throw ReconstructionPersistenceError.simulatedSaveFailure
        }
    }
}
