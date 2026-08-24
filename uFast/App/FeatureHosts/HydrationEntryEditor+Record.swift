import Foundation
import UFastCore

/// The composition boundary converts persistent records before handing them to a feature editor.
extension HydrationEntryEditor {
    init(
        record: HydrationEntryRecord?,
        clock: any AppClock,
        activeFastStart: Date?,
        initialDraft: HydrationEntryDraft? = nil,
        allowedRange: Range<Date>? = nil,
        onSave: @escaping (HydrationEntryDraft, Bool) throws -> Void,
        onDelete: ((Bool) throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            snapshot: record.map(HydrationEntrySnapshot.init),
            clock: clock,
            activeFastStart: activeFastStart,
            initialDraft: initialDraft,
            allowedRange: allowedRange,
            onSave: onSave,
            onDelete: onDelete,
            onCancel: onCancel
        )
    }
}
