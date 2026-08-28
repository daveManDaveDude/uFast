import SwiftUI

/// UI-test-only layout diagnostics used by the prototype comparison. The
/// baseline launch uses this probe without constructing any label inputs,
/// metrics or projection descriptors; candidate launches pass descriptors to
/// expose their identity-derived frames.
struct TemporalRibbonLabelDiagnosticsProbe: View {
    let descriptors: [TemporalRibbonLabelDescriptor]
    let layout: TemporalRibbonLabelLayout
    let appearedSegmentCount: Int

    init(
        descriptors: [TemporalRibbonLabelDescriptor] = [],
        layout: TemporalRibbonLabelLayout,
        appearedSegmentCount: Int
    ) {
        self.descriptors = descriptors
        self.layout = layout
        self.appearedSegmentCount = appearedSegmentCount
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(descriptors) { descriptor in
                Color.white.opacity(0.001)
                    .frame(width: max(descriptor.labelWidth, 1), height: layout.laneHeight)
                    .position(
                        x: descriptor.labelCenterX,
                        y: labelCenterY(for: descriptor.lane)
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(descriptor.title ?? "")
                    .accessibilityValue(
                        "center \(descriptor.labelCenterX), width \(descriptor.labelWidth)"
                    )
                    .accessibilityIdentifier("history.fast-label-probe.\(descriptor.id.uuidString)")
            }
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label projection count")
                .accessibilityValue(String(HistoryLabelWorkProbe.projectionCount))
                .accessibilityIdentifier("history.fast-label-projection-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label metrics resolution count")
                .accessibilityValue(String(HistoryLabelWorkProbe.metricsResolutionCount))
                .accessibilityIdentifier("history.fast-label-metrics-resolution-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label title resolution count")
                .accessibilityValue(String(HistoryLabelWorkProbe.titleResolutionCount))
                .accessibilityIdentifier("history.fast-label-title-resolution-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label input resolution count")
                .accessibilityValue(String(HistoryLabelWorkProbe.inputResolutionCount))
                .accessibilityIdentifier("history.fast-label-input-resolution-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History fast label descriptor count")
                .accessibilityValue(String(HistoryLabelWorkProbe.descriptorCount))
                .accessibilityIdentifier("history.fast-label-descriptor-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History fast label metrics count")
                .accessibilityValue(String(HistoryLabelWorkProbe.metricsCount))
                .accessibilityIdentifier("history.fast-label-metrics-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History fast label layout snapshot")
                .accessibilityValue(HistoryLabelWorkProbe.layoutSnapshot)
                .accessibilityIdentifier("history.fast-label-layout-snapshot")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label work during scroll geometry callbacks")
                .accessibilityValue(
                    String(HistoryLabelWorkProbe.labelWorkDuringCallbackCount)
                )
                .accessibilityIdentifier("history.fast-label-work-during-scroll-callback-count")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History label work trace")
                .accessibilityValue(HistoryLabelWorkProbe.traceSnapshot)
                .accessibilityIdentifier("history.fast-label-trace")
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History appeared lazy segment count")
                .accessibilityValue(
                    String(max(appearedSegmentCount, HistoryLabelWorkProbe.appearedSegmentIDs.count))
                )
                .accessibilityIdentifier("history.fast-label-appeared-segment-count")
        }
        .frame(
            width: max(layout.contentWidth, 0),
            height: max(layout.layerHeight, 0),
            alignment: .topLeading
        )
        .allowsHitTesting(false)
    }

    private func labelCenterY(for lane: Int) -> Double {
        layout.labelTop + Double(lane) * (layout.laneHeight + layout.laneSpacing)
            + layout.laneHeight / 2
    }
}
