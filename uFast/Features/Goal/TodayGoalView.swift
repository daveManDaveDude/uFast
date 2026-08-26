import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length line_length switch_case_alignment

struct TodayGoalView: View {
    @Environment(\.calendar) var calendar
    @Environment(\.locale) var locale
    @Environment(\.applicationCommands) var applicationCommands
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.timeZone) var timeZone
    @Environment(\.liveActivityCoordinator) var liveActivityCoordinator
    @Environment(\.appTextResolver) var textResolver
    @Environment(\.suppressAutomaticLiveActivityOffer) var suppressAutomaticLiveActivityOffer
    let snapshot: TodayFeatureSnapshot
    @State var activeTimelineID = UUID()
    @State var controller = TodayFeatureController()
    @State var endTimeEditor: EndTimeEditorPresentation?
    @State var foodEditor: FoodEditorPresentation?
    @State var isFoodSheetPresented = false
    @State var foodFavouritePending: FoodFavouriteSnapshot?
    @State var foodFavouritePendingOperation: FoodFavouriteQuickAddOperation?
    @State var foodFavouriteConfirmationContext = CaloricEventConfirmationContext(fallbackKind: .active)
    @State var isFoodFavouriteConfirmationPresented = false
    @State var isDrinkSheetPresented = false
    @State var caloricFavouritePending: HydrationFavourite?
    @State var caloricFavouriteConfirmationContext = CaloricEventConfirmationContext(
        fallbackKind: .active
    )
    @State var isCaloricFavouriteConfirmationPresented = false
    @State var hydrationEditor: HydrationEditorPresentation?
    @State var drinkAnnouncement: String?
    @State var caloricFavouriteSaveError: String?
    @State var foodFavouriteSaveError: String?
    @State var foodFavouriteCommitState: FoodFavouriteCommitState?
    @State var isEndConfirmationPresented = false
    @State var isAutomaticLiveActivityOfferPresented = false
    @State var isLiveActivityDisclosurePresented = false
    @State var isLiveActivityActionInFlight = false
    @State var liveActivityControlState: LiveActivityControlState = .show
    @State var startTimeEditor: StartTimeEditorPresentation?

    let clock: any AppClock
    let previewTimelineFailure: TodayDataProviderFailure?

    var authoritativeSettings: AppSettingsSnapshot? {
        snapshot.settings.count == 1 ? snapshot.settings[0] : nil
    }

    var authoritativeActiveFast: ActiveFastSnapshot? {
        snapshot.activeFasts.count == 1 ? snapshot.activeFasts[0] : nil
    }

    var timelineFailureMessage: String? {
        guard let previewTimelineFailure else { return nil }
        switch previewTimelineFailure {
        case .snapshotUnavailable:
            return textResolver(.todayTimelineLoadError)
        }
    }

    init(
        snapshot: TodayFeatureSnapshot = .init(
            settings: [], activeFasts: [], foodEntries: [], hydrationEntries: []
        ),
        clock: any AppClock = SystemAppClock(),
        previewTimelineFailure: TodayDataProviderFailure? = nil
    ) {
        self.snapshot = snapshot
        self.clock = clock
        self.previewTimelineFailure = previewTimelineFailure
    }
}

