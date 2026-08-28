import Foundation

/// Describes which side of an interval an instant belongs to when it lies on
/// a local-calendar midnight. Starts belong to the day being entered while
/// ends belong to the day being left. Keeping this distinction here avoids
/// making label placement depend on page-fragment ownership.
enum TemporalContinuousEndpointRole: Equatable, Sendable {
    case start
    case end
}

/// A continuous coordinate resolver for the same equal-width local-day runway
/// used by `TemporalContinuousTimelineGeometry`.
struct TemporalContinuousDaySpaceResolver: Equatable, Sendable {
    let days: [Date]
    let dayStride: Double
    let contentWidth: Double
    let calendar: Calendar
    let layoutDirection: TemporalHorizontalLayoutDirection

    init(
        days: [Date],
        contentWidth: Double,
        calendar: Calendar,
        layoutDirection: TemporalHorizontalLayoutDirection = .leftToRight
    ) {
        self.days = days
        self.contentWidth = contentWidth
        dayStride = days.isEmpty ? .nan : contentWidth / Double(days.count)
        self.calendar = calendar
        self.layoutDirection = layoutDirection
    }

    var isValid: Bool {
        guard !days.isEmpty,
              contentWidth.isFinite,
              contentWidth > 0,
              dayStride.isFinite,
              dayStride > 0
        else { return false }

        return days.indices.dropLast().allSatisfy { index in
            guard days[index] < days[index + 1] else { return false }
            return TemporalHistoryPresentation.adjacentDay(
                to: days[index],
                direction: 1,
                calendar: calendar
            ) == days[index + 1]
        }
    }

    /// Resolves an absolute instant to a visual content coordinate. The
    /// terminal midnight is a valid end but never a valid start because it is
    /// outside the supplied runway.
    func coordinate(
        for instant: Date,
        role: TemporalContinuousEndpointRole
    ) -> Double? {
        guard isValid, instant.timeIntervalSince1970.isFinite else { return nil }
        guard let chronological = chronologicalCoordinate(for: instant, role: role),
              chronological.isFinite,
              chronological >= 0,
              chronological <= contentWidth
        else { return nil }

        let visual = layoutDirection == .rightToLeft
            ? contentWidth - chronological
            : chronological
        return visual.isFinite && visual >= 0 && visual <= contentWidth ? visual : nil
    }

    func interval(
        start: Date,
        end: Date
    ) -> TemporalContinuousIntervalProjection? {
        guard start < end,
              let projectedStart = coordinate(for: start, role: .start),
              let projectedEnd = coordinate(for: end, role: .end)
        else { return nil }
        let lower = min(projectedStart, projectedEnd)
        let upper = max(projectedStart, projectedEnd)
        guard lower.isFinite, upper.isFinite, upper > lower else { return nil }
        return TemporalContinuousIntervalProjection(
            projectedStartX: projectedStart,
            projectedEndX: projectedEnd,
            lowerX: lower,
            upperX: upper
        )
    }

    private func chronologicalCoordinate(
        for instant: Date,
        role: TemporalContinuousEndpointRole
    ) -> Double? {
        guard let last = days.last,
              let terminalMidnight = calendar.date(byAdding: .day, value: 1, to: last)
        else { return nil }

        if role == .end, instant == terminalMidnight {
            return contentWidth
        }

        let localDay = calendar.startOfDay(for: instant)
        guard let index = days.firstIndex(of: localDay) else { return nil }
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: localDay) else {
            return nil
        }
        let dayDuration = nextMidnight.timeIntervalSince(localDay)
        guard dayDuration.isFinite, dayDuration > 0 else { return nil }

        if instant == localDay, role == .end {
            guard index > 0 else { return nil }
            return Double(index) * dayStride
        }

        guard instant >= localDay, instant <= nextMidnight else { return nil }
        let fraction = instant.timeIntervalSince(localDay) / dayDuration
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
        return (Double(index) + fraction) * dayStride
    }
}

struct TemporalContinuousIntervalProjection: Equatable, Sendable {
    let projectedStartX: Double
    let projectedEndX: Double
    let lowerX: Double
    let upperX: Double

    var width: Double {
        upperX - lowerX
    }

    var midpoint: Double {
        (lowerX + upperX) / 2
    }
}

/// Input to the pure label projector. The title is already localized by the
/// presentation adapter; semantic detail and accessibility copy stay on the
/// original interval item and never enter this decoration descriptor.
struct TemporalRibbonLabelInput: Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let kind: TemporalRibbonIntervalItem.Kind
    let title: String
    let glyphName: String
}

/// Platform measurement supplied to the pure fit policy. A value is keyed by
/// the localized title and presentation generation by its owner; the pure
/// projector only needs the resulting widths.
struct TemporalRibbonLabelMetrics: Equatable, Sendable {
    let title: String
    let glyphWidth: Double
    let textWidth: Double

