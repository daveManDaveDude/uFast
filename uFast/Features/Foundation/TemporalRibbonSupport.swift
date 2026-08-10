import SwiftUI

// swiftlint:disable function_body_length opening_brace

@Observable
@MainActor
final class TemporalCoupledScrollPresentation {
    private(set) var preview: TemporalDaySpaceProgress?
    private(set) var liveCenteredDay: Date?
    private(set) var isReconciling = false

    func handle(_ update: TemporalCoupledPresentationUpdate) {
        switch update {
        case let .preview(preview):
            isReconciling = false
            guard preview != self.preview else { return }
            self.preview = preview
            let liveDay = preview.centeredCalendarDay
            if liveCenteredDay != liveDay {
                liveCenteredDay = liveDay
            }
        case let .reconcile(day, dates):
            guard let index = dates.firstIndex(of: day),
                  dates.count > 1
            else {
                finishReconciliation()
                return
            }
            let lowerStride = preview?.lowerPageStride ?? 1
            if dates.indices.contains(index + 1) {
                preview = TemporalDaySpaceProgress(
                    leadingDay: dates[index],
                    trailingDay: dates[index + 1],
                    fraction: 0,
                    lowerPageStride: lowerStride
                )
            } else {
                preview = TemporalDaySpaceProgress(
                    leadingDay: dates[index - 1],
                    trailingDay: dates[index],
                    fraction: 1,
                    lowerPageStride: lowerStride
                )
            }
            isReconciling = true
        case .end:
            finishReconciliation()
        }
    }

    func finishReconciliation() {
        isReconciling = false
        preview = nil
        liveCenteredDay = nil
    }
}

enum TemporalCoupledPresentationUpdate {
    case preview(TemporalDaySpaceProgress)
    case reconcile(day: Date, dates: [Date])
    case end
}

struct TemporalDateChipStrideKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TemporalDateChipMidpointsKey: PreferenceKey {
    static let defaultValue: [Date: CGFloat] = [:]

    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

enum TemporalDateNavigatorCoordinateSpace {
    static let name = "temporal-date-navigator"
}

struct TemporalSelectedDateChipMidXKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

struct TemporalDateNavigatorWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TemporalRibbonSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast

    let isContinuous: Bool

    func body(content: Content) -> some View {
        if isContinuous {
            content
                .padding(.vertical, UFastTheme.Spacing.standard)
                .background(UFastTheme.surface)
                .overlay(alignment: .top) {
                    separator
                }
                .overlay(alignment: .bottom) {
                    separator
                }
        } else {
            content.uFastCard()
        }
    }

    var separator: some View {
        Rectangle()
            .fill(
                UFastTheme.border.opacity(
                    contrast == .increased ? 1 : 0.72
                )
            )
            .frame(height: contrast == .increased ? 2 : 1)
    }
}

@MainActor
final class TemporalCarouselGeometrySnapshot {
    var geometry: TemporalContinuousTimelineGeometry?
    var hasActiveMotion = false
}

struct TemporalSelectedPageHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
