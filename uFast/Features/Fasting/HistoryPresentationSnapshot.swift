import Foundation

// swiftlint:disable function_body_length function_parameter_count trailing_comma

struct HistoryPresentationSnapshot: Equatable {
    let window: DateInterval
    let fastItems: [HistoryVisibleFastItem]
    let events: [TemporalRibbonEventItem]

    func intervals(activeEndingAt now: Date) -> [TemporalRibbonIntervalItem] {
        fastItems.map { item in
            item.kind == .active ? item.ending(at: now).ribbonItem : item.ribbonItem
        }
    }

    func visibleFastItems(activeEndingAt now: Date) -> [HistoryVisibleFastItem] {
        fastItems.map { $0.kind == .active ? $0.ending(at: now) : $0 }
    }
}

struct HistoryPresentationKey: Equatable {
    let data: HistoryDataSlice
    let localeIdentifier: String
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
}

@MainActor
final class HistoryPresentationCache {
    private(set) var rebuildCount = 0
    private var key: HistoryPresentationKey?
    private var snapshot: HistoryPresentationSnapshot?

    func presentation(
        for data: HistoryDataSlice,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        referenceNow: Date
    ) -> HistoryPresentationSnapshot {
        let newKey = HistoryPresentationKey(
            data: data,
            localeIdentifier: locale.identifier,
            calendarIdentifier: calendar.identifier,
            timeZoneIdentifier: timeZone.identifier
        )
        if key == newKey, let snapshot {
            return snapshot
        }
        let built = HistoryPresentationBuilder.build(
            data: data,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: referenceNow
        )
        key = newKey
        snapshot = built
        rebuildCount += 1
        return built
    }

    func invalidate() {
        key = nil
        snapshot = nil
    }
}

enum HistoryPresentationBuilder {
    static func build(
        data: HistoryDataSlice,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        referenceNow: Date
    ) -> HistoryPresentationSnapshot {
        let window = data.window.start ..< data.window.end
        let boundaries = CaloricBoundaryExtractor.boundaries(
            food: data.foods.map {
                .init(id: $0.id, occurredAt: $0.occurredAt, description: $0.foodDescription, isCaloric: $0.isCaloric)
            },
            hydration: data.drinks.map {
                .init(id: $0.id, occurredAt: $0.occurredAt, description: $0.displayName, isCaloric: $0.isCaloric)
            }
        )
        let recorded = data.completedFasts.compactMap { fast -> HistoryVisibleFastItem? in
            guard fast.presentationIntegrity == .available,
                  fast.origin == .recorded,
                  let end = fast.endDate,
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window)
            else { return nil }
            return .recorded(fast)
        }
        let active = data.activeFast.flatMap { fast -> HistoryVisibleFastItem? in
            guard fast.startDate < referenceNow,
                  AutomaticFastProjector.intersects(fast.startDate ..< referenceNow, window)
            else { return nil }
            return .active(fast, endingAt: referenceNow)
        }.map { [$0] } ?? []
        let legacy = data.completedFasts.compactMap { fast -> HistoryVisibleFastItem? in
            guard fast.presentationIntegrity == .available,
                  fast.origin == .reconstructed,
                  let end = fast.endDate,
                  !LegacyFastCompatibility.isExactlyReproducible(
                      startDate: fast.startDate,
                      endDate: end,
                      boundaries: fast.boundaryPair,
                      caloricBoundaries: boundaries
                  ),
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window),
                  !recorded.contains(where: { $0.intersects(fast.startDate ..< end) })
            else { return nil }
            return .previouslySaved(fast)
        }
        let unavailable = data.completedFasts.compactMap { fast -> HistoryVisibleFastItem? in
            guard fast.presentationIntegrity == .unavailable,
                  let end = fast.endDate,
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window)
            else { return nil }
            return .unavailable(fast)
        }
        let excluded = (data.completedFasts + [data.activeFast].compactMap(\.self))
            .filter { $0.origin == .recorded || $0.presentationIntegrity == .unavailable }
            .map(\.recordedInterval)
        let automatic = AutomaticFastProjector.project(
            boundaries: boundaries,
            visibleInterval: window,
            excluding: excluded
        ).compactMap { interval -> HistoryVisibleFastItem? in
            guard !legacy.contains(where: { $0.intersects(interval.interval) }) else { return nil }
            return .automatic(interval)
        }
        return HistoryPresentationSnapshot(
            window: data.window,
            fastItems: recorded + active + legacy + unavailable + automatic,
            events: makeEvents(data: data, locale: locale, calendar: calendar, timeZone: timeZone)
        )
    }

    private static func makeEvents(
        data: HistoryDataSlice,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> [TemporalRibbonEventItem] {
        let foods = data.foods.map { food in
            let nutrition = nutritionDetail(food.nutrition)
            let detail = ([eventDetail(
                category: "Food", caloric: food.isCaloric, date: food.occurredAt,
                locale: locale, calendar: calendar, timeZone: timeZone
            )] + (nutrition.map { [$0] } ?? [])).joined(separator: " · ")
            let accessibility = ([
                "\(food.foodDescription), food, \(food.isCaloric ? "caloric" : "non-caloric"), "
                    + formatted(food.occurredAt, locale: locale, calendar: calendar, timeZone: timeZone),
            ] + (nutrition.map { [$0] } ?? [])).joined(separator: ", ")
            return TemporalRibbonEventItem(
                id: food.id, occurredAt: food.occurredAt, title: food.foodDescription,
                detail: detail, accessibilityLabel: accessibility, kind: .food
            )
        }
        let drinks = data.drinks.map { drink in
            let formattedDate = formatted(
                drink.occurredAt, locale: locale, calendar: calendar, timeZone: timeZone
            )
            return TemporalRibbonEventItem(
                id: drink.id,
                occurredAt: drink.occurredAt,
                title: drink.displayName,
                detail: "\(drink.volumeMillilitres) ml · "
                    + "\(drink.isCaloric ? "Caloric drink" : "Non-caloric drink") · \(formattedDate)",
                accessibilityLabel: "\(drink.displayName), \(drink.volumeMillilitres) millilitres, "
                    + "\(drink.isCaloric ? "caloric drink" : "non-caloric drink"), \(formattedDate)",
                kind: drink.isCaloric ? .caloricDrink : .nonCaloricDrink
            )
        }
        return foods + drinks
    }

    private static func eventDetail(
        category: String,
        caloric: Bool,
        date: Date,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        "\(category) · \(caloric ? "Caloric" : "Non-caloric") · "
            + formatted(date, locale: locale, calendar: calendar, timeZone: timeZone)
    }

    private static func nutritionDetail(_ nutrition: FoodNutrition) -> String? {
        let values: [(String, Double?)] = [
            ("Energy", nutrition.energyKilocalories), ("Protein", nutrition.proteinGrams),
            ("Carbohydrate", nutrition.carbohydrateGrams), ("Fat", nutrition.fatGrams),
            ("Fibre", nutrition.fibreGrams), ("Sugar", nutrition.sugarGrams), ("Salt", nutrition.saltGrams),
        ]
        let parts = values.compactMap { label, value -> String? in
            guard let value else { return nil }
            return "\(label) \(value.formatted()) \(label == "Energy" ? "kcal" : "g")"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func formatted(
        _ date: Date,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        date.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone
        ))
    }
}

