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
    @State private var stage: Stage = .confirmation
    @State private var selectedInstant: Date

    let presentation: DirectHistoricalEntryPresentation
    let clock: any AppClock
    let activeFastStart: Date?
    let favourites: [HydrationFavourite]
    let onSaveFood: (FoodEntryDraft, Bool) throws -> Void
    let onSaveHydration: (HydrationEntryDraft, Bool) throws -> Void
    let onClose: () -> Void

    init(
        presentation: DirectHistoricalEntryPresentation,
        clock: any AppClock,
        activeFastStart: Date?,
        favourites: [HydrationFavourite],
        onSaveFood: @escaping (FoodEntryDraft, Bool) throws -> Void,
        onSaveHydration: @escaping (HydrationEntryDraft, Bool) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.clock = clock
        self.activeFastStart = activeFastStart
        self.favourites = favourites
        self.onSaveFood = onSaveFood
        self.onSaveHydration = onSaveHydration
        self.onClose = onClose
        _selectedInstant = State(initialValue: presentation.initialInstant)
    }

    var body: some View {
        switch stage {
        case .confirmation:
            confirmation
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
        case .drinkChoice:
            AddDrinkSheet(
                favourites: favourites,
                onAdd: { favourite in
                    stage = .hydration(
                        HydrationEntryDraft(
                            type: favourite.type,
                            customName: nil,
                            volumeMillilitres: favourite.volumeMillilitres,
                            occurredAt: selectedInstant,
                            isCaloric: false
                        )
                    )
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
                Section("Selected date and time") {
                    Text(summary)
                        .font(.headline)
                        .foregroundStyle(UFastTheme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("history.add.summary")
                    DatePicker(
                        "Date",
                        selection: $selectedInstant,
                        in: pickerRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("history.add.date")
                    DatePicker(
                        "Time",
                        selection: $selectedInstant,
                        in: pickerRange,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("history.add.time")
                }

                Section {
                    Button {
                        stage = .food
                    } label: {
                        Label("Food", systemImage: "fork.knife")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("history.add.food")

                    Button {
                        stage = .drinkChoice
                    } label: {
                        Label("Drink", systemImage: "drop")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("history.add.drink")
                } footer: {
                    Text("Nothing is recorded until you save the full editor.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle("Add to history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
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
    case food
    case drinkChoice
    case hydration(HydrationEntryDraft)
}
