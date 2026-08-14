import Foundation

public enum DomainValidation {
    public static func nonEmptyTrimmed(_ value: String, maximumLength: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximumLength ? trimmed : nil
    }

    public static func isFinite(_ value: Double, in range: ClosedRange<Double>) -> Bool {
        value.isFinite && range.contains(value)
    }

    public static func contains(_ value: Int, in range: ClosedRange<Int>) -> Bool {
        range.contains(value)
    }
}