struct HistoryVisibleFastItem: Identifiable, Equatable {
    enum Kind: Equatable { case recorded, active, automatic, previouslySaved, unavailable }

    let id: UUID
    let startDate: Date
    let endDate: Date
    let kind: Kind
    let fast: HistoryFastSnapshot?

    static func recorded(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .recorded, fast: fast
        )
    }

    static func active(_ fast: HistoryFastSnapshot, endingAt endDate: Date) -> Self {
        Self(id: fast.id, startDate: fast.startDate, endDate: endDate, kind: .active, fast: fast)
    }

    static func previouslySaved(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .previouslySaved, fast: fast
        )
    }

    static func unavailable(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .unavailable, fast: fast
        )
    }

    static func automatic(_ interval: AutomaticFastInterval) -> Self {
        Self(
            id: interval.identity.boundaries.start.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .automatic,
            fast: nil
        )
    }

    func ending(at date: Date) -> Self {
        guard kind == .active else { return self }
        return Self(id: id, startDate: startDate, endDate: date, kind: kind, fast: fast)
    }

    func intersects(_ interval: Range<Date>) -> Bool {
        AutomaticFastProjector.intersects(startDate ..< endDate, interval)
    }

    var title: String {
        switch kind {
        case .recorded: "Recorded fast"
        case .active: "Active Fast"
        case .automatic: "Fast"
        case .previouslySaved: "Previously saved fast"
        case .unavailable: "Saved fast · Details unavailable"
        }
    }

    var ribbonKind: TemporalRibbonIntervalItem.Kind {
        switch kind {
        case .recorded: .recorded
        case .active: .active
        case .automatic: .automatic
        case .previouslySaved, .unavailable: .previouslySaved
        }
    }

    var ribbonItem: TemporalRibbonIntervalItem {
        TemporalRibbonIntervalItem(
            id: id,
            start: startDate,
            end: endDate,
            title: title,
            detail: detail,
            accessibilityLabel: accessibilityLabel,
            kind: ribbonKind
        )
    }

    var detail: String {
        let duration = kind == .active
            ? ActiveElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate))
            : ElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate))
        var components = [
            "start \(startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
        ]
        if kind != .active {
            components[0] += " → end \(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
        }
        components.append("duration \(duration)")
        if kind == .recorded, let goal = fast?.capturedHistoricalGoal {
            components.append("goal \(goal.hours) hours")
        }
        return components.joined(separator: " · ")
    }

    var accessibilityLabel: String {
        let duration = kind == .active
            ? ActiveElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate))
            : ElapsedTimeFormatter.string(from: endDate.timeIntervalSince(startDate))
        var components = [
            title,
            "start \(startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
            "duration \(duration)",
        ]
        if kind != .active {
            components.insert(
                "end \(endDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))",
                at: 2
            )
        }
        if kind == .recorded, let goal = fast?.capturedHistoricalGoal {
            components.append("goal \(goal.hours) hours")
        }
        return components.joined(separator: ", ")
    }
}
