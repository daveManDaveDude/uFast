import Foundation

enum FoodNutritionValueParser {
    static func value(_ text: String, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }
}

enum FoodNutritionValueFormatter {
    static func string(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }
}
