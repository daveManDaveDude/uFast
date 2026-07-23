import Foundation

// swiftlint:disable file_length opening_brace

struct TemporalRibbonWindow: Equatable, Sendable {
    let selectedDay: Date
    let selectedDayInterval: DateInterval
    let interval: DateInterval
    let midnightMarkers: [Date]

    var duration: TimeInterval {
        interval.duration
    }

    func fraction(for date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(interval.start) / duration, 0), 1)
    }

    func contains(_ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    func instant(at fraction: Double) -> Date {
        interval.start.addingTimeInterval(duration * min(max(fraction, 0), 1))
    }
}

struct TemporalIntervalInput: Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
}

struct TemporalIntervalSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    let originalStart: Date
    let originalEnd: Date
    let visibleStart: Date
    let visibleEnd: Date
    let continuesBefore: Bool
    let continuesAfter: Bool
    let lane: Int

    func startFraction(in window: TemporalRibbonWindow) -> Double {
        window.fraction(for: visibleStart)
    }

    func endFraction(in window: TemporalRibbonWindow) -> Double {
        window.fraction(for: visibleEnd)
    }
}

struct TemporalEventOrderingValue: Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
}

struct TemporalFormattingContext: Sendable {
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
}

enum TemporalDaySelectionSource: Equatable, Sendable {
    case initial
    case dateChip
    case carousel
    case pager
    case datePicker
    case accessibility
    case timeline
}

struct TemporalDaySelectionChange: Equatable, Sendable {
    let day: Date
    let source: TemporalDaySelectionSource
    let revision: Int
}

struct TemporalDaySelectionCoordinator: Equatable, Sendable {
    private(set) var selectedDay: Date
    private(set) var source: TemporalDaySelectionSource
    private(set) var revision: Int

    init(selectedDate: Date, calendar: Calendar) {
        selectedDay = calendar.startOfDay(for: selectedDate)
        source = .initial
        revision = 0
    }

    mutating func select(
        _ date: Date,
        source: TemporalDaySelectionSource,
        calendar: Calendar
    ) -> TemporalDaySelectionChange? {
        let canonicalDay = calendar.startOfDay(for: date)
        guard canonicalDay != selectedDay else {
            return nil
        }
        selectedDay = canonicalDay
        self.source = source
        revision += 1
        return TemporalDaySelectionChange(day: canonicalDay, source: source, revision: revision)
    }
}

enum TemporalCarouselMovementPhase: Equatable, Sendable {
    case settled
    case userDriven
    case decelerating
    case programmatic

    var suppressesAutomaticAlignment: Bool {
        self != .settled
    }

    var allowsTimelineInteraction: Bool {
        self == .settled
    }
}

struct TemporalDayBuffer: Equatable, Sendable {
    private(set) var days: [Date]

    init(
        centeredOn selectedDate: Date,
        maximumDate: Date,
        calendar: Calendar,
        radius: Int = 400
    ) {
        let maximumDay = calendar.startOfDay(for: maximumDate)
        let selectedDay = min(calendar.startOfDay(for: selectedDate), maximumDay)
        let safeRadius = max(radius, 1)
        guard let proposedStart = calendar.date(
            byAdding: .day,
            value: -safeRadius,
            to: selectedDay
        ),
            let proposedEnd = calendar.date(
                byAdding: .day,
                value: safeRadius,
                to: selectedDay
            )
        else {
            days = [selectedDay]
            return
        }
        days = Self.calendarDays(
            from: proposedStart,
            through: min(proposedEnd, maximumDay),
            calendar: calendar
        )
    }

    mutating func ensureCoverage(
        around selectedDate: Date,
        maximumDate: Date,
        calendar: Calendar,
        edgeThreshold: Int = 7,
        expansion: Int = 30
    ) {
        let maximumDay = calendar.startOfDay(for: maximumDate)
        let selectedDay = min(calendar.startOfDay(for: selectedDate), maximumDay)
        let safeExpansion = max(expansion, 1)
        guard let index = days.firstIndex(of: selectedDay),
              let firstDay = days.first,
              let lastDay = days.last
        else {
            self = Self(
                centeredOn: selectedDay,
                maximumDate: maximumDay,
                calendar: calendar,
                radius: safeExpansion
            )
            return
        }

        let safeThreshold = max(edgeThreshold, 0)
        if index <= safeThreshold,
           let newStart = calendar.date(
               byAdding: .day,
               value: -safeExpansion,
               to: firstDay
           ),
           let dayBeforeFirst = calendar.date(byAdding: .day, value: -1, to: firstDay)
        {
            days.insert(
                contentsOf: Self.calendarDays(
                    from: newStart,
                    through: dayBeforeFirst,
                    calendar: calendar
                ),
                at: 0
            )
        }

        if days.count - 1 - index <= safeThreshold,
           lastDay < maximumDay,
           let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: lastDay),
           let proposedEnd = calendar.date(
               byAdding: .day,
               value: safeExpansion,
               to: lastDay
           )
        {
            days.append(
                contentsOf: Self.calendarDays(
                    from: dayAfterLast,
                    through: min(proposedEnd, maximumDay),
                    calendar: calendar
                )
            )
        }
    }

    private static func calendarDays(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        guard start <= end else { return [] }
        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor),
                  next > cursor
            else { break }
            cursor = calendar.startOfDay(for: next)
        }
        return result
    }
}

