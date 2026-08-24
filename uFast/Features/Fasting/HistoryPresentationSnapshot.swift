import Foundation

// swiftlint:disable file_length function_body_length function_parameter_count trailing_comma opening_brace

struct HistoryTextContext: Equatable, Sendable {
    let locale: Locale
    let calendar: Calendar
    let timeZone: TimeZone
    let textResolver: AppTextResolver

    init(
        locale: Locale = .current,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        textResolver: AppTextResolver = .init()
    ) {
        self.locale = locale
        self.calendar = calendar
        self.timeZone = timeZone
        self.textResolver = textResolver
    }
}

struct HistoryPresentationSnapshot: Equatable {
    let window: DateInterval
    let fastItems: [HistoryVisibleFastItem]
    let events: [TemporalRibbonEventItem]
    let textContext: HistoryTextContext

    init(
        window: DateInterval,
        fastItems: [HistoryVisibleFastItem],
        events: [TemporalRibbonEventItem],
        textContext: HistoryTextContext = .init()
    ) {
        self.window = window
        self.fastItems = fastItems
        self.events = events
        self.textContext = textContext
    }

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
                isCaloric: true
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
    let textContext: HistoryTextContext

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
        textContext = snapshot.textContext
    }

    init(
        window: DateInterval,
        intervals: [HistoryMotionIntervalPrimitive],
        events: [HistoryMotionEventPrimitive],
        inferredContext: HistoryMotionInferredContext? = nil,
        textContext: HistoryTextContext = .init()
    ) {
        self.window = window
        self.intervals = intervals
        self.events = events
        self.inferredContext = inferredContext
        self.textContext = textContext
    }

    func ribbonIntervals(activeEndingAt now: Date) -> [TemporalRibbonIntervalItem] {
        let existing = intervals
            .filter { inferredContext == nil || $0.semanticKind != .inferred }
            .compactMap { $0.ribbonItem(activeEndingAt: now, textContext: textContext) }
        let projected = inferredContext?.project(
            now: now,
            visibleInterval: window.start ..< window.end
        ).map { HistoryVisibleFastItem.inferred($0, textContext: textContext).ribbonItem } ?? []
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
                title: textContext.textResolver(
                    .historyCopy(primitive.kind == .food ? .eventFood : .eventDrink)
                ),
                detail: "",
                accessibilityLabel: textContext.textResolver(
                    .historyMotionEvent(kind: primitive.kind == .food ? .food : .drink)
                ),
                kind: primitive.kind
            )
        }
    }
}

