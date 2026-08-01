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

/// Separates the day being drawn during carousel motion from the date exposed
/// to controls and assistive technologies. The latter changes only when the
/// shared History selection settles.
struct TemporalHistoryDayPresentation: Equatable, Sendable {
    let visualDay: Date
    let settledDay: Date

    init(settledDay: Date, liveDay: Date?, calendar: Calendar) {
        self.settledDay = calendar.startOfDay(for: settledDay)
        visualDay = calendar.startOfDay(for: liveDay ?? settledDay)
    }
}

enum TemporalMidnightMarkerLayout {
    static func labelCenterX(
        markerX: Double,
        labelWidth: Double,
        availableWidth: Double,
        layoutDirection: TemporalHorizontalLayoutDirection
    ) -> Double {
        let halfWidth = labelWidth / 2
        let offset = layoutDirection == .rightToLeft ? -halfWidth : halfWidth
        return min(
            max(halfWidth, markerX + offset),
            max(halfWidth, availableWidth - halfWidth)
        )
    }
}

struct TemporalMidnightMarkerText: Equatable, Sendable {
    let localDate: String
    let localTime: String

    init(date: Date, context: TemporalFormattingContext) {
        localDate = date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .omitted,
                locale: context.locale,
                calendar: context.calendar,
                timeZone: context.timeZone
            ).day().month(.abbreviated)
        )
        localTime = date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: context.locale,
                calendar: context.calendar,
                timeZone: context.timeZone
            )
        )
    }
}

enum TemporalDaySelectionSource: Equatable, Sendable {
    case initial
    case dateChip
    case carousel
    case pager
    case datePicker
    case accessibility
    case timeline
    case dateRailSettlement
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
    case aligning
    case programmatic

    var suppressesAutomaticAlignment: Bool {
        self != .settled
    }

    var allowsTimelineInteraction: Bool {
        self == .settled
    }

    var showsTimelineDetails: Bool {
        self == .settled
    }
}

enum TemporalHorizontalLayoutDirection: Equatable, Sendable {
    case leftToRight
    case rightToLeft
}

enum TemporalScrollMotionOwner: Equatable, Sendable {
    case settled
    case lowerUserDriven
    case lowerDecelerating
    case lowerAligning
    case upperUserDriven
    case deliberateProgrammatic

    var publishesCoupledPreview: Bool {
        switch self {
        case .lowerUserDriven, .lowerDecelerating, .lowerAligning:
            true
        case .settled, .upperUserDriven, .deliberateProgrammatic:
            false
        }
    }

    var allowsSettledActions: Bool {
        self == .settled
    }
}

struct TemporalDaySpaceProgress: Equatable, Sendable {
    let leadingDay: Date
    let trailingDay: Date
    let fraction: Double
    let lowerPageStride: Double

    /// The local-calendar day visually under the viewport centre. A seam belongs
    /// to the day being entered so reversal immediately restores the prior day.
    var centeredCalendarDay: Date {
        fraction < 0.5 ? leadingDay : trailingDay
    }

    static func resolve(
        contentOffset: Double,
        contentWidth: Double,
        containerWidth: Double,
        days: [Date],
        layoutDirection: TemporalHorizontalLayoutDirection
    ) -> Self? {
        guard days.count > 1,
              containerWidth > 0
        else { return nil }
        let stride = (contentWidth - containerWidth) / Double(days.count - 1)
        guard stride.isFinite, stride > 0 else { return nil }
        let maximumOffset = max(contentWidth - containerWidth, 0)
        let chronologicalOffset = switch layoutDirection {
        case .leftToRight:
            contentOffset
        case .rightToLeft:
            maximumOffset - contentOffset
        }
        let progress = min(max(chronologicalOffset / stride, 0), Double(days.count - 1))
        if progress >= Double(days.count - 1) {
            return Self(
                leadingDay: days[days.count - 2],
                trailingDay: days[days.count - 1],
                fraction: 1,
                lowerPageStride: stride
            )
        }
        let leadingIndex = Int(floor(progress))
        return Self(
            leadingDay: days[leadingIndex],
            trailingDay: days[leadingIndex + 1],
            fraction: progress - Double(leadingIndex),
            lowerPageStride: stride
        )
    }

    func upperTranslation(measuredChipStride: Double) -> Double? {
        guard measuredChipStride.isFinite,
              measuredChipStride > 0,
              fraction.isFinite
        else { return nil }
        return fraction * measuredChipStride
    }

    func isValid(
        in days: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard fraction.isFinite,
              (0 ... 1).contains(fraction),
              lowerPageStride.isFinite,
              lowerPageStride > 0,
              let leadingIndex = days.firstIndex(of: leadingDay),
              days.indices.contains(leadingIndex + 1),
              days[leadingIndex + 1] == trailingDay,
              trailingDay <= calendar.startOfDay(for: maximumDate),
              TemporalHistoryPresentation.adjacentDay(
                  to: leadingDay,
                  direction: 1,
                  calendar: calendar
              ) == trailingDay
        else { return false }
        return true
    }

    func rebased(
        in days: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Self? {
        isValid(in: days, maximumDate: maximumDate, calendar: calendar) ? self : nil
    }
}

struct TemporalContinuousTimelineGeometry: Equatable, Sendable {
    let contentOffset: Double
    let contentWidth: Double
    let containerWidth: Double