enum TemporalRibbonHitKind: Int, Equatable, Sendable {
    case interval = 1
    case event = 2
}

struct TemporalRibbonHitRegion: Equatable, Sendable {
    let id: UUID
    let range: ClosedRange<Double>
    let kind: TemporalRibbonHitKind
}

enum TemporalRibbonHitTarget: Equatable, Sendable {
    case mark(id: UUID, kind: TemporalRibbonHitKind)
    case empty(instant: Date)
}

enum TemporalProvenancePresentation: Equatable, Sendable {
    case recorded
    case reconstructed(adjusted: Bool, needsReview: Bool)
    case unknown

    var title: String {
        switch self {
        case .recorded:
            "Recorded by you"
        case let .reconstructed(adjusted, needsReview):
            if needsReview {
                adjusted
                    ? "Needs review · Reconstructed · Confirmed by you · Adjusted by you"
                    : "Needs review · Reconstructed · Confirmed by you"
            } else if adjusted {
                "Reconstructed · Confirmed by you · Adjusted by you"
            } else {
                "Reconstructed · Confirmed by you"
            }
        case .unknown:
            "Unknown period"
        }
    }
}

struct TemporalRibbonGeometry: Equatable, Sendable {
    let contentWidth: Double
    let intervalLaneHeight: Double
    let eventLaneHeight: Double

    static func policy(for viewportWidth: Double, accessibilitySize: Bool) -> Self {
        let safeWidth = max(viewportWidth, 280)
        return Self(
            contentWidth: max(accessibilitySize ? 1120 : 900, safeWidth * 2.45),
            intervalLaneHeight: accessibilitySize ? 42 : 34,
            eventLaneHeight: accessibilitySize ? 52 : 44
        )
    }

    static func pagePolicy(for viewportWidth: Double, accessibilitySize: Bool) -> Self {
        Self(
            contentWidth: max(viewportWidth, 280),
            intervalLaneHeight: accessibilitySize ? 46 : 40,
            eventLaneHeight: accessibilitySize ? 56 : 48
        )
    }
}

