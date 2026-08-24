// swiftlint:disable file_length trailing_comma

/// The catalog-backed text consumed by each system-surface presentation path.
///
/// This stays in the shared target because the app test bundle cannot link the
/// widget extension. WidgetKit and ActivityKit views use these values directly;
/// it is not a preview-only representation.
enum SystemSurfaceWidgetLayout: CaseIterable, Sendable {
    case accessory
    case small
    case medium
    case large
}

enum SystemSurfaceActivityLayout: CaseIterable, Sendable {
    case compactLeading
    case compactTrailing
    case minimal
    case expanded
}

struct SystemSurfaceWidgetRenderContent: Equatable, Sendable {
    let visibleText: [String]
}

struct SystemSurfaceActivityRenderContent: Equatable, Sendable {
    let visibleText: [String]
    let elapsedPrefix: String
    let goalOnlyDetail: String
    let detail: String
    let goalReachedSuffix: String
    let opensSuffix: String
}

enum SystemSurfacePresentationContent {
    static func accessoryWidget(
        active: LockScreenWidgetActiveContent,
        resolver: SystemSurfaceTextResolver
    ) -> SystemSurfaceWidgetRenderContent {
        .init(
            visibleText: [
                resolver(.brand),
                resolver(.percentage(value: active.progressPercentage)),
                resolver(.elapsed),
            ]
        )
    }

    static func widget(
        layout: SystemSurfaceWidgetLayout,
        presentation: LockScreenActivePresentation,
        resolver: SystemSurfaceTextResolver
    ) -> SystemSurfaceWidgetRenderContent {
        let target = presentation.targetText.map { resolver(.target(value: $0)) }
        let percentage = resolver(.percentage(value: presentation.progressPercentage))

        switch layout {
        case .accessory:
            return .init(visibleText: [resolver(.brand), percentage, resolver(.elapsed)])
        case .small:
            return .init(
                visibleText: [resolver(.brand), resolver(.elapsed), percentage]
                    + detail(target, resolver: resolver)
            )
        case .medium:
            return .init(
                visibleText: [resolver(.brand), resolver(.inProgress), resolver(.elapsed), percentage]
                    + detail(target, resolver: resolver)
            )
        case .large:
            return .init(
                visibleText: [
                    resolver(.brand),
                    resolver(.inProgress),
                    resolver(.elapsedTime),
                    presentation.progressAccessibilityValue,
                ] + detail(target, resolver: resolver)
            )
        }
    }

    static func activity(
        layout: SystemSurfaceActivityLayout,
        goal: String?,
        target: String?,
        hasReachedGoal: Bool,
        resolver: SystemSurfaceTextResolver
    ) -> SystemSurfaceActivityRenderContent {
        let elapsedPrefix = resolver(.activityElapsedPrefix)
        let goalOnlyDetail = goal.map { resolver(.activityGoalOnlyDetail(goal: $0)) } ?? ""
        let detail = (
            goal.flatMap { goal in
                target.map { resolver(.activityDetail(goal: goal, target: $0)) }
            }
        ) ?? goalOnlyDetail
        let goalReachedSuffix = hasReachedGoal ? resolver(.activityGoalReachedSuffix) : ""
        let opensSuffix = resolver(.opensSuffix)
        let visibleText = layout == .compactLeading ? [] : [resolver(.brand), elapsedPrefix, detail, opensSuffix]

        return .init(
            visibleText: visibleText,
            elapsedPrefix: elapsedPrefix,
            goalOnlyDetail: goalOnlyDetail,
            detail: detail,
            goalReachedSuffix: goalReachedSuffix,
            opensSuffix: opensSuffix
        )
    }

    private static func detail(
        _ target: String?,
        resolver: SystemSurfaceTextResolver
    ) -> [String] {
        [target ?? resolver(.goalReachedShort)]
    }
}
