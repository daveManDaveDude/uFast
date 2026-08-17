import Foundation

// swiftlint:disable file_length function_body_length function_parameter_count trailing_comma opening_brace

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

/// The moving ribbon's deliberately lossy value projection.  It contains no
/// food descriptions, nutrition, editor payloads, settings or SwiftData
/// models.  Settled History continues to use `HistoryPresentationSnapshot` as
/// its exact authority.
struct HistoryMotionIntervalPrimitive: Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let kind: TemporalRibbonIntervalItem.Kind
    let isActive: Bool
    let title: String?
    let detail: String?
    let accessibilityLabel: String?
    let semanticKind: HistoryVisibleFastItem.Kind?
    let inferredInterval: InferredFastInterval?

    init(
        id: UUID,
        start: Date,
        end: Date,
        kind: TemporalRibbonIntervalItem.Kind,
        isActive: Bool,
        title: String? = nil,
        detail: String? = nil,
        accessibilityLabel: String? = nil,
        semanticKind: HistoryVisibleFastItem.Kind? = nil,
        inferredInterval: InferredFastInterval? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.kind = kind
        self.isActive = isActive
        self.title = title
        self.detail = detail
        self.accessibilityLabel = accessibilityLabel
        self.semanticKind = semanticKind
        self.inferredInterval = inferredInterval
    }
}

struct HistoryMotionEventPrimitive: Equatable, Sendable {
    let id: UUID
    let occurredAt: Date
    let kind: TemporalRibbonEventItem.Kind
}

struct HistoryMotionInferredContext: Equatable, Sendable {
    let foodEvents: [FoodBoundarySnapshot]
    let hydrationEvents: [HydrationBoundarySnapshot]
    let recordedFasts: [RecordedFastInterval]
    let currentGoal: FastingGoal
    let enabled: Bool

    init(
        foodEvents: [FoodBoundarySnapshot],
        hydrationEvents: [HydrationBoundarySnapshot] = [],
        recordedFasts: [RecordedFastInterval],
        currentGoal: FastingGoal,
        enabled: Bool
    ) {
        self.foodEvents = foodEvents
        self.hydrationEvents = hydrationEvents
        self.recordedFasts = recordedFasts
        self.currentGoal = currentGoal
        self.enabled = enabled
    }

    init(data: HistoryDataSlice) {
        foodEvents = data.foods.map {
            FoodBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.foodDescription,
                isCaloric: $0.isCaloric
            )
        }
        hydrationEvents = data.drinks.map {
            HydrationBoundarySnapshot(
                id: $0.id,
                occurredAt: $0.occurredAt,
                description: $0.displayName,
                isCaloric: $0.isCaloric
            )
        }
        recordedFasts = (data.completedFasts + [data.activeFast].compactMap(\.self))
            .map(\.recordedInterval)
        currentGoal = data.settings?.fastingGoal ?? .default
        enabled = data.settings?.inferredFastDetectionEnabled ?? false
    }

    func project(now: Date, visibleInterval: Range<Date>) -> [InferredFastInterval] {
        InferredFastProjector.project(
            boundaries: CaloricBoundaryExtractor.boundaries(
                food: foodEvents,
                hydration: hydrationEvents
            ),
            recordedFasts: recordedFasts,
            currentGoal: currentGoal,
            enabled: enabled,
            now: now,
            visibleInterval: visibleInterval
        )
    }
}

struct HistoryMotionPresentation: Equatable, Sendable {
    let window: DateInterval
    let intervals: [HistoryMotionIntervalPrimitive]
    let events: [HistoryMotionEventPrimitive]
    let inferredContext: HistoryMotionInferredContext?

    init(
        _ snapshot: HistoryPresentationSnapshot,
        inferredContext: HistoryMotionInferredContext? = nil
    ) {
        window = snapshot.window
        intervals = snapshot.fastItems.map {
            HistoryMotionIntervalPrimitive(
                id: $0.id,
                start: $0.startDate,
                end: $0.endDate,
                kind: $0.ribbonKind,
                isActive: $0.kind == .active,
                title: $0.title,
                detail: $0.detail,
                accessibilityLabel: $0.accessibilityLabel,
                semanticKind: $0.kind,
                inferredInterval: $0.inferredInterval
            )
        }
        events = snapshot.events.map {
            HistoryMotionEventPrimitive(id: $0.id, occurredAt: $0.occurredAt, kind: $0.kind)
        }
        self.inferredContext = inferredContext
    }

    init(
        window: DateInterval,
        intervals: [HistoryMotionIntervalPrimitive],
        events: [HistoryMotionEventPrimitive],
        inferredContext: HistoryMotionInferredContext? = nil
    ) {
        self.window = window
        self.intervals = intervals
        self.events = events
        self.inferredContext = inferredContext
    }

