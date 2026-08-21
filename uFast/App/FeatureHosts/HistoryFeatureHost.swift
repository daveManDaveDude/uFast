import SwiftData
import SwiftUI

/// Composition boundary for History persistence and its main-actor owner.
/// The feature view receives value state and never reaches into SwiftData.
struct HistoryFeatureHost: View {
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var environmentTimeZone
    @State private var presentationModel: HistoryPresentationModel?

    let clock: any AppClock
    let isTabSelected: Bool
    let onSelectToday: () -> Void

    var body: some View {
        Group {
            if let presentationModel {
                HistoryView(
                    model: presentationModel,
                    clock: clock,
                    isTabSelected: isTabSelected,
                    onSelectToday: onSelectToday
                )
            } else {
                ProgressView("Loading History")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("history.loading")
            }
        }
        .task {
            guard presentationModel == nil else { return }
            presentationModel = HistoryPresentationModel(
                modelContext: modelContext,
                clock: clock,
                calendar: effectiveCalendar,
                locale: locale,
                timeZone: effectiveCalendar.timeZone
            )
        }
    }

    private var effectiveCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = environmentTimeZone
        return calendar
    }
}
