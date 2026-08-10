import Foundation

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length

enum TodayTimelineKind: Equatable {
    case food(id: UUID, name: String, isCaloric: Bool)
    case drink(id: UUID, name: String, volumeMillilitres: Int, isCaloric: Bool)
}

struct TodayTimelineEntry: Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let kind: TodayTimelineKind
}

enum TodayTimeline {
    static func entries(
        food: [FoodEntrySnapshot],
        drinks: [HydrationEntrySnapshot],
        now: Date,
        calendar: Calendar
    ) -> [TodayTimelineEntry] {
        let foodEntries = food.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }.map {
            TodayTimelineEntry(
                id: $0.id,
                occurredAt: $0.occurredAt,
                kind: .food(id: $0.id, name: $0.foodDescription, isCaloric: $0.isCaloric)
            )
        }
        let drinkEntries = drinks.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }.map {
            TodayTimelineEntry(
                id: $0.id,
                occurredAt: $0.occurredAt,
                kind: .drink(
                    id: $0.id,
                    name: $0.displayName,
                    volumeMillilitres: $0.volumeMillilitres,
                    isCaloric: $0.isCaloric
                )
            )
        }
        return sorted(foodEntries + drinkEntries)
    }

    static func entries(food: [FoodEntryRecord], drinks: [HydrationEntryRecord], now: Date, calendar: Calendar) -> [TodayTimelineEntry] {
        let foodEntries = food.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }.map {
            TodayTimelineEntry(id: $0.id, occurredAt: $0.occurredAt, kind: .food(id: $0.id, name: $0.foodDescription, isCaloric: $0.isCaloric))
        }
        let drinkEntries = drinks.filter { calendar.isDate($0.occurredAt, inSameDayAs: now) }.map {
            TodayTimelineEntry(id: $0.id, occurredAt: $0.occurredAt, kind: .drink(id: $0.id, name: $0.displayName, volumeMillilitres: $0.volumeMillilitres, isCaloric: $0.isCaloric))
        }
        return sorted(foodEntries + drinkEntries)
    }

    private static func sorted(_ entries: [TodayTimelineEntry]) -> [TodayTimelineEntry] {
        entries.sorted {
            if $0.occurredAt == $1.occurredAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.occurredAt > $1.occurredAt
        }
    }

    static func fluidTotal(_ entries: [TodayTimelineEntry]) -> Int {
        entries.reduce(0) { total, entry in
            if case let .drink(_, _, volume, _) = entry.kind {
                return total + volume
            }
            return total
        }
    }
}
