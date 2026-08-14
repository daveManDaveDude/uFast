import SwiftData
import SwiftUI

// swiftlint:disable trailing_comma

struct TodayFeatureHost: View {
    @Query private var settingsRecords: [AppSettingsRecord]
    @Query(filter: #Predicate<FastRecord> { $0.endDate == nil }) private var activeFasts: [FastRecord]
    @Query(sort: [SortDescriptor(\FoodEntryRecord.occurredAt, order: .reverse)])
    private var foodEntries: [FoodEntryRecord]
    @Query(sort: [SortDescriptor(\HydrationEntryRecord.occurredAt, order: .reverse)])
    private var hydrationEntries: [HydrationEntryRecord]
    @Query(sort: [
        SortDescriptor(\HydrationFavouriteRecord.createdAt),
        SortDescriptor(\HydrationFavouriteRecord.creationOrder),
        SortDescriptor(\HydrationFavouriteRecord.id),
    ])
    private var hydrationFavourites: [HydrationFavouriteRecord]

    let clock: any AppClock

    var body: some View {
        TodayGoalView(
            snapshot: TodayFeatureSnapshot(
                settings: settingsRecords.map(AppSettingsSnapshot.init),
                activeFasts: activeFasts.map(ActiveFastSnapshot.init),
                foodEntries: foodEntries.map(FoodEntrySnapshot.init),
                hydrationEntries: hydrationEntries.map(HydrationEntrySnapshot.init),
                hydrationFavourites: hydrationFavourites.map(\.snapshot)
            ),
            clock: clock
        )
    }
}
