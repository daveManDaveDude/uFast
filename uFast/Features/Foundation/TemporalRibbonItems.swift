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
    let compactTitle: String?
    let detail: String
    let accessibilityLabel: String
    let kind: Kind

    /// Active Fast is deliberately not squeezed into the compact label slot.
    /// Its longer state label needs the regular slot to remain full-sized and
    /// readable; shorter interval labels can still use the compact treatment.
    var visualContentMinimumWidth: Double {
        kind == .active
            ? TemporalRibbonGeometry.regularContentMinimumWidth
            : TemporalRibbonGeometry.compactContentMinimumWidth
    }

    init(
        id: UUID,
        start: Date,
        end: Date,
        title: String,
        compactTitle: String? = nil,
        detail: String,
        accessibilityLabel: String,
        kind: Kind
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.compactTitle = compactTitle
        self.detail = detail
        self.accessibilityLabel = accessibilityLabel
        self.kind = kind
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
