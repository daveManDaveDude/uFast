import Foundation

// swiftlint:disable opening_brace file_length

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

/// The single policy surface for the History motion runway.  Calendar days,
/// rather than elapsed seconds, are deliberately used here so the policy is
/// stable over month/year boundaries and DST transitions.
struct HistoryMotionConfiguration: Equatable, Sendable {
    static let product = Self()

    let initialRadius: Int
    let extensionLength: Int
    let prefetchThreshold: Int

    init(initialRadius: Int = 120, extensionLength: Int = 120, prefetchThreshold: Int = 30) {
        self.initialRadius = max(initialRadius, 1)
        self.extensionLength = max(extensionLength, 1)
        self.prefetchThreshold = max(prefetchThreshold, 0)
    }
}

enum HistoryMotionEdge: String, Equatable, Sendable {
    case preceding
    case following
}

enum HistoryMotionLoadPhase: Equatable, Sendable {
    case idle
    case loading
    case failed
}

/// A contiguous, calendar-day coverage interval.  Its `days` are the exact
/// dates that may be handed to the native carousel; the projection is
/// installed at the same snapshot boundary by `HistoryMotionSnapshot`.
struct HistoryMotionCoverage: Equatable, Sendable {
    let firstDay: Date
    let lastDay: Date

    init(firstDay: Date, lastDay: Date, calendar: Calendar) {
        let first = calendar.startOfDay(for: firstDay)
        let last = calendar.startOfDay(for: lastDay)
        self.firstDay = min(first, last)
        self.lastDay = max(first, last)
    }

    var isEmpty: Bool {
        firstDay > lastDay
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= firstDay && day <= lastDay
    }

    func days(calendar: Calendar) -> [Date] {
        guard !isEmpty else { return [] }
        var result: [Date] = []
        var cursor = firstDay
        while cursor <= lastDay {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else {
                break
            }
            cursor = calendar.startOfDay(for: next)
        }
        return result
    }

    /// The one-hour context on either edge required to draw a complete 26-hour
    /// page.  This remains calendar arithmetic for the day boundaries and only
    /// uses hour arithmetic for the explicitly defined visual context.
    func visualWindow(calendar: Calendar) -> DateInterval? {
        guard let endDay = calendar.date(byAdding: .day, value: 1, to: lastDay),
              let start = calendar.date(byAdding: .hour, value: -1, to: firstDay),
              let end = calendar.date(byAdding: .hour, value: 1, to: endDay),
              start < end
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    func adjacent(_ edge: HistoryMotionEdge, length: Int, calendar: Calendar) -> HistoryMotionCoverage? {
        let count = max(length, 1)
        switch edge {
        case .preceding:
            guard let end = calendar.date(byAdding: .day, value: -1, to: firstDay),
                  let start = calendar.date(byAdding: .day, value: -(count - 1), to: end)
            else { return nil }
            return HistoryMotionCoverage(firstDay: start, lastDay: end, calendar: calendar)
        case .following:
            guard let start = calendar.date(byAdding: .day, value: 1, to: lastDay),
                  let end = calendar.date(byAdding: .day, value: count - 1, to: start)
            else { return nil }
            return HistoryMotionCoverage(firstDay: start, lastDay: end, calendar: calendar)
        }
    }

    static func initial(
        centeredOn date: Date,
        maximumDate: Date,
        calendar: Calendar,
        configuration: HistoryMotionConfiguration = .product
    ) -> Self {
        let selected = min(calendar.startOfDay(for: date), calendar.startOfDay(for: maximumDate))
        let radius = configuration.initialRadius
        let start = calendar.date(byAdding: .day, value: -radius, to: selected) ?? selected
        let end = min(
            calendar.date(byAdding: .day, value: radius, to: selected) ?? selected,
            calendar.startOfDay(for: maximumDate)
        )
        return Self(firstDay: start, lastDay: end, calendar: calendar)
    }

    func extended(
        toward edge: HistoryMotionEdge,
        maximumDate: Date,
        calendar: Calendar,
        configuration: HistoryMotionConfiguration = .product
    ) -> Self? {
        guard let adjacent = adjacent(edge, length: configuration.extensionLength, calendar: calendar) else {
            return nil
        }
        let maximum = calendar.startOfDay(for: maximumDate)
        switch edge {
        case .preceding:
            return Self(firstDay: adjacent.firstDay, lastDay: lastDay, calendar: calendar)
        case .following:
            guard adjacent.firstDay <= maximum else { return nil }
            return Self(firstDay: firstDay, lastDay: min(adjacent.lastDay, maximum), calendar: calendar)
        }
    }
}

/// Atomic state boundary consumed by the moving carousel.  Keeping the dates
/// and projection together prevents an unloaded date from ever being rendered
/// as an empty day during an asynchronous extension.
struct HistoryMotionSnapshot: Equatable, Sendable {
    let coverage: HistoryMotionCoverage
    let dates: [Date]
    let presentation: HistoryMotionPresentation
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
    let generation: Int
    let isInitial: Bool
    let precedingState: HistoryMotionLoadPhase
    let followingState: HistoryMotionLoadPhase

