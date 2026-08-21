import Foundation
import SwiftData

struct PresentedCaloricEventImpact: Equatable {
    let before: [InferredFastInterval]
    let after: [InferredFastInterval]

    static let none = Self(before: [], after: [])

    var requiresConfirmation: Bool {
        let beforeBySource = Dictionary(uniqueKeysWithValues: before.map {
            ($0.sourceBoundaryReference, ($0.startDate, $0.endDate))
        })
        let afterBySource = Dictionary(uniqueKeysWithValues: after.map {
            ($0.sourceBoundaryReference, ($0.startDate, $0.endDate))
        })
        return beforeBySource.contains { sourceReference, beforeIdentity in
            guard let afterIdentity = afterBySource[sourceReference] else {
                return true
            }
            return afterIdentity.0 != beforeIdentity.0
                || afterIdentity.1 < beforeIdentity.1
        }
    }
}

@MainActor
final class CaloricEventImpactPresenter {
    private let modelContext: ModelContext
    private let clock: any AppClock
    private let observationSink: BoundaryQueryObservationSink

    init(
        modelContext: ModelContext,
        clock: any AppClock,
        observationSink: BoundaryQueryObservationSink
    ) {
        self.modelContext = modelContext
        self.clock = clock
        self.observationSink = observationSink
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func presentedImpact(
        resultingEventReference: CaloricBoundaryReference,
        resultingEventDate: Date,
        resultingEventIsCaloric: Bool,
        replacing reference: CaloricBoundaryReference?
    ) throws -> PresentedCaloricEventImpact {
        guard let settings = try settingsRecord(), settings.inferredFastDetectionEnabled else {
            return .none
        }
        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let maximumDuration = InferredFastProjector.maximumDuration(for: settings.fastingGoal)
        var dates = [resultingEventDate]
        if let reference {
            switch reference.kind {
            case .food:
                if case let .unique(record) = try query.food(id: reference.id) {
                    dates.append(record.occurredAt)
                }
            case .hydration:
                if case let .unique(record) = try query.hydration(id: reference.id) {
                    dates.append(record.occurredAt)
                }
            }
        }

        var beforeBoundaries: [CaloricBoundary] = []
        var exactCandidateBoundaries: [CaloricBoundary] = []
        var predecessorBoundaries: [CaloricBoundary] = []
        for date in dates {
            let exactFoods = try query.exactFood(at: date)
            let exactHydration = try query.exactCaloricHydration(at: date)
            let exactBoundaries = boundaries(food: exactFoods, hydration: exactHydration)
            beforeBoundaries.append(contentsOf: exactBoundaries)
            exactCandidateBoundaries.append(contentsOf: exactBoundaries)

            let lowerBound = date.addingTimeInterval(-maximumDuration)
            if let food = try query.nearestFood(before: date, notBefore: lowerBound).first {
                let predecessor = CaloricBoundary(
                    reference: .init(kind: .food, id: food.id),
                    occurredAt: food.occurredAt,
                    description: food.foodDescription
                )
                beforeBoundaries.append(predecessor)
                predecessorBoundaries.append(predecessor)
            }
            if let drink = try query.nearestCaloricHydration(
                before: date,
                notBefore: lowerBound
            ).first {
                let predecessor = CaloricBoundary(
                    reference: .init(kind: .hydration, id: drink.id),
                    occurredAt: drink.occurredAt,
                    description: drink.displayName
                )
                beforeBoundaries.append(predecessor)
                predecessorBoundaries.append(predecessor)
            }

            let upper = min(clock.now, date.addingTimeInterval(maximumDuration))
            if upper > date {
                try beforeBoundaries.append(contentsOf: boundaries(
                    food: query.firstFood(in: date ..< upper),
                    hydration: query.firstCaloricHydration(in: date ..< upper)
                ))
            }
        }

        beforeBoundaries = uniqueBoundaries(beforeBoundaries)
        exactCandidateBoundaries = uniqueBoundaries(exactCandidateBoundaries)
        let afterBoundaries = beforeBoundaries
            .filter { $0.reference != reference }
            .adding(
                resultingEventIsCaloric
                    ? CaloricBoundary(
                        reference: resultingEventReference,
                        occurredAt: resultingEventDate,
                        description: ""
                    )
                    : nil
            )

        var recordedByID: [UUID: RecordedFastInterval] = [:]
        var recordedCandidates = predecessorBoundaries + exactCandidateBoundaries
        if resultingEventIsCaloric {
            recordedCandidates.append(CaloricBoundary(
                reference: resultingEventReference,
                occurredAt: resultingEventDate,
                description: ""
            ))
        }
        for boundary in uniqueBoundaries(recordedCandidates) {
            let cap = min(clock.now, boundary.occurredAt.addingTimeInterval(maximumDuration))
            guard cap > boundary.occurredAt else { continue }
            for fast in try query.fasts(overlapping: boundary.occurredAt ..< cap) {
                recordedByID[fast.id] = fast.recordedInterval
            }
        }
        if let reference {
            for fast in try query.reconstructedFasts(endingWith: reference) {
                recordedByID[fast.id] = fast.recordedInterval
            }
        }
        let recorded = recordedByID.values.sorted { $0.id.uuidString < $1.id.uuidString }
        let beforeProjection = project(
            boundaries: beforeBoundaries,
            recordedFasts: recorded,
            goal: settings.fastingGoal
        )
        let afterProjection = project(
            boundaries: afterBoundaries,
            recordedFasts: recorded,
            goal: settings.fastingGoal
        )
        return PresentedCaloricEventImpact(before: beforeProjection, after: afterProjection)
    }

    private func settingsRecord() throws -> AppSettingsRecord? {
        do {
            return try SwiftDataSettingsStore(modelContext: modelContext).authoritativeRecord()
        } catch let error as SettingsStoreError {
            switch error {
            case .conflictingAuthorities:
                throw HydrationFavouriteStoreError.conflictingAuthorities
            default:
                throw error
            }
        }
    }

    private func boundaries(
        food: [FoodEntryRecord],
        hydration: [HydrationEntryRecord]
    ) -> [CaloricBoundary] {
        CaloricBoundaryExtractor.boundaries(
            food: food.map {
                FoodBoundarySnapshot(
                    id: $0.id,
                    occurredAt: $0.occurredAt,
                    description: $0.foodDescription,
                    isCaloric: true
                )
            },
            hydration: hydration.map {
                HydrationBoundarySnapshot(
                    id: $0.id,
                    occurredAt: $0.occurredAt,
                    description: $0.displayName,
                    isCaloric: true
                )
            }
        )
    }

    private func project(
        boundaries: [CaloricBoundary],
        recordedFasts: [RecordedFastInterval],
        goal: FastingGoal
    ) -> [InferredFastInterval] {
        InferredFastProjector.project(
            boundaries: boundaries,
            recordedFasts: recordedFasts,
            currentGoal: goal,
            enabled: true,
            now: clock.now,
            visibleInterval: Date.distantPast ..< Date.distantFuture
        )
    }

    private func uniqueBoundaries(_ boundaries: [CaloricBoundary]) -> [CaloricBoundary] {
        var seen = Set<CaloricBoundaryReference>()
        return CaloricBoundaryOrdering.sorted(boundaries).filter {
            seen.insert($0.reference).inserted
        }
    }
}