private extension HistoryMotionIntervalPrimitive {
    func ribbonItem(
        activeEndingAt now: Date,
        textContext: HistoryTextContext
    ) -> TemporalRibbonIntervalItem? {
        if let inferred = currentInferredInterval(at: now) {
            return HistoryVisibleFastItem.inferred(inferred, textContext: textContext).ribbonItem
        }
        guard semanticKind != .inferred else { return nil }
        return TemporalRibbonIntervalItem(
            id: id,
            start: start,
            end: isActive ? now : end,
            title: title ?? textContext.textResolver(
                .historyFastTitle(kind: kind == .active ? .active : .automatic, needsReview: false)
            ),
            detail: detail ?? "",
            accessibilityLabel: accessibilityLabel
                ?? textContext.textResolver(
                    .historyFastTitle(kind: kind == .active ? .active : .automatic, needsReview: false)
                ),
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
    let pseudolocalizationEnabled: Bool
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
        referenceNow: Date,
        textResolver: AppTextResolver = .init()
    ) -> HistoryPresentationSnapshot {
        let newKey = HistoryPresentationKey(
            data: data,
            localeIdentifier: locale.identifier,
            calendarIdentifier: calendar.identifier,
            timeZoneIdentifier: timeZone.identifier,
            activeFastIntersectsWindow: activeFastIntersectsWindow(
                in: data,
                at: referenceNow
            ),
            pseudolocalizationEnabled: textResolver.pseudolocalizationEnabled
        )
        if key == newKey, let snapshot {
            return snapshot
        }
        let built = HistoryPresentationBuilder.build(
            data: data,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            referenceNow: referenceNow,
            textResolver: textResolver
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
        referenceNow: Date,
        textResolver: AppTextResolver = .init()
    ) -> HistoryPresentationSnapshot {
        let textContext = HistoryTextContext(
            locale: locale,
            calendar: calendar,
            timeZone: timeZone,
            textResolver: textResolver
        )
        let window = data.window.start ..< data.window.end
        let boundaries = CaloricBoundaryExtractor.boundaries(
            food: data.foods.map {
                .init(id: $0.id, occurredAt: $0.occurredAt, description: $0.foodDescription, isCaloric: true)
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
            return .recorded(fast, textContext: textContext)
        }
        let active = data.activeFast.flatMap { fast -> HistoryVisibleFastItem? in
            guard fast.startDate < referenceNow,
                  AutomaticFastProjector.intersects(fast.startDate ..< referenceNow, window)
            else { return nil }
            return .active(fast, endingAt: referenceNow, textContext: textContext)
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
            return .previouslySaved(fast, textContext: textContext)
        }
        let unavailable = data.completedFasts.compactMap { fast -> HistoryVisibleFastItem? in
            guard fast.presentationIntegrity == .unavailable,
                  let end = fast.endDate,
                  AutomaticFastProjector.intersects(fast.startDate ..< end, window)
            else { return nil }
            return .unavailable(fast, textContext: textContext)
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
            ).map { HistoryVisibleFastItem.inferred($0, textContext: textContext) }
        }
        let legacyAutomatic: [HistoryVisibleFastItem] = if data.settings == nil {
            AutomaticFastProjector.project(
                boundaries: boundaries,
                visibleInterval: window,
                excluding: legacyAutomaticExclusions
            ).compactMap { interval -> HistoryVisibleFastItem? in
                guard !legacy.contains(where: { $0.intersects(interval.interval) }) else { return nil }
                return .automatic(interval, textContext: textContext)
            }
        } else {
            []
        }
        return HistoryPresentationSnapshot(
            window: data.window,
            fastItems: recorded + active + legacy + unavailable + (inferred ?? legacyAutomatic),
            events: makeEvents(
                data: data,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone,
                textResolver: textResolver
            ),
            textContext: textContext
        )
    }

    private static func makeEvents(
        data: HistoryDataSlice,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        textResolver: AppTextResolver
    ) -> [TemporalRibbonEventItem] {
        let foods = data.foods.map { food in
            let formattedDate = formatted(
                food.occurredAt, locale: locale, calendar: calendar, timeZone: timeZone
            )
            let nutrition = nutritionDetail(
                food.nutrition,
                textResolver: textResolver,
                locale: locale
            )
            let detailParts = [
                textResolver(.historyEventDetail(kind: .food, date: formattedDate)),
                nutrition,
            ].compactMap(\.self)
            let detail = detailParts.joined(
                separator: " \(textResolver(.historyCopy(.separatorMiddleDot))) "
            )
            let accessibilityParts = [
                textResolver(.historyFoodAccessibility(description: food.foodDescription, date: formattedDate)),
                nutrition,
            ].compactMap(\.self)
            let accessibility = accessibilityParts.joined(
                separator: "\(textResolver(.historyCopy(.separatorComma))) "
            )
            return TemporalRibbonEventItem(
                id: food.id, occurredAt: food.occurredAt, title: food.foodDescription,
                detail: detail, accessibilityLabel: accessibility, kind: .food
            )
        }
        let drinks = data.drinks.map { drink in
            let formattedDate = formatted(
                drink.occurredAt, locale: locale, calendar: calendar, timeZone: timeZone
            )
            let kind: AppText.HistoryEventKind = drink.isCaloric ? .caloricDrink : .nonCaloricDrink
            let detail = [
                textResolver(.historyVolume(value: drink.volumeMillilitres)),
                textResolver(.historyEventDetail(kind: kind, date: formattedDate)),
            ].joined(
                separator: textResolver(.historyCopy(.separatorSpace))
                    + textResolver(.historyCopy(.separatorMiddleDot))
                    + textResolver(.historyCopy(.separatorSpace))
            )
            return TemporalRibbonEventItem(
                id: drink.id,
                occurredAt: drink.occurredAt,
                title: drink.displayName,
                detail: detail,
                accessibilityLabel: textResolver(
                    .historyEventAccessibility(
                        kind: kind,
                        name: drink.displayName,
                        volumeMillilitres: drink.volumeMillilitres,
                        date: formattedDate
                    )
                ),
                kind: drink.isCaloric ? .caloricDrink : .nonCaloricDrink
            )
        }
        return foods + drinks
    }

    private static func nutritionDetail(
        _ nutrition: FoodNutrition,
        textResolver: AppTextResolver,
        locale: Locale
    ) -> String? {
        let values: [(AppText.FoodNutritionField, Double?)] = [
            (.energy, nutrition.energyKilocalories), (.protein, nutrition.proteinGrams),
            (.carbohydrate, nutrition.carbohydrateGrams), (.fat, nutrition.fatGrams),
            (.fibre, nutrition.fibreGrams), (.sugar, nutrition.sugarGrams), (.salt, nutrition.saltGrams),
        ]
        let parts = values.compactMap { label, value -> String? in
            guard let value else { return nil }
            let unit: AppText.FoodNutritionUnit = label == .energy ? .kilocalories : .grams
            return [
                textResolver(.foodNutritionField(label)),
                value.formatted(.number.locale(locale)),
                textResolver(.foodNutritionUnit(unit)),
            ].joined(separator: textResolver(.historyCopy(.separatorSpace)))
        }
        return parts.isEmpty
            ? nil
            : parts.joined(
                separator: textResolver(.historyCopy(.separatorComma))
                    + textResolver(.historyCopy(.separatorSpace))
            )
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
    let textContext: HistoryTextContext

    static func recorded(
        _ fast: HistoryFastSnapshot,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .recorded, fast: fast,
            inferredInterval: nil,
            textContext: textContext
        )
    }

    static func active(
        _ fast: HistoryFastSnapshot,
        endingAt endDate: Date,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: fast.id,
            startDate: fast.startDate,
            endDate: endDate,
            kind: .active,
            fast: fast,
            inferredInterval: nil,
            textContext: textContext
        )
    }

    static func previouslySaved(
        _ fast: HistoryFastSnapshot,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .previouslySaved, fast: fast,
            inferredInterval: nil,
            textContext: textContext
        )
    }

