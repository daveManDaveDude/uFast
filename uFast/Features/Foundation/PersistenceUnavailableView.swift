import SwiftUI

struct PersistenceUnavailableView: View {
    @Environment(\.appTextResolver) private var textResolver

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text(textResolver(.persistenceUnavailableTitle))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("persistence.unavailable.title")
            Text(textResolver(.persistenceUnavailableMessage))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("persistence.unavailable.message")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
