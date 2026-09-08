import SwiftUI

/// UI-test-only layout diagnostics used by the prototype comparison. The
/// baseline launch uses this probe without constructing any label inputs,
/// metrics or projection descriptors; candidate launches pass descriptors to
/// expose their identity-derived frames.
struct TemporalRibbonLabelDiagnosticsProbe: View {
    let descriptors: [TemporalRibbonLabelDescriptor]
    let layout: TemporalRibbonLabelLayout
    let appearedSegmentCount: Int
    let textResolver: AppTextResolver
    let durationPulse: HistoryDurationPulse?
    let movementPhase: TemporalCarouselMovementPhase

    init(
        descriptors: [TemporalRibbonLabelDescriptor] = [],
        layout: TemporalRibbonLabelLayout,
        appearedSegmentCount: Int,
        textResolver: AppTextResolver = .init(),
        durationPulse: HistoryDurationPulse? = nil,
        movementPhase: TemporalCarouselMovementPhase = .settled
    ) {
        self.descriptors = descriptors
        self.layout = layout
        self.appearedSegmentCount = appearedSegmentCount
        self.textResolver = textResolver
        self.durationPulse = durationPulse
        self.movementPhase = movementPhase
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

            TemporalLabelDurationDiagnosticsLeaf(
                descriptors: descriptors,
                layout: layout,
                resolver: textResolver,
                pulse: durationPulse,
                movementPhase: movementPhase
            )
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

/// The diagnostics value surface is intentionally a child of the inert probe.
/// It is the only diagnostic view that observes the shared cadence, so a tick
/// cannot invalidate the History parent or carousel just to refresh counters.
private struct TemporalLabelDurationDiagnosticsLeaf: View {
    let descriptors: [TemporalRibbonLabelDescriptor]
    let layout: TemporalRibbonLabelLayout
    let resolver: AppTextResolver
    let pulse: HistoryDurationPulse?
    let movementPhase: TemporalCarouselMovementPhase

    private var observedNow: Date? {
        guard descriptors.contains(where: { $0.duration?.observesClock == true }) else {
            return nil
        }
        return pulse?.now
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(descriptors) { descriptor in
                if showsRenderedDuration(descriptor), let duration = descriptor.duration {
                    Color.white.opacity(0.001)
                        .frame(
                            width: max(descriptor.durationSlotWidth ?? 1, 1),
                            height: layout.laneHeight
                        )
                        .position(
                            x: descriptor.labelCenterX,
                            y: labelCenterY(for: descriptor.lane)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("History duration")
                        .accessibilityValue(
                            HistoryTextFormatting.compactDuration(
                                duration,
                                at: observedNow ?? duration.startDate,
                                resolver: resolver
                            )
                        )
                        .accessibilityIdentifier(
                            "history.fast-duration-probe.\(descriptor.id.uuidString)"
                        )
                }
            }
            diagnosticValue(
                label: "History duration tick count",
                value: String(HistoryLabelWorkProbe.durationTickCount),
                identifier: "history.fast-duration-tick-count"
            )
            diagnosticValue(
                label: "History duration leaf invalidation count",
                value: String(HistoryLabelWorkProbe.durationLeafInvalidationCount),
                identifier: "history.fast-duration-leaf-invalidation-count"
            )
            diagnosticValue(
                label: "History parent body evaluation count",
                value: String(HistoryLabelWorkProbe.historyParentBodyEvaluationCount),
                identifier: "history.fast-parent-invalidation-count"
            )
            diagnosticValue(
                label: "History carousel body evaluation count",
                value: String(HistoryLabelWorkProbe.carouselBodyEvaluationCount),
                identifier: "history.fast-carousel-invalidation-count"
            )
            diagnosticValue(
                label: "History card body evaluation count",
                value: String(HistoryRowWorkProbe.cardBodyEvaluationCount),
                identifier: "history.fast-card-body-evaluation-count"
            )
            diagnosticValue(
                label: "History settled duration leaf invalidation count",
                value: String(HistoryRowWorkProbe.durationLeafInvalidationCount),
                identifier: "history.fast-settled-duration-leaf-invalidation-count"
            )
        }
        .onChange(of: observedNow) { _, _ in
            guard pulse != nil, observedNow != nil else { return }
            HistoryLabelWorkProbe.recordDurationTick(
                movementPhase,
                now: observedNow ?? Date.distantPast
            )
        }
    }

    private func showsRenderedDuration(_ descriptor: TemporalRibbonLabelDescriptor) -> Bool {
        guard descriptor.showsDuration, let duration = descriptor.duration else { return false }
        let maximumDayDigits = descriptor.durationTemplateDayDigits ?? 0
        return duration.value(at: observedNow ?? duration.startDate).dayDigits <= maximumDayDigits
    }

    private func diagnosticValue(label: String, value: String, identifier: String) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier(identifier)
    }

    private func labelCenterY(for lane: Int) -> Double {
        layout.labelTop + Double(lane) * (layout.laneHeight + layout.laneSpacing)
            + layout.laneHeight / 2
    }
}
