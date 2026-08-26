import SwiftUI

struct DirectHistoricalEntryPresentation: Identifiable {
    let id = UUID()
    let initialInstant: Date
    let allowedRange: Range<Date>
}

struct DirectHistoricalEntryView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.appTextResolver) private var textResolver
    @State private var stage: Stage = .confirmation
    @State private var selectedInstant: Date

    let presentation: DirectHistoricalEntryPresentation
    let clock: any AppClock
    let activeFastStart: Date?
    let favourites: [HydrationFavourite]
    let resolveFavouriteDraft: (HydrationFavourite, Date) throws -> HydrationEntryDraft
    let foodFavourites: [FoodFavouriteSnapshot]
    let resolveFoodFavouriteDraft: (FoodFavouriteSnapshot, Date) throws -> FoodEntryDraft
    let onSaveFood: (FoodEntryDraft, Bool) throws -> Void
    let onSaveHydration: (HydrationEntryDraft, Bool) throws -> Void
    let onClose: () -> Void

    init(
        presentation: DirectHistoricalEntryPresentation,
        clock: any AppClock,
        activeFastStart: Date?,
        favourites: [HydrationFavourite],
        resolveFavouriteDraft: @escaping (HydrationFavourite, Date) throws -> HydrationEntryDraft,
        foodFavourites: [FoodFavouriteSnapshot] = [],
        resolveFoodFavouriteDraft: @escaping (
            FoodFavouriteSnapshot,
            Date
        ) throws -> FoodEntryDraft = { favourite, date in
            FoodFavouriteProjection.foodDraft(from: favourite, occurredAt: date)
        },
        onSaveFood: @escaping (FoodEntryDraft, Bool) throws -> Void,
        onSaveHydration: @escaping (HydrationEntryDraft, Bool) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.clock = clock
        self.activeFastStart = activeFastStart
        self.favourites = favourites
        self.resolveFavouriteDraft = resolveFavouriteDraft
        self.foodFavourites = foodFavourites
        self.resolveFoodFavouriteDraft = resolveFoodFavouriteDraft
        self.onSaveFood = onSaveFood
        self.onSaveHydration = onSaveHydration
        self.onClose = onClose
        _selectedInstant = State(initialValue: presentation.initialInstant)
    }

    var body: some View {
        switch stage {
        case .confirmation:
            confirmation
        case .foodChoice:
            FoodFavouritePicker(
                clock: clock,
                favourites: foodFavourites,
                onAdd: { favourite, _ in
                    stage = try .foodDraft(resolveFoodFavouriteDraft(favourite, selectedInstant))
                },
                onChooseAnother: { stage = .food },
                onCancel: onClose
            )
        case .food:
            FoodEntryEditor(
                record: nil,
                clock: clock,
                activeFastStart: activeFastStart,
                initialOccurredAt: selectedInstant,
                allowedRange: presentation.allowedRange,
                onSave: { draft, endingActiveFast in
                    try onSaveFood(draft, endingActiveFast)
                    onClose()
                },
                onDelete: nil,
                onCancel: onClose
            )
        case let .foodDraft(draft):
            FoodEntryEditor(
                record: nil,
                clock: clock,
                activeFastStart: activeFastStart,
                initialDraft: draft,
                allowedRange: presentation.allowedRange,
                onSave: { savedDraft, endingActiveFast in
                    try onSaveFood(savedDraft, endingActiveFast)
                    onClose()
                },
                onDelete: nil,
                onCancel: onClose
            )
        case .drinkChoice:
            AddDrinkSheet(
                favourites: favourites,
                onAdd: { favourite in
                    stage = try .hydration(resolveFavouriteDraft(favourite, selectedInstant))
                },
                onChooseAnother: {
                    stage = .hydration(
                        HydrationEntryDraft(
                            type: .custom,
                            customName: nil,
                            volumeMillilitres: 300,
                            occurredAt: selectedInstant,
                            isCaloric: false
                        )
                    )
                },
                onCancel: onClose
            )
        case let .hydration(draft):
            HydrationEntryEditor(
                record: nil,
                clock: clock,
                activeFastStart: activeFastStart,
                initialDraft: draft,
                allowedRange: presentation.allowedRange,
                onSave: { savedDraft, endingActiveFast in
                    try onSaveHydration(savedDraft, endingActiveFast)
                    onClose()
                },
                onDelete: nil,
                onCancel: onClose
            )
        }
    }

    private var confirmation: some View {
        NavigationStack {
            Form {
                Section(textResolver(.historySelectedDateAndTime)) {
                    Text(summary)
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("history.add.summary")
                    DatePicker(
                        textResolver(.date),
                        selection: $selectedInstant,
                        in: pickerRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.add.date")
                    DatePicker(
                        textResolver(.time),
                        selection: $selectedInstant,
                        in: pickerRange,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.add.time")
                }

                Section {
                    Button {
                        stage = .foodChoice
                    } label: {
                        Label(textResolver(.historyFood), systemImage: "fork.knife")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("history.add.food")

                    Button {
                        stage = .drinkChoice
                    } label: {
                        Label(textResolver(.historyDrink), systemImage: "drop")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("history.add.drink")
                } footer: {
                    Text(textResolver(.historyNothingRecorded))
                }
            }
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle(textResolver(.historyAddTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onClose)
                        .accessibilityIdentifier("history.add.cancel")
                }
            }
        }
    }

    private var pickerRange: ClosedRange<Date> {
        presentation.allowedRange.lowerBound
            ... presentation.allowedRange.upperBound.addingTimeInterval(-1)
    }

    private var summary: String {
        guard let window = TemporalHistoryPresentation.ribbonWindow(
            containing: selectedInstant,
            calendar: calendar
        ) else {
            return selectedInstant.formatted(date: .complete, time: .shortened)
        }
        return TemporalHistoryPresentation.selectedInstantSummary(
            selectedInstant,
            in: window,
            context: TemporalFormattingContext(
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

private enum Stage {
    case confirmation
    case foodChoice
    case food
    case foodDraft(FoodEntryDraft)
    case drinkChoice
    case hydration(HydrationEntryDraft)
}
