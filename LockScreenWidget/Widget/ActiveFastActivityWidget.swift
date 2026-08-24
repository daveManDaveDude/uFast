import Foundation
import SwiftUI
import WidgetKit

// swiftlint:disable file_length

struct UFastActiveFastActivityWidget: Widget {
    static func compactLeadingContent() -> some View {
        EmptyView()
    }

    static func compactTrailingContent(
        contentState: ActiveFastActivityAttributes.ContentState,
        textResolver: SystemSurfaceTextResolver = .init(),
        now: Date = .now
    ) -> some View {
        ActiveFastActivityCircularProgressView(
            contentState: contentState,
            textResolver: textResolver,
            now: now
        )
    }

    static func minimalContent(
        contentState: ActiveFastActivityAttributes.ContentState,
        textResolver: SystemSurfaceTextResolver = .init(),
        now: Date = .now
    ) -> some View {
        ActiveFastActivityCircularProgressView(
            contentState: contentState,
            textResolver: textResolver,
            now: now
        )
    }

    static func expandedContent(
        contentState: ActiveFastActivityAttributes.ContentState,
        textResolver: SystemSurfaceTextResolver = .init(),
        now: Date = .now
    ) -> some View {
        ActiveFastActivityCircularProgressView(
            contentState: contentState,
            textResolver: textResolver,
            now: now
        )
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ActiveFastActivityAttributes.self) { context in
            ActiveFastActivityLockScreenView(context: context)
                .widgetURL(ActiveFastActivityRoute.currentFastURL)
        } dynamicIsland: { context in
            DynamicIsland(
                expanded: {
                    DynamicIslandExpandedRegion(.center) {
                        Self.expandedContent(contentState: context.state)
                            .widgetURL(ActiveFastActivityRoute.currentFastURL)
                    }
                },
                compactLeading: { Self.compactLeadingContent() },
                compactTrailing: {
                    Self.compactTrailingContent(contentState: context.state)
                        .widgetURL(ActiveFastActivityRoute.currentFastURL)
                },
                minimal: {
                    Self.minimalContent(contentState: context.state)
                        .widgetURL(ActiveFastActivityRoute.currentFastURL)
                }
            )
            .widgetURL(ActiveFastActivityRoute.currentFastURL)
        }
    }
}

private struct ActiveFastActivityLockScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.redactionReasons) private var redactionReasons
    let context: ActivityViewContext<ActiveFastActivityAttributes>

    private let copy = SystemSurfaceTextResolver()

    private var privacyState: ActiveFastActivityPrivacyState {
        .make(isPrivacyRedacted: redactionReasons.contains(.privacy))
    }

    private var presentation: ActiveFastActivityPresentation {
        ActiveFastActivityPresentation.make(
            attributes: context.attributes,
            contentState: context.state,
            now: .now,
            privacyState: privacyState,
            textResolver: copy
        )
    }

    private var visualContent: some View {
        let palette = ActiveFastActivityPalette(colorScheme: colorScheme)

        return ZStack {
            palette.card
            ActiveFastActivityBotanicalArtwork()

            VStack(alignment: .leading, spacing: 8) {
                ActiveFastActivityBrandMark()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: copy(.elapsed))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                    ActiveFastActivityTimerView(contentState: context.state)
                        .font(.title3.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ActiveFastActivityDetailView(contentState: context.state)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var visibleAccessibilityValue: Text? {
        guard privacyState == .visible,
              let goal = presentation.stableGoalText,
              let target = presentation.targetText
        else {
            return nil
        }

        // Text(date, style: .timer) is resolved by the system and remains
        // current while the app and extension are suspended. Keep ordinary
        // sampled projection fields out of this accessibility representation.
        return ActiveFastActivityAccessibility.value(
            startDate: context.state.startDate,
            goal: goal,
            target: target,
            hasReachedGoal: presentation.hasReachedGoal,
            resolver: copy
        )
    }

    var body: some View {
        Group {
            if let visibleAccessibilityValue {
                visualContent
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: copy(.brand)))
                    .accessibilityValue(visibleAccessibilityValue)
            } else {
                // Invalid or privacy-redacted content fails closed to the
                // identity-only summary and does not expose child semantics.
                visualContent
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: copy(.identitySummary)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
    }
}

private struct ActiveFastActivityTimerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let contentState: ActiveFastActivityAttributes.ContentState

    private let copy = SystemSurfaceTextResolver()

    var body: some View {
        Text(contentState.startDate, style: .timer)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(ActiveFastActivityPalette(colorScheme: colorScheme).primary)
            .privacySensitive()
            .accessibilityLabel(Text(verbatim: copy(.elapsed)))
    }
}

private struct ActiveFastActivityCircularProgressView: View {
    @Environment(\.colorScheme) private var colorScheme
    let contentState: ActiveFastActivityAttributes.ContentState
    let now: Date

    private let copy: SystemSurfaceTextResolver

    init(
        contentState: ActiveFastActivityAttributes.ContentState,
        textResolver: SystemSurfaceTextResolver = .init(),
        now: Date = .now
    ) {
        self.contentState = contentState
        self.now = now
        copy = textResolver
    }

    var body: some View {
        let presentation = ActiveFastActivityPresentation.make(
            attributes: ActiveFastActivityAttributes(activeRecordIdentifier: UUID()),
            contentState: contentState,
            now: now,
            textResolver: copy
        )

        let palette = ActiveFastActivityPalette(colorScheme: colorScheme)

        Group {
            if presentation.progress != nil {
                ProgressView(
                    timerInterval: contentState.startDate ... contentState.targetDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
                .tint(palette.action)
            } else {
                Circle()
                    .strokeBorder(palette.track.opacity(0.9), lineWidth: 2.5)
            }
        }
        .frame(width: 22, height: 22)
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: copy(.brand)))
        .accessibilityValue(
            ActiveFastActivityAccessibility.value(
                startDate: contentState.startDate,
                goal: presentation.stableGoalText,
                resolver: copy
            )
        )
    }
}

