import Foundation

struct RecordedFastInterval: Equatable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
}

enum FastConflictChecker {
    static func hasConflict(
        proposedStart: Date,
        proposedEnd: Date?,
        excluding excludedID: UUID? = nil,
        among intervals: [RecordedFastInterval]
    ) -> Bool {
        intervals.contains { interval in
            guard interval.id != excludedID else {
                return false
            }

            return overlaps(
                firstStart: proposedStart,
                firstEnd: proposedEnd,
                secondStart: interval.startDate,
                secondEnd: interval.endDate
            )
        }
    }

    private static func overlaps(
        firstStart: Date,
        firstEnd: Date?,
        secondStart: Date,
        secondEnd: Date?
    ) -> Bool {
        let firstStartsBeforeSecondEnds = secondEnd.map { firstStart < $0 } ?? true
        let secondStartsBeforeFirstEnds = firstEnd.map { secondStart < $0 } ?? true
        return firstStartsBeforeSecondEnds && secondStartsBeforeFirstEnds
    }
}

extension FastRecord {
    var recordedInterval: RecordedFastInterval {
        RecordedFastInterval(
            id: id,
            startDate: startDate,
            endDate: endDate
        )
    }
}
