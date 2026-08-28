import os
import SwiftUI
import UIKit

/// Counts every label-related preparation stage used by UI diagnostics. It is
/// deliberately inert for production launches and is never read from a
/// scroll-geometry callback.
@MainActor
enum HistoryLabelWorkProbe {
    private static let log = OSLog(
        subsystem: "com.davidmcgrath.uFast",
        category: "HistoryLabelLayer"
    )
    private(set) static var inputResolutionCount = 0
    private(set) static var titleResolutionCount = 0
    private(set) static var projectionCount = 0
    private(set) static var metricsResolutionCount = 0
    private(set) static var descriptorCount = 0
    private(set) static var metricsCount = 0
    private(set) static var scrollGeometryCallbackCount = 0
    private(set) static var labelWorkDuringCallbackCount = 0
    private(set) static var maxScrollGeometryCallbackDepth = 0
    private(set) static var appearedSegmentIDs: Set<String> = []
    private(set) static var contentWidth = Double.nan
    private(set) static var dayStride = Double.nan
    private(set) static var initialOffset = Double.nan
    private(set) static var selectedDayCenter = Double.nan
    private(set) static var traceRows: [String] = []
    private static var traceSequence = 0
    private static var scrollGeometryCallbackDepth = 0

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    static func recordProjection() {
        guard isEnabled else { return }
        recordLabelWorkDuringScrollGeometryCallback()
        projectionCount += 1
    }

    static func recordInputResolution() {
        guard isEnabled else { return }
        recordLabelWorkDuringScrollGeometryCallback()
        inputResolutionCount += 1
    }

    static func recordTitleResolution() {
        guard isEnabled else { return }
        recordLabelWorkDuringScrollGeometryCallback()
        titleResolutionCount += 1
    }

    static func recordMetricsResolution() {
        guard isEnabled else { return }
        recordLabelWorkDuringScrollGeometryCallback()
        metricsResolutionCount += 1
    }

    static func recordOutput(descriptorCount: Int, metricsCount: Int) {
        guard isEnabled else { return }
        Self.descriptorCount = descriptorCount
        Self.metricsCount = metricsCount
    }

    static func recordAppearedSegment(_ date: Date) {
        guard isEnabled else { return }
        appearedSegmentIDs.insert(String(date.timeIntervalSince1970))
    }

    static func recordScrollGeometry(
        _ geometry: TemporalContinuousTimelineGeometry
    ) {
        guard isEnabled,
              geometry.contentWidth.isFinite,
              geometry.contentWidth > 0,
              geometry.contentOffset.isFinite,
              geometry.containerWidth.isFinite,
              geometry.containerWidth > 0
        else { return }
        if initialOffset.isNaN {
            initialOffset = geometry.contentOffset
        }
        selectedDayCenter = geometry.contentOffset + geometry.containerWidth / 2
    }

    static func recordMeasuredContentLayout(contentWidth: Double, dayStride: Double) {
        guard isEnabled,
              contentWidth.isFinite, contentWidth > 0,
              dayStride.isFinite, dayStride > 0
        else { return }
        Self.contentWidth = contentWidth
        Self.dayStride = dayStride
    }

