import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length switch_case_alignment

struct TodayGoalView: View {
    @Environment(\.calendar) var calendar
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone
    @Environment(\.liveActivityCoordinator) var liveActivityCoordinator
    @Environment(\.suppressAutomaticLiveActivityOffer) var suppressAutomaticLiveActivityOffer
    let snapshot: TodayFeatureSnapshot
    @State var activeTimelineID = UUID()
    @State var controller = TodayFeatureController()
    @State var endTimeEditor: EndTimeEditorPresentation?
    @State var foodEditor: FoodEditorPresentation?
    @State var isDrinkSheetPresented = false
    @State var caloricFavouritePending: HydrationFavourite?
    @State var isCaloricFavouriteConfirmationPresented = false
    @State var hydrationEditor: HydrationEditorPresentation?
    @State var drinkAnnouncement: String?
    @State var caloricFavouriteSaveError: String?
    @State var isEndConfirmationPresented = false
    @State var isAutomaticLiveActivityOfferPresented = false
    @State var isLiveActivityDisclosurePresented = false
    @State var isLiveActivityActionInFlight = false
    @State var liveActivityControlState: LiveActivityControlState = .show
    @State var startTimeEditor: StartTimeEditorPresentation?

    let clock: any AppClock
    let previewTimelineError: String?

    var authoritativeSettings: AppSettingsSnapshot? {
        snapshot.settings.count == 1 ? snapshot.settings[0] : nil
    }

    var authoritativeActiveFast: ActiveFastSnapshot? {
        snapshot.activeFasts.count == 1 ? snapshot.activeFasts[0] : nil
    }

    init(
        snapshot: TodayFeatureSnapshot = .init(
            settings: [], activeFasts: [], foodEntries: [], hydrationEntries: []
        ),
        clock: any AppClock = SystemAppClock(),
        previewTimelineError: String? = nil
    ) {
        self.snapshot = snapshot
        self.clock = clock
        self.previewTimelineError = previewTimelineError
    }

