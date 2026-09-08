import Foundation

struct TemporalRibbonIntervalItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case recorded
        case active
        case automatic
        case inferred
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
    let duration: HistoryDurationSpec?

    init(
        id: UUID,
        start: Date,
        end: Date,
        title: String,
        detail: String,
        accessibilityLabel: String,
        kind: Kind,
        duration: HistoryDurationSpec? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.detail = detail
        self.accessibilityLabel = accessibilityLabel
        self.kind = kind
        self.duration = duration
    }
}

struct TemporalRibbonEventItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
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
