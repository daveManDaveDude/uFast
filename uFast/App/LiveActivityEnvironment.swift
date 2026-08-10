import SwiftUI

extension EnvironmentValues {
    @Entry var liveActivityCoordinator: ActiveFastLiveActivityCoordinator?
    @Entry var applicationCommands: ApplicationCommands?
    @Entry var suppressAutomaticLiveActivityOffer = false
}
