import Foundation

// swiftlint:disable opening_brace

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

    static func intervalCornerRadius(
        visibleWidth: Double,
        preferredRadius: Double
    ) -> Double {
        min(max(visibleWidth / 2, 0), preferredRadius)
    }

    static func intervalContentLayout(for visibleWidth: Double) -> TemporalIntervalContentLayout {
        guard visibleWidth.isFinite, visibleWidth >= 36 else { return .none }
        return visibleWidth >= 84 ? .regular : .compact
    }
}

enum TemporalIntervalContentLayout: Equatable, Sendable {
    case none
    case compact
    case regular
}

extension TemporalIntervalSegment {
    /// The page containing the original start is the only visual content
    /// owner for this interval. Page ownership is half-open so an interval
    /// starting exactly at local midnight belongs to the day being entered.
    func ownsVisualContent(in window: TemporalRibbonWindow) -> Bool {
        let pageInterval = window.selectedDayInterval
        return pageInterval.start <= originalStart
            && originalStart < pageInterval.end
    }

    /// Chooses a bounded label treatment only after ownership is established.
    /// A continuation never gains content merely because its fragment is wider.
    func visualContentLayout(
        in window: TemporalRibbonWindow,
        visibleWidth: Double
    ) -> TemporalIntervalContentLayout {
        guard ownsVisualContent(in: window) else { return .none }
        return TemporalRibbonGeometry.intervalContentLayout(for: visibleWidth)
    }

    func pageGeometry(
        in window: TemporalRibbonWindow,
        surfaceWidth: Double
    ) -> TemporalIntervalPageGeometry? {
        guard surfaceWidth.isFinite, surfaceWidth > 0 else { return nil }
        let startFraction = startFraction(in: window)
        let endFraction = endFraction(in: window)
        guard startFraction.isFinite, endFraction.isFinite,
              startFraction >= 0, endFraction <= 1,
              startFraction <= endFraction
        else { return nil }

        let startX = min(max(startFraction * surfaceWidth, 0), surfaceWidth)
        let endX = min(max(endFraction * surfaceWidth, 0), surfaceWidth)
        guard startX.isFinite, endX.isFinite, startX <= endX else { return nil }

        // A sub-pixel fragment still needs a finite, visible shape. Expand it
        // inward only, keeping both the temporal endpoints and the page bounds
        // intact. Normal-sized marks retain their exact temporal x positions.
        let minimumVisualWidth = min(1, surfaceWidth)
        let visualWidth = endX - startX
        let visualStartX: Double = if visualWidth >= minimumVisualWidth {
            startX
        } else if startX <= 0 {
            0
        } else if endX >= surfaceWidth {
            max(surfaceWidth - minimumVisualWidth, 0)
        } else {
            min(
                max((startX + endX - minimumVisualWidth) / 2, 0),
                max(surfaceWidth - minimumVisualWidth, 0)
            )
        }
        let boundedVisualStartX = min(max(visualStartX, 0), surfaceWidth)
        let boundedVisualWidth = min(
            max(visualWidth, minimumVisualWidth),
            surfaceWidth - boundedVisualStartX
        )
        guard boundedVisualStartX.isFinite, boundedVisualWidth.isFinite,
              boundedVisualWidth > 0
        else { return nil }

        let hitPadding = Self.hitPadding(
            visualStartX: boundedVisualStartX,
            visualWidth: boundedVisualWidth,
            surfaceWidth: surfaceWidth
        )
        return TemporalIntervalPageGeometry(
            segment: self,
            startX: startX,
            endX: endX,
            visualStartX: boundedVisualStartX,
            visualWidth: boundedVisualWidth,
            leadingHitPadding: hitPadding.leading,
            trailingHitPadding: hitPadding.trailing
        )
    }

    private static func hitPadding(
        visualStartX: Double,
        visualWidth: Double,
        surfaceWidth: Double
    ) -> (leading: Double, trailing: Double) {
        let desired = max((44 - visualWidth) / 2, 0)
        let availableLeading = visualStartX
        let availableTrailing = max(surfaceWidth - visualStartX - visualWidth, 0)
        var leading = min(desired, availableLeading)
        var trailing = min(desired, availableTrailing)
        let unallocated = max(desired * 2 - leading - trailing, 0)
        let leadingRemainder = min(unallocated, max(availableLeading - leading, 0))
        leading += leadingRemainder
        trailing += min(
            unallocated - leadingRemainder,
            max(availableTrailing - trailing, 0)
        )
        return (leading, trailing)
    }
}

/// A clipped interval's complete page-local rendering geometry. Temporal
/// endpoints remain on `segment`; x values are derived only for the current
/// page surface and are guaranteed finite and bounded.
struct TemporalIntervalPageGeometry: Identifiable, Equatable, Sendable {
    let segment: TemporalIntervalSegment
    let startX: Double
    let endX: Double
    let visualStartX: Double
    let visualWidth: Double
    let leadingHitPadding: Double
    let trailingHitPadding: Double

    var id: UUID {
        segment.id
    }

    var continuesBefore: Bool {
        segment.continuesBefore
    }

    var continuesAfter: Bool {
        segment.continuesAfter
    }

