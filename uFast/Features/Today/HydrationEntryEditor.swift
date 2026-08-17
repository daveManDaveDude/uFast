import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length statement_position

struct HydrationEntryEditor: View {
    @Environment(\.calendar) private var calendar
    @State private var type: HydrationDrinkType
    @State private var name: String
    @State private var volume: String
    @State private var occurredAt: Date
    @State private var isCaloric: Bool
    @State private var saveError: String?
    @State private var showsDeleteConfirmation = false
    @State private var showsFastEndConfirmation = false
    @State private var pendingDraft: HydrationEntryDraft?
    @State private var confirmationContext = CaloricEventConfirmationContext(
        fallbackKind: .active
    )
    @State private var pendingDeletion = false

    let record: HydrationEntrySnapshot?
    let clock: any AppClock
    let activeFastStart: Date?
    let allowedRange: Range<Date>?
    let onSave: (HydrationEntryDraft, Bool) throws -> Void
    let onDelete: ((Bool) throws -> Void)?
    let onCancel: () -> Void

    init(record: HydrationEntryRecord?, clock: any AppClock, activeFastStart: Date?, initialDraft: HydrationEntryDraft? = nil, allowedRange: Range<Date>? = nil, onSave: @escaping (HydrationEntryDraft, Bool) throws -> Void, onDelete: ((Bool) throws -> Void)?, onCancel: @escaping () -> Void) {
        self.init(
            snapshot: record.map(HydrationEntrySnapshot.init), clock: clock,
            activeFastStart: activeFastStart, initialDraft: initialDraft,
            allowedRange: allowedRange, onSave: onSave, onDelete: onDelete, onCancel: onCancel
        )
    }

    init(snapshot record: HydrationEntrySnapshot?, clock: any AppClock, activeFastStart: Date?, initialDraft: HydrationEntryDraft? = nil, allowedRange: Range<Date>? = nil, onSave: @escaping (HydrationEntryDraft, Bool) throws -> Void, onDelete: ((Bool) throws -> Void)?, onCancel: @escaping () -> Void) {
        self.record = record; self.clock = clock; self.activeFastStart = activeFastStart
        self.allowedRange = allowedRange
        self.onSave = onSave; self.onDelete = onDelete; self.onCancel = onCancel
        _type = State(initialValue: record?.drinkType ?? initialDraft?.type ?? .custom)
        _name = State(initialValue: record?.customName ?? initialDraft?.customName ?? "")
        _volume = State(initialValue: record.map { String($0.volumeMillilitres) } ?? initialDraft.map { String($0.volumeMillilitres) } ?? "")
        _occurredAt = State(initialValue: record?.occurredAt ?? initialDraft?.occurredAt ?? clock.now)
        _isCaloric = State(initialValue: record?.isCaloric ?? initialDraft?.isCaloric ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Drink") {
                    Picker("Type", selection: $type) {
                        ForEach(HydrationDrinkType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityValue(type.displayName)
                    .accessibilityIdentifier("drink.type")
                    if type == .custom {
                        TextField("Drink name", text: $name).accessibilityIdentifier("drink.name")
                    }
                    TextField("Amount (ml)", text: $volume)
                        .keyboardType(.numberPad).accessibilityIdentifier("drink.volume")
                    if validVolume == nil {
                        validation("Enter an amount from 1 to 5,000 ml.", id: "drink.volume.validation")
                    }
                    if type == .custom, HydrationEntryValidator.validatedCustomName(name) == nil {
                        validation("Enter a drink name of 80 characters or fewer.", id: "drink.name.validation")
                    }
                }
                Section("Time") {
                    DatePicker("Date", selection: $occurredAt, in: datePickerRange, displayedComponents: .date)
                        .accessibilityIdentifier("drink.date")
                    DatePicker("Time", selection: $occurredAt, in: datePickerRange, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("drink.time")
                }
                Section {
                    Picker("Fasting classification", selection: $isCaloric) {
                        Text("Non-caloric").tag(false)
                        Text("Caloric").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityValue(isCaloric ? "Caloric" : "Non-caloric")
                    .accessibilityIdentifier("drink.caloric")
                    Text("Used as a fasting boundary. If it falls during your active fast, saving it ends the fast at this time.")
                        .font(.footnote).foregroundStyle(UFastTheme.secondaryText)
                    if isAtActiveFastStart {
                        validation("Choose a time after the fast started, or change the fast start time.", id: "drink.fast-start.validation")
                    }
                }
                if let saveError {
                    Section { validation(saveError, id: "drink.editor.save-error") }
                }
                if onDelete != nil {
                    Section { Button("Delete drink", role: .destructive) { showsDeleteConfirmation = true }.accessibilityIdentifier("drink.delete") }
                }
            }
            .scrollContentBackground(.hidden).background(UFastTheme.canvas)
            .navigationTitle(record == nil ? "Add another drink" : "Edit drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("drink.cancel")
                }
                ToolbarItem(placement: .confirmationAction) { Button(record == nil ? "Save drink" : "Save changes") { save() }.disabled(validDraft == nil).accessibilityIdentifier("drink.editor.save") }
            }
            .alert("Delete this drink?", isPresented: $showsDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { delete() }
            } message: { Text("This removes it from your local record.") }
            .alert(confirmationTitle, isPresented: $showsFastEndConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingDraft = nil
                    pendingDeletion = false
                }
                .accessibilityIdentifier("drink.confirmation.cancel")
                Button(confirmationActionTitle) { saveEndingFast() }
                    .accessibilityIdentifier("drink.confirmation.primary")
            } message: {
                Text(confirmationMessage)
                    .accessibilityIdentifier("drink.confirmation.consequence")
            }
        }
    }

