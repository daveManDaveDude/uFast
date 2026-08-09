import Foundation
import OSLog
import WidgetKit

struct WidgetTimelineReloader: ActiveFastProjectionReloading {
    func reloadTimelines() {
        // Request both the precise kind and the bundle-wide reload. The kind
        // reload targets an already-installed Lock Screen configuration, while
        // the bundle reload covers configurations restored across extension
        // updates.
        WidgetCenter.shared.reloadTimelines(ofKind: ActiveFastProjectionFileStore.widgetKind)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum WidgetProjectionSupport {
    private static let logger = Logger(
        subsystem: "com.davidmcgrath.uFast",
        category: "WidgetProjection"
    )

    static func coordinator() -> ActiveFastProjectionCoordinator? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
        ) else {
            logger.error(
                "App Group container unavailable: \(ActiveFastProjectionFileStore.appGroupIdentifier, privacy: .public)"
            )
            return nil
        }
        logger.notice("Using widget projection container")
        return ActiveFastProjectionCoordinator(
            store: ActiveFastProjectionFileStore(containerURL: containerURL),
            reloader: WidgetTimelineReloader()
        )
    }

    static func publish(_ fast: FastRecord, goal: FastingGoal, now: Date = .now) {
        logger.notice("Publishing active fast projection")
        coordinator()?.publish(
            activeRecordIdentifier: fast.id,
            startDate: fast.startDate,
            goalHours: goal.hours,
            generatedAt: now
        )
    }

    static func clear() {
        logger.debug("Clearing active fast projection")
        coordinator()?.clear()
    }
}
