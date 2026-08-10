import Foundation

// swiftlint:disable opening_brace

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
