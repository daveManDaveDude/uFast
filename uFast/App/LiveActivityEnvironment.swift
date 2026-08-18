import SwiftUI

extension EnvironmentValues {
    @Entry var liveActivityCoordinator: ActiveFastLiveActivityCoordinator?
    @Entry var applicationCommands: ApplicationCommands?
    @Entry var historyPresentationInvalidation: HistoryPresentationInvalidation?
    @Entry var suppressAutomaticLiveActivityOffer = false
}
