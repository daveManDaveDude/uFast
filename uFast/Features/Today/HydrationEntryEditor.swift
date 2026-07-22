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

    let record: HydrationEntryRecord?
    let clock: any AppClock
    let activeFastStart: Date?
    let allowedRange: Range<Date>?
    let onSave: (HydrationEntryDraft, Bool) throws -> Void
    let onDelete: (() throws -> Void)?
    let onCancel: () -> Void

    init(record: HydrationEntryRecord?, clock: any AppClock, activeFastStart: Date?, initialDraft: HydrationEntryDraft? = nil, allowedRange: Range<Date>? = nil, onSave: @escaping (HydrationEntryDraft, Bool) throws -> Void, onDelete: (() throws -> Void)?, onCancel: @escaping () -> Void) {
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
                    }.accessibilityIdentifier("drink.type")
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
                    DatePicker("Time", selection: $occurredAt, in: datePickerRange, displayedComponents: .hourAndMinute)
                }
                Section {
                    Picker("Fasting classification", selection: $isCaloric) {
                        Text("Non-caloric").tag(false)
                        Text("Caloric").tag(true)
                    }
                    .pickerStyle(.segmented)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button(record == nil ? "Save drink" : "Save changes") { save() }.disabled(validDraft == nil).accessibilityIdentifier("drink.editor.save") }
            }
            .alert("Delete this drink?", isPresented: $showsDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { delete() }
            } message: { Text("This removes it from your local record.") }
            .alert("This entry is during your recorded fast.", isPresented: $showsFastEndConfirmation) {
                Button("Cancel", role: .cancel) { pendingDraft = nil }
                Button("Save and end fast") { saveEndingFast() }
            } message: { Text("Saving this caloric event records the drink and ends your fast at (occurredAt.formatted(date: .omitted, time: .shortened)).") }
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
        catch HydrationEntrySaveError.confirmationRequired { pendingDraft = draft; showsFastEndConfirmation = true }
        catch HydrationEntrySaveError.eventAtActiveFastStart { saveError = "Choose a time after the fast started, or change the fast start time." }
        catch HydrationEntrySaveError.fastConflict { saveError = "This fast overlaps another recorded fast. Correct the fast before saving." }
        catch { saveError = "Your drink couldn’t be saved. Please try again." }
    }

    private func saveEndingFast() {
        guard let pendingDraft else { return }; do { try onSave(pendingDraft, true) } catch { saveError = "Your drink and fast couldn’t be saved. Please try again." }
    }

    private func delete() {
        do { try onDelete?() } catch { saveError = "Your drink couldn’t be deleted. Please try again." }
    }
}
