import Foundation

// swiftlint:disable opening_brace

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

    var isContinuousLowerMotion: Bool {
        switch self {
        case .userDriven, .decelerating, .aligning:
            true
        case .settled, .programmatic:
            false
        }
    }

    func requiresPresentationUpdate(to newPhase: Self) -> Bool {
        guard self != newPhase else { return false }
        return !isContinuousLowerMotion || !newPhase.isContinuousLowerMotion
    }

    var suppressesAutomaticAlignment: Bool {
        self != .settled
    }

    var allowsTimelineInteraction: Bool {
        self == .settled
    }

    var showsTimelineDetails: Bool {
        self == .settled
    }

    var showsFutureReadOnlyAppearance: Bool {
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
