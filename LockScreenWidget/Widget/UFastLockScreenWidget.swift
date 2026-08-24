import SwiftUI
import WidgetKit

struct UFastLockScreenEntry: TimelineEntry {
    let date: Date
    let projectionResult: Result<ActiveFastWidgetProjection?, Error>
}

struct UFastLockScreenProvider: TimelineProvider {
    private let containerURL: URL?
    private let diagnosticSink: any DiagnosticEventSink

    init(
        containerURL: URL? = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
        ),
        diagnosticSink: any DiagnosticEventSink = WidgetDiagnosticEventLogSink()
    ) {
        self.containerURL = containerURL
        self.diagnosticSink = diagnosticSink
    }

    func placeholder(in _: Context) -> UFastLockScreenEntry {
        UFastLockScreenEntry(date: .now, projectionResult: .success(nil))
    }

    func getSnapshot(in _: Context, completion: @escaping (UFastLockScreenEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<UFastLockScreenEntry>) -> Void) {
        let entry = makeEntry()
        let schedule = LockScreenWidgetTimelineSchedule.make(
            projectionResult: entry.projectionResult,
            now: entry.date
        )
        let entries = schedule.dates.map { date in
            UFastLockScreenEntry(date: date, projectionResult: entry.projectionResult)
        }
        completion(
            Timeline(
                entries: entries,
                policy: .after(schedule.reloadDate)
            )
        )
    }

    private func makeEntry() -> UFastLockScreenEntry {
        let result: Result<ActiveFastWidgetProjection?, Error>
        do {
            guard let containerURL else {
                record(.containerUnavailable)
                throw ActiveFastWidgetProjectionError.unreadable
            }
            result = try .success(ActiveFastProjectionFileStore(containerURL: containerURL).read())
            if case let .success(projection?) = result {
                do {
                    try projection.validate(now: .now)
                } catch { /* The closed vocabulary has no validation outcome. */ }
            }
        } catch {
            result = .failure(error)
        }
        return UFastLockScreenEntry(date: .now, projectionResult: result)
    }

    // The provider context is supplied by WidgetKit and cannot be constructed
    // in a unit test; this keeps the projection read boundary deterministic.
    // swiftlint:disable:next unused_declaration
    func makeEntryForTesting() -> UFastLockScreenEntry {
        makeEntry()
    }

    /// The provider read path has no exact closed-vocabulary outcome for a
    /// corrupt or invalid projection; those failures remain fail-closed and
    /// silent. Container absence is the one exact permitted failure here.
    private func record(_ outcome: DiagnosticOutcome) {
        guard let event = DiagnosticEvent(
            subsystem: .widgetProjection,
            outcome: outcome,
            severity: .error
        ) else {
            return
        }
        diagnosticSink.record(event)
    }
}

struct UFastLockScreenWidgetView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let entry: UFastLockScreenEntry

    private let copy: SystemSurfaceTextResolver

    init(
        entry: UFastLockScreenEntry,
        textResolver: SystemSurfaceTextResolver = .init()
    ) {
        self.entry = entry
        copy = textResolver
    }

    private var content: LockScreenWidgetContent {
        .make(
            projectionResult: entry.projectionResult,
            now: entry.date,
            textResolver: copy
        )
    }

    var body: some View {
        Group {
            switch content {
            case let .active(active): activeView(active)
            case .unavailable: unavailableView
            }
        }
        .widgetURL(ActiveFastActivityRoute.currentFastURL)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func activeView(_ active: LockScreenWidgetActiveContent) -> some View {
        let rendered = SystemSurfacePresentationContent.accessoryWidget(
            active: active,
            resolver: copy
        )
        // Accessory rectangular is only about 67 points tall on the Lock
        // Screen. Keep the label and protected elapsed value on one row so the
        // progress track remains inside the family bounds at the largest
        // practical system text size.
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verbatim: rendered.visibleText[0])
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(verbatim: rendered.visibleText[1])
                    .font(.caption2.monospacedDigit())
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: rendered.visibleText[2])
                    .font(.caption2)
                Text(active.elapsedText)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                    .accessibilityHidden(true)
            }
            // WidgetKit resolves this date interval while the extension is
            // suspended, so the bar does not freeze at the entry's fraction.
            ProgressView(
                timerInterval: active.startDate ... active.targetDate,
                countsDown: false,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.linear)
            .labelsHidden()
            .tint(.primary)
            .scaleEffect(y: 1.5)
            .frame(height: contrast == .increased ? 9 : 7)
            .clipShape(Capsule())
            .accessibilityHidden(true)
        }
        // Expose one stable summary so seconds cannot reappear in accessibility.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: active.accessibilitySummary)
        )
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: copy(.brand)).font(.caption.weight(.semibold))
            Text(verbatim: copy(.noActiveFast)).font(.headline)
            Text(verbatim: copy(.open)).font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: copy(.unavailableSummary)))
    }
}

struct UFastLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ActiveFastProjectionFileStore.widgetKind, provider: UFastLockScreenProvider()) {
            UFastLockScreenWidgetView(entry: $0)
        }
        .configurationDisplayName(SystemSurfaceText.widgetActiveFast.resource)
        .description(SystemSurfaceText.widgetActiveFastDescription.resource)
        .supportedFamilies([.accessoryRectangular])
    }
}

@main
struct UFastLockScreenWidgetBundle: WidgetBundle {
    var body: some Widget {
        UFastLockScreenWidget()
        UFastActiveFastActivityWidget()
        UFastHomeScreenWidget()
    }
}
