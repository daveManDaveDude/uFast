import SwiftUI
import UIKit

/// Semantic visual roles for uFast. Feature views should use these purpose-based
/// names instead of introducing literal colours, radii or type treatments.
enum UFastTheme {
    enum Spacing {
        static let compact: CGFloat = 8
        static let standard: CGFloat = 16
        static let generous: CGFloat = 24
        static let section: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 22
        static let hero: CGFloat = 32
    }

    static let canvas = Color.adaptive(
        light: UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.11, blue: 0.10, alpha: 1)
    )
    static let primary = Color.adaptive(
        light: UIColor(red: 0.04, green: 0.24, blue: 0.19, alpha: 1),
        dark: UIColor(red: 0.86, green: 0.93, blue: 0.85, alpha: 1)
    )
    static let actionUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.67, blue: 0.52, alpha: 1)
            : UIColor(red: 0.04, green: 0.29, blue: 0.23, alpha: 1)
    }

    static let action = Color(uiColor: actionUIColor)
    static let keyboardActionUIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.57, blue: 0.47, alpha: 1)
            : UIColor(red: 0.31, green: 0.44, blue: 0.35, alpha: 1)
    }

    static let onAction = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.05, green: 0.12, blue: 0.09, alpha: 1)
    )
    static let surface = Color.adaptive(
        light: UIColor(white: 1, alpha: 0.58),
        dark: UIColor(red: 0.12, green: 0.17, blue: 0.15, alpha: 1)
    )
    static let raisedSurface = Color.adaptive(
        light: UIColor(white: 1, alpha: 0.88),
        dark: UIColor(red: 0.16, green: 0.21, blue: 0.19, alpha: 1)
    )
    static let formSurface = Color.adaptive(
        light: UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.17, blue: 0.15, alpha: 1)
    )
    static let sage = Color.adaptive(
        light: UIColor(red: 0.72, green: 0.81, blue: 0.67, alpha: 1),
        dark: UIColor(red: 0.29, green: 0.40, blue: 0.31, alpha: 1)
    )
    static let sky = Color.adaptive(
        light: UIColor(red: 0.72, green: 0.87, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.35, blue: 0.40, alpha: 1)
    )
    static let apricot = Color.adaptive(
        light: UIColor(red: 0.96, green: 0.74, blue: 0.55, alpha: 1),
        dark: UIColor(red: 0.56, green: 0.34, blue: 0.22, alpha: 1)
    )
    static let border = Color.adaptive(
        light: UIColor(red: 0.16, green: 0.29, blue: 0.23, alpha: 0.18),
        dark: UIColor(red: 0.75, green: 0.84, blue: 0.77, alpha: 0.28)
    )
    static let secondaryText = Color.adaptive(
        light: UIColor(red: 0.25, green: 0.29, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.77, blue: 0.73, alpha: 1)
    )
    static let error = Color.adaptive(
        light: UIColor(red: 0.60, green: 0.17, blue: 0.13, alpha: 1),
        dark: UIColor(red: 1, green: 0.66, blue: 0.57, alpha: 1)
    )
}

extension Font {
    static func uFastDisplay(_ style: TextStyle = .largeTitle) -> Font {
        .system(style, design: .default, weight: .semibold)
    }
}

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

struct UFastPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .foregroundStyle(UFastTheme.onAction)
            .background(UFastTheme.action.opacity(isEnabled ? 1 : 0.45))
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