    static var isBaselineRun: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains(
            "--ui-testing-history-label-layout-baseline"
        )
    }

    static var layoutSnapshot: String {
        "contentWidth=\(contentWidth); dayStride=\(dayStride); "
            + "initialOffset=\(initialOffset); selectedDayCenter=\(selectedDayCenter); "
            + "appearedSegments=\(appearedSegmentIDs.count); descriptors=\(descriptorCount); "
            + "metrics=\(metricsCount); scrollCallbacks=\(scrollGeometryCallbackCount); "
            + "labelWorkDuringScrollCallbacks=\(labelWorkDuringCallbackCount); "
            + "maxScrollCallbackDepth=\(maxScrollGeometryCallbackDepth)"
    }

    static var traceSnapshot: String {
        traceRows.joined(separator: "\n")
    }

    private static func recordTrace(_ event: String) {
        guard isEnabled else { return }
        traceSequence += 1
        let timestamp = String(format: "%.6f", ProcessInfo.processInfo.systemUptime)
        traceRows.append(
            "seq=\(traceSequence);event=\(event);timestamp=\(timestamp);"
                + "depth=\(scrollGeometryCallbackDepth)"
        )
    }

    static func withInputResolution<T>(_ work: () -> T) -> T {
        guard isEnabled else { return work() }
        recordInputResolution()
        recordTrace("input.begin")
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Label input resolution", signpostID: signpostID)
        defer {
            os_signpost(.end, log: log, name: "Label input resolution", signpostID: signpostID)
            recordTrace("input.end")
        }
        return work()
    }

    static func withTitleResolution<T>(_ work: () -> T) -> T {
        guard isEnabled else { return work() }
        recordTitleResolution()
        recordTrace("title.begin")
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Label title resolution", signpostID: signpostID)
        defer {
            os_signpost(.end, log: log, name: "Label title resolution", signpostID: signpostID)
            recordTrace("title.end")
        }
        return work()
    }

    static func withMetricsResolution<T>(_ work: () -> T) -> T {
        guard isEnabled else { return work() }
        recordLabelWorkDuringScrollGeometryCallback()
        recordTrace("metrics.begin")
        let signpostID = OSSignpostID(log: log)
        os_signpost(
            .begin,
            log: log,
            name: "Label metrics resolution",
            signpostID: signpostID
        )
        defer {
            os_signpost(
                .end,
                log: log,
                name: "Label metrics resolution",
                signpostID: signpostID
            )
            recordTrace("metrics.end")
        }
        return work()
    }

    static func withProjection<T>(_ work: () -> T) -> T {
        guard isEnabled else { return work() }
        recordLabelWorkDuringScrollGeometryCallback()
        recordTrace("projection.begin")
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Label projection", signpostID: signpostID)
        defer {
            os_signpost(.end, log: log, name: "Label projection", signpostID: signpostID)
            recordTrace("projection.end")
        }
        return work()
    }

    static func withScrollGeometryCallback<T>(_ work: () -> T) -> T {
        guard isEnabled else { return work() }
        scrollGeometryCallbackCount += 1
        scrollGeometryCallbackDepth += 1
        maxScrollGeometryCallbackDepth = max(
            maxScrollGeometryCallbackDepth,
            scrollGeometryCallbackDepth
        )
        recordTrace("scroll.begin")
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Scroll geometry callback", signpostID: signpostID)
        defer {
            os_signpost(.end, log: log, name: "Scroll geometry callback", signpostID: signpostID)
            recordTrace("scroll.end")
            scrollGeometryCallbackDepth -= 1
        }
        return work()
    }

    private static func recordLabelWorkDuringScrollGeometryCallback() {
        if scrollGeometryCallbackDepth > 0 {
            labelWorkDuringCallbackCount += 1
        }
    }
}