    private var validVolume: Int? {
        Int(volume).flatMap { HydrationEntryValidator.isValid(volumeMillilitres: $0) ? $0 : nil }
    }

    private var isAtActiveFastStart: Bool {
        isCaloric && activeFastStart == occurredAt
    }

    private var validDraft: HydrationEntryDraft? {
        guard let validVolume, !isAtActiveFastStart else { return nil }
        return HydrationEntryValidator.validated(type: type, customName: name, volumeMillilitres: validVolume, occurredAt: occurredAt, isCaloric: isCaloric, now: clock.now, calendar: calendar, allowedRange: allowedRange)
    }

    private var datePickerRange: ClosedRange<Date> {
        if let allowedRange {
            return allowedRange.lowerBound ... allowedRange.upperBound.addingTimeInterval(-1)
        }
        return calendar.startOfDay(for: clock.now) ... clock.now
    }

    private func validation(_ text: String, id: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(UFastTheme.error).accessibilityIdentifier(id)
    }

    private func save() {
        guard let draft = validDraft else { return }
        do { try onSave(draft, false) }
        catch let HydrationEntrySaveError.confirmationRequiredWithImpact(context) { showConfirmation(context, draft: draft) }
        catch let HydrationEntrySaveError.completedConfirmationWithImpact(context) { showConfirmation(context, draft: draft) }
        catch let HydrationEntrySaveError.inferredConfirmationWithImpact(context) { showConfirmation(context, draft: draft) }
        catch HydrationEntrySaveError.confirmationRequired { showConfirmation(.init(fallbackKind: .active), draft: draft) }
        catch HydrationEntrySaveError.completedFastConfirmationRequired { showConfirmation(.init(fallbackKind: .completed), draft: draft) }
        catch HydrationEntrySaveError.inferredFastConfirmationRequired { showConfirmation(.init(fallbackKind: .inferred), draft: draft) }
        catch HydrationEntrySaveError.eventAtActiveFastStart { saveError = "Choose a time after the fast started, or change the fast start time." }
        catch HydrationEntrySaveError.fastConflict { saveError = "This fast overlaps another recorded fast. Correct the fast before saving." }
        catch { saveError = "Your drink couldn’t be saved. Please try again." }
    }

    private func saveEndingFast() {
        if pendingDeletion {
            do {
                try onDelete?(true)
                pendingDeletion = false
                showsFastEndConfirmation = false
                saveError = nil
            } catch {
                saveError = "Your drink couldn’t be deleted. Please try again."
            }
            return
        }
        guard let pendingDraft else { return }; do { try onSave(pendingDraft, true) } catch { saveError = "Your drink and fast couldn’t be saved. Please try again." }
    }

    private var confirmationTitle: String {
        switch confirmationContext.kind {
        case .active: "This entry is during your recorded fast."
        case .completed: "This drink updates \(confirmationContext.affectedPersistedFastCount) recorded fast(s)."
        case .inferred: "This drink updates inferred History."
        }
    }

    private var confirmationActionTitle: String {
        if pendingDeletion {
            return "Delete and update History"
        }
        switch confirmationContext.kind {
        case .active: return "Save and end fast"
        case .completed: return "Save and update fast"
        case .inferred: return "Save and update History"
        }
    }

    private var confirmationMessage: String {
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
            "\(action) this caloric drink updates \(confirmationContext.affectedPersistedFastCount) recorded fast(s) at \(time)."
        case .inferred:
            "\(action) this caloric drink refreshes derived inferred History at \(time)."
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

    private func delete() {
        do {
            try onDelete?(false)
        } catch let HydrationEntrySaveError.inferredConfirmationWithImpact(context) {
            showConfirmation(context, pendingDeletion: true)
        } catch {
            saveError = "Your drink couldn’t be deleted. Please try again."
        }
    }

    private func showConfirmation(
        _ context: CaloricEventConfirmationContext,
        draft: HydrationEntryDraft? = nil,
        pendingDeletion: Bool = false
    ) {
        confirmationContext = context
        pendingDraft = draft
        self.pendingDeletion = pendingDeletion
        showsFastEndConfirmation = true
    }
}

extension HydrationEntryEditor {
    static func activeConfirmationMessage(
        context: CaloricEventConfirmationContext,
        action: String,
        time: String
    ) -> String {
        guard context.affectedPersistedFastCount > 1 else {
            return "\(action) this caloric drink records it and ends your fast at \(time)."
        }
        return "Ending your active fast at \(time) updates \(context.affectedPersistedFastCount) persisted fasts."
    }
}