    func ribbonIntervals(activeEndingAt now: Date) -> [TemporalRibbonIntervalItem] {
        let existing = intervals
            .filter { inferredContext == nil || $0.semanticKind != .inferred }
            .compactMap { $0.ribbonItem(activeEndingAt: now) }
        let projected = inferredContext?.project(
            now: now,
            visibleInterval: window.start ..< window.end
        ).map { HistoryVisibleFastItem.inferred($0).ribbonItem } ?? []
        return (existing + projected).sorted { $0.start < $1.start }
    }

    func inferredInterval(for id: UUID, at now: Date) -> InferredFastInterval? {
        if let context = inferredContext {
            return context.project(
                now: now,
                visibleInterval: window.start ..< window.end
            ).first { $0.id == id }
        }
        return intervals.first { $0.id == id }?.currentInferredInterval(at: now)
    }

    var ribbonEvents: [TemporalRibbonEventItem] {
        events.map { primitive in
            TemporalRibbonEventItem(
                id: primitive.id,
                occurredAt: primitive.occurredAt,
                title: primitive.kind == .food ? "Food" : "Drink",
                detail: "",
                accessibilityLabel: primitive.kind == .food ? "Food event" : "Drink event",
                kind: primitive.kind
            )
        }
    }
}

private extension HistoryMotionIntervalPrimitive {
    func ribbonItem(activeEndingAt now: Date) -> TemporalRibbonIntervalItem? {
        if let inferred = currentInferredInterval(at: now) {
            return HistoryVisibleFastItem.inferred(inferred).ribbonItem
        }
        guard semanticKind != .inferred else { return nil }
        return TemporalRibbonIntervalItem(
            id: id,
            start: start,
            end: isActive ? now : end,
            title: title ?? (kind == .active ? "Active fast" : "Fast"),
            detail: detail ?? "",
            accessibilityLabel: accessibilityLabel
                ?? (kind == .active ? "Active fast" : "Fast"),
            kind: kind
        )
    }

    func currentInferredInterval(at now: Date) -> InferredFastInterval? {
        guard semanticKind == .inferred, let inferredInterval else { return nil }
        let eligibilityDate = inferredInterval.sourceDate.addingTimeInterval(
            InferredFastProjector.eligibilityDuration
        )
        guard now >= eligibilityDate else { return nil }
        let cap = inferredInterval.sourceDate.addingTimeInterval(
            InferredFastProjector.maximumDuration(for: inferredInterval.goal)
        )
        let punctuatingBoundaryDate: Date?
        let punctuatingBoundaryReference: CaloricBoundaryReference?
        if let nextBoundaryDate = inferredInterval.nextBoundaryDate,
           nextBoundaryDate <= now,
           nextBoundaryDate < cap
        {
            punctuatingBoundaryDate = nextBoundaryDate
            punctuatingBoundaryReference = inferredInterval.nextBoundaryReference
        } else {
            punctuatingBoundaryDate = nil
            punctuatingBoundaryReference = nil
        }
        let currentEnd = min(punctuatingBoundaryDate ?? now, cap)
        guard inferredInterval.sourceDate < currentEnd else { return nil }
        let state: InferredFastState = punctuatingBoundaryDate == nil && now < cap
            ? .inProgress
            : .historical
        return InferredFastInterval(
            sourceBoundaryReference: inferredInterval.sourceBoundaryReference,
            sourceDate: inferredInterval.sourceDate,
            sourceDescription: inferredInterval.sourceDescription,
            nextBoundaryReference: punctuatingBoundaryReference,
            nextBoundaryDate: punctuatingBoundaryDate,
            startDate: inferredInterval.startDate,
            endDate: currentEnd,
            goal: inferredInterval.goal,
            state: state
        )
    }
}

struct HistoryPresentationKey: Equatable {
    let data: HistoryDataSlice
    let localeIdentifier: String
    let calendarIdentifier: Calendar.Identifier
    let timeZoneIdentifier: String
    let activeFastIntersectsWindow: Bool
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
            timeZoneIdentifier: timeZone.identifier,
            activeFastIntersectsWindow: activeFastIntersectsWindow(
                in: data,
                at: referenceNow
            )
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