    var lane: Int {
        segment.lane
    }
}

enum TemporalHistoryPresentation {
    /// Resolves a manual rail only after native scrolling is idle.  Geometry is
    /// already expressed in the visual coordinate space, so this is identical
    /// in LTR and RTL; the caller supplies visual chip midpoints.
    static func settledRailDay(
        chipMidpoints: [Date: Double],
        viewportMidpoint: Double,
        availableDays: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Date? {
        guard viewportMidpoint.isFinite else { return nil }
        let maximumDay = calendar.startOfDay(for: maximumDate)
        var candidate: Date?
        var candidateDistance = Double.infinity
        for date in availableDays {
            guard date <= maximumDay,
                  let midpoint = chipMidpoints[date], midpoint.isFinite
            else { continue }
            let distance = abs(midpoint - viewportMidpoint)
            // At an exact visual midpoint, choose the later calendar day. This
            // makes the seam deterministic in both layout directions.
            if distance < candidateDistance
                || (distance == candidateDistance && (candidate.map { date > $0 } ?? true))
            {
                candidate = date
                candidateDistance = distance
            }
        }
        return candidate
    }

    static func allowsHistoricalEntry(
        at instant: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let targetDay = calendar.startOfDay(for: instant)
        let today = calendar.startOfDay(for: now)
        return targetDay < today || (targetDay == today && instant <= now)
    }

    /// The read-only portion of a ribbon.  The range is presentation-only and
    /// uses absolute instants after deriving local-day boundaries with Calendar.
    static func futureShadingInterval(
        for window: TemporalRibbonWindow,
        now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        let today = calendar.startOfDay(for: now)
        if window.selectedDay > today {
            return window.interval
        }
        guard window.selectedDay == today else { return nil }
        let start = max(now, window.interval.start)
        guard start < window.interval.end else { return nil }
        return DateInterval(start: start, end: window.interval.end)
    }

    static func twoHourMarkers(
        in window: TemporalRibbonWindow,
        calendar: Calendar
    ) -> [Date] {
        var markers = Set(window.midnightMarkers)
        // Generate each local boundary via Calendar. Missing spring-forward
        // hours yield no boundary; Calendar's deterministic resolution avoids
        // inventing a duplicate during autumn fallback.
        for hour in stride(from: 0, through: 22, by: 2) {
            var components = calendar.dateComponents([.era, .year, .month, .day], from: window.selectedDay)
            components.hour = hour
            components.minute = 0
            components.second = 0
            if let date = calendar.date(from: components),
               date >= window.interval.start,
               date < window.interval.end
            {
                markers.insert(date)
            }
        }
        return markers.sorted()
    }

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
              let start = calendar.date(byAdding: .hour, value: -1, to: selectedStart),
              let end = calendar.date(byAdding: .hour, value: 1, to: selectedEnd),
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

    static func calendarDayWindow(containing date: Date, calendar: Calendar) -> TemporalRibbonWindow? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return TemporalRibbonWindow(
            selectedDay: start,
            selectedDayInterval: DateInterval(start: start, end: end),
            interval: DateInterval(start: start, end: end),
            midnightMarkers: [start]
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
        guard window.interval.start < window.interval.end else { return [] }

        let validInputs = intervals.filter { $0.start < $0.end }.sorted {
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            if $0.end != $1.end {
                return $0.end < $1.end
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        // Assign lanes from the original half-open intervals, not their page
        // fragments. A record therefore keeps its lane when a neighbouring
        // page clips another interval away at the seam.
        var laneEnds: [Date] = []
        var laneByID: [UUID: Int] = [:]
        for input in validInputs {
            let lane = laneEnds.firstIndex { $0 <= input.start } ?? laneEnds.count
            if lane == laneEnds.count {
                laneEnds.append(input.end)
            } else {
                laneEnds[lane] = input.end
            }
            laneByID[input.id] = lane
        }

        return validInputs.compactMap { input -> TemporalIntervalSegment? in
            guard input.end > window.interval.start,
                  input.start < window.interval.end,
                  let lane = laneByID[input.id]
            else { return nil }
            let visibleStart = max(input.start, window.interval.start)
            let visibleEnd = min(input.end, window.interval.end)
            guard visibleStart < visibleEnd else { return nil }
            return TemporalIntervalSegment(
                id: input.id,
                originalStart: input.start,
                originalEnd: input.end,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                continuesBefore: input.start < window.interval.start,
                continuesAfter: input.end > window.interval.end,
                lane: lane
            )
        }
    }

    static func pageGeometry(
        _ intervals: [TemporalIntervalInput],
        in window: TemporalRibbonWindow,
        surfaceWidth: Double
    ) -> [TemporalIntervalPageGeometry] {
        clip(intervals, to: window).compactMap {
            $0.pageGeometry(in: window, surfaceWidth: surfaceWidth)
        }
    }

    static func intervalContinuationShowsMarkers(isActive: Bool) -> Bool {
        !isActive
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
        let duration = HistoryTextFormatting.duration(
            seconds: end.timeIntervalSince(start),
            resolver: .init()
        )
        return "\(provenance.title), start \(start.formatted(style)), end "
            + "\(end.formatted(style)), duration \(duration)"
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
