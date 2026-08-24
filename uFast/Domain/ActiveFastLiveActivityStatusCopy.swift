enum ActiveFastLiveActivityStatus: Equatable, Sendable {
    case unavailable(LiveActivityAvailability)
    case requestFailed
    case hideFailed

    static func status(for result: ActiveFastLiveActivityResult) -> Self? {
        switch result {
        case let .unavailable(availability):
            switch availability {
            case .unsupported, .disabled: .unavailable(availability)
            case .enabled: nil
            }
        case .requestFailed: .requestFailed
        case .hideFailed: .hideFailed
        case .shown, .alreadyShown, .hidden, .updated, .reconciled,
             .noActiveFast, .coalesced: nil
        }
    }
}
