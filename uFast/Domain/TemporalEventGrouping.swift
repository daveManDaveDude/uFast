import Foundation

// swiftlint:disable trailing_comma

/// The two event families intentionally remain distinct because they have
/// different meanings, symbols and editors.
enum TemporalEventFamily: String, CaseIterable, Equatable, Hashable, Sendable {
    case food
    case hydration
}

/// Presentation categories are intentionally more specific than the storage
/// and editor family. A hydration record still routes to the hydration editor,
/// while the History ribbon keeps caloric and non-caloric drinks independent.
enum TemporalEventPresentationCategory: String, CaseIterable, Equatable, Hashable, Sendable {
    case food
    case caloricDrink = "caloric-drink"
    case nonCaloricDrink = "non-caloric-drink"

    var family: TemporalEventFamily {
        self == .food ? .food : .hydration
    }

    var isCaloric: Bool {
        self != .nonCaloricDrink
    }

    var sortOrder: Int {
        switch self {
        case .food: 0
        case .caloricDrink: 1
        case .nonCaloricDrink: 2
        }
    }
}

/// A typed reference prevents a food UUID and a hydration UUID from being
/// treated as interchangeable during presentation or deletion.
struct TemporalEventReference: Equatable, Hashable, Sendable {
    let family: TemporalEventFamily
    let id: UUID

    var stableValue: String {
        "\(family.rawValue):\(id.uuidString.lowercased())"
    }
}

struct TemporalEventGroupingInput: Equatable, Sendable {
    let reference: TemporalEventReference
    let occurredAt: Date
    let title: String
    let detail: String
    let accessibilityLabel: String
    let isCaloric: Bool
    let presentationCategory: TemporalEventPresentationCategory

    init(
        reference: TemporalEventReference,
        occurredAt: Date,
        title: String,
        detail: String,
        accessibilityLabel: String,
        isCaloric: Bool,
        presentationCategory: TemporalEventPresentationCategory? = nil
    ) {
        self.reference = reference
        self.occurredAt = occurredAt
        self.title = title
        self.detail = detail
        self.accessibilityLabel = accessibilityLabel
        self.isCaloric = isCaloric
        self.presentationCategory = presentationCategory
            ?? (reference.family == .food
                ? .food
                : (isCaloric ? .caloricDrink : .nonCaloricDrink))
    }

    var family: TemporalEventFamily {
        reference.family
    }
}

struct TemporalEventBucket: Equatable, Hashable, Sendable {
    let start: Date
    let end: Date

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

struct TemporalEventGroupID: Equatable, Hashable, Sendable {
    let family: TemporalEventFamily
    let presentationCategory: TemporalEventPresentationCategory
    let bucket: TemporalEventBucket
    let memberReferences: [TemporalEventReference]

    var stableValue: String {
        let members = memberReferences.map(\.stableValue).joined(separator: ",")
        return [
            family.rawValue,
            presentationCategory.rawValue,
            String(bucket.start.timeIntervalSince1970),
            String(bucket.end.timeIntervalSince1970),
            members,
        ].joined(separator: "|")
    }
}

struct TemporalEventGroup: Identifiable, Equatable, Sendable {
    let id: TemporalEventGroupID
    let bucket: TemporalEventBucket
    let family: TemporalEventFamily
    let presentationCategory: TemporalEventPresentationCategory
    let members: [TemporalEventGroupingInput]

    init(
        bucket: TemporalEventBucket,
        family: TemporalEventFamily,
        presentationCategory: TemporalEventPresentationCategory,
        members: [TemporalEventGroupingInput]
    ) {
        self.bucket = bucket
        self.family = family
        self.presentationCategory = presentationCategory
        self.members = members.sorted(by: TemporalEventGrouping.memberOrder)
        id = TemporalEventGroupID(
            family: family,
            presentationCategory: presentationCategory,
            bucket: bucket,
            memberReferences: self.members.map(\.reference)
        )
    }

    var count: Int {
        members.count
    }

    var memberReferences: [TemporalEventReference] {
        members.map(\.reference)
    }

    var visualCountText: String {
        count > 99 ? "99+" : String(count)
    }

    /// Returns the shared member title when the group can use it as a
    /// presentation title. Family/count wording belongs to the catalog-backed
    /// History presentation layer, not to the grouping domain model.
    var commonMemberTitle: String? {
        guard Set(members.map(\.title)).count == 1 else { return nil }
        return members.first?.title
    }
}

enum TemporalEventPresentationItem: Identifiable, Equatable, Sendable {
    case single(bucket: TemporalEventBucket, member: TemporalEventGroupingInput)
    case group(TemporalEventGroup)

    var id: String {
        switch self {
        case let .single(_, member):
            "single|\(member.reference.stableValue)"
        case let .group(group):
            "group|\(group.id.stableValue)"
        }
    }

    var bucket: TemporalEventBucket {
        switch self {
        case let .single(bucket, _): bucket
        case let .group(group): group.bucket
        }
    }

    var family: TemporalEventFamily {
        switch self {
        case let .single(_, member): member.reference.family
        case let .group(group): group.family
        }
    }

    var presentationCategory: TemporalEventPresentationCategory {
        switch self {
        case let .single(_, member): member.presentationCategory
        case let .group(group): group.presentationCategory
        }
    }

    var memberReferences: [TemporalEventReference] {
        switch self {
        case let .single(_, member): [member.reference]
        case let .group(group): group.members.map(\.reference)
        }
    }

    var group: TemporalEventGroup? {
        if case let .group(group) = self {
            return group
        }
        return nil
    }
}
