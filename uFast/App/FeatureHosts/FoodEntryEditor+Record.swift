import Foundation
import UFastCore

extension FoodEntryEditor {
    init(
        record: FoodEntryRecord?,
        clock: any AppClock,
        activeFastStart: Date?,
        initialOccurredAt: Date? = nil,
        allowedRange: Range<Date>? = nil,
        onSave: @escaping (FoodEntryDraft, Bool) throws -> Void,
        onDelete: ((Bool) throws -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            snapshot: record.map(FoodEntrySnapshot.init),
            clock: clock,
            activeFastStart: activeFastStart,
            initialOccurredAt: initialOccurredAt,
            allowedRange: allowedRange,
            onSave: onSave,
            onDelete: onDelete,
            onCancel: onCancel
        )
    }
}
