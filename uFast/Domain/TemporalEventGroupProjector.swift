import Foundation

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