    private func activeFastIntersectsWindow(in data: HistoryDataSlice, at referenceNow: Date) -> Bool {
        guard let activeFast = data.activeFast,
              activeFast.startDate < referenceNow
        else { return false }
        return AutomaticFastProjector.intersects(
            activeFast.startDate ..< referenceNow,
            data.window.start ..< data.window.end
        )
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
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window),
                  !recorded.contains(where: { $0.intersects(fast.startDate ..< end) })
            else { return nil }
            guard data.settings != nil || !LegacyFastCompatibility.isExactlyReproducible(
                startDate: fast.startDate,
                endDate: end,
                boundaries: fast.boundaryPair,
                caloricBoundaries: boundaries
            ) else { return nil }
            return .previouslySaved(fast)
        }
        let unavailable = data.completedFasts.compactMap { fast -> HistoryVisibleFastItem? in
            guard fast.presentationIntegrity == .unavailable,
                  let end = fast.endDate,
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window)
            else { return nil }
            return .unavailable(fast)
        }
        let inferredExclusions = (data.completedFasts + [data.activeFast].compactMap(\.self))
            .map(\.recordedInterval)
        let legacyAutomaticExclusions = (data.completedFasts + [data.activeFast].compactMap(\.self))
            .filter { $0.origin == .recorded || $0.presentationIntegrity == .unavailable }
            .map(\.recordedInterval)
        let inferred = data.settings.map { settings in
            InferredFastProjector.project(
                boundaries: boundaries,
                recordedFasts: inferredExclusions,
                currentGoal: settings.fastingGoal,
                enabled: settings.inferredFastDetectionEnabled,
                now: referenceNow,
                visibleInterval: window
            ).map(HistoryVisibleFastItem.inferred)
        }
        let legacyAutomatic: [HistoryVisibleFastItem] = if data.settings == nil {
            AutomaticFastProjector.project(
                boundaries: boundaries,
                visibleInterval: window,
                excluding: legacyAutomaticExclusions
            ).compactMap { interval -> HistoryVisibleFastItem? in
                guard !legacy.contains(where: { $0.intersects(interval.interval) }) else { return nil }
                return .automatic(interval)
            }
        } else {
            []
        }
        return HistoryPresentationSnapshot(
            window: data.window,
            fastItems: recorded + active + legacy + unavailable + (inferred ?? legacyAutomatic),
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

struct HistoryVisibleFastItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case recorded
        case active
        case automatic
        case inferred
        case previouslySaved
        case unavailable
    }

    let id: UUID
    let startDate: Date
    let endDate: Date
    let kind: Kind
    let fast: HistoryFastSnapshot?
    let inferredInterval: InferredFastInterval?

    static func recorded(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .recorded, fast: fast,
            inferredInterval: nil
        )
    }

    static func active(_ fast: HistoryFastSnapshot, endingAt endDate: Date) -> Self {
        Self(
            id: fast.id,
            startDate: fast.startDate,
            endDate: endDate,
            kind: .active,
            fast: fast,
            inferredInterval: nil
        )
    }

    static func previouslySaved(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .previouslySaved, fast: fast,
            inferredInterval: nil
        )
    }

    static func unavailable(_ fast: HistoryFastSnapshot) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .unavailable, fast: fast,
            inferredInterval: nil
        )
    }

    static func automatic(_ interval: AutomaticFastInterval) -> Self {
        Self(
            id: interval.identity.boundaries.start.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .automatic,
            fast: nil,
            inferredInterval: nil
        )
    }

    static func inferred(_ interval: InferredFastInterval) -> Self {
        Self(
            id: interval.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .inferred,
            fast: nil,
            inferredInterval: interval
        )
    }

    func ending(at date: Date) -> Self {
        guard kind == .active else { return self }
        return Self(
            id: id,
            startDate: startDate,
            endDate: date,
            kind: kind,
            fast: fast,
            inferredInterval: inferredInterval
        )
    }

    func intersects(_ interval: Range<Date>) -> Bool {
        AutomaticFastProjector.intersects(startDate ..< endDate, interval)
    }

    var title: String {
        switch kind {
        case .recorded: "Recorded fast"
        case .active: "Active Fast"
        case .automatic: "Fast"
        case .inferred where inferredInterval?.isInProgress == true: "Inferred fast in progress"
        case .inferred: "Inferred fast"
        case .previouslySaved: "Previously saved fast"
        case .unavailable: "Saved fast · Details unavailable"
        }
    }

    var ribbonKind: TemporalRibbonIntervalItem.Kind {
        switch kind {
        case .recorded: .recorded
        case .active: .active
        case .automatic: .automatic
        case .inferred: .automatic
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
        if kind == .inferred {
            components.append(
                inferredInterval?.isInProgress == true
                    ? "start action available"
                    : "save action available"
            )
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
        if kind == .inferred {
            components.append("source food \(inferredInterval?.sourceDescription ?? "")")
            components.append(inferredInterval?.isInProgress == true ? "Start fast available" : "Save fast available")
        }
        return components.joined(separator: ", ")
    }
}
