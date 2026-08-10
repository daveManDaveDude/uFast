import Foundation

struct TemporalRibbonIntervalItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case recorded
        case active
        case automatic
        case previouslySaved
        case reconstructed
        case needsReview
        case unknown
    }

    let id: UUID
    let start: Date
    let end: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let kind: Kind
}

struct TemporalRibbonEventItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case food
        case caloricDrink
        case nonCaloricDrink
    }

    let id: UUID
    let occurredAt: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let kind: Kind

    var family: TemporalEventFamily {
        kind == .food ? .food : .hydration
    }

    var isCaloric: Bool {
        kind == .food || kind == .caloricDrink
    }

    var presentationCategory: TemporalEventPresentationCategory {
        switch kind {
        case .food: .food
        case .caloricDrink: .caloricDrink
        case .nonCaloricDrink: .nonCaloricDrink
        }
    }

    var reference: TemporalEventReference {
        TemporalEventReference(family: family, id: id)
    }

    var groupingInput: TemporalEventGroupingInput {
        TemporalEventGroupingInput(
            reference: reference,
            occurredAt: occurredAt,
            title: title,
            detail: detail,
            accessibilityLabel: accessibilityLabel,
            isCaloric: isCaloric,
            presentationCategory: presentationCategory
        )
    }
}
