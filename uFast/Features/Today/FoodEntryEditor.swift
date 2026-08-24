import SwiftUI

struct FoodEntryEditor: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.appTextResolver) private var textResolver
    @FocusState private var isDescriptionFocused: Bool
    @State private var descriptionText: String
    @State private var occurredAt: Date
    @State private var nutritionInput: FoodNutritionTextInput
    @State private var showsDetails: Bool
    @State private var saveError: String?
    @State private var showsDeleteConfirmation = false
    @State private var showsFastEndConfirmation = false
    @State private var pendingFastEndDraft: FoodEntryDraft?
    @State private var confirmationContext = CaloricEventConfirmationContext(
        fallbackKind: .active
    )
    @State private var pendingDeletion = false

    let record: FoodEntrySnapshot?
    let clock: any AppClock
    let activeFastStart: Date?
    let allowedRange: Range<Date>?
    let onSave: (FoodEntryDraft, Bool) throws -> Void
    let onDelete: ((Bool) throws -> Void)?
    let onCancel: () -> Void

    init(
        snapshot record: FoodEntrySnapshot?,
        clock: any AppClock,
        activeFastStart: Date?,
        initialOccurredAt: Date? = nil,
        allowedRange: Range<Date>? = nil,
        onSave: @escaping (FoodEntryDraft, Bool) throws -> Void,
        onDelete: ((Bool) throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.record = record
        self.clock = clock
        self.activeFastStart = activeFastStart
        self.allowedRange = allowedRange
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _descriptionText = State(initialValue: record?.foodDescription ?? "")
        _occurredAt = State(initialValue: record?.occurredAt ?? initialOccurredAt ?? clock.now)
        let input = FoodNutritionTextInput(nutrition: record?.nutrition ?? FoodNutrition())
        _nutritionInput = State(initialValue: input)
        _showsDetails = State(initialValue: input.hasValues)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(textResolver(.foodDescriptionPlaceholder), text: $descriptionText, axis: .vertical)
                        .lineLimit(2 ... 5)
                        .focused($isDescriptionFocused)
                        .accessibilityIdentifier("food.description")

                    if let descriptionError {
                        validationLabel(descriptionError, identifier: "food.description.validation")
                    }
                }

                Section(textResolver(.foodTimeSection)) {
                    DatePicker(
                        textResolver(.date),
                        selection: $occurredAt,
                        in: datePickerRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("food.date")

                    DatePicker(
                        textResolver(.time),
                        selection: $occurredAt,
                        in: datePickerRange,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("food.time")
                }

                Section {
                    Text(
                        textResolver(.foodCaloricExplanation)
                    )
                    .font(.footnote)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("food.caloric.explanation")

                    if isAtActiveFastStart {
                        validationLabel(
                            textResolver(.foodActiveStartValidation),
                            identifier: "food.fast-start.validation"
                        )
                    }
                }

                Section {
                    Button(showsDetails ? textResolver(.foodDetailsHide) : textResolver(.foodDetailsAdd)) {
                        showsDetails.toggle()
                    }
                    .accessibilityIdentifier("food.details.toggle")
                }

                if showsDetails {
                    Section(textResolver(.foodOptionalDetailsSection)) {
                        nutritionField(.energy, unit: .kilocalories, identifier: "energy", text: $nutritionInput.energy)
                        nutritionField(.protein, unit: .grams, identifier: "protein", text: $nutritionInput.protein)
                        nutritionField(
                            .carbohydrate,
                            unit: .grams,
                            identifier: "carbohydrate",
                            text: $nutritionInput.carbohydrate
                        )
                        nutritionField(.fat, unit: .grams, identifier: "fat", text: $nutritionInput.fat)
                        nutritionField(.fibre, unit: .grams, identifier: "fibre", text: $nutritionInput.fibre)
                        nutritionField(.sugar, unit: .grams, identifier: "sugar", text: $nutritionInput.sugar)
                        nutritionField(.salt, unit: .grams, identifier: "salt", text: $nutritionInput.salt)

                        Text(textResolver(.foodNutritionRange))
                            .font(.footnote)
                            .foregroundStyle(UFastTheme.secondaryText)

                        if nutritionResult == nil {
                            validationLabel(
                                textResolver(.foodValidation(.invalidNutrition)),
                                identifier: "food.nutrition.validation"
                            )
                        }
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .accessibilityIdentifier("food.save-error")
                    }
                }

                if onDelete != nil {
                    Section {
                        Button(textResolver(.foodDeleteEvent), role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("food.delete")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle(textResolver(.foodTitle(isEditing: record != nil)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("food.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.foodSaveTitle(isEditing: record != nil))) {
                        save()
                    }
                    .disabled(validDraft == nil)
                    .accessibilityIdentifier("food.save")
                }
            }
            .onAppear {
                if record == nil {
                    isDescriptionFocused = true
                }
            }
            .alert(textResolver(.foodDeleteConfirmationTitle), isPresented: $showsDeleteConfirmation) {
                Button(textResolver(.cancel), role: .cancel) {}
                    .accessibilityIdentifier("food.delete.cancel")
                Button(textResolver(.delete), role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("food.delete.confirm")
            } message: {
                Text(textResolver(.localRecordRemoval))
            }
            .alert(confirmationTitle, isPresented: $showsFastEndConfirmation) {
                Button(textResolver(.cancel), role: .cancel) {
                    pendingFastEndDraft = nil
                    pendingDeletion = false
                }
                .accessibilityIdentifier("food.confirmation.cancel")
                Button(confirmationActionTitle) {
                    saveEndingFast()
                }
                .accessibilityIdentifier("food.confirmation.primary")
            } message: {
                Text(confirmationMessage)
                    .accessibilityIdentifier("food.confirmation.consequence")
            }
        }
    }

    private var descriptionError: String? {
        let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return textResolver(.foodValidation(.emptyDescription))
        }
        if trimmed.count > FoodEntryValidator.descriptionLimit {
            return textResolver(.foodValidation(.descriptionTooLong))
        }
        return nil
    }

    private var nutritionResult: FoodNutrition? {
        nutritionInput.nutrition(locale: locale)
    }

    private var validDraft: FoodEntryDraft? {
        guard let nutrition = nutritionResult, !isAtActiveFastStart else {
            return nil
        }
        return try? FoodEntryValidator.validated(
            description: descriptionText,
            occurredAt: occurredAt,
            nutrition: nutrition,
            now: clock.now,
            calendar: calendar,
            allowedRange: allowedRange
        ).get()
    }

    private var datePickerRange: ClosedRange<Date> {
        if let allowedRange {
            return allowedRange.lowerBound ... allowedRange.upperBound.addingTimeInterval(-1)
        }
        return calendar.startOfDay(for: clock.now) ... clock.now
    }

    private var isAtActiveFastStart: Bool {
        activeFastStart == occurredAt
    }

    private func validationLabel(_ message: String, identifier: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(UFastTheme.error)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }

    private func save() {
        guard let draft = validDraft else {
            return
        }
        do {
            try onSave(draft, false)
            saveError = nil
        } catch let error as FoodEntrySaveError {
            switch error.presentation {
            case let .confirmation(context):
                showConfirmation(context, draft: draft)
            case .eventAtActiveFastStart:
                saveError = textResolver(.foodActiveStartValidation)
            case .fastConflict:
                saveError = textResolver(.foodConflictError)
            case .saveFailure:
                saveError = textResolver(.foodSaveError)
            }
        } catch {
            saveError = textResolver(.foodSaveError)
        }
    }

    private func saveEndingFast() {
        if pendingDeletion {
            do {
                try onDelete?(true)
                pendingDeletion = false
                showsFastEndConfirmation = false
                saveError = nil
            } catch {
                saveError = textResolver(.foodDeleteError)
            }
            return
        }
        guard let draft = pendingFastEndDraft else {
            return
        }
        do {
            try onSave(draft, true)
            saveError = nil
            pendingFastEndDraft = nil
        } catch {
            saveError = textResolver(.foodCombinedSaveError)
        }
    }

    private func delete() {
        do {
            try onDelete?(false)
            saveError = nil
        } catch let error as FoodEntrySaveError {
            if case let .confirmation(context) = error.presentation {
                showConfirmation(context, pendingDeletion: true)
            } else {
                saveError = textResolver(.foodDeleteError)
            }
        } catch {
            saveError = textResolver(.foodDeleteError)
        }
    }

    private func showConfirmation(
        _ context: CaloricEventConfirmationContext,
        draft: FoodEntryDraft? = nil,
        pendingDeletion: Bool = false
    ) {
        confirmationContext = context
        pendingFastEndDraft = draft
        self.pendingDeletion = pendingDeletion
        showsFastEndConfirmation = true
    }
}

extension FoodEntryEditor {
    static func activeConfirmationMessage(
        context: CaloricEventConfirmationContext,
        action: String,
        time: String
    ) -> String {
        let confirmationAction: AppText.CaloricEventConfirmationAction = action == "Deleting" ? .deleting : .saving
        return AppTextResolver()(
            .confirmationMessage(
                action: confirmationAction,
                kind: .active,
                noun: .food,
                count: max(1, context.affectedPersistedFastCount),
                time: time
            )
        )
    }
}

private extension FoodEntryEditor {
    func nutritionField(
        _ field: AppText.FoodNutritionField,
        unit: AppText.FoodNutritionUnit,
        identifier: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            Text(textResolver(.foodNutritionField(field)))
                .accessibilityIdentifier("food.nutrition.\(identifier).label")
            Spacer(minLength: UFastTheme.Spacing.compact)
            TextField(textResolver(.foodNutritionValuePlaceholder), text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, idealWidth: 96, maxWidth: 120)
                .accessibilityLabel(textResolver(.foodNutritionField(field)))
                .accessibilityIdentifier("food.nutrition.\(identifier).input")
            Text(textResolver(.foodNutritionUnit(unit)))
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityIdentifier("food.nutrition.\(identifier).unit")
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            textResolver(.foodNutritionHint(unit: textResolver(.foodNutritionUnit(unit))))
        )
    }

    var confirmationTitle: String {
        textResolver(
            .confirmationTitle(
                confirmationContext.kind,
                noun: .food,
                count: max(1, confirmationContext.affectedPersistedFastCount)
            )
        )
    }

    var confirmationActionTitle: String {
        if pendingDeletion {
            return textResolver(
                .confirmationAction(.deleting, kind: confirmationContext.kind, noun: .food)
            )
        }
        return textResolver(
            .confirmationAction(.saving, kind: confirmationContext.kind, noun: .food)
        )
    }

    var confirmationMessage: String {
        let time = occurredAt.formatted(date: .omitted, time: .shortened)
        let action: AppText.CaloricEventConfirmationAction = pendingDeletion ? .deleting : .saving
        var details = textResolver(
            .confirmationMessage(
                action: action,
                kind: confirmationContext.kind,
                noun: .food,
                count: max(1, confirmationContext.affectedPersistedFastCount),
                time: time
            )
        )
        if confirmationContext.includesReconstructedReview {
            details += " " + textResolver(.reconstructedReviewDetail)
        }
        if confirmationContext.isCombined {
            details += " " + textResolver(.inferredIntervalDetail)
        }
        return details
    }
}

private struct FoodNutritionTextInput {
    var energy = ""
    var protein = ""
    var carbohydrate = ""
    var fat = ""
    var fibre = ""
    var sugar = ""
    var salt = ""

    init(nutrition: FoodNutrition) {
        energy = Self.text(nutrition.energyKilocalories)
        protein = Self.text(nutrition.proteinGrams)
        carbohydrate = Self.text(nutrition.carbohydrateGrams)
        fat = Self.text(nutrition.fatGrams)
        fibre = Self.text(nutrition.fibreGrams)
        sugar = Self.text(nutrition.sugarGrams)
        salt = Self.text(nutrition.saltGrams)
    }

    var hasValues: Bool {
        ![energy, protein, carbohydrate, fat, fibre, sugar, salt].allSatisfy(\.isEmpty)
    }

    func nutrition(locale: Locale) -> FoodNutrition? {
        guard let energy = Self.value(energy, locale: locale),
              let protein = Self.value(protein, locale: locale),
              let carbohydrate = Self.value(carbohydrate, locale: locale),
              let fat = Self.value(fat, locale: locale),
              let fibre = Self.value(fibre, locale: locale),
              let sugar = Self.value(sugar, locale: locale),
              let salt = Self.value(salt, locale: locale)
        else {
            return nil
        }

        return FoodNutrition(
            energyKilocalories: energy,
            proteinGrams: protein,
            carbohydrateGrams: carbohydrate,
            fatGrams: fat,
            fibreGrams: fibre,
            sugarGrams: sugar,
            saltGrams: salt
        )
    }

    private static func value(_ text: String, locale: Locale) -> Double?? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .some(nil)
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: trimmed) else {
            return nil
        }
        return .some(number.doubleValue)
    }

    private static func text(_ value: Double?) -> String {
        value.map { String(format: "%g", $0) } ?? ""
    }
}
