import SwiftData
import SwiftUI
import UIKit

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length line_length switch_case_alignment type_body_length

struct TodayGoalView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeZone) private var timeZone
    @Environment(\.liveActivityCoordinator) private var liveActivityCoordinator
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @Query(sort: [SortDescriptor(\FoodEntryRecord.occurredAt, order: .reverse)])
    private var foodEntries: [FoodEntryRecord]
    @Query(sort: [SortDescriptor(\HydrationEntryRecord.occurredAt, order: .reverse)])
    private var hydrationEntries: [HydrationEntryRecord]
    @State private var activeTimelineID = UUID()
    @State private var endError: String?
    @State private var endTimeEditor: EndTimeEditorPresentation?
    @State private var fastRecorded = false
    @State private var foodEditor: FoodEditorPresentation?
    @State private var isDrinkSheetPresented = false
    @State private var hydrationEditor: HydrationEditorPresentation?
    @State private var drinkAnnouncement: String?
    @State private var isEndConfirmationPresented = false
    @State private var isLiveActivityDisclosurePresented = false
    @State private var isLiveActivityActionInFlight = false
    @State private var liveActivityControlState: LiveActivityControlState = .show
    @State private var liveActivityStatus: String?
    @State private var startError: String?
    @State private var startTimeEditor: StartTimeEditorPresentation?

    private let clock: any AppClock
    private let previewTimelineError: String?

    init(
        clock: any AppClock = SystemAppClock(),
        previewTimelineError: String? = nil
    ) {
        self.clock = clock
        self.previewTimelineError = previewTimelineError
    }

    var body: some View {
        ScreenLayout(title: "Today", identifier: "today") {
            Group {
                if let activeFast = activeFasts.first {
                    let goal = settingsRecords.first?.fastingGoal ?? .default

                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        activeFastView(
                            activeFast,
                            goal: goal,
                            now: clock.now
                        )
                    }
                    .id(activeTimelineID)
                } else {
                    let goal = settingsRecords.first?.fastingGoal ?? .default
                    let presentation = InactiveFastPresentation(
                        now: clock.now,
                        goal: goal
                    )

                    InactiveFastView(
                        goal: goal,
                        target: formatted(presentation.targetDate),
                        fastRecorded: fastRecorded,
                        startError: startError,
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
        .task(id: activeFasts.first?.id) {
            refreshLiveActivityControl()
        }
        .onChange(of: fastRecorded) { _, isRecorded in
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
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                onSave: { draft, endingActiveFast in
                    try saveFood(
                        draft,
                        record: presentation.record,
                        endingActiveFast: endingActiveFast
                    )
                    foodEditor = nil
                },
                onDelete: presentation.record.map { record in
                    {
                        try deleteFood(record)
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
                favourites: HydrationFavouriteProvider.favourites(settings: settingsRecords.first),
                onAdd: { favourite in
                    try addFavouriteDrink(favourite)
                    drinkAnnouncement = "\(favourite.type.displayName), "
                        + "\(favourite.volumeMillilitres) millilitres, added."
                    isDrinkSheetPresented = false
                },
                onChooseAnother: {
                    isDrinkSheetPresented = false
                    hydrationEditor = HydrationEditorPresentation(record: nil)
                },
                onCancel: { isDrinkSheetPresented = false }
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                record: presentation.record,
                clock: clock,
                activeFastStart: activeFasts.first?.startDate,
                onSave: { draft, endingActiveFast in
                    try saveHydration(draft, record: presentation.record, endingActiveFast: endingActiveFast)
                    hydrationEditor = nil
                },
                onDelete: presentation.record.map { record in { try deleteHydration(record); hydrationEditor = nil } },
                onCancel: { hydrationEditor = nil }
            )
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

    private func activeFastView(
        _ activeFast: FastRecord,
        goal: FastingGoal,
        now: Date
    ) -> some View {
        let presentation = ActiveFastPresentation(
            startDate: activeFast.startDate,
            targetDate: activeFast.targetDate(currentGoal: goal),
            now: now
        )
        let target = formatted(presentation.targetDate)
        let started = formatted(activeFast.startDate)

        return ActiveFastProgressView(
            presentation: presentation,
            goal: goal,
            started: started,
            target: target,
            canEndNow: now > activeFast.startDate,
            endError: endError,
            onEnd: {
                isEndConfirmationPresented = true
            },
            onEditStart: {
                startTimeEditor = StartTimeEditorPresentation(
                    mode: .correct,
                    initialStartDate: activeFast.startDate
                )
            },
            onEndAtPastTime: {
                endTimeEditor = EndTimeEditorPresentation(
                    startDate: activeFast.startDate,
                    initialEndDate: clock.now
                )
            },
            additionalContent: AnyView(
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    liveActivitySection
                    foodSection
                }
            )
        )
    }

    @ViewBuilder
    private var liveActivitySection: some View {
        if liveActivityCoordinator != nil {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                UFastSectionHeading("Live Activity")
                Text(
                    "Show this active interval on the Lock Screen and Dynamic Island for up to 8 hours. Your recorded interval continues if the activity ends."
                )
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                switch liveActivityControlState {
                case .hide:
                    Button("Hide Live Activity", action: hideLiveActivity)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .disabled(isLiveActivityActionInFlight)
                        .accessibilityIdentifier("fast.live-activity.hide")
                case .show, .showAgain:
                    Button(
                        liveActivityControlState == .show
                            ? "Show Live Activity"
                            : "Show Live Activity again",
                        action: { isLiveActivityDisclosurePresented = true }
                    )
                    .buttonStyle(UFastSecondaryButtonStyle())
                    .disabled(isLiveActivityActionInFlight)
                    .accessibilityIdentifier(
                        liveActivityControlState == .show
                            ? "fast.live-activity.show"
                            : "fast.live-activity.show-again"
                    )
                case .unavailable:
                    EmptyView()
                }

                if let liveActivityStatus {
                    Label(liveActivityStatus, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.live-activity.status")
                }
            }
            .uFastCard(accent: UFastTheme.sky)
        }
    }

    private func refreshLiveActivityControl() {
        guard let liveActivityCoordinator else { return }
        Task {
            liveActivityControlState = await liveActivityCoordinator.controlState()
        }
    }

    private func showLiveActivity() {
        guard let liveActivityCoordinator else { return }
        isLiveActivityActionInFlight = true
        Task {
            let result = await liveActivityCoordinator.show()
            liveActivityStatus = liveActivityStatus(for: result)
            isLiveActivityActionInFlight = false
            refreshLiveActivityControl()
        }
    }

    private func hideLiveActivity() {
        guard let liveActivityCoordinator else { return }
        isLiveActivityActionInFlight = true
        Task {
            let result = await liveActivityCoordinator.hide()
            liveActivityStatus = liveActivityStatus(for: result)
            isLiveActivityActionInFlight = false
            refreshLiveActivityControl()
        }
    }

    private func liveActivityStatus(
        for result: ActiveFastLiveActivityResult
    ) -> String? {
        switch result {
        case let .unavailable(availability):
            switch availability {
            case .unsupported: ActiveFastLiveActivityStatusCopy.unsupported
            case .disabled: ActiveFastLiveActivityStatusCopy.disabled
            case .enabled: nil
            }
        case .requestFailed:
            ActiveFastLiveActivityStatusCopy.requestFailure
        case .hideFailed:
            ActiveFastLiveActivityStatusCopy.hideFailure
        case .shown, .alreadyShown, .hidden, .updated, .reconciled,
             .noActiveFast, .coalesced:
            nil
        }
    }

    private var todaysFoodEntries: [FoodEntryRecord] {
        foodEntries.filter { calendar.isDate($0.occurredAt, inSameDayAs: clock.now) }
    }

    private var todaysHydrationEntries: [HydrationEntryRecord] {
        hydrationEntries.filter { calendar.isDate($0.occurredAt, inSameDayAs: clock.now) }
    }

    private var timelineEntries: [TodayTimelineEntry] {
        TodayTimeline.entries(food: foodEntries, drinks: hydrationEntries, now: clock.now, calendar: calendar)
    }

    private var foodSection: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Button {
                foodEditor = FoodEditorPresentation(record: nil)
            } label: {
                HStack {
                    Label("Log food", systemImage: "fork.knife")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("food.add")

            Button {
                isDrinkSheetPresented = true
            } label: {
                HStack {
                    Label("Add drink", systemImage: "drop")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(UFastSecondaryButtonStyle())
            .accessibilityIdentifier("drink.add")

            HStack {
                Text("Fluids today")
                    .font(.headline)
                    .foregroundStyle(UFastTheme.primary)
                Spacer()
                Text("\(TodayTimeline.fluidTotal(timelineEntries)) ml")
                    .foregroundStyle(UFastTheme.primary)
                    .accessibilityIdentifier("drink.total")
            }
            .uFastCard()

            if let previewTimelineError {
                Label(previewTimelineError, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.error)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.error")
            } else if timelineEntries.isEmpty {
                Text("Food and drinks you add today will appear here.")
                    .foregroundStyle(UFastTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .uFastCard()
                    .accessibilityIdentifier("timeline.empty")
            } else {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                    UFastSectionHeading("Today timeline")
                    ForEach(timelineEntries) { entry in
                        Button { openTimelineEntry(entry) } label: {
                            HStack(alignment: .top, spacing: UFastTheme.Spacing.standard) {
                                Image(systemName: timelineSymbol(entry))
                                    .foregroundStyle(UFastTheme.action)
                                    .frame(width: 24, height: 24)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timelineName(entry))
                                        .foregroundStyle(UFastTheme.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(entry.occurredAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(UFastTheme.secondaryText)
                                    Text(timelineDetail(entry))
                                        .font(.caption)
                                        .foregroundStyle(UFastTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(UFastTheme.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(timelineAccessibilityLabel(entry))
                        .accessibilityValue("\(timelineDetail(entry)), " + entry.occurredAt.formatted(date: .omitted, time: .shortened))
                        .accessibilityHint("Opens this event for editing.")
                        .accessibilityIdentifier("timeline.entry.\(entry.id.uuidString)")

                        if entry.id != timelineEntries.last?.id {
                            Divider()
                        }
                    }
                }
                .uFastCard()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ date: Date) -> String {
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
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        let service = FastStartService(
            repository: repository,
            clock: clock
        )

        do {
            let fast = try service.startFast(goal: goal)
            WidgetProjectionSupport.publish(fast, goal: goal, now: clock.now)
            startError = nil
            fastRecorded = false
        } catch {
            startError = "Your fast couldn’t be started. Please try again."
        }
    }

    private func saveStartTime(
        _ mode: StartTimeEditor.Mode,
        startDate: Date
    ) throws {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        let service = FastStartService(
            repository: repository,
            clock: clock
        )
        let goal = settingsRecords.first?.fastingGoal ?? .default

        switch mode {
        case .create:
            let fast = try service.startFast(at: startDate, goal: goal)
            WidgetProjectionSupport.publish(fast, goal: goal, now: clock.now)
            fastRecorded = false
        case .correct:
            let fast = try service.correctActiveFastStart(to: startDate)
            WidgetProjectionSupport.publish(fast, goal: goal, now: clock.now)
            Task { await liveActivityCoordinator?.didCommitActiveFastChange() }
        }
    }

    private func hasStartConflict(
        _ startDate: Date,
        mode: StartTimeEditor.Mode
    ) -> Bool {
        let repository = SwiftDataActiveFastRepository(modelContext: modelContext)
        let service = FastStartService(repository: repository, clock: clock)
        let excludedID = mode == .correct ? activeFasts.first?.id : nil
        return (try? service.hasConflict(
            startDate: startDate,
            excluding: excludedID
        )) ?? false
    }

    private func endFastNow() {
        let service = makeEndService()
        let goal = settingsRecords.first?.fastingGoal ?? .default

        do {
            _ = try service.endFast(goal: goal)
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
            endError = nil
            fastRecorded = true
        } catch {
            endError = "Your fast couldn’t be ended. Please try again."
        }
    }

    private func saveEndTime(_ endDate: Date) throws {
        let service = makeEndService()
        let goal = settingsRecords.first?.fastingGoal ?? .default

        _ = try service.endFast(at: endDate, goal: goal)
        WidgetProjectionSupport.clear()
        Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
        endError = nil
        fastRecorded = true
    }

    private func makeEndService() -> FastEndService {
        let repository = SwiftDataActiveFastRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-fast-save-failure"
            )
        )
        return FastEndService(
            repository: repository,
            clock: clock
        )
    }

    private func saveFood(
        _ draft: FoodEntryDraft,
        record: FoodEntryRecord?,
        endingActiveFast: Bool
    ) throws {
        let repository = makeFoodRepository()
        let service = FoodEntryService(repository: repository, clock: clock)
        try service.save(
            draft,
            replacing: record,
            goal: settingsRecords.first?.fastingGoal ?? .default,
            endingActiveFast: endingActiveFast
        )
        if endingActiveFast {
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
        }
    }

    private func deleteFood(_ record: FoodEntryRecord) throws {
        try makeFoodRepository().delete(record)
    }

    private func makeFoodRepository() -> SwiftDataFoodEntryRepository {
        SwiftDataFoodEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-food-save-failure"
            )
        )
    }

    private func addFavouriteDrink(_ favourite: HydrationFavourite) throws {
        let repository = SwiftDataHydrationEntryRepository(
            modelContext: modelContext,
            simulateSaveFailure: ProcessInfo.processInfo.arguments.contains(
                "--simulate-drink-save-failure"
            )
        )
        _ = try repository.createFavourite(favourite, occurredAt: clock.now)
    }

    private func saveHydration(_ draft: HydrationEntryDraft, record: HydrationEntryRecord?, endingActiveFast: Bool) throws {
        try HydrationEntryService(repository: makeHydrationRepository(), clock: clock).save(draft, replacing: record, goal: settingsRecords.first?.fastingGoal ?? .default, endingActiveFast: endingActiveFast)
        if endingActiveFast {
            WidgetProjectionSupport.clear()
            Task { await liveActivityCoordinator?.didCommitFastEndOrDeletion() }
        }
    }

    private func deleteHydration(_ record: HydrationEntryRecord) throws {
        try makeHydrationRepository().delete(record)
    }

    private func makeHydrationRepository() -> SwiftDataHydrationEntryRepository {
        SwiftDataHydrationEntryRepository(modelContext: modelContext, simulateSaveFailure: ProcessInfo.processInfo.arguments.contains("--simulate-drink-save-failure"))
    }

    private func openTimelineEntry(_ entry: TodayTimelineEntry) {
        switch entry.kind {
        case let .food(id, _, _): foodEditor = FoodEditorPresentation(record: foodEntries.first { $0.id == id })
        case let .drink(id, _, _, _): hydrationEditor = HydrationEditorPresentation(record: hydrationEntries.first { $0.id == id })
        }
    }

    private func timelineName(_ entry: TodayTimelineEntry) -> String {
        switch entry.kind { case let .food(_, name, _), let .drink(_, name, _, _): name }
    }

    private func timelineSymbol(_ entry: TodayTimelineEntry) -> String {
        if case .food = entry.kind {
            return "fork.knife"
        }; return "drop.fill"
    }

    private func timelineDetail(_ entry: TodayTimelineEntry) -> String {
        switch entry.kind {
        case let .food(_, _, caloric): caloric ? "Caloric" : "Non-caloric"
        case let .drink(_, _, volume, caloric): "\(volume) ml · \(caloric ? "Caloric" : "Non-caloric")"
        }
    }

    private func timelineAccessibilityLabel(_ entry: TodayTimelineEntry) -> String {
        "\(timelineSymbol(entry) == "fork.knife" ? "Food" : "Drink"), \(timelineName(entry))"
    }
}

private struct HydrationEditorPresentation: Identifiable {
    let id = UUID()
    let record: HydrationEntryRecord?
}

private struct InactiveFastView: View {
    let goal: FastingGoal
    let target: String
    let fastRecorded: Bool
    let startError: String?
    let onStart: () -> Void
    let onStartPast: () -> Void
    let additionalContent: AnyView

    var body: some View {
        ScrollView {
            VStack(spacing: UFastTheme.Spacing.generous) {
                HStack(spacing: UFastTheme.Spacing.standard) {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Text("Ready when you are")
                            .font(.uFastDisplay(.title))
                            .foregroundStyle(UFastTheme.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("No fast is running.")
                            .foregroundStyle(UFastTheme.secondaryText)
                            .accessibilityIdentifier("fast.inactive-state")
                    }
                    Spacer(minLength: 0)
                    FastingBotanicalThumbnail()
                        .frame(width: 104)
                }

                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    UFastSectionHeading("Your next target", eyebrow: "\(goal.hours)-hour goal")
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("If started now")
                                .font(.caption)
                                .foregroundStyle(UFastTheme.secondaryText)
                            Text(target)
                                .font(.uFastDisplay(.title2))
                                .foregroundStyle(UFastTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Target if started now")
                                .accessibilityValue(target)
                                .accessibilityIdentifier("fast.preview-target")
                        }
                        Spacer()
                        Image(systemName: "sun.horizon.fill")
                            .font(.title)
                            .foregroundStyle(UFastTheme.apricot)
                            .accessibilityHidden(true)
                    }
                    Text("Your fasting goal is \(goal.hours) hours.")
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .uFastCard(accent: UFastTheme.sky)

                if fastRecorded {
                    Label("Fast recorded.", systemImage: "checkmark.circle")
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .uFastCard(accent: UFastTheme.sage)
                        .accessibilityIdentifier("fast.recorded")
                }

                if let startError {
                    Label(startError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.start-error")
                }

                VStack(spacing: UFastTheme.Spacing.standard) {
                    Button(startError == nil ? "Start fast" : "Try again", action: onStart)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .accessibilityIdentifier("fast.start")

                    Button("Start at a past time", action: onStartPast)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("fast.start-past")
                }

                additionalContent
            }
            .padding(UFastTheme.Spacing.standard)
        }
    }
}

private struct StartTimeEditorPresentation: Identifiable {
    let id = UUID()
    let mode: StartTimeEditor.Mode
    let initialStartDate: Date
}

private struct EndTimeEditorPresentation: Identifiable {
    let id = UUID()
    let startDate: Date
    let initialEndDate: Date
}

private struct FoodEditorPresentation: Identifiable {
    let id = UUID()
    let record: FoodEntryRecord?
}

#Preview("Today · Empty") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("Today · Mixed timeline") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
}

#Preview("Today · Active fast and timeline") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.activeFastTodayTimelineModelContainer)
}

#Preview("Today · Long content") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.longTodayTimelineModelContainer)
}

#Preview("Today · Persistence error") {
    TodayGoalView(
        clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow),
        previewTimelineError: "Your timeline couldn’t be loaded. Please try again."
    )
    .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("Today · Dark") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Today · Accessibility size") {
    TodayGoalView(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
