import SwiftUI

/// State changes only on Start/Finish; no geometry-driven accessibility work.
struct HistoryScrollDiagnosticControls: View {
    @State private var result = "ready"

    var body: some View {
        if HistoryScrollDiagnosticProbe.isEnabled {
            HStack {
                Button("Start capture") {
                    result = "capturing"
                    HistoryScrollDiagnosticProbe.startCapture()
                }
                .accessibilityIdentifier("history.scroll-performance-start")
                Button("Finish capture") {
                    HistoryScrollDiagnosticProbe.finishCapture()
                    result = HistoryScrollDiagnosticProbe.rawSnapshot()
                }
                .accessibilityIdentifier("history.scroll-performance-finish")
                Color.clear.frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("History scroll performance snapshot")
                    .accessibilityValue(result)
                    .accessibilityIdentifier("history.scroll-performance-snapshot")
                    .allowsHitTesting(false)
            }
            .font(.caption2)
            .buttonStyle(.bordered)
        }
    }
}
