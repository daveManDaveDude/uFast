import Foundation

@MainActor
extension ApplicationCommands {
    // swiftlint:disable:next function_parameter_count
    func deleteInferredFast(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String,
        expectedGoal: FastingGoal,
        expectedState: InferredFastState
    ) throws {
        do {
            let candidate = try revalidatedInferredCandidate(
                sourceBoundaryReference: sourceBoundaryReference,
                expectedStartDate: expectedStartDate,
                expectedEndDate: expectedEndDate,
                expectedSourceDescription: expectedSourceDescription,
                expectedGoal: expectedGoal,
                expectedState: expectedState
            )
            let store = InferredFastSuppressionStore(
                modelContext: modelContext,
                diagnosticSink: diagnosticSink
            )
            try commitSuppressionMutation {
                try store.insert(InferredFastSuppressionDecider.make(candidate: candidate, at: clock.now))
            }
            projectionCoordinator.publishHistoryInvalidation()
        } catch is InferredFastConversionError {
            throw InferredFastSuppressionError.candidateUnavailable
        } catch let error as InferredFastSuppressionError {
            throw error
        }
    }

    // swiftlint:disable:next function_parameter_count
    func reenableInferredFast(
        sourceBoundaryReference: CaloricBoundaryReference,
        expectedStartDate: Date,
        expectedEndDate: Date,
        expectedSourceDescription: String,
        expectedGoal: FastingGoal,
        expectedState: InferredFastState
    ) throws {
        guard !configuration.simulateSuppressionReenableStale else {
            throw InferredFastSuppressionError.candidateUnavailable
        }
        do {
            _ = try revalidatedInferredCandidate(
                sourceBoundaryReference: sourceBoundaryReference,
                expectedStartDate: expectedStartDate,
                expectedEndDate: expectedEndDate,
                expectedSourceDescription: expectedSourceDescription,
                expectedGoal: expectedGoal,
                expectedState: expectedState
            )
            let store = InferredFastSuppressionStore(
                modelContext: modelContext,
                diagnosticSink: diagnosticSink
            )
            guard try store.all().contains(where: {
                $0.sourceBoundaryReference == sourceBoundaryReference
            }) else {
                throw InferredFastSuppressionError.suppressionUnavailable
            }
            try commitSuppressionMutation {
                try store.remove(source: sourceBoundaryReference)
            }
            projectionCoordinator.publishHistoryInvalidation()
        } catch is InferredFastConversionError {
            throw InferredFastSuppressionError.candidateUnavailable
        } catch let error as InferredFastSuppressionError {
            throw error
        }
    }

    private func commitSuppressionMutation(
        _ changes: () throws -> Void
    ) throws {
        let store = InferredFastSuppressionStore(
            modelContext: modelContext,
            diagnosticSink: diagnosticSink
        )
        let snapshot = try store.snapshot()
        let transaction = PersistenceTransaction(
            modelContext: modelContext,
            saveAction: configuration.simulateSuppressionSaveFailure ? {
                throw InferredFastSuppressionError.simulatedSaveFailure
            } : nil
        )
        do {
            try changes()
        } catch {
            snapshot.restore(in: modelContext)
            modelContext.rollback()
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
        do {
            try transaction.save()
        } catch {
            PersistenceTransactionDiagnostics.recordFailure(to: diagnosticSink)
            throw error
        }
    }

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

        let planner = CaloricBoundaryPersistencePlanner(
            modelContext: modelContext,
            observationSink: observationSink
        )
        let recorded = try planner.fasts().map {
            RecordedFastInterval(id: $0.id, startDate: $0.startDate, endDate: $0.endDate)
        }
        guard let candidate = try InferredFastProjector.project(
            boundaries: planner.allBoundaries(),
            recordedFasts: [],
            currentGoal: settings.fastingGoal,
            enabled: true,
            now: clock.now
        ).first(where: { $0.sourceBoundaryReference == sourceBoundaryReference }),
            candidate.sourceDate == expectedStartDate,
            candidate.sourceDescription == sourceDescription
        else { throw InferredFastConversionError.candidateUnavailable }
        guard expectedState == .inProgress || candidate.endDate == expectedEndDate,
              candidate.state == expectedState
        else { throw InferredFastConversionError.candidateUnavailable }
        guard !recorded.contains(where: {
            InferredFastProjector.overlaps(candidate.interval, $0)
        }) else {
            throw InferredFastConversionError.conflictingRecordedFast
        }
        return candidate
    }
}
