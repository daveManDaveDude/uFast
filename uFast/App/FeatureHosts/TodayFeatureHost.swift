import SwiftUI
import UFastCore

struct TodayFeatureHost: View {
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.timeZone) private var environmentTimeZone

    @State private var dataProvider: SwiftDataTodayDataProvider?

    let clock: any AppClock

    var body: some View {
        TodayGoalView(
            snapshot: dataProvider?.snapshot ?? TodayFeatureSnapshot(
                settings: [],
                activeFasts: [],
                foodEntries: [],
                hydrationEntries: []
            ),
            clock: clock,
            previewTimelineError: dataProvider?.errorMessage
        )
        .environment(\.calendar, effectiveCalendar)
        .environment(\.timeZone, effectiveCalendar.timeZone)
        .onAppear { refreshProvider() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshProvider()
        }
        .onChange(of: environmentTimeZone.identifier) { _, _ in
            refreshProvider()
        }
        .onChange(of: calendarIdentity) { _, _ in
            refreshProvider()
        }
        .task { refreshProvider() }
        .task(id: dataProvider?.dayInterval.end) {
            await refreshAtNextCalendarDay()
        }
    }

    static func effectiveCalendar(
        environmentCalendar: Calendar,
        environmentTimeZone: TimeZone
    ) -> Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = environmentTimeZone
        return calendar
    }

    private var effectiveCalendar: Calendar {
        Self.effectiveCalendar(
            environmentCalendar: environmentCalendar,
            environmentTimeZone: environmentTimeZone
        )
    }

    private var calendarIdentity: String {
        "\(String(describing: effectiveCalendar.identifier))|"
            + "\(effectiveCalendar.timeZone.identifier)|"
            + "\(effectiveCalendar.locale?.identifier ?? "")"
    }

    private func refreshProvider() {
        if let dataProvider {
            dataProvider.refresh(now: clock.now, calendar: effectiveCalendar)
        } else {
            dataProvider = SwiftDataTodayDataProvider(
                modelContext: modelContext,
                clock: clock,
                calendar: effectiveCalendar
            )
        }
    }

    private func refreshAtNextCalendarDay() async {
        guard let dataProvider else { return }
        let schedule = TodayRolloverSchedule(interval: dataProvider.dayInterval)
        let nanoseconds = max(schedule.nanosecondsUntil(now: clock.now), 100_000_000)
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }
        guard schedule.shouldRefresh(now: clock.now, taskIsCancelled: Task.isCancelled) else { return }
        dataProvider.refresh(now: clock.now, calendar: effectiveCalendar)
    }
}
