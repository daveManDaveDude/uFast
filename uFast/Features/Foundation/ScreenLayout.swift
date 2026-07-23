import SwiftUI

struct ScreenLayout<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            UFastTheme.canvas
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.uFastDisplay())
                        .foregroundStyle(UFastTheme.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("screen-title.\(identifier)")
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                        UFastBrandMark(compact: true)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UFastTheme.Spacing.standard)
                .padding(.bottom, UFastTheme.Spacing.compact)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(UFastTheme.action)
    }
}
