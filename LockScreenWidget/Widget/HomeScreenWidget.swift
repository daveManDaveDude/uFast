import SwiftUI
import WidgetKit

struct UFastHomeScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "UFastHomeScreenWidget",
            provider: UFastLockScreenProvider()
        ) { entry in
            UFastHomeScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Shows your active fast progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct UFastHomeScreenWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetFamily) private var family

    let entry: UFastLockScreenEntry

    private var palette: UFastHomeScreenPalette {
        UFastHomeScreenPalette(colorScheme: colorScheme)
    }

    private var privacyState: LockScreenPrivacyState {
        redactionReasons.contains(.privacy) ? .protected : .authenticated
    }

    private var presentation: LockScreenFastPresentation {
        .make(
            projectionResult: entry.projectionResult,
            now: entry.date,
            privacyState: privacyState
        )
    }

    var body: some View {
        Group {
            switch presentation {
            case let .active(active):
                activeView(active)
            case .unavailable:
                unavailableView
            }
        }
        .widgetURL(ActiveFastActivityRoute.currentFastURL)
        .containerBackground(for: .widget) {
            palette.canvas
        }
    }

    @ViewBuilder
    private func activeView(_ active: LockScreenActivePresentation) -> some View {
        switch family {
        case .systemSmall:
            smallActiveView(active)
        case .systemLarge:
            largeActiveView(active)
        default:
            mediumActiveView(active)
        }
    }

    private func smallActiveView(_ active: LockScreenActivePresentation) -> some View {
        ZStack {
            palette.card
            UFastHomeScreenBotanicalArtwork()

            VStack(alignment: .leading, spacing: 6) {
                UFastHomeScreenBrandMark(palette: palette, compact: true)
                Spacer(minLength: 0)
                Text("Elapsed")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                elapsedView(active)
                    .font(.title3.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                systemDrivenProgress(active)
                compactDetail(active)
            }
            .padding(12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(active.accessibilitySummary))
    }

    private func mediumActiveView(_ active: LockScreenActivePresentation) -> some View {
        ZStack {
            palette.card
            UFastHomeScreenBotanicalArtwork()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    UFastHomeScreenBrandMark(palette: palette)
                    Spacer(minLength: 8)
                    Text("Fast in progress")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Elapsed")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    elapsedView(active)
                        .font(.title2.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 0)
                systemDrivenProgress(active)
                compactDetail(active)
            }
            .padding(16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(active.accessibilitySummary))
    }

    private func largeActiveView(_ active: LockScreenActivePresentation) -> some View {
        ZStack {
            palette.card
            UFastHomeScreenBotanicalArtwork()

            VStack(alignment: .leading, spacing: 10) {
                UFastHomeScreenBrandMark(palette: palette)
                Spacer(minLength: 0)

                Label("Fast in progress", systemImage: "timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primary)

                Text("Elapsed time")
                    .font(.headline)
                    .foregroundStyle(palette.secondaryText)
                elapsedView(active)
                    .font(.system(size: 42, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 0)
                systemDrivenProgress(active)
                HStack(alignment: .firstTextBaseline) {
                    Text(active.progressAccessibilityValue)
                    Spacer(minLength: 8)
                    if let targetText = active.targetText {
                        Text("Target \(targetText)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                if active.hasReachedGoal == true {
                    Label("Goal time reached", systemImage: "checkmark.circle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                }
            }
            .padding(20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(active.accessibilitySummary))
    }

    private func elapsedView(_ active: LockScreenActivePresentation) -> some View {
        Group {
            if privacyState == .protected {
                Text(active.elapsedText)
            } else {
                Text(active.startDate, style: .timer)
            }
        }
        .monospacedDigit()
        .foregroundStyle(palette.primary)
        .privacySensitive()
    }

    private func systemDrivenProgress(
        _ active: LockScreenActivePresentation
    ) -> some View {
        // WidgetKit can keep a date-relative ProgressView current without
        // granting the extension execution time or persisting timer ticks.
        ProgressView(
            timerInterval: active.startDate ... active.targetDate,
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.linear)
        .tint(palette.action)
        .scaleEffect(y: 1.5)
    }

    private func compactDetail(_ active: LockScreenActivePresentation) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: "\(active.progressPercentage)%")
            Spacer(minLength: 6)
            if let targetText = active.targetText {
                Text("Target \(targetText)")
            } else if active.hasReachedGoal == true {
                Text("Goal reached")
            }
        }
        .font(.caption2)
        .foregroundStyle(palette.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private var unavailableView: some View {
        ZStack {
            palette.card
            UFastHomeScreenBotanicalArtwork()

            VStack(alignment: .leading, spacing: 6) {
                UFastHomeScreenBrandMark(palette: palette)
                Spacer(minLength: 0)
                Text("No active fast")
                    .font(.headline)
                    .foregroundStyle(palette.primary)
                Text("Open uFast to start one.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("uFast. No active fast. Opens uFast.")
    }
}

private struct UFastHomeScreenPalette {
    let canvas: Color
    let card: Color
    let primary: Color
    let secondaryText: Color
    let action: Color
    let track: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            canvas = Color(red: 0.08, green: 0.11, blue: 0.10)
            card = Color(red: 0.19, green: 0.35, blue: 0.40)
            primary = Color(red: 0.86, green: 0.93, blue: 0.85)
            secondaryText = Color(red: 0.72, green: 0.77, blue: 0.73)
            action = Color(red: 0.48, green: 0.67, blue: 0.52)
            track = Color(red: 0.16, green: 0.21, blue: 0.19)
        } else {
            canvas = Color(red: 0.98, green: 0.96, blue: 0.91)
            card = Color(red: 0.72, green: 0.87, blue: 0.91)
            primary = Color(red: 0.04, green: 0.24, blue: 0.19)
            secondaryText = Color(red: 0.25, green: 0.29, blue: 0.27)
            action = Color(red: 0.04, green: 0.29, blue: 0.23)
            track = Color.white.opacity(0.78)
        }
    }
}

private struct UFastHomeScreenBrandMark: View {
    let palette: UFastHomeScreenPalette
    let compact: Bool

    init(palette: UFastHomeScreenPalette, compact: Bool = false) {
        self.palette = palette
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(systemName: "leaf.fill")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(palette.action)
                .accessibilityHidden(true)
            Text("uFast")
                .font(compact ? .headline : .title3.weight(.semibold))
                .foregroundStyle(palette.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("uFast")
    }
}

private struct UFastHomeScreenBotanicalArtwork: View {
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
