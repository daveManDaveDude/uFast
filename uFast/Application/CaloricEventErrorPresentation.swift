enum CaloricEventErrorPresentation: Equatable {
    case confirmation(CaloricEventConfirmationContext)
    case eventAtActiveFastStart
    case fastConflict
    case saveFailure
}

extension FoodEntrySaveError {
    var presentation: CaloricEventErrorPresentation {
        switch self {
        case let .confirmationRequiredWithImpact(context),
             let .completedConfirmationWithImpact(context),
             let .inferredConfirmationWithImpact(context):
            .confirmation(context)
        case .confirmationRequired:
            .confirmation(.init(fallbackKind: .active))
        case .completedFastConfirmationRequired:
            .confirmation(.init(fallbackKind: .completed))
        case .inferredFastConfirmationRequired:
            .confirmation(.init(fallbackKind: .inferred))
        case .eventAtActiveFastStart:
            .eventAtActiveFastStart
        case .fastConflict:
            .fastConflict
        }
    }
}

extension HydrationEntrySaveError {
    var presentation: CaloricEventErrorPresentation {
        switch self {
        case let .confirmationRequiredWithImpact(context),
             let .completedConfirmationWithImpact(context),
             let .inferredConfirmationWithImpact(context):
            .confirmation(context)
        case .confirmationRequired:
            .confirmation(.init(fallbackKind: .active))
        case .completedFastConfirmationRequired:
            .confirmation(.init(fallbackKind: .completed))
        case .inferredFastConfirmationRequired:
            .confirmation(.init(fallbackKind: .inferred))
        case .eventAtActiveFastStart:
            .eventAtActiveFastStart
        case .fastConflict:
            .fastConflict
        }
    }
}
