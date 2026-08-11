import Foundation

struct LockScreenWidgetActiveContent: Equatable, Sendable {
    let startDate: Date
    let targetDate: Date
    let elapsedText: String
    let progress: Double
    let progressPercentage: Int
    let accessibilitySummary: String
}

enum LockScreenWidgetContent: Equatable, Sendable {
    case active(LockScreenWidgetActiveContent)
    case unavailable(reason: LockScreenUnavailableReason)

    static func make(
        projectionResult: Result<ActiveFastWidgetProjection?, Error>,
        now: Date
    ) -> Self {
        switch LockScreenFastPresentation.make(
            projectionResult: projectionResult,
            now: now,
            privacyState: .protected
        ) {
        case let .active(presentation):
            .active(
                LockScreenWidgetActiveContent(
                    startDate: presentation.startDate,
                    targetDate: presentation.targetDate,
                    elapsedText: presentation.elapsedText,
                    progress: presentation.progress,
                    progressPercentage: presentation.progressPercentage,
                    accessibilitySummary: presentation.accessibilitySummary
                )
            )
        case let .unavailable(reason):
            .unavailable(reason: reason)
        }
    }
}
