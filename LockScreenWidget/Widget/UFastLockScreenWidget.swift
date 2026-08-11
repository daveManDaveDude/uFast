import OSLog
import SwiftUI
import WidgetKit

struct UFastLockScreenEntry: TimelineEntry {
    let date: Date
    let projectionResult: Result<ActiveFastWidgetProjection?, Error>
}

struct UFastLockScreenProvider: TimelineProvider {
    private let logger = Logger(
        subsystem: "com.davidmcgrath.uFast",
        category: "LockScreenWidget"
    )

    func placeholder(in _: Context) -> UFastLockScreenEntry {
        UFastLockScreenEntry(date: .now, projectionResult: .success(nil))
    }

    func getSnapshot(in _: Context, completion: @escaping (UFastLockScreenEntry) -> Void) {
        logger.notice("Widget snapshot requested")
        completion(makeEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<UFastLockScreenEntry>) -> Void) {
        logger.notice("Widget timeline requested")
        let entry = makeEntry()
        // A target-date refresh lets the clamped progress percentage converge
        // without persisting ticks or requesting per-second entries.
        let nextRefresh: Date? = if case let .success(projection?) = entry.projectionResult {
            projection.targetDate > entry.date ? projection.targetDate : nil
        } else {
            nil
        }
        // A no-active/error entry must not become permanent if an app-triggered
        // reload is coalesced while the widget is installed on the Lock Screen.
        // Five minutes is the platform's practical lower bound for timeline
        // refreshes and remains far from per-second polling.
        let policy: TimelineReloadPolicy = nextRefresh.map { .after($0) }
            ?? .after(entry.date.addingTimeInterval(5 * 60))
        completion(Timeline(entries: [entry], policy: policy))
    }

    private func makeEntry() -> UFastLockScreenEntry {
        let result: Result<ActiveFastWidgetProjection?, Error>
        do {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
            ) else {
                logger.error("Widget App Group container unavailable")
                throw ActiveFastWidgetProjectionError.unreadable
            }
            result = try .success(ActiveFastProjectionFileStore(containerURL: containerURL).read())
            logger.notice("Widget projection read: \(resultSummary(result), privacy: .public)")
            if case let .success(projection?) = result {
                do {
                    try projection.validate(now: .now)
                    logger.notice("Widget projection validation passed")
                } catch {
                    logger.error("Widget projection validation failed: \(String(describing: error), privacy: .public)")
                }
            }
        } catch {
            logger.error("Widget projection read failed: \(String(describing: error), privacy: .public)")
            result = .failure(error)
        }
        return UFastLockScreenEntry(date: .now, projectionResult: result)
    }

    private func resultSummary(_ result: Result<ActiveFastWidgetProjection?, Error>) -> String {
        switch result {
        case let .success(projection?):
            "active \(projection.activeRecordIdentifier.uuidString)"
        case .success:
            "none"
        case .failure:
            "failure"
        }
    }
}

struct UFastLockScreenWidgetView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let entry: UFastLockScreenEntry

    private var content: LockScreenWidgetContent {
        .make(
            projectionResult: entry.projectionResult,
            now: entry.date
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
        // Accessory rectangular is only about 67 points tall on the Lock
        // Screen. Keep the label and protected elapsed value on one row so the
        // progress track remains inside the family bounds at the largest
        // practical system text size.
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("uFast")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(verbatim: "\(active.progressPercentage)%")
                    .font(.caption2.monospacedDigit())
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Elapsed")
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
            Text("uFast").font(.caption.weight(.semibold))
            Text("No active fast").font(.headline)
            Text("Open uFast").font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("uFast. No active fast. Opens uFast.")
    }
}

struct UFastLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ActiveFastProjectionFileStore.widgetKind, provider: UFastLockScreenProvider()) {
            UFastLockScreenWidgetView(entry: $0)
        }
        .configurationDisplayName("Active fast")
        .description("Shows elapsed time for your active uFast record.")
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
