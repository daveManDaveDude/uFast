import os
import SwiftUI
import UIKit

// swiftlint:disable file_length

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
    private(set) static var durationTickCount = 0
    private(set) static var durationLeafInvalidationCount = 0
    private(set) static var durationTicksDuringMotionCount = 0
    private(set) static var historyParentBodyEvaluationCount = 0
    private(set) static var carouselBodyEvaluationCount = 0
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
            && !ProcessInfo.processInfo.arguments.contains(
                HistoryScrollDiagnosticConfiguration.diagnosticArgument
            )
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

    static func recordDurationTick(_ phase: TemporalCarouselMovementPhase, now: Date) {
        guard isEnabled else { return }
        durationTickCount += 1
        if phase != .settled {
            durationTicksDuringMotionCount += 1
        }
        recordTrace(
            "duration.tick.phase=\(String(describing: phase));logicalNow=\(now.timeIntervalSince1970)"
        )
    }

    static func recordDurationLeafInvalidation() {
        guard isEnabled else { return }
        durationLeafInvalidationCount += 1
        recordTrace("duration.leaf.invalidate")
    }

    static func recordMovementPhase(_ phase: TemporalCarouselMovementPhase) {
        guard isEnabled else { return }
        if phase == .settled {
            recordTrace("motion.end")
        } else {
            recordTrace("motion.begin.phase=\(String(describing: phase))")
        }
    }

    static func recordHistoryParentBodyEvaluation() {
        guard isEnabled else { return }
        historyParentBodyEvaluationCount += 1
    }

    static func recordCarouselBodyEvaluation() {
        guard isEnabled else { return }
        carouselBodyEvaluationCount += 1
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
            + "durationTicks=\(durationTickCount); durationLeafInvalidations=\(durationLeafInvalidationCount); "
            + "durationTicksDuringMotion=\(durationTicksDuringMotionCount); "
            + "historyParentBodyEvaluations=\(historyParentBodyEvaluationCount); "
            + "carouselBodyEvaluations=\(carouselBodyEvaluationCount); "
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
    let durationPulse: HistoryDurationPulse?
    let movementPhase: TemporalCarouselMovementPhase

    @State private var descriptors: [TemporalRibbonLabelDescriptor] = []
    @State private var generation: TemporalRibbonLabelProjectionGeneration?

    @Environment(\.locale) private var locale

    private func resolveLabelInputs() -> [TemporalRibbonLabelInput] {
        HistoryScrollDiagnosticProbe.withWork(.labelInputs) {
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
                        glyphName: intervalSymbol(for: item.kind),
                        duration: item.duration
                    )
                }
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
                    appearedSegmentCount: appearedSegmentCount,
                    textResolver: textResolver,
                    durationPulse: durationPulse,
                    movementPhase: movementPhase
                )
            }
        }
        .coordinateSpace(name: "history.fast-label-layer")
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
        let metricsByKey = HistoryScrollDiagnosticProbe.withWork(.labelMetrics) {
            HistoryLabelWorkProbe.withMetricsResolution {
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
        }
        HistoryLabelWorkProbe.recordMetricsResolution()
        let metrics = Dictionary(uniqueKeysWithValues: metricsByKey.map { ($0.key.title, $0.value) })
        descriptors = HistoryScrollDiagnosticProbe.withWork(.labelProjection) {
            HistoryLabelWorkProbe.withProjection {
                TemporalRibbonLabelProjector.project(
                    inputs,
                    days: days,
                    contentWidth: layout.contentWidth,
                    calendar: calendar,
                    layoutDirection: layoutDirection,
                    metrics: metrics
                )
            }
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
        let durationTemplateWidths = durationTemplateWidths(for: title, font: font)
        return TemporalRibbonLabelMetrics(
            title: title,
            glyphWidth: font.pointSize,
            textWidth: textWidth,
            durationTemplateWidths: durationTemplateWidths
        )
    }

    private func measureGlyphOnly(title: String) -> TemporalRibbonLabelMetrics {
        let font = captionSemiboldFont
        return TemporalRibbonLabelMetrics(
            title: title,
            glyphWidth: font.pointSize,
            textWidth: 0,
            durationTemplateWidths: durationTemplateWidths(for: title, font: font)
        )
    }

    private func durationTemplateWidths(for title: String, font: UIFont) -> [Int: Double] {
        let daySpace = TemporalContinuousDaySpaceResolver(
            days: days,
            contentWidth: layout.contentWidth,
            calendar: calendar,
            layoutDirection: layoutDirection
        )
        let maximumProjectedBarWidth = intervals
            .filter { visualTitle(for: $0.kind) == title && $0.duration != nil }
            .compactMap { daySpace.interval(start: $0.start, end: $0.end)?.width }
            .max() ?? 0
        let titleWidth = Double((title as NSString).size(withAttributes: [.font: font]).width)
        let glyphWidth = Double(font.pointSize)
        let labelMetrics = TemporalRibbonLabelMetrics(
            title: title,
            glyphWidth: glyphWidth,
            textWidth: titleWidth
        )
        var widths: [Int: Double] = [:]

        for dayDigits in 0 ... HistoryDurationValue.maximumDayDigits {
            let currentTemplate = HistoryTextFormatting.activeTemplate(
                dayDigits: dayDigits, resolver: textResolver
            )
            let completedTemplate = HistoryTextFormatting.compactCompletedTemplate(
                dayDigits: dayDigits, resolver: textResolver
            )
            let currentWidth = Double(
                (currentTemplate as NSString).size(withAttributes: [.font: font]).width
            )
            let completedWidth = Double(
                (completedTemplate as NSString).size(withAttributes: [.font: font]).width
            )
            let durationWidth = max(currentWidth, completedWidth)
            widths[dayDigits] = durationWidth

            let completeBarWidth = labelMetrics.fullLabelWidth(durationWidth: durationWidth)
            let durationOnlyBarWidth = durationWidth + 12
            guard maximumProjectedBarWidth >= completeBarWidth
                || maximumProjectedBarWidth >= durationOnlyBarWidth
            else { break }
        }
        return widths
    }

    private var captionSemiboldFont: UIFont {
        let preferred = UIFont.preferredFont(forTextStyle: .caption1)
        return UIFont.systemFont(ofSize: preferred.pointSize, weight: .semibold)
    }

    private func visualLabel(_ descriptor: TemporalRibbonLabelDescriptor) -> some View {
        visualLabelGroup(descriptor)
            .padding(.horizontal, 6)
            .font(.caption.weight(.semibold))
            .foregroundStyle(UFastTheme.primary)
            // Keep the glyph, title, duration and disclosure as one intrinsic
            // group. The fixed descriptor frame below is the stable outer
            // reservation and the only centering wrapper; it must not be
            // proposed back as HStack width.
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(!HistoryLabelWorkProbe.isEnabled)
            .frame(width: descriptor.labelWidth, height: labelLaneHeight, alignment: .center)
            .position(
                x: descriptor.labelCenterX,
                y: labelCenterY(for: descriptor.lane)
            )
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

private extension TemporalRibbonLabelLayer {
    func visualLabelGroup(_ descriptor: TemporalRibbonLabelDescriptor) -> some View {
        HStack(spacing: 4) {
            if descriptor.showsGlyph, let glyphName = descriptor.glyphName {
                Image(systemName: glyphName)
                    .frame(width: descriptor.glyphWidth)
                    .accessibilityHidden(true)
            }
            if descriptor.showsDuration, let duration = descriptor.duration {
                if descriptor.showsText, let title = descriptor.title {
                    Text(title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityHidden(true)
                }
                TemporalRibbonLabelDurationLeaf(
                    descriptorID: descriptor.id,
                    duration: duration,
                    resolver: textResolver,
                    pulse: duration.isCurrent ? durationPulse : nil,
                    maximumDayDigits: descriptor.durationTemplateDayDigits ?? 0
                )
            } else if descriptor.showsText, let title = descriptor.title {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
            }
            if descriptor.showsText {
                ZStack {
                    Text(">")
                        .accessibilityHidden(true)
                    if HistoryLabelWorkProbe.isEnabled {
                        renderedGeometryProbe(
                            label: "History fast label disclosure",
                            identifier: "history.fast-label-disclosure-probe.\(descriptor.id.uuidString)"
                        )
                    }
                }
                .frame(width: TemporalRibbonLabelMetrics.disclosureWidth)
            }
        }
        // This is the compact intrinsic group centered inside the stable
        // descriptor frame. Duration reservation remains in descriptor.labelWidth,
        // not in a frame applied to the painted duration leaf.
        .fixedSize(horizontal: true, vertical: false)
        .background {
            if HistoryLabelWorkProbe.isEnabled {
                renderedGeometryProbe(
                    label: "History fast label content group",
                    identifier: "history.fast-label-group-probe.\(descriptor.id.uuidString)"
                )
            }
        }
    }

    func renderedGeometryProbe(label: String, identifier: String) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("history.fast-label-layer"))
            Color.clear
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(
                    "center \(frame.midX), "
                        + "width \(proxy.size.width)"
                )
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct TemporalRibbonLabelDurationLeaf: View {
    let descriptorID: UUID
    let duration: HistoryDurationSpec
    let resolver: AppTextResolver
    let pulse: HistoryDurationPulse?
    let maximumDayDigits: Int

    private var now: Date {
        guard duration.observesClock else { return duration.endDate }
        return pulse?.now ?? duration.startDate
    }

    private var displayText: String {
        HistoryTextFormatting.compactDuration(duration, at: now, resolver: resolver)
    }

    var body: some View {
        Group {
            if duration.value(at: now).dayDigits <= maximumDayDigits {
                Text(displayText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
                    .background {
                        if HistoryLabelWorkProbe.isEnabled {
                            renderedDurationProbe
                        }
                    }
            }
        }
        .onChange(of: now) { _, _ in
            guard duration.observesClock, pulse != nil else { return }
            HistoryLabelWorkProbe.recordDurationLeafInvalidation()
        }
    }

    private var renderedDurationProbe: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("history.fast-label-layer"))
            Color.clear
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("History fast rendered duration")
                .accessibilityValue(displayText)
                .accessibilityIdentifier(
                    "history.fast-label-rendered-duration-probe.\(descriptorID.uuidString)"
                )
                .accessibilityHint(
                    "center \(frame.midX), width \(proxy.size.width)"
                )
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