struct TemporalRibbonLabelLayer: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let intervals: [TemporalRibbonIntervalItem]
    let days: [Date]
    let layout: TemporalRibbonLabelLayout
    let calendar: Calendar
    let layoutDirection: TemporalHorizontalLayoutDirection
    let textResolver: AppTextResolver
    let appearedSegmentCount: Int

    @State private var descriptors: [TemporalRibbonLabelDescriptor] = []
    @State private var generation: TemporalRibbonLabelProjectionGeneration?

    @Environment(\.locale) private var locale

    private func resolveLabelInputs() -> [TemporalRibbonLabelInput] {
        HistoryLabelWorkProbe.withInputResolution {
            intervals.map { item in
                let title = HistoryLabelWorkProbe.withTitleResolution {
                    visualTitle(for: item.kind) ?? ""
                }
                return TemporalRibbonLabelInput(
                    id: item.id,
                    start: item.start,
                    end: item.end,
                    kind: item.kind,
                    title: title,
                    glyphName: intervalSymbol(for: item.kind)
                )
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(descriptors) { descriptor in
                visualLabel(descriptor)
            }
            if HistoryLabelWorkProbe.isEnabled {
                TemporalRibbonLabelDiagnosticsProbe(
                    descriptors: descriptors,
                    layout: layout,
                    appearedSegmentCount: appearedSegmentCount
                )
            }
        }
        .frame(
            width: max(layout.contentWidth, 0),
            height: max(layout.layerHeight, 0),
            alignment: .topLeading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(!HistoryLabelWorkProbe.isEnabled)
        .onAppear {
            updateProjectionIfNeeded()
        }
        .onChange(of: intervals) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: days) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: layout.contentWidth) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: calendar) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: layoutDirection) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: dynamicTypeSize) { _, _ in
            updateProjectionIfNeeded()
        }
        .onChange(of: locale) { _, _ in
            updateProjectionIfNeeded()
        }
    }

    private func updateProjectionIfNeeded() {
        let inputs = resolveLabelInputs()
        let nextGeneration = TemporalRibbonLabelProjectionGeneration(
            intervals: inputs,
            days: days,
            contentWidth: layout.contentWidth,
            calendar: calendar,
            layoutDirection: layoutDirection,
            localeIdentifier: locale.identifier,
            dynamicTypeCategory: String(describing: dynamicTypeSize),
            font: "caption.semibold"
        )
        guard generation != nextGeneration else { return }
        generation = nextGeneration
        let metricsByKey = HistoryLabelWorkProbe.withMetricsResolution {
            Dictionary(uniqueKeysWithValues: Set(inputs.map(\.title)).map { title in
                let key = TemporalRibbonLabelMetricKey(
                    title: title,
                    localeIdentifier: nextGeneration.localeIdentifier,
                    layoutDirection: nextGeneration.layoutDirection,
                    dynamicTypeCategory: nextGeneration.dynamicTypeCategory,
                    font: "caption.semibold"
                )
                return (key, title.isEmpty ? measureGlyphOnly(title: title) : measure(title: title))
            })
        }
        HistoryLabelWorkProbe.recordMetricsResolution()
        let metrics = Dictionary(uniqueKeysWithValues: metricsByKey.map { ($0.key.title, $0.value) })
        descriptors = HistoryLabelWorkProbe.withProjection {
            TemporalRibbonLabelProjector.project(
                inputs,
                days: days,
                contentWidth: layout.contentWidth,
                calendar: calendar,
                layoutDirection: layoutDirection,
                metrics: metrics
            )
        }
        HistoryLabelWorkProbe.recordProjection()
        HistoryLabelWorkProbe.recordOutput(
            descriptorCount: descriptors.count,
            metricsCount: metricsByKey.count
        )
    }

    private func measure(title: String) -> TemporalRibbonLabelMetrics {
        let font = captionSemiboldFont
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return TemporalRibbonLabelMetrics(
            title: title,
            glyphWidth: font.pointSize,
            textWidth: textWidth
        )
    }

    private func measureGlyphOnly(title: String) -> TemporalRibbonLabelMetrics {
        let font = captionSemiboldFont
        return TemporalRibbonLabelMetrics(
            title: title,
            glyphWidth: font.pointSize,
            textWidth: 0
        )
    }

    private var captionSemiboldFont: UIFont {
        let preferred = UIFont.preferredFont(forTextStyle: .caption1)
        return UIFont.systemFont(ofSize: preferred.pointSize, weight: .semibold)
    }

    private func visualLabel(_ descriptor: TemporalRibbonLabelDescriptor) -> some View {
        HStack(spacing: 4) {
            if descriptor.showsGlyph, let glyphName = descriptor.glyphName {
                Image(systemName: glyphName)
                    .frame(width: descriptor.glyphWidth)
            }
            if descriptor.showsText, let title = descriptor.title {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            if descriptor.showsText {
                Text(">")
                    .frame(width: TemporalRibbonLabelMetrics.disclosureWidth)
            }
        }
        .padding(.horizontal, 6)
        .font(.caption.weight(.semibold))
        .foregroundStyle(UFastTheme.primary)
        .frame(width: descriptor.labelWidth, height: labelLaneHeight, alignment: .leading)
        .position(
            x: descriptor.labelCenterX,
            y: labelCenterY(for: descriptor.lane)
        )
        .accessibilityHidden(true)
    }

    private var labelLaneHeight: Double {
        layout.laneHeight
    }

    private func labelCenterY(for lane: Int) -> Double {
        layout.labelTop + Double(lane) * (labelLaneHeight + layout.laneSpacing)
            + labelLaneHeight / 2
    }

    private func visualTitle(for kind: TemporalRibbonIntervalItem.Kind) -> String? {
        switch kind {
        case .recorded, .previouslySaved, .reconstructed, .needsReview:
            textResolver(.historyCopy(.visualFast))
        case .active:
            textResolver(.historyCopy(.visualActiveFast))
        case .automatic, .inferred:
            textResolver(.historyCopy(.visualInferredFast))
        case .unknown:
            nil
        }
    }

    private func intervalSymbol(for kind: TemporalRibbonIntervalItem.Kind) -> String {
        switch kind {
        case .recorded, .active: "moon.stars.fill"
        case .automatic, .inferred: "moon.fill"
        case .previouslySaved: "archivebox"
        case .reconstructed: "wand.and.stars"
        case .needsReview: "exclamationmark.triangle"
        case .unknown: "questionmark.circle"
        }
    }
}

private struct TemporalRibbonLabelProjectionGeneration: Equatable {
    let intervals: [TemporalRibbonLabelInput]
    let days: [Date]
    let contentWidth: Double
    let calendar: Calendar
    let layoutDirection: TemporalHorizontalLayoutDirection
    let localeIdentifier: String
    let dynamicTypeCategory: String
    let font: String
}
