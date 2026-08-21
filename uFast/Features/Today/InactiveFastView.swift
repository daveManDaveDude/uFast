import SwiftUI
import UFastCore

// swiftlint:disable trailing_comma

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
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(),
        clock: InactiveFastPreviewData.clock
    )
}

#Preview("Today · Mixed timeline") {
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(foodCount: 2, drinkCount: 2),
        clock: InactiveFastPreviewData.clock
    )
}

#Preview("Today · Active fast and timeline") {
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(
            foodCount: 2,
            drinkCount: 2,
            hasActiveFast: true
        ),
        clock: InactiveFastPreviewData.clock
    )
}

#Preview("Today · Long content") {
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(foodCount: 7, drinkCount: 6),
        clock: InactiveFastPreviewData.clock
    )
}

#Preview("Today · Persistence error") {
    TodayGoalView(
        clock: FixedAppClock(now: PreviewFixtures.todayTimelineNow),
        previewTimelineError: "Your timeline couldn’t be loaded. Please try again."
    )
}

#Preview("Today · Dark") {
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(foodCount: 2, drinkCount: 2),
        clock: InactiveFastPreviewData.clock
    )
    .preferredColorScheme(.dark)
}

#Preview("Today · Accessibility size") {
    TodayGoalView(
        snapshot: InactiveFastPreviewData.snapshot(foodCount: 2, drinkCount: 2),
        clock: InactiveFastPreviewData.clock
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

private enum InactiveFastPreviewData {
    static let clock = FixedAppClock(now: Date(timeIntervalSince1970: 1_800_000_000))

    static func snapshot(
        foodCount: Int = 0,
        drinkCount: Int = 0,
        hasActiveFast: Bool = false
    ) -> TodayFeatureSnapshot {
        let foods = [
            "Porridge and berries",
            "Vegetable soup and bread",
            "Apple and peanut butter",
            "Rice, tofu and greens",
            "Yoghurt with seeds",
            "Tomato pasta",
            "Banana",
        ]
        let drinks = [
            PreviewDrink(type: .water, name: nil, volume: 500, isCaloric: false),
            PreviewDrink(type: .tea, name: nil, volume: 300, isCaloric: false),
            PreviewDrink(type: .custom, name: "Coconut water", volume: 330, isCaloric: true),
            PreviewDrink(type: .coffee, name: nil, volume: 300, isCaloric: false),
        ]
        let now = clock.now
        return TodayFeatureSnapshot(
            settings: [AppSettingsSnapshot()],
            activeFasts: hasActiveFast
                ? [
                    ActiveFastSnapshot(
                        id: UUID(),
                        startDate: now.addingTimeInterval(-4 * 60 * 60),
                        endDate: nil
                    ),
                ]
                : [],
            foodEntries: (0 ..< foodCount).map { index in
                let occurredAt = now.addingTimeInterval(TimeInterval(-index * 37 * 60))
                return FoodEntrySnapshot(
                    id: UUID(),
                    foodDescription: foods[index % foods.count],
                    occurredAt: occurredAt,
                    nutrition: FoodNutrition(energyKilocalories: Double(240 + index * 35)),
                    isCaloric: true
                )
            },
            hydrationEntries: (0 ..< drinkCount).map { index in
                let drink = drinks[index % drinks.count]
                return HydrationEntrySnapshot(
                    id: UUID(),
                    drinkType: drink.type,
                    customName: drink.name,
                    displayName: drink.name ?? drink.type.displayName,
                    volumeMillilitres: drink.volume,
                    occurredAt: now.addingTimeInterval(TimeInterval(-(index * 41 + 12) * 60)),
                    isCaloric: drink.isCaloric
                )
            }
        )
    }

    private struct PreviewDrink {
        let type: HydrationDrinkType
        let name: String?
        let volume: Int
        let isCaloric: Bool
    }
}