    init(
        coverage: HistoryMotionCoverage,
        calendar: Calendar,
        generation: Int,
        presentation: HistoryMotionPresentation,
        isInitial: Bool = false,
        precedingState: HistoryMotionLoadPhase = .idle,
        followingState: HistoryMotionLoadPhase = .idle
    ) {
        self.coverage = coverage
        dates = coverage.days(calendar: calendar)
        self.presentation = presentation
        calendarIdentifier = calendar.identifier
        timeZoneIdentifier = calendar.timeZone.identifier
        self.generation = generation
        self.isInitial = isInitial
        self.precedingState = precedingState
        self.followingState = followingState
    }

    func canExtend(
        _ edge: HistoryMotionEdge,
        around date: Date,
        calendar: Calendar,
        threshold: Int = HistoryMotionConfiguration.product.prefetchThreshold
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        let distances: Int? = switch edge {
        case .preceding:
            calendar.dateComponents([.day], from: coverage.firstDay, to: day).day
        case .following:
            calendar.dateComponents([.day], from: day, to: coverage.lastDay).day
        }
        return (distances ?? Int.max) <= threshold
    }

    func dayState(_ date: Date, calendar: Calendar) -> HistoryMotionDayState {
        let day = calendar.startOfDay(for: date)
        guard coverage.contains(day, calendar: calendar) else { return .unloaded }
        guard let window = TemporalHistoryPresentation.calendarDayWindow(containing: day, calendar: calendar) else {
            return .loadedEmpty
        }
        let hasEvent = presentation.events.contains {
            window.interval.contains($0.occurredAt)
        }
        let hasInterval = presentation.intervals.contains {
            AutomaticFastProjector.intersects($0.start ..< $0.end, window.interval.start ..< window.interval.end)
        }
        return hasEvent || hasInterval ? .loaded : .loadedEmpty
    }
}

enum HistoryMotionDayState: Equatable, Sendable {
    case unloaded
    case loadedEmpty
    case loaded
}

struct HistoryMotionRequest: Equatable, Sendable {
    let edge: HistoryMotionEdge
    let generation: Int
    let expectedFirstDay: Date
    let expectedLastDay: Date
}

/// Small deterministic state machine used by the SwiftUI owner and by tests.
/// It makes the one-request-per-edge/generation rule explicit and rejects
/// results that no longer belong to the published calendar environment.
struct HistoryMotionStore: Equatable, Sendable {
    private(set) var snapshot: HistoryMotionSnapshot?
    private(set) var inFlight: Set<HistoryMotionEdge> = []

    mutating func install(_ snapshot: HistoryMotionSnapshot, replacingGeneration: Int? = nil) {
        if let replacingGeneration,
           self.snapshot?.generation != replacingGeneration
        {
            return
        }
        self.snapshot = snapshot
        inFlight.removeAll()
    }

    mutating func beginRequest(_ edge: HistoryMotionEdge) -> HistoryMotionRequest? {
        guard let snapshot, !inFlight.contains(edge) else { return nil }
        inFlight.insert(edge)
        return HistoryMotionRequest(
            edge: edge,
            generation: snapshot.generation,
            expectedFirstDay: snapshot.coverage.firstDay,
            expectedLastDay: snapshot.coverage.lastDay
        )
    }

    mutating func complete(
        _ request: HistoryMotionRequest,
        with snapshot: HistoryMotionSnapshot,
        calendar: Calendar
    ) -> Bool {
        defer { inFlight.remove(request.edge) }
        guard let current = self.snapshot,
              current.generation == request.generation,
              snapshot.generation == request.generation,
              snapshot.calendarIdentifier == calendar.identifier,
              snapshot.timeZoneIdentifier == calendar.timeZone.identifier,
              request.expectedFirstDay == current.coverage.firstDay,
              request.expectedLastDay == current.coverage.lastDay,
              request.edge == .preceding
              ? snapshot.coverage.firstDay < current.coverage.firstDay
              : snapshot.coverage.lastDay > current.coverage.lastDay
        else { return false }
        self.snapshot = snapshot
        return true
    }
}

/// Compatibility shim for the pre-HS-101 unit tests.  History no longer uses
/// this independently published buffer; the coordinator publishes
/// `HistoryMotionSnapshot.dates` atomically with its projection.
@available(*, deprecated, message: "Use HistoryMotionCoverage and HistoryMotionSnapshot")
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
    case unavailable

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
        case .unavailable:
            "Saved fast · Details unavailable"
        }
    }
}
