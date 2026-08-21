import SwiftUI

struct HistoryView: View {
    static let futureDisplayDayCount = 1
    static let futureRailContextDayCount = 4

    @Environment(\.calendar) var calendar
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.historyPresentationInvalidation) var historyPresentationInvalidation
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone

    let model: HistoryPresentationModel
    @State var editor: CompletedFastEditorPresentation?
    @State var inferredConversion: InferredFastConversionPresentation?
    @State var foodEditor: HistoryFoodEditorPresentation?
    @State var hydrationEditor: HistoryHydrationEditorPresentation?
    @State var directHistoricalEntry: DirectHistoricalEntryPresentation?
    @State var eventGroupDisclosure: TemporalEventGroup?
    @State var isCalendarPresented = false
    @State var temporalMovementPhase = TemporalCarouselMovementPhase.settled
    @State var coupledScrollPresentation = TemporalCoupledScrollPresentation()
    @State var historyInteractionRevision = 0
    @State var isDateRailMoving = false
    @State var settledVisibleWindow: TemporalRibbonWindow?

    let clock: any AppClock
    let isTabSelected: Bool
    let onSelectToday: () -> Void

    var historyData: HistoryDataSlice? {
        model.historyData
    }

    var historyPresentation: HistoryPresentationSnapshot? {
        model.historyPresentation
    }

    var motionSnapshot: HistoryMotionSnapshot? {
        model.motionSnapshot
    }

    var motionInitialLoading: Bool {
        model.motionInitialLoading
    }

    var motionFailedEdges: Set<HistoryMotionEdge> {
        model.motionFailedEdges
    }

    var selectedDate: Date {
        model.selectedDate
    }

    var completedFasts: [HistoryFastSnapshot] {
        historyData?.completedFasts ?? []
    }

    var activeFasts: [HistoryFastSnapshot] {
        historyData?.activeFast.map { [$0] } ?? []
    }

    var foodEntries: [FoodEntrySnapshot] {
        historyData?.foods ?? []
    }

    var hydrationEntries: [HydrationEntrySnapshot] {
        historyData?.drinks ?? []
    }

    var authoritativeSettings: AppSettingsSnapshot? {
        historyData?.settings
    }

    var authoritativeActiveFast: HistoryFastSnapshot? {
        historyData?.activeFast
    }

    var liveHistoryPresentation: HistoryPresentationSnapshot? {
        guard let historyData else { return historyPresentation }
        return HistoryPresentationBuilder.build(
            data: historyData, locale: locale, calendar: calendar,
            timeZone: timeZone, referenceNow: clock.now
        )
    }

    init(
        model: HistoryPresentationModel,
        clock: any AppClock,
        isTabSelected: Bool = true,
        onSelectToday: @escaping () -> Void = {}
    ) {
        self.model = model
        self.clock = clock
        self.isTabSelected = isTabSelected
        self.onSelectToday = onSelectToday
    }

    var body: some View {
        historyBody
    }

    func visibleFastItems(at now: Date) -> [HistoryVisibleFastItem] {
        guard let visible = settledVisibleWindow?.interval else { return [] }
        let window = visible.start ..< visible.end
        return (liveHistoryPresentation?.visibleFastItems(activeEndingAt: now) ?? [])
            .filter { $0.intersects(window) }
            .sorted { $0.startDate < $1.startDate }
    }

    var motionIntervalsAtCurrentTime: [TemporalRibbonIntervalItem] {
        let now = clock.now
        let motion = motionSnapshot?.presentation.ribbonIntervals(activeEndingAt: now)
            ?? historyPresentation?.intervals(activeEndingAt: now) ?? []
        guard let live = liveHistoryPresentation else { return motion }
        let inferred = live.visibleFastItems(activeEndingAt: now).filter { $0.kind == .inferred }
        guard !inferred.isEmpty else { return motion }
        let inferredIDs = Set(inferred.map(\.id))
        return (motion.filter { !inferredIDs.contains($0.id) } + inferred.map(\.ribbonItem))
            .sorted { $0.start < $1.start }
    }
}
