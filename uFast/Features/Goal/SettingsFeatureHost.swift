import SwiftData
import SwiftUI

// swiftlint:disable trailing_comma

struct SettingsFeatureHost: View {
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(sort: [
        SortDescriptor(\HydrationFavouriteRecord.createdAt),
        SortDescriptor(\HydrationFavouriteRecord.creationOrder),
        SortDescriptor(\HydrationFavouriteRecord.id),
    ])
    private var hydrationFavourites: [HydrationFavouriteRecord]

    var body: some View {
        SettingsView(
            snapshot: SettingsFeatureSnapshot(
                settings: settingsRecords.map(AppSettingsSnapshot.init),
                hydrationFavourites: hydrationFavourites.map(\.snapshot)
            )
        )
    }
}