    var fullLabelWidth: Double {
        glyphWidth + 4 + textWidth + 12
    }

    var glyphOnlyWidth: Double {
        glyphWidth + 12
    }

    var isFinite: Bool {
        glyphWidth.isFinite && glyphWidth >= 0 && textWidth.isFinite && textWidth >= 0
    }
}

/// Stable presentation inputs used to cache platform text measurements. The
/// dynamic-type category and font treatment are explicit so a localized title
/// is never measured with metrics from another accessibility configuration.
struct TemporalRibbonLabelMetricKey: Hashable, Sendable {
    let title: String
    let localeIdentifier: String
    let layoutDirection: TemporalHorizontalLayoutDirection
    let dynamicTypeCategory: String
    let font: String
}

/// Geometry needed only by the rendering adapter. Projection itself consumes
/// the immutable interval/day/layout values above and never observes scrolling.
struct TemporalRibbonLabelLayout: Equatable, Sendable {
    let contentWidth: Double
    let layerHeight: Double
    let laneHeight: Double
    let labelTop: Double
    let laneSpacing: Double
}

struct TemporalRibbonLabelDescriptor: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: TemporalRibbonIntervalItem.Kind
    let title: String?
    let glyphName: String?
    let lane: Int
    let projectedStartX: Double
    let projectedEndX: Double
    let labelCenterX: Double
    let labelWidth: Double
    let glyphWidth: Double
    let showsText: Bool
    let showsGlyph: Bool
}

private struct TemporalRibbonLabelFit: Equatable, Sendable {
    let showsText: Bool
    let showsGlyph: Bool
    let width: Double
}

enum TemporalRibbonLabelProjector {
    /// Produces at most one stable descriptor for each interval identity. The
    /// lane map is the same original-interval allocator used by `clip`, so a
    /// page fragment and its continuous decoration cannot diverge vertically.
    static func project(
        _ inputs: [TemporalRibbonLabelInput],
        days: [Date],
        contentWidth: Double,
        calendar: Calendar,
        layoutDirection: TemporalHorizontalLayoutDirection = .leftToRight,
        metrics: [String: TemporalRibbonLabelMetrics]
    ) -> [TemporalRibbonLabelDescriptor] {
        let resolver = TemporalContinuousDaySpaceResolver(
            days: days,
            contentWidth: contentWidth,
            calendar: calendar,
            layoutDirection: layoutDirection
        )
        guard resolver.isValid else { return [] }

        let canonical = inputs
            .filter { $0.start < $0.end }
            .sorted {
                if $0.id != $1.id {
                    return $0.id.uuidString < $1.id.uuidString
                }
                if $0.start != $1.start {
                    return $0.start < $1.start
                }
                if $0.end != $1.end {
                    return $0.end < $1.end
                }
                return $0.title < $1.title
            }
        var seen = Set<UUID>()
        let intervalInputs = canonical.map {
            TemporalIntervalInput(id: $0.id, start: $0.start, end: $0.end)
        }
        let laneByID = TemporalHistoryPresentation.laneAssignments(for: intervalInputs)

        return canonical.compactMap { input in
            guard seen.insert(input.id).inserted,
                  let projection = resolver.interval(start: input.start, end: input.end),
                  let lane = laneByID[input.id],
                  let inputMetrics = metrics[input.title],
                  inputMetrics.title == input.title,
                  inputMetrics.isFinite
            else { return nil }

            let fit = fit(for: input, projection: projection, metrics: inputMetrics)
            return TemporalRibbonLabelDescriptor(
                id: input.id,
                kind: input.kind,
                title: fit.showsText ? input.title : nil,
                glyphName: fit.showsGlyph ? input.glyphName : nil,
                lane: lane,
                projectedStartX: projection.projectedStartX,
                projectedEndX: projection.projectedEndX,
                labelCenterX: projection.midpoint,
                labelWidth: fit.width,
                glyphWidth: inputMetrics.glyphWidth,
                showsText: fit.showsText,
                showsGlyph: fit.showsGlyph
            )
        }
    }

    private static func fit(
        for input: TemporalRibbonLabelInput,
        projection: TemporalContinuousIntervalProjection,
        metrics: TemporalRibbonLabelMetrics
    ) -> TemporalRibbonLabelFit {
        guard projection.width >= metrics.glyphOnlyWidth else {
            return TemporalRibbonLabelFit(showsText: false, showsGlyph: false, width: 0)
        }
        guard !input.title.isEmpty, projection.width >= metrics.fullLabelWidth else {
            return TemporalRibbonLabelFit(
                showsText: false,
                showsGlyph: true,
                width: metrics.glyphOnlyWidth
            )
        }
        return TemporalRibbonLabelFit(
            showsText: true,
            showsGlyph: true,
            width: metrics.fullLabelWidth
        )
    }
}