    func visibleWindow(
        days: [Date],
        calendar: Calendar,
        layoutDirection: TemporalHorizontalLayoutDirection
    ) -> TemporalRibbonWindow? {
        guard let segmentWidth = daySegmentWidth(days: days),
              let start = instant(
                  at: chronologicalOffset(
                      layoutDirection: layoutDirection
                  ),
                  segmentWidth: segmentWidth,
                  days: days,
                  calendar: calendar
              ),
              let end = instant(
                  at: chronologicalOffset(
                      layoutDirection: layoutDirection
                  ) + containerWidth,
                  segmentWidth: segmentWidth,
                  days: days,
                  calendar: calendar
              ),
              start < end
        else { return nil }
        let selectedDay = calendar.startOfDay(
            for: instant(
                at: chronologicalOffset(layoutDirection: layoutDirection)
                    + containerWidth / 2,
                segmentWidth: segmentWidth,
                days: days,
                calendar: calendar
            ) ?? start
        )
        guard let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) else {
            return nil
        }
        let midnights = days.filter { $0 > start && $0 < end }
        return TemporalRibbonWindow(
            selectedDay: selectedDay,
            selectedDayInterval: DateInterval(start: selectedDay, end: selectedEnd),
            interval: DateInterval(start: start, end: end),
            midnightMarkers: midnights
        )
    }

    func centerProgress(
        days: [Date],
        layoutDirection: TemporalHorizontalLayoutDirection
    ) -> TemporalDaySpaceProgress? {
        guard let segmentWidth = daySegmentWidth(days: days), days.count > 1 else {
            return nil
        }
        let center = chronologicalOffset(layoutDirection: layoutDirection)
            + containerWidth / 2
        let progress = min(
            max(center / segmentWidth - 0.5, 0),
            Double(days.count - 1)
        )
        if progress >= Double(days.count - 1) {
            return TemporalDaySpaceProgress(
                leadingDay: days[days.count - 2],
                trailingDay: days[days.count - 1],
                fraction: 1,
                lowerPageStride: segmentWidth
            )
        }
        let leadingIndex = Int(floor(progress))
        return TemporalDaySpaceProgress(
            leadingDay: days[leadingIndex],
            trailingDay: days[leadingIndex + 1],
            fraction: progress - Double(leadingIndex),
            lowerPageStride: segmentWidth
        )
    }

    private func daySegmentWidth(days: [Date]) -> Double? {
        guard !days.isEmpty, contentWidth > 0 else { return nil }
        let width = contentWidth / Double(days.count)
        return width.isFinite && width > 0 ? width : nil
    }

    private func chronologicalOffset(
        layoutDirection: TemporalHorizontalLayoutDirection
    ) -> Double {
        let maximumOffset = max(contentWidth - containerWidth, 0)
        return switch layoutDirection {
        case .leftToRight:
            min(max(contentOffset, 0), maximumOffset)
        case .rightToLeft:
            min(max(maximumOffset - contentOffset, 0), maximumOffset)
        }
    }

    private func instant(
        at position: Double,
        segmentWidth: Double,
        days: [Date],
        calendar: Calendar
    ) -> Date? {
        guard !days.isEmpty else { return nil }
        let clamped = min(
            max(position / segmentWidth, 0),
            Double(days.count)
        )
        let index = min(Int(floor(clamped)), days.count - 1)
        let fraction = min(max(clamped - Double(index), 0), 1)
        let start = days[index]
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return start.addingTimeInterval(
            end.timeIntervalSince(start) * fraction
        )
    }
}

struct TemporalCoupledScrollCoordinator: Equatable, Sendable {
    private(set) var owner = TemporalScrollMotionOwner.settled
    private(set) var preview: TemporalDaySpaceProgress?
    private(set) var epoch = 0

    mutating func begin(_ newOwner: TemporalScrollMotionOwner) -> Int? {
        guard canTransition(from: owner, to: newOwner) else { return nil }
        if owner == .settled {
            epoch += 1
        }
        owner = newOwner
        if !newOwner.publishesCoupledPreview {
            preview = nil
        }
        return epoch
    }

    mutating func publish(
        _ progress: TemporalDaySpaceProgress,
        epoch requestedEpoch: Int,
        days: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard requestedEpoch == epoch,
              owner.publishesCoupledPreview,
              progress.isValid(
                  in: days,
                  maximumDate: maximumDate,
                  calendar: calendar
              )
        else { return false }
        preview = progress
        return true
    }

    mutating func rebase(
        days: [Date],
        maximumDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let preview else { return true }
        guard let rebased = preview.rebased(
            in: days,
            maximumDate: maximumDate,
            calendar: calendar
        ) else {
            self.preview = nil
            owner = .settled
            epoch += 1
            return false
        }
        self.preview = rebased
        return true
    }

    mutating func settle() {
        preview = nil
        owner = .settled
        epoch += 1
    }

    mutating func interrupt() {
        settle()
    }

    private func canTransition(
        from current: TemporalScrollMotionOwner,
        to proposed: TemporalScrollMotionOwner
    ) -> Bool {
        switch (current, proposed) {
        case (.settled, .lowerUserDriven),
             (.settled, .upperUserDriven),
             (.settled, .deliberateProgrammatic),
             (.lowerUserDriven, .lowerDecelerating),
             (.lowerUserDriven, .lowerAligning),
             (.lowerUserDriven, .settled),
             (.lowerDecelerating, .lowerUserDriven),
             (.lowerDecelerating, .lowerAligning),
             (.lowerDecelerating, .settled),
             (.lowerAligning, .settled),
             (.upperUserDriven, .settled),
             (.deliberateProgrammatic, .settled):
            true
        default:
            current == proposed
        }
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
