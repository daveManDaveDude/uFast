import Foundation
@testable import UFastLockScreenWidget
import XCTest

final class WidgetProviderDiagnosticTests: XCTestCase {
    func testUnavailableContainerReportsTypedFailureWithoutPayload() {
        let diagnostics = WidgetRecordingDiagnosticEventSink()
        let provider = UFastLockScreenProvider(
            containerURL: nil,
            diagnosticSink: diagnostics
        )

        let entry = provider.makeEntryForTesting()

        guard case .failure = entry.projectionResult else {
            return XCTFail("Expected the widget provider to fail closed")
        }
        XCTAssertEqual(
            diagnostics.events.map(\.outcome),
            [.containerUnavailable]
        )
        XCTAssertEqual(diagnostics.events.count, 1)
    }
}

private final class WidgetRecordingDiagnosticEventSink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [DiagnosticEvent] = []

    var events: [DiagnosticEvent] {
        lock.withWidgetTestLock { storage }
    }

    func record(_ event: DiagnosticEvent) {
        lock.withWidgetTestLock {
            storage.append(event)
        }
    }
}

private extension NSLock {
    func withWidgetTestLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
