import Foundation

extension TemporalIntervalSegment {
    /// Chooses a bounded label treatment only after ownership is established.
    /// A continuation never gains content merely because its fragment is wider.
    func visualContentLayout(
        in window: TemporalRibbonWindow,
        visibleWidth: Double
    ) -> TemporalIntervalContentLayout {
        guard ownsVisualContent(in: window) else { return .none }
        let layout = TemporalRibbonGeometry.intervalContentLayout(for: visibleWidth)
        if layout != .none {
            return layout
        }
        return .none
    }

    /// A very late start can leave the original owner fragment too narrow for
    /// any readable content. In that case the first continuation page becomes
    /// the sole visual content host, provided it has enough room for the
    /// complete compact icon and title. Later continuations remain content-free.
    func visualContentFallbackLayout(
        in window: TemporalRibbonWindow,
        visibleWidth: Double,
        surfaceWidth: Double,
        calendar: Calendar
    ) -> TemporalIntervalContentLayout {
        guard let leadingOverflow = visualContentFallbackLeadingOverflow(
            in: window,
            visibleWidth: visibleWidth,
            surfaceWidth: surfaceWidth,
            calendar: calendar
        ) else { return .none }
        return TemporalRibbonGeometry.intervalContentLayout(
            for: visibleWidth + leadingOverflow
        )
    }

    /// Keeps fallback content visually anchored to the original start even
    /// though the first continuation hosts it. This lets a late-night label
    /// span the midnight page join instead of appearing to start at midnight.
    func visualContentFallbackLeadingOverflow(
        in window: TemporalRibbonWindow,
        visibleWidth: Double,
        surfaceWidth: Double,
        calendar: Calendar
    ) -> Double? {
        guard !ownsVisualContent(in: window),
              continuesBefore,
              window.interval.start == window.selectedDayInterval.start,
              visibleWidth.isFinite,
              visibleWidth >= TemporalRibbonGeometry.compactContentMinimumWidth,
              surfaceWidth.isFinite,
              surfaceWidth > 0
        else { return nil }

        let ownerDay = calendar.startOfDay(for: originalStart)
        let continuationDay = window.selectedDayInterval.start
        guard calendar.date(byAdding: .day, value: 1, to: ownerDay) == continuationDay,
              let ownerEnd = calendar.date(byAdding: .day, value: 1, to: ownerDay)
        else { return nil }

        let ownerDayDuration = ownerEnd.timeIntervalSince(ownerDay)
        guard ownerDayDuration > 0 else { return nil }
        let ownerWidth = surfaceWidth
            * continuationDay.timeIntervalSince(originalStart)
            / ownerDayDuration
        guard ownerWidth > 0,
              ownerWidth < TemporalRibbonGeometry.compactContentMinimumWidth
        else { return nil }
        return ownerWidth
    }
}
