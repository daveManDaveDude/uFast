import Foundation
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
    static func coordinator(
        containerURL: URL? = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
        ),
        diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()
    ) -> ActiveFastProjectionCoordinator? {
        guard let containerURL else {
            record(.containerUnavailable, to: diagnosticSink)
            return nil
        }
        return ActiveFastProjectionCoordinator(
            store: ActiveFastProjectionFileStore(containerURL: containerURL),
            reloader: WidgetTimelineReloader(),
            diagnosticSink: diagnosticSink
        )
    }

    static func publish(
        _ fast: FastRecord,
        goal: FastingGoal,
        now: Date = .now,
        projectionCoordinator: ActiveFastProjectionCoordinator? = nil,
        diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()
    ) {
        (projectionCoordinator ?? coordinator(diagnosticSink: diagnosticSink))?.publish(
            activeRecordIdentifier: fast.id,
            startDate: fast.startDate,
            goalHours: goal.hours,
            generatedAt: now
        )
    }

    @MainActor
    static func synchronize(
        in container: ModelContainer,
        now: Date,
        projectionCoordinator: ActiveFastProjectionCoordinator? = nil,
        diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()
    ) {
        let context = container.mainContext
        let coordinator = projectionCoordinator ?? coordinator(diagnosticSink: diagnosticSink)
        let activeFast: FastRecord?
        do {
            activeFast = try ActiveFastAuthority.fetch(in: context)
        } catch let ActiveFastIntegrityError.multipleActiveFasts(count) {
            record(.authorityConflict, countBucket: DiagnosticCountBucket(count: count), to: diagnosticSink)
            coordinator?.clear()
            return
        } catch {
            record(.authorityConflict, to: diagnosticSink)
            coordinator?.clear()
            return
        }
        guard let activeFast else {
            coordinator?.clear()
            return
        }
        let goal: FastingGoal
        do {
            goal = try SwiftDataSettingsStore(modelContext: context)
                .authoritativeRecord()?.fastingGoal ?? .default
        } catch let SettingsStoreError.conflictingAuthorities(count) {
            record(.authorityConflict, countBucket: DiagnosticCountBucket(count: count), to: diagnosticSink)
            return
        } catch {
            record(.authorityConflict, to: diagnosticSink)
            return
        }
        coordinator?.publish(
            activeRecordIdentifier: activeFast.id,
            startDate: activeFast.startDate,
            goalHours: goal.hours,
            generatedAt: now
        )
    }

    static func clear(
        projectionCoordinator: ActiveFastProjectionCoordinator? = nil,
        diagnosticSink: any DiagnosticEventSink = AppDiagnosticEventLogSink()
    ) {
        (projectionCoordinator ?? coordinator(diagnosticSink: diagnosticSink))?.clear()
    }

    private static func record(
        _ outcome: DiagnosticOutcome,
        countBucket: DiagnosticCountBucket? = nil,
        to sink: any DiagnosticEventSink
    ) {
        guard let event = DiagnosticEvent(
            subsystem: .widgetProjection,
            outcome: outcome,
            severity: .error,
            countBucket: countBucket
        ) else {
            return
        }
        sink.record(event)
    }
}
