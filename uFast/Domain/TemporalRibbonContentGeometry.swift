import Foundation

extension TemporalIntervalSegment {
    /// Chooses a bounded label treatment only after ownership is established.
    /// A continuation never gains content merely because its fragment is wider.
    func visualContentLayout(
        in window: TemporalRibbonWindow,
        visibleWidth: Double,
        minimumWidth: Double = TemporalRibbonGeometry.compactContentMinimumWidth
    ) -> TemporalIntervalContentLayout {
        guard ownsVisualContent(in: window) else { return .none }
        guard visibleWidth >= minimumWidth else { return .none }
        let layout = TemporalRibbonGeometry.intervalContentLayout(for: visibleWidth)
        if layout != .none {
            return layout
        }
        return .none
    }

    /// Hosts one stable fallback label on the first continuation only when the
    /// original-start fragment is too narrow to render any bounded content.
    func visualContentFallbackLayout(
        in window: TemporalRibbonWindow,
        visibleWidth: Double,
        surfaceWidth: Double,
        calendar: Calendar,
        minimumWidth: Double = TemporalRibbonGeometry.compactContentMinimumWidth
    ) -> TemporalIntervalContentLayout {
        guard isVisualContentFallbackHost(
            in: window,
            surfaceWidth: surfaceWidth,
            calendar: calendar,
            minimumWidth: minimumWidth
        ) else { return .none }
        guard visibleWidth >= minimumWidth else { return .none }
        return TemporalRibbonGeometry.intervalContentLayout(for: visibleWidth)
    }

    private func isVisualContentFallbackHost(
        in window: TemporalRibbonWindow,
        surfaceWidth: Double,
        calendar: Calendar,
        minimumWidth: Double
    ) -> Bool {
        guard !ownsVisualContent(in: window),
              continuesBefore,
              surfaceWidth.isFinite,
              surfaceWidth > 0
        else { return false }

        let ownerDay = calendar.startOfDay(for: originalStart)
        guard let ownerEnd = calendar.date(byAdding: .day, value: 1, to: ownerDay),
              ownerEnd == window.selectedDayInterval.start
        else { return false }

        let ownerDayDuration = ownerEnd.timeIntervalSince(ownerDay)
        guard ownerDayDuration > 0 else { return false }
        let ownerWidth = surfaceWidth
            * ownerEnd.timeIntervalSince(originalStart)
            / ownerDayDuration
        return ownerWidth.isFinite
            && ownerWidth > 0
            && ownerWidth < minimumWidth
    }
}
