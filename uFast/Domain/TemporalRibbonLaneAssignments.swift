import Foundation

extension TemporalHistoryPresentation {
    /// Returns the original-interval lane allocation shared by page clipping
    /// and continuous label projection. Invalid intervals are ignored and
    /// equivalent IDs retain the first deterministic assignment.
    static func laneAssignments(
        for intervals: [TemporalIntervalInput]
    ) -> [UUID: Int] {
        let validInputs = intervals.filter { $0.start < $0.end }.sorted {
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            if $0.end != $1.end {
                return $0.end < $1.end
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        var laneEnds: [Date] = []
        var laneByID: [UUID: Int] = [:]
        for input in validInputs where laneByID[input.id] == nil {
            let lane = laneEnds.firstIndex { $0 <= input.start } ?? laneEnds.count
            if lane == laneEnds.count {
                laneEnds.append(input.end)
            } else {
                laneEnds[lane] = input.end
            }
            laneByID[input.id] = lane
        }
        return laneByID
    }
}
