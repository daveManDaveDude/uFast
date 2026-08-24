import SwiftData
import SwiftUI

/// Composition boundary for History persistence and its main-actor owner.
/// The feature view receives value state and never reaches into SwiftData.
struct HistoryFeatureHost: View {
    @Environment(\.appTextResolver) private var textResolver
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeZone) private var environmentTimeZone
    @State private var presentationModel: HistoryPresentationModel?

    let clock: any AppClock
    let isTabSelected: Bool
    let onSelectToday: () -> Void
    let diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()

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
                ProgressView(textResolver(.historyCopy(.loading)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("history.loading")
            }
        }
        .task {
            guard presentationModel == nil else { return }
            let launchConfiguration = AppLaunchConfiguration.current()
            let retryFixtureLoader = HistoryMotionRetryFixtureLoader(
                container: modelContext.container,
                enabled: launchConfiguration.historyMotionRetryFixture
            )
            presentationModel = HistoryPresentationModel(
                modelContext: modelContext,
                clock: clock,
                calendar: effectiveCalendar,
                locale: locale,
                timeZone: effectiveCalendar.timeZone,
                textResolver: textResolver,
                motionConfiguration: launchConfiguration.historyMotionRetryFixture
                    ? HistoryMotionConfiguration(initialRadius: 1, extensionLength: 1, prefetchThreshold: 0)
                    : .product,
                diagnosticSink: diagnosticSink,
                loadChunk: { coverage, calendar, referenceNow, textResolver in
                    try await retryFixtureLoader.load(
                        coverage: coverage,
                        calendar: calendar,
                        referenceNow: referenceNow,
                        textResolver: textResolver
                    )
                }
            )
        }
    }

    private var effectiveCalendar: Calendar {
        var calendar = environmentCalendar
        calendar.timeZone = environmentTimeZone
        return calendar
    }
}

private actor HistoryMotionRetryFixtureLoader {
    private let loader: SwiftDataHistoryMotionRangeLoader
    private var initialFailureIssued: Bool
    private var extensionFailureIssued: Bool

    init(container: ModelContainer, enabled: Bool) {
        loader = SwiftDataHistoryMotionRangeLoader(container: container)
        initialFailureIssued = !enabled
        extensionFailureIssued = !enabled
    }

    func load(
        coverage: HistoryMotionCoverage,
        calendar: Calendar,
        referenceNow: Date,
        textResolver: AppTextResolver
    ) async throws -> HistoryMotionChunk {
        let dayCount = coverage.days(calendar: calendar).count
        if dayCount > 1, !initialFailureIssued {
            initialFailureIssued = true
            throw HistoryMotionChunkError.invalidCoverage
        }
        if dayCount == 1, !extensionFailureIssued {
            extensionFailureIssued = true
            throw HistoryMotionChunkError.invalidCoverage
        }
        return try await loader.load(
            coverage: coverage,
            calendar: calendar,
            referenceNow: referenceNow,
            textResolver: textResolver
        )
    }
}
