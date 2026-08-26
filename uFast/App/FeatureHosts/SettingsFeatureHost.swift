import SwiftData
import SwiftUI

// swiftlint:disable trailing_comma

struct SettingsFeatureHost: View {
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(sort: [
        SortDescriptor(\HydrationFavouriteRecord.creationOrder),
        SortDescriptor(\HydrationFavouriteRecord.createdAt),
        SortDescriptor(\HydrationFavouriteRecord.id),
    ])
    private var hydrationFavourites: [HydrationFavouriteRecord]
    @Query(sort: [
        SortDescriptor(\FoodFavouriteRecord.creationOrder),
        SortDescriptor(\FoodFavouriteRecord.createdAt),
        SortDescriptor(\FoodFavouriteRecord.id),
    ])
    private var foodFavourites: [FoodFavouriteRecord]

    var body: some View {
        SettingsView(
            snapshot: SettingsFeatureSnapshot(
                settings: settingsRecords.map(AppSettingsSnapshot.init),
                hydrationFavourites: hydrationFavourites.map(\.snapshot),
                foodFavourites: foodFavourites.map(\.snapshot)
            )
        )
    }
}
