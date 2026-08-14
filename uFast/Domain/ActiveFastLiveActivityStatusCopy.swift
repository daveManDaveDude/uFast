enum ActiveFastLiveActivityStatusCopy {
    static let unsupported = "Live Activities aren’t available on this iPhone."
    static let disabled = "Live Activities are turned off for uFast in iPhone Settings."
    static let requestFailure = "The Live Activity couldn’t be started. Please try again."
    static let hideFailure =
        "The Live Activity couldn’t be hidden. You can remove it from the Lock Screen."
    static let disclosure =
        "Shows uFast, elapsed time, goal progress and target on the Lock Screen and Dynamic Island "
            + "for up to 8 hours. You can hide it at any time. Your fast continues if the activity ends."

    static func message(for result: ActiveFastLiveActivityResult) -> String? {
        switch result {
        case let .unavailable(availability):
            switch availability {
            case .unsupported: unsupported
            case .disabled: disabled
            case .enabled: nil
            }
        case .requestFailed: requestFailure
        case .hideFailed: hideFailure
        case .shown, .alreadyShown, .hidden, .updated, .reconciled,
             .noActiveFast, .coalesced: nil
        }
    }
}
