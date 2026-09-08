import SwiftUI

struct HistoryView: View {
    static let futureDisplayDayCount = 1
    static let futureRailContextDayCount = 4
    static let bottomScrollClearance: CGFloat = 96

    @Environment(\.calendar) var calendar
    @Environment(\.appTextResolver) var textResolver
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.historyPresentationInvalidation) var historyPresentationInvalidation
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone

    let model: HistoryPresentationModel
    @State var editor: CompletedFastEditorPresentation?
    @State var inferredConversion: InferredFastConversionPresentation?
    @State var inferredRecoveryError: InferredFastRecoveryError?
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
    @State var durationPulse: HistoryDurationPulse
    @State var capTransitionPending = false

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
        historyPresentation
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
        _durationPulse = State(
            initialValue: HistoryDurationPulse(
                clock: clock,
                driver: clock is MutableAppClock
                    ? ManualHistoryDurationCadence()
                    : SystemHistoryDurationCadence()
            )
        )
    }

    var body: some View {
        historyBody
    }

    func visibleFastItems(at now: Date) -> [HistoryVisibleFastItem] {
        guard let visible = settledVisibleWindow?.interval else { return [] }
        let window = visible.start ..< visible.end
        let normalItems = liveHistoryPresentation?.visibleFastItems(activeEndingAt: now) ?? []
        let hiddenItems = liveHistoryPresentation?.hiddenInferredFastItems ?? []
        return (normalItems + hiddenItems)
            .filter { $0.intersects(window) }
            .sorted { $0.startDate < $1.startDate }
    }

    func reenableInferredFast(_ item: HistoryVisibleFastItem) {
        guard let interval = item.inferredInterval,
              let applicationCommands
        else {
            inferredRecoveryError = .unavailable
            return
        }
        do {
            try applicationCommands.reenableInferredFast(
                sourceBoundaryReference: interval.sourceBoundaryReference,
                expectedStartDate: interval.startDate,
                expectedEndDate: interval.endDate,
                expectedSourceDescription: interval.sourceDescription,
                expectedGoal: interval.goal,
                expectedState: interval.state
            )
            inferredRecoveryError = nil
            _ = model.reloadHistoryAfterMutation()
        } catch let error as InferredFastSuppressionError {
            inferredRecoveryError = error == .candidateUnavailable ? .unavailable : .failed
            _ = model.reloadHistoryAfterMutation()
        } catch {
            inferredRecoveryError = .failed
            _ = model.reloadHistoryAfterMutation()
        }
    }

    var motionIntervalsAtCurrentTime: [TemporalRibbonIntervalItem] {
        motionSnapshot?.presentation.loadedRibbonIntervals
            ?? historyPresentation?.loadedIntervals
            ?? []
    }

    /// Keeps the single duration pulse scoped to a visible History
    /// presentation that actually contains a current interval. The cap is a
    /// separate one-shot deadline; ordinary pulses never enter this path.
    func syncDurationPulseLifecycle() {
        guard isTabSelected,
              scenePhase == .active,
              presentedHistorySheetID == "none",
              let presentation = historyPresentation,
              presentation.fastItems.contains(where: \.durationSpec.isCurrent)
        else {
            durationPulse.stop()
            return
        }

        durationPulse.start()
        let capDate = presentation.fastItems
            .filter(\.durationSpec.isCurrent)
            .compactMap(\.durationSpec.capDate)
            .min()
        durationPulse.armCapDeadline(at: capDate)
    }
}

enum InferredFastRecoveryError: Equatable {
    case unavailable
    case failed
}
