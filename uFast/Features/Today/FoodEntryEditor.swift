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
    @State private var isCaloric: Bool

    let record: FoodEntryRecord?
    let clock: any AppClock
    let activeFastStart: Date?
    let onSave: (FoodEntryDraft, Bool) throws -> Void
    let onDelete: (() throws -> Void)?
    let onCancel: () -> Void

    init(
        record: FoodEntryRecord?,
        clock: any AppClock,
        activeFastStart: Date?,
        onSave: @escaping (FoodEntryDraft, Bool) throws -> Void,
        onDelete: (() throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.record = record
        self.clock = clock
        self.activeFastStart = activeFastStart
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _descriptionText = State(initialValue: record?.foodDescription ?? "")
        _occurredAt = State(initialValue: record?.occurredAt ?? clock.now)
        let input = FoodNutritionTextInput(nutrition: record?.nutrition ?? FoodNutrition())
        _nutritionInput = State(initialValue: input)
        _showsDetails = State(initialValue: input.hasValues)
        _isCaloric = State(initialValue: record?.isCaloric ?? true)
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
                        in: calendar.startOfDay(for: clock.now) ... clock.now,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("food.date")

                    DatePicker(
                        "Time",
                        selection: $occurredAt,
                        in: calendar.startOfDay(for: clock.now) ... clock.now,
                        displayedComponents: .hourAndMinute
                    )
                    .accessibilityIdentifier("food.time")
                }

                Section {
                    Toggle("Counts as caloric", isOn: $isCaloric)
                        .accessibilityIdentifier("food.caloric")
                    Text(
                        "Used as a fasting boundary. If it falls during your active fast, "
                            + "saving it ends the fast at this time."
                    )
                    .font(.footnote)
                    .foregroundStyle(UFastTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

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
                        nutritionField("Energy", unit: "kcal", text: $nutritionInput.energy)
                        nutritionField("Protein", unit: "g", text: $nutritionInput.protein)
                        nutritionField("Carbohydrate", unit: "g", text: $nutritionInput.carbohydrate)
                        nutritionField("Fat", unit: "g", text: $nutritionInput.fat)
                        nutritionField("Fibre", unit: "g", text: $nutritionInput.fibre)
                        nutritionField("Sugar", unit: "g", text: $nutritionInput.sugar)
                        nutritionField("Salt", unit: "g", text: $nutritionInput.salt)

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
            .alert(
                "This entry is during your recorded fast.",
                isPresented: $showsFastEndConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    pendingFastEndDraft = nil
                }
                Button("Save and end fast") {
                    saveEndingFast()
                }
            } message: {
                Text(
                    "Saving this caloric event records the food and ends your fast at "
                        + occurredAt.formatted(date: .omitted, time: .shortened) + "."
                )
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
            isCaloric: isCaloric,
            nutrition: nutrition,
            now: clock.now,
            calendar: calendar
        ).get()
    }

    private var isAtActiveFastStart: Bool {
        isCaloric && activeFastStart == occurredAt
    }

    private func nutritionField(
        _ label: String,
        unit: String,
        text: Binding<String>
    ) -> some View {
        HStack {
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .accessibilityLabel(label)
            Text(unit)
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Optional, from 0 to 1,000,000 (unit).")
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
        } catch FoodEntrySaveError.confirmationRequired {
            pendingFastEndDraft = draft
            showsFastEndConfirmation = true
        } catch FoodEntrySaveError.eventAtActiveFastStart {
            saveError = "Choose a time after the fast started, or change the fast start time."
        } catch FoodEntrySaveError.fastConflict {
            saveError = "This fast overlaps another recorded fast. Correct the fast before saving."
        } catch {
            saveError = "Your food event couldn’t be saved. Please try again."
        }
    }

    private func saveEndingFast() {
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
            try onDelete?()
            saveError = nil
        } catch {
            saveError = "Your food event couldn’t be deleted. Please try again."
        }
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
