import Foundation

@MainActor
extension ApplicationCommands {
    // The expectation captures presentation identity while allowing an
    // in-progress inferred end to advance with the injected clock.
    // swiftlint:disable:next function_body_length function_parameter_count cyclomatic_complexity
    func revalidatedInferredCandidate(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String?,
        expectedGoal: FastingGoal?,
        expectedState: InferredFastState
    ) throws -> InferredFastInterval {
        _ = try ActiveFastAuthority.fetch(
            in: modelContext,
            diagnosticSink: diagnosticSink
        )
        let settings: AppSettingsRecord?
        do {
            settings = try SwiftDataSettingsStore(
                modelContext: modelContext,
                diagnosticSink: diagnosticSink
            ).authoritativeRecord()
        } catch let error as SettingsStoreError {
            switch error {
            case .conflictingAuthorities:
                throw HydrationFavouriteStoreError.conflictingAuthorities
            default:
                throw error
            }
        }
        guard let settings,
              settings.inferredFastDetectionEnabled,
              expectedGoal == nil || expectedGoal == settings.fastingGoal
        else { throw InferredFastConversionError.candidateUnavailable }

        let query = SwiftDataCaloricBoundaryQueryAdapter(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let sourceDescription: String?
        switch sourceBoundaryReference.kind {
        case .food:
            guard case let .unique(source) = try query.food(id: sourceBoundaryReference.id) else {
                throw InferredFastConversionError.candidateUnavailable
            }
            sourceDescription = source.foodDescription
        case .hydration:
            guard case let .unique(source) = try query.hydration(id: sourceBoundaryReference.id) else {
                throw InferredFastConversionError.candidateUnavailable
            }
            sourceDescription = source.displayName
        }
        guard let sourceDescription,
              expectedSourceDescription == nil || sourceDescription == expectedSourceDescription
        else { throw InferredFastConversionError.candidateUnavailable }

        let sourceBoundaries = try CaloricBoundaryExtractor.boundaries(
            food: query.exactFood(at: expectedStartDate).map {
                FoodBoundarySnapshot(
                    id: $0.id,
                    occurredAt: $0.occurredAt,
                    description: $0.foodDescription,
                    isCaloric: true
                )
            },
            hydration: query.exactCaloricHydration(at: expectedStartDate).map {
                HydrationBoundarySnapshot(
                    id: $0.id,
                    occurredAt: $0.occurredAt,
                    description: $0.displayName,
                    isCaloric: true
                )
            }
        )
        guard let sourceBoundary = sourceBoundaries.first(where: {
            $0.reference == sourceBoundaryReference
        }), sourceBoundary.occurredAt == expectedStartDate,
        sourceBoundaries.first?.reference == sourceBoundaryReference
        else { throw InferredFastConversionError.candidateUnavailable }

        let maximumDate = expectedStartDate.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: settings.fastingGoal)
        )
        let laterUpperBound = min(clock.now, maximumDate)
        let laterBoundaries = try CaloricBoundaryExtractor.boundaries(
            food: laterUpperBound > expectedStartDate
                ? query.firstFood(in: expectedStartDate ..< laterUpperBound).map {
                    FoodBoundarySnapshot(
                        id: $0.id,
                        occurredAt: $0.occurredAt,
                        description: $0.foodDescription,
                        isCaloric: true
                    )
                }
                : [],
            hydration: laterUpperBound > expectedStartDate
                ? query.firstCaloricHydration(in: expectedStartDate ..< laterUpperBound).map {
                    HydrationBoundarySnapshot(
                        id: $0.id,
                        occurredAt: $0.occurredAt,
                        description: $0.displayName,
                        isCaloric: true
                    )
                }
                : []
        )
        let laterBoundary = laterBoundaries.first {
            $0.occurredAt > expectedStartDate && $0.occurredAt <= clock.now
                && $0.occurredAt < maximumDate
        }
        let eligibilityDeadline = expectedStartDate
            .addingTimeInterval(InferredFastProjector.eligibilityDuration)
        if let laterBoundary, laterBoundary.occurredAt < eligibilityDeadline {
            throw InferredFastConversionError.candidateUnavailable
        }
        let endDate = min(laterBoundary?.occurredAt ?? clock.now, maximumDate)
        guard expectedStartDate < endDate else {
            throw InferredFastConversionError.candidateUnavailable
        }
        let state: InferredFastState = laterBoundary == nil && clock.now < maximumDate
            ? .inProgress
            : .historical
        let candidate = InferredFastInterval(
            sourceBoundaryReference: sourceBoundaryReference,
            sourceDate: expectedStartDate,
            sourceDescription: sourceDescription,
            nextBoundaryReference: laterBoundary?.reference,
            nextBoundaryDate: laterBoundary?.occurredAt,
            startDate: expectedStartDate,
            endDate: endDate,
            goal: settings.fastingGoal,
            state: state
        )
        guard expectedState == .inProgress || candidate.endDate == expectedEndDate,
              candidate.state == expectedState
        else { throw InferredFastConversionError.candidateUnavailable }
        guard try !query.hasFastConflict(
            proposedStart: candidate.startDate,
            proposedEnd: candidate.endDate,
            excluding: nil
        ) else {
            throw InferredFastConversionError.conflictingRecordedFast
        }
        return candidate
    }
}
