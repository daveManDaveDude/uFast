import SwiftUI
import WidgetKit

struct PrototypeEntry: TimelineEntry {
    let date: Date
    let projectionResult: Result<ActiveFastWidgetProjection?, Error>
}

struct PrototypeProvider: TimelineProvider {
    func placeholder(in _: Context) -> PrototypeEntry {
        PrototypeEntry(date: Date(), projectionResult: .success(Self.sampleProjection()))
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (PrototypeEntry) -> Void
    ) {
        completion(PrototypeEntry(date: Date(), projectionResult: loadProjection()))
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<PrototypeEntry>) -> Void
    ) {
        let entry = PrototypeEntry(date: Date(), projectionResult: loadProjection())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadProjection() -> Result<ActiveFastWidgetProjection?, Error> {
        do {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
            ) else {
                return .failure(ActiveFastWidgetProjectionError.unreadable)
            }
            return try .success(ActiveFastProjectionFileStore(containerURL: containerURL).read())
        } catch {
            return .failure(error)
        }
    }

    private static func sampleProjection() -> ActiveFastWidgetProjection {
        let now = Date()
        let elapsed: TimeInterval = 12 * 60 * 60 + 34 * 60 + 56
        let start = now.addingTimeInterval(-elapsed)
        return ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: start,
            targetDate: start.addingTimeInterval(16 * 60 * 60),
            goalHours: 16,
            generatedAt: now
        )
    }
}

struct PrototypeWidgetView: View {
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.colorSchemeContrast) private var contrast

    let entry: PrototypeEntry

    var body: some View {
        Group {
            switch presentation {
            case let .active(active):
                activeView(active)
            case .unavailable:
                unavailableView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var privacyState: LockScreenPrivacyState {
        redactionReasons.contains(.privacy) ? .protected : .authenticated
    }

    private var presentation: LockScreenFastPresentation {
        .make(
            projectionResult: entry.projectionResult,
            now: entry.date,
            privacyState: privacyState
        )
    }

    private var activeProjection: ActiveFastWidgetProjection? {
        guard case let .success(value) = entry.projectionResult else {
            return nil
        }
        return value
    }

    private func activeView(_ active: LockScreenActivePresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("uFast")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(active.progressPercentage)%")
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel("Progress")
                    .accessibilityValue(active.progressAccessibilityValue)
            }

            Text("Elapsed")
                .font(.caption2)

            elapsedView(active)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(.primary)
                        .frame(width: proxy.size.width * active.progress)
                }
            }
            .frame(height: contrast == .increased ? 7 : 5)
            .accessibilityHidden(true)

            if privacyState == .authenticated {
                authenticatedDetails(active)
                    .privacySensitive()
            }
        }
        .unredacted()
    }

    @ViewBuilder
    private func elapsedView(_ active: LockScreenActivePresentation) -> some View {
        if privacyState == .protected {
            Text(active.elapsedText)
                .font(.headline.monospacedDigit())
                .accessibilityLabel("Elapsed")
                .accessibilityValue(active.elapsedAccessibilityValue)
        } else {
            authenticatedElapsedView(active)
        }
    }

    @ViewBuilder
    private func authenticatedElapsedView(_ active: LockScreenActivePresentation) -> some View {
        if let projection = activeProjection {
            Text(
                timerInterval: projection.startDate ... Date.distantFuture,
                countsDown: false,
                showsHours: true
            )
            .font(.headline.monospacedDigit())
            .accessibilityLabel("Elapsed")
            .accessibilityValue(active.elapsedAccessibilityValue)
        }
    }

    @ViewBuilder
    private func authenticatedDetails(_ active: LockScreenActivePresentation) -> some View {
        if active.hasReachedGoal == true {
            Text("Goal time reached")
                .font(.caption2.weight(.semibold))
        } else if let targetText = active.targetText {
            Text("Target \(targetText)")
                .font(.caption2)
        }
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("uFast")
                .font(.caption.weight(.semibold))
            Text("No active fast")
                .font(.headline)
            Text("Open uFast")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .unredacted()
        .accessibilityElement(children: .combine)
    }
}

struct PrototypeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "UFastLockScreenContractPrototype",
            provider: PrototypeProvider()
        ) { entry in
            PrototypeWidgetView(entry: entry)
        }
        .configurationDisplayName("uFast contract prototype")
        .description("Validates Lock Screen privacy and timer behavior.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@main
struct UFastLockScreenPrototypeBundle: WidgetBundle {
    var body: some Widget {
        PrototypeWidget()
    }
}
