import SwiftUI

struct FoodEntryEditor: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
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
                    TextField("What did you eat?", text: $descriptionText, axis: .vertical)
                        .lineLimit(2 ... 5)
                        .focused($isDescriptionFocused)
                        .accessibilityIdentifier("food.description")

                    if let descriptionError {
                        validationLabel(descriptionError, identifier: "food.description.validation")
                    }
                }

                Section("Time") {
                    DatePicker(
                        "Date",
                        selection: $occurredAt,
                        in: datePickerRange,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("food.date")

                    DatePicker(
                        "Time",
                        selection: $occurredAt,
                        in: datePickerRange,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("food.time")
                }

                Section {
                    Text(
                        "Food events count as caloric and are used as fasting boundaries. "
                            + "If this event falls during your active fast, "
                            + "saving it ends the fast at this time."
                    )
                    .font(.footnote)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("food.caloric.explanation")

                    if isAtActiveFastStart {
                        validationLabel(
                            "Choose a time after the fast started, or change the fast start time.",
                            identifier: "food.fast-start.validation"
                        )
                    }
                }

                Section {
                    Button(showsDetails ? "Hide details" : "Add details") {
                        showsDetails.toggle()
                    }
                    .accessibilityIdentifier("food.details.toggle")
                }

                if showsDetails {
                    Section("Optional manual details") {
                        nutritionField("Energy", unit: "kcal", identifier: "energy", text: $nutritionInput.energy)
                        nutritionField("Protein", unit: "g", identifier: "protein", text: $nutritionInput.protein)
                        nutritionField(
                            "Carbohydrate",
                            unit: "g",
                            identifier: "carbohydrate",
                            text: $nutritionInput.carbohydrate
                        )
                        nutritionField("Fat", unit: "g", identifier: "fat", text: $nutritionInput.fat)
                        nutritionField("Fibre", unit: "g", identifier: "fibre", text: $nutritionInput.fibre)
                        nutritionField("Sugar", unit: "g", identifier: "sugar", text: $nutritionInput.sugar)
                        nutritionField("Salt", unit: "g", identifier: "salt", text: $nutritionInput.salt)

                        Text("Each value is optional. Valid range: 0–1,000,000.")
                            .font(.footnote)
                            .foregroundStyle(UFastTheme.secondaryText)

                        if nutritionResult == nil {
                            validationLabel(
                                FoodEntryValidationError.invalidNutrition.message,
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
                        Button("Delete food event", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("food.delete")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .navigationTitle(record == nil ? "Log food" : "Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("food.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(record == nil ? "Save food" : "Save changes") {
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
            .alert("Delete this food event?", isPresented: $showsDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    delete()
                }
            } message: {
                Text("This removes it from your local record.")
            }
            .alert(confirmationTitle, isPresented: $showsFastEndConfirmation) {
                Button("Cancel", role: .cancel) {
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
            return FoodEntryValidationError.emptyDescription.message
        }
        if trimmed.count > FoodEntryValidator.descriptionLimit {
            return FoodEntryValidationError.descriptionTooLong.message
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
        } catch let FoodEntrySaveError.confirmationRequiredWithImpact(context) {
            showConfirmation(context, draft: draft)
        } catch let FoodEntrySaveError.completedConfirmationWithImpact(context) {
            showConfirmation(context, draft: draft)
        } catch let FoodEntrySaveError.inferredConfirmationWithImpact(context) {
            showConfirmation(context, draft: draft)
        } catch FoodEntrySaveError.confirmationRequired {
            showConfirmation(.init(fallbackKind: .active), draft: draft)
        } catch FoodEntrySaveError.completedFastConfirmationRequired {
            showConfirmation(.init(fallbackKind: .completed), draft: draft)
        } catch FoodEntrySaveError.inferredFastConfirmationRequired {
            showConfirmation(.init(fallbackKind: .inferred), draft: draft)
        } catch FoodEntrySaveError.eventAtActiveFastStart {
            saveError = "Choose a time after the fast started, or change the fast start time."
        } catch FoodEntrySaveError.fastConflict {
            saveError = "This fast overlaps another recorded fast. Correct the fast before saving."
        } catch {
            saveError = "Your food event couldn’t be saved. Please try again."
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
                saveError = "Your food event couldn’t be deleted. Please try again."
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
            saveError = "Your food event and fast couldn’t be saved. Please try again."
        }
    }

    private func delete() {
        do {
            try onDelete?(false)
            saveError = nil
        } catch let FoodEntrySaveError.confirmationRequiredWithImpact(context) {
            showConfirmation(context, pendingDeletion: true)
        } catch let FoodEntrySaveError.completedConfirmationWithImpact(context) {
            showConfirmation(context, pendingDeletion: true)
        } catch let FoodEntrySaveError.inferredConfirmationWithImpact(context) {
            showConfirmation(context, pendingDeletion: true)
        } catch {
            saveError = "Your food event couldn’t be deleted. Please try again."
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
        guard context.affectedPersistedFastCount > 1 else {
            return "\(action) this caloric event records the food and ends your fast at \(time)."
        }
        return "Ending your active fast at \(time) updates \(context.affectedPersistedFastCount) persisted fasts."
    }
}

private extension FoodEntryEditor {
    func nutritionField(
        _ label: String,
        unit: String,
        identifier: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            Text(label)
                .accessibilityIdentifier("food.nutrition.\(identifier).label")
            Spacer(minLength: UFastTheme.Spacing.compact)
            TextField("Value", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, idealWidth: 96, maxWidth: 120)
                .accessibilityLabel(label)
                .accessibilityIdentifier("food.nutrition.\(identifier).input")
            Text(unit)
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityIdentifier("food.nutrition.\(identifier).unit")
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Optional, from 0 to 1,000,000 \(unit).")
    }

    var confirmationTitle: String {
        switch confirmationContext.kind {
        case .active: "This entry is during your recorded fast."
        case .completed:
            "This entry updates \(confirmationContext.affectedPersistedFastCount) recorded fast(s)."
        case .inferred: "This entry updates inferred History."
        }
    }

    var confirmationActionTitle: String {
        if pendingDeletion {
            switch confirmationContext.kind {
            case .active, .completed: return "Delete and update fast"
            case .inferred: return "Delete and update History"
            }
        }
        switch confirmationContext.kind {
        case .active: return "Save and end fast"
        case .completed: return "Save and update fast"
        case .inferred: return "Save and update History"
        }
    }

    var confirmationMessage: String {
        let time = occurredAt.formatted(date: .omitted, time: .shortened)
        let action = pendingDeletion ? "Deleting" : "Saving"
        let consequence = switch confirmationContext.kind {
        case .active:
            Self.activeConfirmationMessage(
                context: confirmationContext,
                action: action,
                time: time
            )
        case .completed:
            "\(action) this caloric event updates \(confirmationContext.affectedPersistedFastCount) "
                + "recorded fast(s) at \(time)."
        case .inferred:
            "\(action) this caloric event refreshes derived inferred History at \(time)."
        }
        var details = consequence
        if confirmationContext.includesReconstructedReview {
            details += " At least one affected fast is reconstructed and will be marked for review."
        }
        if confirmationContext.isCombined {
            details += " It also refreshes the derived inferred interval."
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
