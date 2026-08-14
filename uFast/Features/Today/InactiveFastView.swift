import SwiftUI

struct HydrationEditorPresentation: Identifiable {
    let id = UUID()
    let record: HydrationEntrySnapshot?
}

struct InactiveFastView: View {
    let goal: FastingGoal
    let target: String
    let fastRecorded: Bool
    let startError: String?
    let onStart: () -> Void
    let onStartPast: () -> Void
    let additionalContent: AnyView

    var body: some View {
        ScrollView {
            VStack(spacing: UFastTheme.Spacing.generous) {
                HStack(spacing: UFastTheme.Spacing.standard) {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
                        Text("Ready when you are")
                            .font(.uFastDisplay(.title))
                            .foregroundStyle(UFastTheme.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("No fast is running.")
                            .foregroundStyle(UFastTheme.secondaryText)
                            .accessibilityIdentifier("fast.inactive-state")
                    }
                    Spacer(minLength: 0)
                    FastingBotanicalThumbnail()
                        .frame(width: 104)
                }

                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    UFastSectionHeading("Your next target", eyebrow: "\(goal.hours)-hour goal")
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("If started now")
                                .font(.caption)
                                .foregroundStyle(UFastTheme.secondaryText)
                            Text(target)
                                .font(.uFastDisplay(.title2))
                                .foregroundStyle(UFastTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Target if started now")
                                .accessibilityValue(target)
                                .accessibilityIdentifier("fast.preview-target")
                        }
                        Spacer()
                        Image(systemName: "sun.horizon.fill")
                            .font(.title)
                            .foregroundStyle(UFastTheme.apricot)
                            .accessibilityHidden(true)
                    }
                    Text("Your fasting goal is \(goal.hours) hours.")
                        .font(.subheadline)
                        .foregroundStyle(UFastTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .uFastCard(accent: UFastTheme.sky)

                if fastRecorded {
                    Label("Fast recorded.", systemImage: "checkmark.circle")
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .uFastCard(accent: UFastTheme.sage)
                        .accessibilityIdentifier("fast.recorded")
                }

                if let startError {
                    Label(startError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fast.start-error")
                }

                VStack(spacing: UFastTheme.Spacing.standard) {
                    Button(startError == nil ? "Start fast" : "Try again", action: onStart)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .accessibilityIdentifier("fast.start")

                    Button("Start at a past time", action: onStartPast)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("fast.start-past")
                }

                additionalContent
            }
            .padding(UFastTheme.Spacing.standard)
        }
        .accessibilityIdentifier("today.content")
    }
}

struct StartTimeEditorPresentation: Identifiable {
    let id = UUID()
    let mode: StartTimeEditor.Mode
    let initialStartDate: Date
}

struct EndTimeEditorPresentation: Identifiable {
    let id = UUID()
    let startDate: Date
    let initialEndDate: Date
}

struct FoodEditorPresentation: Identifiable {
    let id = UUID()
    let record: FoodEntrySnapshot?
}

#Preview("Today · Empty") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.modelContainer)
}

#Preview("Today · Mixed timeline") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
}

#Preview("Today · Active fast and timeline") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.activeFastTodayTimelineModelContainer)
}

#Preview("Today · Long content") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.longTodayTimelineModelContainer)
}

#Preview("Today · Persistence error") {
    TodayGoalView(
        clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow),
        previewTimelineError: "Your timeline couldn’t be loaded. Please try again."
    )
}

#Preview("Today · Dark") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Today · Accessibility size") {
    TodayFeatureHost(clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow))
        .modelContainer(PreviewFixtures.todayTimelineModelContainer)
        .environment(\.dynamicTypeSize, .accessibility3)
}
