import SwiftUI

struct GroupMarkerAccessibilityModifier: ViewModifier {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.appTextResolver) private var textResolver

    let group: TemporalEventGroup?
    let member: TemporalEventGroupingInput?
    let prefix: String
    let usesVisualEventIdentifier: Bool

    func body(content: Content) -> some View {
        guard let group else {
            guard let member else { return AnyView(content) }
            let identifier = "\(prefix)."
                + (usesVisualEventIdentifier ? "visual-event" : "event")
                + ".\(member.reference.id.uuidString)"
            return AnyView(
                content
                    .accessibilityLabel(member.accessibilityLabel)
                    .accessibilityIdentifier(identifier)
            )
        }
        let identifier = "\(prefix).event-group.\(group.presentationCategory.rawValue)."
            + String(Int(group.bucket.start.timeIntervalSince1970))
        return AnyView(
            content
                .accessibilityLabel(accessibilityLabel(for: group))
                .accessibilityValue(String(group.count))
                .accessibilityHint(textResolver(.historyCopy(.groupHint)))
                .accessibilityIdentifier(identifier)
        )
    }

    private func accessibilityLabel(for group: TemporalEventGroup) -> String {
        textResolver(
            .historyGroupAccessibility(
                count: group.count,
                family: group.family == .food ? .food : .drink,
                start: timeText(group.bucket.start),
                end: timeText(group.bucket.end),
                classification: textResolver(
                    .historyGroupClassification(group.presentationCategory)
                ).lowercased()
            )
        )
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

struct HistoryEventGroupDisclosure: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    @Environment(\.appTextResolver) private var textResolver
    @State private var displayedGroup: TemporalEventGroup
    @State private var foodEditor: GroupFoodEditorPresentation?
    @State private var hydrationEditor: GroupHydrationEditorPresentation?

    let group: TemporalEventGroup
    let canAddEvent: Bool
    let onAddEvent: () -> Void
    let onDismiss: () -> Void
    let clock: any AppClock
    let activeFastStart: Date?
    let resolveFood: (UUID) -> FoodEntrySnapshot?
    let resolveHydration: (UUID) -> HydrationEntrySnapshot?
    let saveFood: (UUID, FoodEntryDraft, Bool) throws -> Void
    let deleteFood: (UUID, Bool) throws -> Void
    let saveHydration: (UUID, HydrationEntryDraft, Bool) throws -> Void
    let deleteHydration: (UUID, Bool) throws -> Void
    let onMutationSucceeded: (TemporalEventGroup, HistoryEventGroupMutation) -> TemporalEventGroup?

    init(
        group: TemporalEventGroup,
        canAddEvent: Bool,
        onAddEvent: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        clock: any AppClock,
        activeFastStart: Date?,
        resolveFood: @escaping (UUID) -> FoodEntrySnapshot?,
        resolveHydration: @escaping (UUID) -> HydrationEntrySnapshot?,
        saveFood: @escaping (UUID, FoodEntryDraft, Bool) throws -> Void,
        deleteFood: @escaping (UUID, Bool) throws -> Void,
        saveHydration: @escaping (UUID, HydrationEntryDraft, Bool) throws -> Void,
        deleteHydration: @escaping (UUID, Bool) throws -> Void,
        onMutationSucceeded: @escaping (TemporalEventGroup, HistoryEventGroupMutation) -> TemporalEventGroup?
    ) {
        self.group = group
        self.canAddEvent = canAddEvent
        self.onAddEvent = onAddEvent
        self.onDismiss = onDismiss
        self.clock = clock
        self.activeFastStart = activeFastStart
        self.resolveFood = resolveFood
        self.resolveHydration = resolveHydration
        self.saveFood = saveFood
        self.deleteFood = deleteFood
        self.saveHydration = saveHydration
        self.deleteHydration = deleteHydration
        self.onMutationSucceeded = onMutationSucceeded
        _displayedGroup = State(initialValue: group)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                    Text(textResolver(.historyCopy(.groupExactTimes)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(UFastTheme.secondaryText)
                    ForEach(displayedGroup.members, id: \.reference) { member in
                        memberRow(member)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bucketText)
                            .font(.subheadline)
                        Text(textResolver(.historyGroupClassification(displayedGroup.presentationCategory)))
                            .font(.subheadline)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .uFastCard()
                }
                .padding(UFastTheme.Spacing.standard)
                .padding(.bottom, 96)
            }
            .navigationTitle(
                textResolver(
                    .historyGroupTitle(
                        count: displayedGroup.count,
                        family: displayedGroup.family == .food ? .food : .drink
                    )
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.historyCopy(.groupCancel)), action: onDismiss)
                        .accessibilityIdentifier("history.event-group.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAddEvent()
                } label: {
                    Label(textResolver(.historyCopy(.groupAddEvent)), systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(UFastSecondaryButtonStyle())
                .disabled(!canAddEvent)
                .accessibilityHint(
                    canAddEvent
                        ? textResolver(.historyCopy(.groupAddHint))
                        : textResolver(.historyCopy(.groupNoEligibleTime))
                )
                .padding(.horizontal, UFastTheme.Spacing.standard)
                .padding(.vertical, 8)
                .accessibilityIdentifier("history.event-group.add")
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("history.event-group.disclosure")
        .sheet(item: $foodEditor) { presentation in
            FoodEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: activeFastStart,
                initialOccurredAt: presentation.record.occurredAt,
                allowedRange: calendar.dateInterval(of: .day, for: presentation.record.occurredAt).map {
                    $0.start ..< $0.end
                },
                onSave: { draft, endingActiveFast in
                    try saveFood(presentation.record.id, draft, endingActiveFast)
                    foodEditor = nil
                    if let refreshed = onMutationSucceeded(
                        displayedGroup,
                        .saved(.init(family: .food, id: presentation.record.id))
                    ) {
                        displayedGroup = refreshed
                    }
                },
                onDelete: { confirmingInferredImpact in
                    try deleteFood(presentation.record.id, confirmingInferredImpact)
                    foodEditor = nil
                    if let refreshed = onMutationSucceeded(
                        displayedGroup,
                        .deleted(.init(family: .food, id: presentation.record.id))
                    ) {
                        displayedGroup = refreshed
                    }
                },
                onCancel: { foodEditor = nil }
            )
        }
        .sheet(item: $hydrationEditor) { presentation in
            HydrationEntryEditor(
                snapshot: presentation.record,
                clock: clock,
                activeFastStart: activeFastStart,
                initialDraft: nil,
                allowedRange: calendar.dateInterval(of: .day, for: presentation.record.occurredAt).map {
                    $0.start ..< $0.end
                },
                onSave: { draft, endingActiveFast in
                    try saveHydration(presentation.record.id, draft, endingActiveFast)
                    hydrationEditor = nil
                    if let refreshed = onMutationSucceeded(
                        displayedGroup,
                        .saved(.init(family: .hydration, id: presentation.record.id))
                    ) {
                        displayedGroup = refreshed
                    }
                },
                onDelete: { confirmingInferredImpact in
                    try deleteHydration(presentation.record.id, confirmingInferredImpact)
                    hydrationEditor = nil
                    if let refreshed = onMutationSucceeded(
                        displayedGroup,
                        .deleted(.init(family: .hydration, id: presentation.record.id))
                    ) {
                        displayedGroup = refreshed
                    }
                },
                onCancel: { hydrationEditor = nil }
            )
        }
    }

    private func memberRow(_ member: TemporalEventGroupingInput) -> some View {
        Button {
            edit(member)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(timeText(member.occurredAt))
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Text(member.title)
                        .font(.headline)
                }
                Text(member.detail)
                    .font(.subheadline)
                    .foregroundStyle(UFastTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .uFastCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            textResolver(
                .historyMemberAccessibility(
                    time: timeText(member.occurredAt),
                    title: member.title,
                    detail: member.detail
                )
            )
        )
        .accessibilityHint(
            member.family == .food
                ? textResolver(.historyCopy(.groupMemberFoodHint))
                : textResolver(.historyCopy(.groupMemberDrinkHint))
        )
        .accessibilityIdentifier("history.event-group.member.\(member.reference.id.uuidString)")
    }

    private func edit(_ member: TemporalEventGroupingInput) {
        switch member.reference.family {
        case .food:
            if let record = resolveFood(member.reference.id) {
                foodEditor = GroupFoodEditorPresentation(record: record)
            }
        case .hydration:
            if let record = resolveHydration(member.reference.id) {
                hydrationEditor = GroupHydrationEditorPresentation(record: record)
            }
        }
    }

    private var bucketText: String {
        "\(timeText(displayedGroup.bucket.start))"
            + textResolver(.historyCopy(.separatorRange))
            + "\(timeText(displayedGroup.bucket.end))"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

enum HistoryEventGroupMutation {
    case saved(TemporalEventReference)
    case deleted(TemporalEventReference)
}

private struct GroupFoodEditorPresentation: Identifiable {
    let record: FoodEntrySnapshot
    var id: UUID {
        record.id
    }
}

private struct GroupHydrationEditorPresentation: Identifiable {
    let record: HydrationEntrySnapshot
    var id: UUID {
        record.id
    }
}
