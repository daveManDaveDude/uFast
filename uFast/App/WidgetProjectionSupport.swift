import Foundation
import OSLog
import SwiftData
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

    @MainActor
    static func synchronize(in container: ModelContainer, now: Date) {
        let context = container.mainContext
        let activeFast: FastRecord?
        do {
            activeFast = try ActiveFastAuthority.fetch(in: context)
        } catch {
            logger.error("Active fast authority is ambiguous; widget projection unchanged")
            return
        }
        guard let activeFast else {
            clear()
            return
        }
        let goal: FastingGoal
        do {
            goal = try SwiftDataSettingsStore(modelContext: context)
                .authoritativeRecord()?.fastingGoal ?? .default
        } catch {
            logger.error("Settings authority is ambiguous; widget projection unchanged")
            return
        }
        publish(activeFast, goal: goal, now: now)
    }

    static func clear() {
        logger.debug("Clearing active fast projection")
        coordinator()?.clear()
    }
}