enum TemporalHistoryPresentation {
    static func settledCarouselDay(
        centeredPage: Date?,
        currentSelection: Date,
        availableDays: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Date {
        let currentDay = calendar.startOfDay(for: currentSelection)
        guard let centeredPage else { return currentDay }
        let proposedDay = calendar.startOfDay(for: centeredPage)
        let maximumDay = calendar.startOfDay(for: maximumDate)
        guard proposedDay <= maximumDay,
              availableDays.contains(proposedDay)
        else { return currentDay }
        return proposedDay
    }

    static func adjacentDay(
        to date: Date,
        direction: Int,
        calendar: Calendar
    ) -> Date? {
        let day = calendar.startOfDay(for: date)
        guard direction != 0 else {
            return day
        }
        return calendar.date(byAdding: .day, value: direction > 0 ? 1 : -1, to: day)
            .map { calendar.startOfDay(for: $0) }
    }

    static func ribbonWindow(containing date: Date, calendar: Calendar) -> TemporalRibbonWindow? {
        let selectedStart = calendar.startOfDay(for: date)
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedStart),
              let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedStart),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedStart),
              let start = localTime(hour: 18, on: previousDay, calendar: calendar),
              let end = localTime(hour: 18, on: nextDay, calendar: calendar),
              start < end
        else { return nil }

        let markers = [selectedStart, selectedEnd].filter { $0 > start && $0 < end }
        return TemporalRibbonWindow(
            selectedDay: selectedStart,
            selectedDayInterval: DateInterval(start: selectedStart, end: selectedEnd),
            interval: DateInterval(start: start, end: end),
            midnightMarkers: markers
        )
    }

    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        return (0 ..< 7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: week.start)
        }
    }

    static func clip(
        _ intervals: [TemporalIntervalInput],
        to window: TemporalRibbonWindow
    ) -> [TemporalIntervalSegment] {
        let visible = intervals.compactMap { input -> TemporalIntervalSegment? in
            guard input.start < input.end,
                  input.end > window.interval.start,
                  input.start < window.interval.end
            else { return nil }
            return TemporalIntervalSegment(
                id: input.id,
                originalStart: input.start,
                originalEnd: input.end,
                visibleStart: max(input.start, window.interval.start),
                visibleEnd: min(input.end, window.interval.end),
                continuesBefore: input.start < window.interval.start,
                continuesAfter: input.end > window.interval.end,
                lane: 0
            )
        }
        .sorted {
            if $0.visibleStart == $1.visibleStart {
                if $0.visibleEnd == $1.visibleEnd {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.visibleEnd < $1.visibleEnd
            }
            return $0.visibleStart < $1.visibleStart
        }

        var laneEnds: [Date] = []
        return visible.map { segment in
            let lane = laneEnds.firstIndex { $0 <= segment.visibleStart } ?? laneEnds.count
            if lane == laneEnds.count {
                laneEnds.append(segment.visibleEnd)
            } else {
                laneEnds[lane] = segment.visibleEnd
            }
            return TemporalIntervalSegment(
                id: segment.id,
                originalStart: segment.originalStart,
                originalEnd: segment.originalEnd,
                visibleStart: segment.visibleStart,
                visibleEnd: segment.visibleEnd,
                continuesBefore: segment.continuesBefore,
                continuesAfter: segment.continuesAfter,
                lane: lane
            )
        }
    }

    static func chronological(_ values: [TemporalEventOrderingValue]) -> [TemporalEventOrderingValue] {
        values.sorted {
            if $0.occurredAt == $1.occurredAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.occurredAt < $1.occurredAt
        }
    }

    static func ribbonHitTarget(
        at position: Double,
        width: Double,
        window: TemporalRibbonWindow,
        hitRegions: [TemporalRibbonHitRegion]
    ) -> TemporalRibbonHitTarget? {
        guard width > 0, position >= 0, position <= width else {
            return nil
        }
        let fraction = position / width
        let matchingHits = hitRegions
            .filter { $0.range.contains(fraction) }
            .sorted(by: {
                if $0.kind.rawValue == $1.kind.rawValue {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.kind.rawValue > $1.kind.rawValue
            })
        if let hit = matchingHits.first {
            return .mark(id: hit.id, kind: hit.kind)
        }
        return .empty(instant: window.instant(at: fraction))
    }

    static func selectedInstantSummary(
        _ instant: Date,
        in window: TemporalRibbonWindow,
        context: TemporalFormattingContext
    ) -> String {
        let style = Date.FormatStyle(
            date: .complete,
            time: .shortened,
            locale: context.locale,
            calendar: context.calendar,
            timeZone: context.timeZone
        )
        let formatted = instant.formatted(style)
        guard hasRepeatedLocalTime(
            instant,
            in: window,
            calendar: context.calendar
        ) else {
            return formatted
        }
        return "\(formatted) (\(timeZoneAbbreviation(for: instant, context: context)))"
    }

    static func intervalSummary(
        provenance: TemporalProvenancePresentation,
        start: Date,
        end: Date,
        context: TemporalFormattingContext
    ) -> String {
        let style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: context.locale,
            calendar: context.calendar,
            timeZone: context.timeZone
        )
        let duration = ElapsedTimeFormatter.string(from: end.timeIntervalSince(start))
        return "\(provenance.title), start \(start.formatted(style)), end "
            + "\(end.formatted(style)), duration \(duration)"
    }

    private static func localTime(hour: Int, on date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private static func hasRepeatedLocalTime(
        _ instant: Date,
        in window: TemporalRibbonWindow,
        calendar: Calendar
    ) -> Bool {
        let components: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute]
        let local = calendar.dateComponents(components, from: instant)
        return [-3600.0, 3600.0]
            .map { instant.addingTimeInterval($0) }
            .contains {
                window.interval.contains($0)
                    && calendar.dateComponents(components, from: $0) == local
            }
    }

    private static func timeZoneAbbreviation(
        for instant: Date,
        context: TemporalFormattingContext
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = context.calendar
        formatter.locale = context.locale
        formatter.timeZone = context.timeZone
        formatter.dateFormat = "z"
        return formatter.string(from: instant)
    }
}