struct UFastSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .foregroundStyle(UFastTheme.primary.opacity(isEnabled ? 1 : 0.45))
            .background(UFastTheme.raisedSurface)
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .stroke(
                        UFastTheme.primary.opacity(contrast == .increased ? 0.8 : 0.38),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct UFastActionRowButtonStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .foregroundStyle(UFastTheme.primary)
            .background(UFastTheme.raisedSurface)
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .stroke(
                        UFastTheme.action.opacity(contrast == .increased ? 0.9 : 0.42),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct UFastDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, UFastTheme.Spacing.standard)
            .foregroundStyle(UFastTheme.error)
            .background(UFastTheme.raisedSurface)
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .stroke(UFastTheme.error.opacity(0.55), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct UFastCardModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let accent: Color?
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(UFastTheme.Spacing.standard)
            .background(accent?.opacity(0.22) ?? UFastTheme.surface)
            .clipShape(.rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        UFastTheme.border.opacity(contrast == .increased ? 1 : 0.72),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
    }
}

extension View {
    func uFastCard(
        accent: Color? = nil,
        radius: CGFloat = UFastTheme.Radius.card
    ) -> some View {
        modifier(UFastCardModifier(accent: accent, radius: radius))
    }
}

struct UFastSectionHeading: View {
    let title: String
    let eyebrow: String?

    init(_ title: String, eyebrow: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            Text(title)
                .font(.uFastDisplay(.title2))
                .foregroundStyle(UFastTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A calm, non-interactive empty or explanatory state. Artwork is decorative;
/// the native heading and message always carry the meaning.
struct UFastIllustratedInformationCard<Artwork: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var cardHeight = 220

    let title: String
    let eyebrow: String?
    let message: String
    let artwork: Artwork

    init(
        title: String,
        eyebrow: String? = nil,
        message: String,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.message = message
        self.artwork = artwork()
    }

    var body: some View {
        ZStack {
            UFastTheme.sky.opacity(0.72)
            artwork

            VStack(spacing: UFastTheme.Spacing.compact) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(UFastTheme.secondaryText)
                }

                Text(title)
                    .font(.uFastDisplay(.title2))
                    .foregroundStyle(UFastTheme.primary)

                Text(message)
                    .font(.body)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, UFastTheme.Spacing.section)
            .padding(.vertical, UFastTheme.Spacing.generous)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .clipShape(.rect(cornerRadius: UFastTheme.Radius.hero))
        .overlay {
            RoundedRectangle(cornerRadius: UFastTheme.Radius.hero)
                .stroke(
                    UFastTheme.border.opacity(contrast == .increased ? 1 : 0.72),
                    lineWidth: contrast == .increased ? 2 : 1
                )
        }
        .accessibilityElement(children: .contain)
    }
}

struct UFastBrandMark: View {
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(UFastTheme.action)
                .accessibilityHidden(true)
            Text("uFast")
                .font(.uFastDisplay(compact ? .headline : .title3))
                .foregroundStyle(UFastTheme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("uFast")
    }
}

struct FastingBotanicalThumbnail: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("FastingBotanicalThumbnail")
            .resizable()
            .scaledToFill()
            .opacity(colorScheme == .dark ? 1 : 0.92)
            .aspectRatio(1.35, contentMode: .fit)
            .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                    .stroke(
                        UFastTheme.border.opacity(contrast == .increased ? 1 : 0.72),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .accessibilityHidden(true)
    }
}

struct UFastThickProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { proxy in
            let progress = UFastProgressFillGeometry.clampedProgress(
                configuration.fractionCompleted
            )
            let trackRadius = proxy.size.height / 2
            let visibleFillWidth = UFastProgressFillGeometry.visibleWidth(
                progress: progress,
                trackWidth: proxy.size.width
            )

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackRadius, style: .continuous)
                    .fill(UFastTheme.raisedSurface.opacity(0.74))

                if visibleFillWidth > 0 {
                    RoundedRectangle(cornerRadius: trackRadius, style: .continuous)
                        .fill(UFastTheme.action)
                        .frame(width: proxy.size.width)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: visibleFillWidth)
                        }
                }
            }
        }
        .frame(height: 24)
    }
}

enum UFastProgressFillGeometry {
    /// Keeps a non-zero value visible without turning the start of a long fast
    /// into a large cap. The rounded track is clipped at this width, leaving a
    /// curved leading edge and a vertical trailing edge.
    static let minimumVisibleWidth: CGFloat = 2

    static func clampedProgress(_ fractionCompleted: Double?) -> Double {
        min(max(fractionCompleted ?? 0, 0), 1)
    }

    static func visibleWidth(progress: Double, trackWidth: CGFloat) -> CGFloat {
        let clampedProgress = clampedProgress(progress)

        guard clampedProgress > 0, trackWidth > 0 else {
            return 0
        }

        return min(
            trackWidth,
            max(minimumVisibleWidth, trackWidth * clampedProgress)
        )
    }
}

struct FastingBotanicalArtwork: View {
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

#Preview("Foundation · Light") {
    UFastFoundationPreview()
        .preferredColorScheme(.light)
}

#Preview("Foundation · Dark") {
    UFastFoundationPreview()
        .preferredColorScheme(.dark)
}

#Preview("Foundation · Accessibility") {
    UFastFoundationPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}

private struct UFastFoundationPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                UFastBrandMark()
                UFastSectionHeading("A calm place to record", eyebrow: "Design foundation")
                FastingBotanicalThumbnail()
                    .frame(width: 120)
                Text("Cards group related information without becoming a default form.")
                    .foregroundStyle(UFastTheme.primary)
                    .uFastCard(accent: UFastTheme.sage)
                UFastIllustratedInformationCard(
                    title: "Nothing recorded yet",
                    eyebrow: "Information",
                    message: "A short explanation appears here."
                ) {
                    FastingBotanicalArtwork()
                }
                Button("Primary action") {}
                    .buttonStyle(UFastPrimaryButtonStyle())
                Button("Secondary action") {}
                    .buttonStyle(UFastSecondaryButtonStyle())
            }
            .padding()
        }
        .background(UFastTheme.canvas)
    }
}