private struct ActiveFastActivityDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    let contentState: ActiveFastActivityAttributes.ContentState

    private let copy = SystemSurfaceTextResolver()

    var body: some View {
        let palette = ActiveFastActivityPalette(colorScheme: colorScheme)
        let attributes = ActiveFastActivityAttributes(activeRecordIdentifier: UUID())
        let presentation = ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: contentState,
            now: .now
        )
        VStack(alignment: .leading, spacing: 5) {
            if presentation.progress != nil {
                // A date-relative progress view is resolved by the system and
                // keeps advancing while uFast and this extension are suspended.
                ProgressView(
                    timerInterval: contentState.startDate ... contentState.targetDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(palette.action)
                .scaleEffect(y: 1.5)

                if let target = presentation.targetText {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: presentation.stableGoalText ?? copy(.goal(hours: contentState.goalHours)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 4)
                            Text(verbatim: copy(.target(value: target)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: presentation.stableGoalText ?? copy(.goal(hours: contentState.goalHours)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(verbatim: copy(.target(value: target)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: presentation.stableGoalText ?? copy(.goal(hours: contentState.goalHours)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Text(verbatim: copy(.target(value: target)))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(verbatim: presentation.stableGoalText ?? copy(.goal(hours: contentState.goalHours)))
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            if presentation.hasReachedGoal {
                Text(verbatim: copy(.goalReached))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: copy(.brand)))
        .accessibilityValue(
            ActiveFastActivityAccessibility.value(
                startDate: contentState.startDate,
                goal: presentation.stableGoalText,
                target: presentation.targetText,
                hasReachedGoal: presentation.hasReachedGoal,
                resolver: copy
            )
        )
    }
}

private enum ActiveFastActivityAccessibility {
    static func value(
        startDate: Date,
        goal: String?,
        target: String? = nil,
        hasReachedGoal: Bool = false,
        resolver: SystemSurfaceTextResolver = .init()
    ) -> Text {
        let content = SystemSurfacePresentationContent.activity(
            layout: .expanded,
            goal: goal,
            target: target,
            hasReachedGoal: hasReachedGoal,
            resolver: resolver
        )
        guard goal != nil else { return Text(verbatim: content.opensSuffix) }

        var value = Text(verbatim: content.elapsedPrefix)
            + Text(startDate, style: .timer)
        if let target {
            // Text composition is required to preserve the system timer segment.
            // swiftlint:disable:next shorthand_operator
            value = value + Text(
                verbatim: content.detail
            )
        } else {
            // swiftlint:disable:next shorthand_operator
            value = value + Text(verbatim: content.goalOnlyDetail)
        }
        if hasReachedGoal {
            // swiftlint:disable:next shorthand_operator
            value = value + Text(verbatim: content.goalReachedSuffix)
        }
        return value + Text(verbatim: content.opensSuffix)
    }
}

private struct ActiveFastActivityPalette {
    static let heroRadius: CGFloat = 32

    static let dark = Self(
        card: Color(red: 0.19, green: 0.35, blue: 0.40),
        primary: Color(red: 0.86, green: 0.93, blue: 0.85),
        secondaryText: Color(red: 0.72, green: 0.77, blue: 0.73),
        action: Color(red: 0.48, green: 0.67, blue: 0.52),
        track: Color(red: 0.16, green: 0.21, blue: 0.19),
        border: Color(red: 0.75, green: 0.84, blue: 0.77).opacity(0.28)
    )

    static let light = Self(
        card: Color(red: 0.72, green: 0.87, blue: 0.91),
        primary: Color(red: 0.04, green: 0.24, blue: 0.19),
        secondaryText: Color(red: 0.25, green: 0.29, blue: 0.27),
        action: Color(red: 0.04, green: 0.29, blue: 0.23),
        track: Color.white.opacity(0.88),
        border: Color(red: 0.16, green: 0.29, blue: 0.23).opacity(0.18)
    )

    let card: Color
    let primary: Color
    let secondaryText: Color
    let action: Color
    let track: Color
    let border: Color

    private init(
        card: Color,
        primary: Color,
        secondaryText: Color,
        action: Color,
        track: Color,
        border: Color
    ) {
        self.card = card
        self.primary = primary
        self.secondaryText = secondaryText
        self.action = action
        self.track = track
        self.border = border
    }

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? Self.dark : Self.light
    }
}

private struct ActiveFastActivityBrandMark: View {
    @Environment(\.colorScheme) private var colorScheme
    let compact: Bool

    private let copy = SystemSurfaceTextResolver()

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        Group {
            if compact {
                Text(verbatim: copy(.compactBrand))
                    .font(.caption.weight(.semibold))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.headline)
                        .accessibilityHidden(true)
                    Text(verbatim: copy(.brand))
                        .font(.headline.weight(.semibold))
                }
            }
        }
        .foregroundStyle(ActiveFastActivityPalette(colorScheme: colorScheme).primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: copy(.brand)))
    }
}

private struct ActiveFastActivityBotanicalArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let artworkHeight = proxy.size.width / 1.75
            let verticalOverflow = max(0, artworkHeight - proxy.size.height)

            Image("FastingBotanical")
                .resizable()
                .frame(width: proxy.size.width, height: artworkHeight)
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height / 2 + verticalOverflow * 0.15
                )
                .opacity(colorScheme == .dark ? 0.62 : 0.9)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private let activityPreviewStart = Date(timeIntervalSince1970: 1_800_000_000)

private struct ActiveFastActivityPreviewSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    let contentState: ActiveFastActivityAttributes.ContentState

    var body: some View {
        let palette = ActiveFastActivityPalette(colorScheme: colorScheme)

        ZStack {
            palette.card
            ActiveFastActivityBotanicalArtwork()

            VStack(alignment: .leading, spacing: 10) {
                ActiveFastActivityBrandMark()
                ActiveFastActivityTimerView(contentState: contentState)
                    .font(.title.monospacedDigit())
                ActiveFastActivityDetailView(contentState: contentState)
            }
            .padding(16)
        }
        .clipShape(.rect(cornerRadius: ActiveFastActivityPalette.heroRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ActiveFastActivityPalette.heroRadius)
                .stroke(palette.border, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActiveFastActivityPreviewProvider: PreviewProvider {
    static var previews: some View {
        Group {
            ActiveFastActivityPreviewSurface(
                contentState: .init(
                    startDate: activityPreviewStart,
                    targetDate: activityPreviewStart.addingTimeInterval(12 * 60 * 60),
                    goalHours: 12,
                    generatedAt: activityPreviewStart.addingTimeInterval(6 * 60 * 60)
                )
            )
            .previewDisplayName("Below goal")

            ActiveFastActivityPreviewSurface(
                contentState: .init(
                    startDate: activityPreviewStart,
                    targetDate: activityPreviewStart.addingTimeInterval(12 * 60 * 60),
                    goalHours: 12,
                    generatedAt: activityPreviewStart.addingTimeInterval(12 * 60 * 60)
                )
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("At goal · dark")

            ActiveFastActivityPreviewSurface(
                contentState: .init(
                    startDate: activityPreviewStart,
                    targetDate: activityPreviewStart.addingTimeInterval(12 * 60 * 60),
                    goalHours: 12,
                    generatedAt: activityPreviewStart.addingTimeInterval(15 * 60 * 60)
                )
            )
            .environment(\.dynamicTypeSize, .accessibility3)
            .previewDisplayName("Beyond goal · accessibility")
        }
    }
}