    static func unavailable(
        _ fast: HistoryFastSnapshot,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: fast.id, startDate: fast.startDate,
            endDate: fast.endDate ?? fast.startDate, kind: .unavailable, fast: fast,
            inferredInterval: nil,
            textContext: textContext
        )
    }

    static func automatic(
        _ interval: AutomaticFastInterval,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: interval.identity.boundaries.start.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .automatic,
            fast: nil,
            inferredInterval: nil,
            textContext: textContext
        )
    }

    static func inferred(
        _ interval: InferredFastInterval,
        textContext: HistoryTextContext = .init()
    ) -> Self {
        Self(
            id: interval.id,
            startDate: interval.startDate,
            endDate: interval.endDate,
            kind: .inferred,
            fast: nil,
            inferredInterval: interval,
            textContext: textContext
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
            inferredInterval: inferredInterval,
            textContext: textContext
        )
    }

    func intersects(_ interval: Range<Date>) -> Bool {
        AutomaticFastProjector.intersects(startDate ..< endDate, interval)
    }

    var title: String {
        switch kind {
        case .recorded: textContext.textResolver(.historyCopy(.recordedFast))
        case .active: textContext.textResolver(.historyCopy(.activeFast))
        case .automatic: textContext.textResolver(.historyCopy(.fast))
        case .inferred where inferredInterval?.isInProgress == true:
            textContext.textResolver(.historyCopy(.inferredFastInProgress))
        case .inferred: textContext.textResolver(.historyCopy(.inferredFast))
        case .previouslySaved:
            textContext.textResolver(
                .historyFastTitle(
                    kind: .previouslySaved,
                    needsReview: fast?.reviewState == .needsReview
                )
            )
        case .unavailable: textContext.textResolver(.historyCopy(.unavailableFast))
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
            ? HistoryTextFormatting.activeAccessibility(
                seconds: endDate.timeIntervalSince(startDate),
                resolver: textContext.textResolver
            )
            : HistoryTextFormatting.duration(
                from: startDate, to: endDate, resolver: textContext.textResolver
            )
        let start = HistoryTextFormatting.dateTime(
            startDate,
            calendar: textContext.calendar,
            locale: textContext.locale,
            timeZone: textContext.timeZone
        )
        let end = HistoryTextFormatting.dateTime(
            endDate,
            calendar: textContext.calendar,
            locale: textContext.locale,
            timeZone: textContext.timeZone
        )
        var components = [
            textContext.textResolver(.historyFastComponent(kind: .start, value: start)),
        ]
        if kind != .active {
            components[0] += textContext.textResolver(.historyCopy(.separatorSpace))
                + textContext.textResolver(.historyCopy(.separatorArrow))
                + textContext.textResolver(.historyCopy(.separatorSpace))
                + textContext.textResolver(.historyFastComponent(kind: .end, value: end))
        }
        components.append(
            textContext.textResolver(.historyFastComponent(kind: .duration, value: duration))
        )
        if kind == .recorded, let goal = fast?.capturedHistoricalGoal {
            components.append(
                textContext.textResolver(
                    .historyFastComponent(
                        kind: .goal,
                        value: textContext.textResolver(
                            .durationComponent(value: goal.hours, unit: .hour)
                        )
                    )
                )
            )
        }
        if let reviewBoundaryUnavailableDescription {
            components.append(reviewBoundaryUnavailableDescription)
        }
        if kind == .inferred {
            components.append(
                inferredInterval?.isInProgress == true
                    ? textContext.textResolver(.historyCopy(.startActionAvailable))
                    : textContext.textResolver(.historyCopy(.saveActionAvailable))
            )
        }
        return components.joined(
            separator: " \(textContext.textResolver(.historyCopy(.separatorMiddleDot))) "
        )
    }

    var accessibilityLabel: String {
        let duration = kind == .active
            ? HistoryTextFormatting.activeAccessibility(
                seconds: endDate.timeIntervalSince(startDate),
                resolver: textContext.textResolver
            )
            : HistoryTextFormatting.duration(
                from: startDate, to: endDate, resolver: textContext.textResolver
            )
        let start = HistoryTextFormatting.dateTime(
            startDate,
            calendar: textContext.calendar,
            locale: textContext.locale,
            timeZone: textContext.timeZone
        )
        let end = HistoryTextFormatting.dateTime(
            endDate,
            calendar: textContext.calendar,
            locale: textContext.locale,
            timeZone: textContext.timeZone
        )
        var components = [
            title,
            textContext.textResolver(.historyFastComponent(kind: .start, value: start)),
            textContext.textResolver(.historyFastComponent(kind: .duration, value: duration)),
        ]
        if kind != .active {
            components.insert(
                textContext.textResolver(.historyFastComponent(kind: .end, value: end)),
                at: 2
            )
        }
        if kind == .recorded, let goal = fast?.capturedHistoricalGoal {
            components.append(
                textContext.textResolver(
                    .historyFastComponent(
                        kind: .goal,
                        value: textContext.textResolver(
                            .durationComponent(value: goal.hours, unit: .hour)
                        )
                    )
                )
            )
        }
        if let reviewBoundaryUnavailableDescription {
            components.append(reviewBoundaryUnavailableDescription)
        }
        if kind == .inferred {
            let sourceKind: AppText.HistoryEventFamily = inferredInterval.map {
                $0.sourceKind == .hydration ? .drink : .food
            } ?? .food
            components.append(
                textContext.textResolver(
                    .historyFastSource(
                        kind: sourceKind,
                        description: inferredInterval?.sourceDescription ?? ""
                    )
                )
            )
            components.append(
                inferredInterval?.isInProgress == true
                    ? textContext.textResolver(.historyCopy(.startActionAvailable))
                    : textContext.textResolver(.historyCopy(.saveActionAvailable))
            )
        }
        return components.joined(
            separator: textContext.textResolver(.historyCopy(.separatorComma))
                + textContext.textResolver(.historyCopy(.separatorSpace))
        )
    }

    private var reviewBoundaryUnavailableDescription: String? {
        guard fast?.reviewState == .needsReview else { return nil }
        guard let reference = fast?.retainedReviewBoundary else {
            return textContext.textResolver(.historyFastBoundary(kind: .unavailable))
        }
        return textContext.textResolver(
            .historyFastBoundary(
                kind: reference.kind == .hydration ? .formerDrink : .formerFood
            )
        )
    }
}
