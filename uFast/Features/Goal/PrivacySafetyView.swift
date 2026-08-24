import SwiftUI

struct PrivacySafetyView: View {
    @Environment(\.appTextResolver) private var textResolver
    private let privacyPolicyURL = URL(
        string: "https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md"
    )
    private let supportURL = URL(string: "https://github.com/daveManDaveDude/uFast/issues")

    var body: some View {
        ScreenLayout(title: textResolver(.privacyTitle), identifier: "privacy-safety") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    privacySection(
                        title: textResolver(.privacySection(.stored)),
                        text: textResolver(.privacyBody(.stored))
                    )

                    privacySection(
                        title: textResolver(.privacySection(.location)),
                        text: textResolver(.privacyBody(.location))
                    )

                    privacySection(
                        title: textResolver(.privacySection(.collection)),
                        text: textResolver(.privacyBody(.collection))
                    )

                    privacySection(
                        title: textResolver(.privacySection(.liveActivities)),
                        text: textResolver(.privacyBody(.liveActivities))
                    )

                    privacySection(
                        title: textResolver(.privacySection(.deletion)),
                        text: textResolver(.privacyBody(.deletion))
                    )

                    privacySection(
                        title: textResolver(.privacySection(.safety)),
                        text: textResolver(.privacyBody(.safety))
                    )

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading(textResolver(.privacyMoreInformation))
                        if let privacyPolicyURL {
                            Link(destination: privacyPolicyURL) {
                                Label(textResolver(.privacyReadPolicy), systemImage: "safari")
                            }
                            .buttonStyle(UFastActionRowButtonStyle())
                            .accessibilityIdentifier("privacy.public-policy")
                        }
                        if let supportURL {
                            Link(destination: supportURL) {
                                Label(textResolver(.privacyContactSupport), systemImage: "questionmark.circle")
                            }
                            .buttonStyle(UFastActionRowButtonStyle())
                            .accessibilityIdentifier("privacy.contact-support")
                        }
                        Text(textResolver(.privacySupportNote))
                            .font(.footnote)
                            .foregroundStyle(UFastTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .uFastCard(accent: UFastTheme.sky)
                }
                .padding(UFastTheme.Spacing.standard)
            }
        }
    }

    private func privacySection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
            UFastSectionHeading(title)
            Text(text)
                .font(.body)
                .foregroundStyle(UFastTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .uFastCard()
    }
}

#Preview("Privacy and safety") {
    NavigationStack {
        PrivacySafetyView()
    }
}
