import SwiftUI
import WidgetKit

@main
struct UFastLockScreenPrototypeHostApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeControlView()
        }
    }
}

private struct PrototypeControlView: View {
    @State private var status = "Choose a state, then add the uFast prototype widget."

    var body: some View {
        NavigationStack {
            Form {
                Section("Projection") {
                    Button("Write valid active fast") {
                        writeValidProjection()
                    }
                    Button("Write future start") {
                        writeFutureProjection()
                    }
                    Button("Write corrupt projection") {
                        writeCorruptProjection()
                    }
                    Button("Clear projection") {
                        clearProjection()
                    }
                }

                Section("Evidence") {
                    Text(status)
                    Text("File protection: complete until first user authentication")
                    Text(ActiveFastProjectionFileStore.appGroupIdentifier)
                        .font(.footnote.monospaced())
                }
            }
            .navigationTitle("Lock Screen prototype")
        }
    }

    private func writeValidProjection() {
        let now = Date()
        let elapsed: TimeInterval = 12 * 60 * 60 + 34 * 60 + 56
        let start = now.addingTimeInterval(-elapsed)
        write(
            ActiveFastWidgetProjection(
                activeRecordIdentifier: UUID(),
                startDate: start,
                targetDate: start.addingTimeInterval(16 * 60 * 60),
                goalHours: 16,
                generatedAt: now
            ),
            success: "Valid active projection written."
        )
    }

    private func writeFutureProjection() {
        let now = Date()
        let start = now.addingTimeInterval(60 * 60)
        write(
            ActiveFastWidgetProjection(
                activeRecordIdentifier: UUID(),
                startDate: start,
                targetDate: start.addingTimeInterval(16 * 60 * 60),
                goalHours: 16,
                generatedAt: now
            ),
            success: "Future-start projection written."
        )
    }

    private func write(
        _ projection: ActiveFastWidgetProjection,
        success: String
    ) {
        do {
            try projectionStore().write(projection)
            WidgetCenter.shared.reloadTimelines(ofKind: ActiveFastProjectionFileStore.widgetKind)
            status = success
        } catch {
            status = "Write failed: \(error.localizedDescription)"
        }
    }

    private func writeCorruptProjection() {
        do {
            let store = try projectionStore()
            try Data("not-json".utf8).write(to: store.fileURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.protectionKey: ActiveFastProjectionFileStore.protectionType],
                ofItemAtPath: store.fileURL.path
            )
            WidgetCenter.shared.reloadTimelines(ofKind: ActiveFastProjectionFileStore.widgetKind)
            status = "Corrupt projection written."
        } catch {
            status = "Write failed: \(error.localizedDescription)"
        }
    }

    private func clearProjection() {
        do {
            try projectionStore().clear()
            WidgetCenter.shared.reloadTimelines(ofKind: ActiveFastProjectionFileStore.widgetKind)
            status = "Projection cleared."
        } catch {
            status = "Clear failed: \(error.localizedDescription)"
        }
    }

    private func projectionStore() throws -> ActiveFastProjectionFileStore {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ActiveFastProjectionFileStore.appGroupIdentifier
        ) else {
            throw PrototypeError.appGroupUnavailable
        }
        return ActiveFastProjectionFileStore(containerURL: containerURL)
    }
}

private enum PrototypeError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        "The prototype App Group container is unavailable."
    }
}
