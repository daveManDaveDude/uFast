import SwiftUI

struct DestinationPlaceholderView: View {
    let destination: AppDestination

    var body: some View {
        ScreenLayout(
            title: destination.title,
            identifier: destination.rawValue
        ) {
            ContentUnavailableView {
                Label(destination.title, systemImage: destination.systemImage)
            } description: {
                Text("This area is ready for the next uFast story.")
            }
        }
    }
}
