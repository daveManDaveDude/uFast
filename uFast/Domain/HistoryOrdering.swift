import Foundation

enum HistoryRecordKind: Int, Equatable, Sendable {
    case recordedFast
    case reconstructedFast
    case unknownPeriod
}

struct HistoryOrderingValue: Equatable, Sendable {
    let id: UUID
    let endDate: Date
    let kind: HistoryRecordKind
}

enum HistoryOrdering {
    static func newestFirst(_ values: [HistoryOrderingValue]) -> [HistoryOrderingValue] {
        values.sorted {
            if $0.endDate != $1.endDate {
                return $0.endDate > $1.endDate
            }
            if $0.kind != $1.kind {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
