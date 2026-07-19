import SwiftUI

struct ScreenLayout<Content: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("screen-title.\(identifier)")

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
