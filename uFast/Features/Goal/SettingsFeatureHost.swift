import SwiftData
import SwiftUI

struct SettingsFeatureHost: View {
    @Query private var settingsRecords: [AppSettingsRecord]

    var body: some View {
        SettingsView(
            snapshot: SettingsFeatureSnapshot(
                settings: settingsRecords.map(AppSettingsSnapshot.init)
            )
        )
    }
}
