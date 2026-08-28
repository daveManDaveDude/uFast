import SwiftUI

extension TemporalHistoryCarousel {
    @ViewBuilder
    var labelLayer: some View {
        if measuredContentWidth > 0 {
            let policy = TemporalRibbonGeometry.pagePolicy(
                for: viewportWidth,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let markerHeight = TemporalEventMarkerMetrics.make(
                category: .nonCaloricDrink,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            ).ribbonHeight
            let layout = TemporalRibbonLabelLayout(
                contentWidth: measuredContentWidth,
                layerHeight: markerHeight,
                laneHeight: policy.intervalMarkHeight,
                // The continuous surface adds this existing inset inside each
                // page; the overlay is attached to the raw scroll-content
                // stack, so it must use the same local origin.
                labelTop: policy.intervalLaneTop + Double(UFastTheme.Spacing.standard),
                laneSpacing: policy.intervalLabelLaneSpacing
            )
            if HistoryLabelWorkProbe.isBaselineRun {
                TemporalRibbonLabelDiagnosticsProbe(
                    layout: layout,
                    appearedSegmentCount: appearedSegmentDates.count
                )
            } else if !motionIntervals.isEmpty {
                let direction = layoutDirection == .rightToLeft
                    ? TemporalHorizontalLayoutDirection.rightToLeft
                    : TemporalHorizontalLayoutDirection.leftToRight
                TemporalRibbonLabelLayer(
                    intervals: motionIntervals,
                    days: dates,
                    layout: layout,
                    calendar: calendar,
                    layoutDirection: direction,
                    textResolver: textResolver,
                    appearedSegmentCount: appearedSegmentDates.count
                )
            }
        }
    }
}