    var body: some View {
        ScreenLayout(title: "Today", identifier: "today") {
            Group {
                if snapshot.settings.count > 1 || snapshot.activeFasts.count > 1 {
                    Label(
                        "uFast found conflicting local records. Nothing was changed.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(UFastTheme.error)
                    .uFastCard(accent: UFastTheme.apricot)
                    .accessibilityIdentifier("today.data-integrity-error")
                } else if let activeFast = authoritativeActiveFast {
                    let goal = authoritativeSettings?.fastingGoal ?? .default

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        activeFastView(
                            activeFast,
                            goal: goal,
                            now: clock.now
                        )
                    }
                    .id(activeTimelineID)
                } else {
                    let goal = authoritativeSettings?.fastingGoal ?? .default
                    let presentation = InactiveFastPresentation(
                        now: clock.now,
                        goal: goal
                    )

                    InactiveFastView(
                        goal: goal,
                        target: formatted(presentation.targetDate),
                        fastRecorded: controller.fastRecorded,
                        startError: controller.startError,
                        onStart: {
                            startFast(goal: goal)
                        },
                        onStartPast: {
                            startTimeEditor = StartTimeEditorPresentation(
                                mode: .create,
                                initialStartDate: clock.now
                            )
                        },
                        additionalContent: AnyView(foodSection)
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                activeTimelineID = UUID()
                refreshLiveActivityControl()
            }
        }
        .task(id: authoritativeActiveFast?.id) {
            refreshLiveActivityControl()
            await offerAutomaticLiveActivityIfEligible()
        }
        .onChange(of: authoritativeActiveFast?.id) { oldID, newID in
            if oldID != newID {
                caloricFavouritePending = nil
                caloricFavouriteSaveError = nil
            }
        }
        .onAppear { controller.connect(commands: applicationCommands) }
        .onChange(of: applicationCommands != nil) { _, _ in
            controller.connect(commands: applicationCommands)
        }
        .onChange(of: controller.fastRecorded) { _, isRecorded in
            if isRecorded {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Fast recorded."
                )
            }
        }
        .onChange(of: drinkAnnouncement) { _, announcement in
            if let announcement {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
        .alert("End this fast?", isPresented: $isEndConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("End fast") {
                endFastNow()
            }
        } message: {
            Text("This will record the end time as now.")
        }
        .sheet(item: $startTimeEditor) { presentation in
            StartTimeEditor(
                mode: presentation.mode,
                initialStartDate: presentation.initialStartDate,
                clock: clock,
                hasConflict: { startDate in
                    hasStartConflict(
                        startDate,
                        mode: presentation.mode
                    )
                },
                onConfirm: { startDate in
                    try saveStartTime(presentation.mode, startDate: startDate)
                    startTimeEditor = nil
                },
                onCancel: {
                    startTimeEditor = nil
                }
            )
        }
        .sheet(item: $endTimeEditor) { presentation in
            EndTimeEditor(
                startDate: presentation.startDate,
                initialEndDate: presentation.initialEndDate,
                clock: clock,
                onConfirm: { endDate in
                    try saveEndTime(endDate)
                    endTimeEditor = nil
                },
                onCancel: {
                    endTimeEditor = nil
                }
            )
        }
        .sheet(item: $foodEditor) { presentation in
            FoodEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: authoritativeActiveFast?.startDate,
                onSave: { draft, endingActiveFast in
                    try saveFood(
                        draft,
                        record: presentation.record,
                        endingActiveFast: endingActiveFast
                    )
                    foodEditor = nil
                },
                onDelete: presentation.record.map { record in
                    { confirmingInferredImpact in
                        try deleteFood(record, confirmingInferredImpact: confirmingInferredImpact)
                        foodEditor = nil
                    }
                },
                onCancel: {
                    foodEditor = nil
                }
            )
        }
        .sheet(isPresented: $isDrinkSheetPresented) {
            AddDrinkSheet(
                favourites: HydrationFavouriteProvider.combined(
                    settings: authoritativeSettings,
                    userCreated: snapshot.hydrationFavourites
                ),
                onAdd: { favourite in
                    try addFavouriteDrink(favourite)
                    caloricFavouriteSaveError = nil
                    drinkAnnouncement = "\(favourite.displayName), "
                        + "\(favourite.volumeMillilitres) millilitres, added."
                    isDrinkSheetPresented = false
                },
                onConfirmationRequired: { favourite in
                    caloricFavouriteSaveError = nil
                    caloricFavouritePending = favourite
                    isDrinkSheetPresented = false
                    isCaloricFavouriteConfirmationPresented = true
                },
                onChooseAnother: {
                    isDrinkSheetPresented = false
                    hydrationEditor = HydrationEditorPresentation(record: nil)
                },
                onCancel: { isDrinkSheetPresented = false }
            )
        }
        .alert(
            "This entry is during your recorded fast.",
            isPresented: $isCaloricFavouriteConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {
                caloricFavouritePending = nil
            }
            Button("Save and end fast") {
                savePendingCaloricFavourite(endingActiveFast: true)
            }
        } message: {
            Text(
                "Saving this caloric event records the drink and ends your fast at "
                    + "\(clock.now.formatted(date: .omitted, time: .shortened))."
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: authoritativeActiveFast?.startDate,
                onSave: { draft, endingActiveFast in
                    try saveHydration(draft, record: presentation.record, endingActiveFast: endingActiveFast)
                    hydrationEditor = nil
                },
                onDelete: presentation.record.map { record in { confirmingInferredImpact in
                    try deleteHydration(record, confirmingInferredImpact: confirmingInferredImpact)
                    hydrationEditor = nil
                } },
                onCancel: { hydrationEditor = nil }
            )
        }
        .alert(
            AutomaticLiveActivityCopy.title,
            isPresented: $isAutomaticLiveActivityOfferPresented
        ) {
            Button(
                AutomaticLiveActivityCopy.showAutomatically,
                action: enableAutomaticLiveActivities
            )
            .accessibilityIdentifier("fast.automatic-offer.show")
            Button(
                AutomaticLiveActivityCopy.notNow,
                role: .cancel,
                action: disableAutomaticLiveActivities
            )
            .accessibilityIdentifier("fast.automatic-offer.not-now")
        } message: {
            Text(AutomaticLiveActivityCopy.message)
        }
        .alert(
            "Show Live Activity?",
            isPresented: $isLiveActivityDisclosurePresented
        ) {
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("fast.live-activity.disclosure.cancel")
            Button("Show Live Activity", action: showLiveActivity)
                .accessibilityIdentifier("fast.live-activity.disclosure.show")
        } message: {
            Text(ActiveFastLiveActivityStatusCopy.disclosure)
        }
    }
}

extension TodayGoalView {
    func refreshLiveActivityControl() {
        guard let liveActivityCoordinator else { return }
        Task {
            liveActivityControlState = await liveActivityCoordinator.controlState()
        }
    }

    private func offerAutomaticLiveActivityIfEligible() async {
        guard !suppressAutomaticLiveActivityOffer else { return }
        guard authoritativeActiveFast != nil,
              authoritativeSettings?.automaticLiveActivityPreference == .notAsked,
              let liveActivityCoordinator
        else { return }

        guard liveActivityCoordinator.isAvailableForAutomaticConsent() else {
            return
        }

        // This task runs after the committed query result is rendered. Yielding
        // once keeps consent subordinate to that visible Today state.
        await Task.yield()
        guard authoritativeActiveFast != nil,
              authoritativeSettings?.automaticLiveActivityPreference == .notAsked
        else { return }
        isAutomaticLiveActivityOfferPresented = true
    }

    private func enableAutomaticLiveActivities() {
        persistAutomaticLiveActivityPreference(.enabled, requestAfterCommit: true)
    }

    private func disableAutomaticLiveActivities() {
        persistAutomaticLiveActivityPreference(.disabled, requestAfterCommit: false)
    }

    private func persistAutomaticLiveActivityPreference(
        _ preference: AutomaticLiveActivityPreference,
        requestAfterCommit: Bool
    ) {
        guard authoritativeSettings != nil else { return }

        do {
            try controller.updateAutomaticPreference(
                preference,
                projectSystemSurfaces: requestAfterCommit
            ) {
                refreshLiveActivityControl()
            }
            controller.liveActivityStatus = nil
        } catch {
            controller.liveActivityStatus = AutomaticLiveActivityCopy.settingsSaveFailure
        }
    }

    func showLiveActivity() {
        guard let liveActivityCoordinator else { return }
        isLiveActivityActionInFlight = true
        Task {
            let result = await liveActivityCoordinator.show()
            controller.setLiveActivityStatus(result)
            isLiveActivityActionInFlight = false
            refreshLiveActivityControl()
        }
    }

    func hideLiveActivity() {
        guard let liveActivityCoordinator else { return }
        isLiveActivityActionInFlight = true
        Task {
            let result = await liveActivityCoordinator.hide()
            controller.setLiveActivityStatus(result)
            isLiveActivityActionInFlight = false
            refreshLiveActivityControl()
        }
    }

    var timelineEntries: [TodayTimelineEntry] {
        TodayTimeline.entries(
            food: snapshot.foodEntries,
            drinks: snapshot.hydrationEntries,
            now: clock.now,
            calendar: calendar
        )
    }

    func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }

    private func startFast(goal: FastingGoal) {
        controller.startFast(goal: goal, onOutcome: refreshLiveActivityControl)
    }

    private func saveStartTime(
        _ mode: StartTimeEditor.Mode,
        startDate: Date
    ) throws {
        let goal = authoritativeSettings?.fastingGoal ?? .default

        switch mode {
        case .create:
            try controller.startFast(
                at: startDate, goal: goal, onOutcome: refreshLiveActivityControl
            )
        case .correct:
            try controller.correctActiveFastStart(to: startDate, goal: goal)
        }
    }

    private func hasStartConflict(
        _ startDate: Date,
        mode: StartTimeEditor.Mode
    ) -> Bool {
        let excludedID = mode == .correct ? authoritativeActiveFast?.id : nil
        return controller.hasStartConflict(startDate: startDate, excluding: excludedID)
    }

    private func endFastNow() {
        let goal = authoritativeSettings?.fastingGoal ?? .default

        controller.endFast(goal: goal)
    }

    private func saveEndTime(_ endDate: Date) throws {
        let goal = authoritativeSettings?.fastingGoal ?? .default
        try controller.endFast(at: endDate, goal: goal)
    }

    private func saveFood(
        _ draft: FoodEntryDraft,
        record: FoodEntrySnapshot?,
        endingActiveFast: Bool
    ) throws {
        try controller.saveFood(
            draft,
            replacing: record?.id,
            goal: authoritativeSettings?.fastingGoal ?? .default,
            endingActiveFast: endingActiveFast
        )
    }

    private func deleteFood(_ record: FoodEntrySnapshot, confirmingInferredImpact: Bool = false) throws {
        try controller.deleteFood(id: record.id, confirmingInferredImpact: confirmingInferredImpact)
    }

    private func addFavouriteDrink(_ favourite: HydrationFavourite) throws {
        try controller.addFavouriteDrink(favourite)
    }

    private func saveHydration(_ draft: HydrationEntryDraft, record: HydrationEntrySnapshot?, endingActiveFast: Bool) throws {
        try controller.saveHydration(
            draft,
            replacing: record?.id,
            goal: authoritativeSettings?.fastingGoal ?? .default,
            endingActiveFast: endingActiveFast
        )
    }

    private func deleteHydration(_ record: HydrationEntrySnapshot, confirmingInferredImpact: Bool = false) throws {
        try controller.deleteHydration(id: record.id, confirmingInferredImpact: confirmingInferredImpact)
    }

    func openTimelineEntry(_ entry: TodayTimelineEntry) {
        switch entry.kind {
        case let .food(id, _, _):
            foodEditor = FoodEditorPresentation(record: snapshot.foodEntries.first { $0.id == id })
        case let .drink(id, _, _, _):
            hydrationEditor = HydrationEditorPresentation(
                record: snapshot.hydrationEntries.first { $0.id == id }
            )
        }
    }

    func timelineName(_ entry: TodayTimelineEntry) -> String {
        switch entry.kind { case let .food(_, name, _), let .drink(_, name, _, _): name }
    }

    func timelineSymbol(_ entry: TodayTimelineEntry) -> String {
        if case .food = entry.kind {
            return "fork.knife"
        }; return "drop.fill"
    }

    func timelineDetail(_ entry: TodayTimelineEntry) -> String {
        switch entry.kind {
        case let .food(_, _, caloric): caloric ? "Caloric" : "Non-caloric"
        case let .drink(_, _, volume, caloric): "\(volume) ml · \(caloric ? "Caloric" : "Non-caloric")"
        }
    }

    func timelineAccessibilityLabel(_ entry: TodayTimelineEntry) -> String {
        "\(timelineSymbol(entry) == "fork.knife" ? "Food" : "Drink"), \(timelineName(entry))"
    }
}
