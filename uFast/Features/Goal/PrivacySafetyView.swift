import SwiftUI

struct PrivacySafetyView: View {
    private let privacyPolicyURL = URL(
        string: "https://github.com/daveManDaveDude/uFast/blob/main/PRIVACY.md"
    )
    private let supportURL = URL(string: "https://github.com/daveManDaveDude/uFast/issues")

    var body: some View {
        ScreenLayout(title: "Privacy and safety", identifier: "privacy-safety") {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    privacySection(
                        title: "What uFast stores",
                        text: "uFast stores user-entered fasting intervals, food entries, "
                            + "hydration entries, fasting and drink settings, and legacy "
                            + "history required by the current local schema."
                    )

                    privacySection(
                        title: "Where it stays",
                        text: "These records stay locally in uFast’s protected app container "
                            + "on this iPhone. uFast has no account, cloud sync, backup, "
                            + "restore or password recovery."
                    )

                    privacySection(
                        title: "No collection",
                        text: "In this release uFast sends fasting, food, drink or settings "
                            + "records to neither the developer nor a third party. uFast "
                            + "has no analytics, advertising or tracking."
                    )

                    privacySection(
                        title: "Live Activities",
                        text: "Live Activities are optional. If you enable automatic "
                            + "Live Activities, the preference and minimal presentation "
                            + "lifecycle metadata stay on this iPhone. The elapsed time, "
                            + "goal progress and target you choose to show may be visible "
                            + "on the Lock Screen and Dynamic Island. No Live Activity "
                            + "content is sent to uFast, a server or a third party. Turn "
                            + "the setting off or choose Hide for this fast at any time."
                    )

                    privacySection(
                        title: "Deletion",
                        text: "Delete all data in Settings to remove every uFast record "
                            + "from this iPhone after two confirmations. Deleting the app "
                            + "may also remove its local data. Deleted data cannot be "
                            + "recovered by uFast."
                    )

                    privacySection(
                        title: "Safety",
                        text: "uFast records information you choose to enter and displays "
                            + "patterns in those records. It is not medical advice and does "
                            + "not diagnose, treat or guarantee a health outcome."
                    )

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        UFastSectionHeading("More information")
                        if let privacyPolicyURL {
                            Link(destination: privacyPolicyURL) {
                                Label("Read the public privacy policy", systemImage: "safari")
                            }
                            .buttonStyle(UFastActionRowButtonStyle())
                            .accessibilityIdentifier("privacy.public-policy")
                        }
                        if let supportURL {
                            Link(destination: supportURL) {
                                Label("Contact support", systemImage: "questionmark.circle")
                            }
                            .buttonStyle(UFastActionRowButtonStyle())
                            .accessibilityIdentifier("privacy.contact-support")
                        }
                        Text(
                            "Only information you voluntarily include in a support request "
                                + "is received through that route."
                        )
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
