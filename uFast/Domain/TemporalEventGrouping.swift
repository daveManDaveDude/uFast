import Foundation

// swiftlint:disable trailing_comma

/// The two event families intentionally remain distinct because they have
/// different meanings, symbols and editors.
enum TemporalEventFamily: String, CaseIterable, Equatable, Hashable, Sendable {
    case food
    case hydration

    var singularName: String {
        switch self {
        case .food: "food event"
        case .hydration: "drink"
        }
    }

    var pluralName: String {
        switch self {
        case .food: "food events"
        case .hydration: "drinks"
        }
    }
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

    var classificationSummary: String {
        switch presentationCategory {
        case .food:
            "Caloric food"
        case .caloricDrink:
            "Caloric drink"
        case .nonCaloricDrink:
            "Non-caloric drink"
        }
    }

    var allTitlesMatch: Bool {
        Set(members.map(\.title)).count == 1
    }

    var summaryTitle: String {
        if allTitlesMatch, let firstTitle = members.first?.title {
            return "\(firstTitle) ×\(count)"
        }
        return "\(count) \(family.pluralName)"
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

enum TemporalEventGrouping {
    static let visibleMarkerWidthFraction = 0.82

    static func project(
        _ inputs: [TemporalEventGroupingInput],
        in window: DateInterval,
        calendar: Calendar
    ) -> [TemporalEventPresentationItem] {
        let buckets = makeBuckets(intersecting: window, calendar: calendar)
        let visibleInputs = inputs.filter {
            $0.occurredAt >= window.start && $0.occurredAt < window.end
        }
        var membersByKey: [BucketCategoryKey: [TemporalEventGroupingInput]] = [:]

        for input in visibleInputs {
            guard let bucket = buckets.first(where: { $0.contains(input.occurredAt) }) else {
                continue
            }
            let key = BucketCategoryKey(
                bucket: bucket,
                category: input.presentationCategory
            )
            membersByKey[key, default: []].append(input)
        }

        return membersByKey
            .map { key, members in
                let orderedMembers = members.sorted(by: memberOrder)
                if orderedMembers.count >= 2 {
                    return .group(
                        TemporalEventGroup(
                            bucket: key.bucket,
                            family: key.category.family,
                            presentationCategory: key.category,
                            members: orderedMembers
                        )
                    )
                }
                return .single(bucket: key.bucket, member: orderedMembers[0])
            }
            .sorted(by: presentationOrder)
    }

    static func makeBuckets(
        intersecting window: DateInterval,
        calendar: Calendar
    ) -> [TemporalEventBucket] {
        guard window.start < window.end else { return [] }

        var buckets: [TemporalEventBucket] = []
        var day = calendar.startOfDay(for: window.start)
        while day < window.end {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            for hour in stride(from: 0, through: 22, by: 2) {
                guard let start = localBoundary(day: day, hour: hour, calendar: calendar) else {
                    continue
                }
                let end: Date? = if hour == 22 {
                    nextDay
                } else {
                    localBoundary(day: day, hour: hour + 2, calendar: calendar)
                }
                guard let end, start < end,
                      end > window.start, start < window.end
                else { continue }
                buckets.append(TemporalEventBucket(start: start, end: end))
            }

            day = nextDay
        }
        return buckets.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
    }

    static func bucket(
        containing instant: Date,
        calendar: Calendar
    ) -> TemporalEventBucket? {
        let day = calendar.startOfDay(for: instant)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
            return nil
        }
        for hour in stride(from: 0, through: 22, by: 2) {
            guard let start = localBoundary(day: day, hour: hour, calendar: calendar) else {
                continue
            }
            let end = hour == 22
                ? nextDay
                : localBoundary(day: day, hour: hour + 2, calendar: calendar)
            if let end, start <= instant, instant < end {
                return TemporalEventBucket(start: start, end: end)
            }
        }
        return nil
    }

    static func memberOrder(
        _ lhs: TemporalEventGroupingInput,
        _ rhs: TemporalEventGroupingInput
    ) -> Bool {
        lhs.occurredAt == rhs.occurredAt
            ? lhs.reference.stableValue < rhs.reference.stableValue
            : lhs.occurredAt < rhs.occurredAt
    }

    private static func presentationOrder(
        _ lhs: TemporalEventPresentationItem,
        _ rhs: TemporalEventPresentationItem
    ) -> Bool {
        if lhs.bucket.start != rhs.bucket.start {
            return lhs.bucket.start < rhs.bucket.start
        }
        if lhs.presentationCategory != rhs.presentationCategory {
            return lhs.presentationCategory.sortOrder < rhs.presentationCategory.sortOrder
        }
        return lhs.id < rhs.id
    }

    private static func localBoundary(
        day: Date,
        hour: Int,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private struct BucketCategoryKey: Hashable {
        let bucket: TemporalEventBucket
        let category: TemporalEventPresentationCategory
    }
}

struct TemporalEventGroupLayout: Equatable, Sendable {
    let centerFraction: Double
    let visibleWidth: Double
    let visibleWidthFraction: Double
    let interactiveWidth: Double
    let bucketStartFraction: Double
    let bucketEndFraction: Double

    static func make(
        bucketStartFraction: Double,
        bucketEndFraction: Double,
        ribbonWidth: Double
    ) -> Self? {
        guard ribbonWidth.isFinite, ribbonWidth > 0,
              bucketStartFraction.isFinite, bucketEndFraction.isFinite,
              bucketStartFraction <= bucketEndFraction
        else { return nil }
        let start = min(max(bucketStartFraction, 0), 1)
        let end = min(max(bucketEndFraction, 0), 1)
        let width = max(0, (end - start) * ribbonWidth)
        let visibleWidth = width * TemporalEventGrouping.visibleMarkerWidthFraction
        return Self(
            centerFraction: (start + end) / 2,
            visibleWidth: visibleWidth,
            visibleWidthFraction: (end - start) * TemporalEventGrouping.visibleMarkerWidthFraction,
            interactiveWidth: max(44, visibleWidth),
            bucketStartFraction: start,
            bucketEndFraction: end
        )
    }

    var visibleBounds: ClosedRange<Double> {
        let halfWidth = visibleWidthFraction / 2
        return (centerFraction - halfWidth) ... (centerFraction + halfWidth)
    }

    var visibleContentWidth: Double {
        max(1, min(44, visibleWidth))
    }
}

struct TemporalEventMarkerMetrics: Equatable, Sendable {
    let ribbonHeight: Double
    let eventAreaTop: Double
    let rowHeight: Double
    let rowIndex: Int
    let tileSize: Double
    let labelBandHeight: Double
    let labelGap: Double
    let hitHeight: Double

    static let normalRibbonHeight = 268.0
    static let accessibilityRibbonHeight = 320.0

    static func make(
        category: TemporalEventPresentationCategory,
        accessibilitySize: Bool
    ) -> Self {
        let rowHeight = accessibilitySize ? 68.0 : 52.0
        let rowIndex = category.sortOrder
        return Self(
            ribbonHeight: accessibilitySize ? accessibilityRibbonHeight : normalRibbonHeight,
            eventAreaTop: 122,
            rowHeight: rowHeight,
            rowIndex: rowIndex,
            tileSize: accessibilitySize ? 32 : 26,
            labelBandHeight: accessibilitySize ? 18 : 14,
            labelGap: accessibilitySize ? 3 : 2,
            hitHeight: max(44, rowHeight)
        )
    }

    var rowTop: Double {
        eventAreaTop + Double(rowIndex) * rowHeight
    }

    var cellHeight: Double {
        tileSize + labelGap + labelBandHeight
    }
}

struct TemporalRibbonSurfaceMetrics: Equatable, Sendable {
    static let topLabelClearance = 32.0

    static func gridRuleHeight(surfaceHeight: Double) -> Double {
        max(0, surfaceHeight - topLabelClearance)
    }
}
