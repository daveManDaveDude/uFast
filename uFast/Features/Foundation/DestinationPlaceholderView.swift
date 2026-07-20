import SwiftUI

struct DestinationPlaceholderView: View {
    let destination: AppDestination

    var body: some View {
        ScreenLayout(
            title: destination.title,
            identifier: destination.rawValue
        ) {
            VStack(spacing: UFastTheme.Spacing.generous) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(UFastTheme.action)
                    .accessibilityHidden(true)
                UFastSectionHeading("Not available yet", eyebrow: destination.title)
                Text("This part of uFast will arrive in a later story.")
                    .foregroundStyle(UFastTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .uFastCard(accent: UFastTheme.sky)
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(destination.title). Not available yet. " +
                    "This part of uFast will arrive in a later story."
            )
        }
    }
}
