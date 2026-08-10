struct TemporalEventGroupLayout: Equatable, Sendable {
    let centerFraction: Double
    let visibleWidth: Double
    let visibleWidthFraction: Double
    let interactiveWidth: Double
    let bucketStartFraction: Double
    let bucketEndFraction: Double

    static func make(
        bucketStartFraction: Double,
        bucketEndFraction: Double,
        ribbonWidth: Double
    ) -> Self? {
        guard ribbonWidth.isFinite, ribbonWidth > 0,
              bucketStartFraction.isFinite, bucketEndFraction.isFinite,
              bucketStartFraction <= bucketEndFraction
        else { return nil }
        let start = min(max(bucketStartFraction, 0), 1)
        let end = min(max(bucketEndFraction, 0), 1)
        let width = max(0, (end - start) * ribbonWidth)
        let visibleWidth = width * TemporalEventGrouping.visibleMarkerWidthFraction
        return Self(
            centerFraction: (start + end) / 2,
            visibleWidth: visibleWidth,
            visibleWidthFraction: (end - start) * TemporalEventGrouping.visibleMarkerWidthFraction,
            interactiveWidth: max(44, visibleWidth),
            bucketStartFraction: start,
            bucketEndFraction: end
        )
    }

    var visibleBounds: ClosedRange<Double> {
        let halfWidth = visibleWidthFraction / 2
        return (centerFraction - halfWidth) ... (centerFraction + halfWidth)
    }

    var visibleContentWidth: Double {
        max(1, min(44, visibleWidth))
    }
}

struct TemporalEventMarkerMetrics: Equatable, Sendable {
    let ribbonHeight: Double
    let eventAreaTop: Double
    let rowHeight: Double
    let rowIndex: Int
    let tileSize: Double
    let labelBandHeight: Double
    let labelGap: Double
    let hitHeight: Double

    static let normalRibbonHeight = 268.0
    static let accessibilityRibbonHeight = 320.0

    static func make(
        category: TemporalEventPresentationCategory,
        accessibilitySize: Bool
    ) -> Self {
        let rowHeight = accessibilitySize ? 68.0 : 52.0
        let rowIndex = category.sortOrder
        return Self(
            ribbonHeight: accessibilitySize ? accessibilityRibbonHeight : normalRibbonHeight,
            eventAreaTop: 122,
            rowHeight: rowHeight,
            rowIndex: rowIndex,
            tileSize: accessibilitySize ? 32 : 26,
            labelBandHeight: accessibilitySize ? 18 : 14,
            labelGap: accessibilitySize ? 3 : 2,
            hitHeight: max(44, rowHeight)
        )
    }

    var rowTop: Double {
        eventAreaTop + Double(rowIndex) * rowHeight
    }

    var cellHeight: Double {
        tileSize + labelGap + labelBandHeight
    }
}

struct TemporalRibbonSurfaceMetrics: Equatable, Sendable {
    static let topLabelClearance = 32.0

    static func gridRuleHeight(surfaceHeight: Double) -> Double {
        max(0, surfaceHeight - topLabelClearance)
    }
}
