import SwiftUI
import UFastCore

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length statement_position

struct HydrationEntryEditor: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.appTextResolver) private var textResolver
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
                Section(textResolver(.drinkSection)) {
                    Picker(textResolver(.drinkType), selection: $type) {
                        ForEach(HydrationDrinkType.allCases, id: \.self) {
                            Text(textResolver(.drinkTypeName($0)))
                                .tag($0)
                                .accessibilityIdentifier("drink.type.\($0.rawValue)")
                        }
                    }
                    .accessibilityValue(textResolver(.drinkTypeName(type)))
                    .accessibilityIdentifier("drink.type")
                    if type == .custom {
                        TextField(textResolver(.drinkName), text: $name)
                            .accessibilityIdentifier("drink.name")
                    }
                    TextField(textResolver(.drinkAmount), text: $volume)
                        .keyboardType(.numberPad).accessibilityIdentifier("drink.volume")
                    if validVolume == nil {
                        validation(textResolver(.drinkVolumeValidation), id: "drink.volume.validation")
                    }
                    if type == .custom, HydrationEntryValidator.validatedCustomName(name) == nil {
                        validation(textResolver(.drinkNameValidation), id: "drink.name.validation")
                    }
                }
                Section(textResolver(.drinkTimeSection)) {
                    DatePicker(textResolver(.date), selection: $occurredAt, in: datePickerRange, displayedComponents: .date)
                        .accessibilityIdentifier("drink.date")
                    DatePicker(textResolver(.time), selection: $occurredAt, in: datePickerRange, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("drink.time")
                }
                Section {
                    Picker(textResolver(.drinkFastingClassification), selection: $isCaloric) {
                        Text(textResolver(.drinkNonCaloric))
                            .tag(false)
                            .accessibilityIdentifier("drink.classification.non-caloric")
                        Text(textResolver(.drinkCaloric))
                            .tag(true)
                            .accessibilityIdentifier("drink.classification.caloric")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityValue(textResolver(.drinkPickerClassification(isCaloric: isCaloric)))
                    .accessibilityIdentifier("drink.caloric")
                    Text(textResolver(.drinkBoundaryExplanation))
                        .font(.footnote).foregroundStyle(UFastTheme.secondaryText)
                    if isAtActiveFastStart {
                        validation(textResolver(.drinkActiveStartValidation), id: "drink.fast-start.validation")
                    }
                }
                if let saveError {
                    Section { validation(saveError, id: "drink.editor.save-error") }
                }
                if onDelete != nil {
                    Section {
                        Button(textResolver(.drinkDelete), role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("drink.delete")
                    }
                }
            }
            .scrollContentBackground(.hidden).background(UFastTheme.canvas)
            .navigationTitle(textResolver(.drinkTitle(isEditing: record != nil)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("drink.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(textResolver(.drinkSaveTitle(isEditing: record != nil))) { save() }
                        .disabled(validDraft == nil)
                        .accessibilityIdentifier("drink.editor.save")
                }
            }
            .alert(textResolver(.drinkDeleteConfirmationTitle), isPresented: $showsDeleteConfirmation) {
                Button(textResolver(.cancel), role: .cancel) {}
                    .accessibilityIdentifier("drink.delete.cancel")
                Button(textResolver(.delete), role: .destructive) { delete() }
                    .accessibilityIdentifier("drink.delete.confirm")
            } message: { Text(textResolver(.localRecordRemoval)) }
            .alert(confirmationTitle, isPresented: $showsFastEndConfirmation) {
                Button(textResolver(.cancel), role: .cancel) {
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
        catch let error as HydrationEntrySaveError {
            switch error.presentation {
            case let .confirmation(context): showConfirmation(context, draft: draft)
            case .eventAtActiveFastStart: saveError = textResolver(.drinkActiveStartValidation)
            case .fastConflict: saveError = textResolver(.drinkConflictError)
            case .saveFailure: saveError = textResolver(.drinkSaveError)
            }
        } catch { saveError = textResolver(.drinkSaveError) }
    }

    private func saveEndingFast() {
        if pendingDeletion {
            do {
                try onDelete?(true)
                pendingDeletion = false
                showsFastEndConfirmation = false
                saveError = nil
            } catch {
                saveError = textResolver(.drinkDeleteError)
            }
            return
        }
        guard let pendingDraft else { return }
        do {
            try onSave(pendingDraft, true)
        } catch {
            saveError = textResolver(.drinkCombinedSaveError)
        }
    }

    private var confirmationTitle: String {
        textResolver(
            .confirmationTitle(
                confirmationContext.kind,
                noun: .drink,
                count: max(1, confirmationContext.affectedPersistedFastCount)
            )
        )
    }

    private var confirmationActionTitle: String {
        if pendingDeletion {
            return textResolver(
                .confirmationAction(.deleting, kind: confirmationContext.kind, noun: .drink)
            )
        }
        return textResolver(
            .confirmationAction(.saving, kind: confirmationContext.kind, noun: .drink)
        )
    }

    private var confirmationMessage: String {
        let time = occurredAt.formatted(date: .omitted, time: .shortened)
        let action: AppText.CaloricEventConfirmationAction = pendingDeletion ? .deleting : .saving
        var details = textResolver(
            .confirmationMessage(
                action: action,
                kind: confirmationContext.kind,
                noun: .drink,
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

    private func delete() {
        do {
            try onDelete?(false)
        } catch let error as HydrationEntrySaveError {
            if case let .confirmation(context) = error.presentation {
                showConfirmation(context, pendingDeletion: true)
            } else {
                saveError = textResolver(.drinkDeleteError)
            }
        } catch {
            saveError = textResolver(.drinkDeleteError)
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
        let confirmationAction: AppText.CaloricEventConfirmationAction = action == "Deleting" ? .deleting : .saving
        return AppTextResolver()(
            .confirmationMessage(
                action: confirmationAction,
                kind: .active,
                noun: .drink,
                count: max(1, context.affectedPersistedFastCount),
                time: time
            )
        )
    }
}