extension TodayGoalView {
    var body: some View {
        ScreenLayout(title: textResolver(.todayTitle), identifier: "today") {
            Group {
                if snapshot.settings.count > 1 || snapshot.activeFasts.count > 1 {
                    Label(
                        textResolver(.todayDataIntegrity),
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
                foodFavouritePending = nil
                foodFavouritePendingOperation = nil
                if foodFavouriteCommitState == .saving {
                    foodFavouriteSaveError = nil
                    foodFavouriteCommitState = nil
                }
            }
        }
        .onAppear {
            controller.connect(commands: applicationCommands)
            controller.setTextResolver(textResolver)
        }
        .onChange(of: applicationCommands != nil) { _, _ in
            controller.connect(commands: applicationCommands)
        }
        .onChange(of: controller.fastRecorded) { _, isRecorded in
            if isRecorded {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: textResolver(.fastRecorded)
                )
            }
        }
        .onChange(of: drinkAnnouncement) { _, announcement in
            guard let announcement else { return }
            UIAccessibility.post(notification: .announcement, argument: announcement)
            drinkAnnouncement = nil
        }
        .alert(textResolver(.endFastConfirmationTitle), isPresented: $isEndConfirmationPresented) {
            Button(textResolver(.cancel), role: .cancel) {}
            Button(textResolver(.endFastAction)) {
                endFastNow()
            }
        } message: {
            Text(textResolver(.endFastMessage))
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
                favourites: HydrationFavouriteProvider.favourites(records: snapshot.hydrationFavourites),
                onAdd: { favourite in
                    try addFavouriteDrink(favourite)
                    caloricFavouriteSaveError = nil
                    drinkAnnouncement = textResolver(
                        .drinkAddedAnnouncement(
                            name: localizedFavouriteName(favourite),
                            volumeMillilitres: favourite.volumeMillilitres
                        )
                    )
                    isDrinkSheetPresented = false
                },
                onConfirmationRequired: { favourite, context in
                    caloricFavouriteSaveError = nil
                    caloricFavouritePending = favourite
                    caloricFavouriteConfirmationContext = context
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
        .sheet(isPresented: $isFoodSheetPresented) {
            FoodFavouritePicker(
                clock: clock,
                favourites: snapshot.foodFavourites,
                onAdd: { favourite, operation in
                    try addFoodFavourite(operation)
                    foodFavouriteSaveError = nil
                    foodFavouriteCommitState = .success
                    drinkAnnouncement = textResolver(.foodFavouriteAddedAnnouncement(name: favourite.description))
                    isFoodSheetPresented = false
                },
                onConfirmationRequired: { favourite, operation, context in
                    foodFavouriteSaveError = nil
                    foodFavouriteCommitState = .saving
                    foodFavouritePending = favourite
                    foodFavouritePendingOperation = operation
                    foodFavouriteConfirmationContext = context
                    isFoodSheetPresented = false
                    isFoodFavouriteConfirmationPresented = true
                },
                onChooseAnother: {
                    isFoodSheetPresented = false
                    foodEditor = FoodEditorPresentation(record: nil)
                },
                onCancel: { isFoodSheetPresented = false }
            )
        }
        .sheet(
            isPresented: $isFoodFavouriteConfirmationPresented,
            onDismiss: {
                if foodFavouriteCommitState != .failure, foodFavouriteCommitState != .stale {
                    foodFavouritePending = nil
                    foodFavouritePendingOperation = nil
                }
            },
            content: {
                FoodFavouriteActiveFastConfirmation(
                    title: foodFavouriteConfirmationTitle,
                    consequence: foodFavouriteConfirmationMessage,
                    primaryActionTitle: foodFavouriteConfirmationActionTitle,
                    cancelTitle: textResolver(.cancel),
                    onCancel: {
                        foodFavouritePending = nil
                        foodFavouritePendingOperation = nil
                        foodFavouriteSaveError = nil
                        foodFavouriteCommitState = nil
                        isFoodFavouriteConfirmationPresented = false
                    },
                    onConfirm: {
                        savePendingFoodFavourite(endingActiveFast: true)
                    }
                )
            }
        )
        .alert(
            caloricFavouriteConfirmationTitle,
            isPresented: $isCaloricFavouriteConfirmationPresented
        ) {
            Button(textResolver(.cancel), role: .cancel) {
                caloricFavouritePending = nil
            }
            .accessibilityIdentifier("drink.caloric-favourite.confirmation.cancel")
            Button(caloricFavouriteConfirmationActionTitle) {
                savePendingCaloricFavourite(endingActiveFast: true)
            }
            .accessibilityIdentifier("drink.caloric-favourite.confirmation.primary")
        } message: {
            Text(caloricFavouriteConfirmationMessage)
                .accessibilityIdentifier("drink.caloric-favourite.confirmation.consequence")
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
            textResolver(.automaticOfferTitle),
            isPresented: $isAutomaticLiveActivityOfferPresented
        ) {
            Button(
                textResolver(.automaticOfferShow),
                action: enableAutomaticLiveActivities
            )
            .accessibilityIdentifier("fast.automatic-offer.show")
            Button(
                textResolver(.automaticOfferNotNow),
                role: .cancel,
                action: disableAutomaticLiveActivities
            )
            .accessibilityIdentifier("fast.automatic-offer.not-now")
        } message: {
            Text(textResolver(.automaticOfferMessage))
        }
        .alert(
            textResolver(.liveActivityDisclosureTitle),
            isPresented: $isLiveActivityDisclosurePresented
        ) {
            Button(textResolver(.cancel), role: .cancel) {}
                .accessibilityIdentifier("fast.live-activity.disclosure.cancel")
            Button(textResolver(.liveActivityShow), action: showLiveActivity)
                .accessibilityIdentifier("fast.live-activity.disclosure.show")
        } message: {
            Text(textResolver(.liveActivityDisclosureMessage))
        }
    }
}

private struct FoodFavouriteActiveFastConfirmation: View {
    let title: String
    let consequence: String
    let primaryActionTitle: String
    let cancelTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(UFastTheme.primary)
                    Text(consequence)
                        .foregroundStyle(UFastTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("food.favourite.confirmation.consequence")
                    Button(primaryActionTitle, action: onConfirm)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .accessibilityIdentifier("food.favourite.confirmation.primary")
                    Button(cancelTitle, action: onCancel)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("food.favourite.confirmation.cancel")
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .accessibilityIdentifier("food.favourite.confirmation")
            .background(UFastTheme.canvas)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
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
            controller.liveActivityStatus = textResolver(.settingsLiveActivitySaveError)
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

    private func addFoodFavourite(_ operation: FoodFavouriteQuickAddOperation) throws {
        try controller.addFoodFavourite(operation, endingActiveFast: false)
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

    func localizedFavouriteName(_ favourite: HydrationFavourite) -> String {
        favourite.displayName
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
        case let .food(_, _, caloric):
            textResolver(.drinkPickerClassification(isCaloric: caloric))
        case let .drink(_, _, volume, caloric):
            textResolver(.drinkPickerDetail(volumeMillilitres: volume, isCaloric: caloric))
        }
    }

    func timelineAccessibilityLabel(_ entry: TodayTimelineEntry) -> String {
        switch entry.kind {
        case .food:
            "\(textResolver(.historyFood)), \(timelineName(entry))"
        case .drink:
            "\(textResolver(.historyDrink)), \(timelineName(entry))"
        }
    }
}
