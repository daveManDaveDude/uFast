import SwiftUI

struct FastingGoalPicker: View {
    @Binding var selection: FastingGoal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTextResolver) private var textResolver

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: UFastTheme.Spacing.compact),
            count: count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.compact) {
            Text(textResolver(.goalSelectionSummary(hours: selection.hours)))
                .font(.caption)
                .foregroundStyle(UFastTheme.secondaryText)
                .accessibilityLabel(textResolver(.goalAccessibilityLabel))
                .accessibilityValue(textResolver(.goalHours(hours: selection.hours)))
                .accessibilityIdentifier("goal.picker")

            LazyVGrid(columns: columns, spacing: UFastTheme.Spacing.compact) {
                ForEach(FastingGoal.choices) { goal in
                    let isSelected = goal == selection

                    Button {
                        selection = goal
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                            Text(textResolver(.goalOption(hours: goal.hours)))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(UFastTheme.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            isSelected
                                ? UFastTheme.sage.opacity(0.46)
                                : UFastTheme.raisedSurface
                        )
                        .clipShape(.rect(cornerRadius: UFastTheme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                                .stroke(
                                    isSelected ? UFastTheme.action : UFastTheme.border,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(textResolver(.goalHours(hours: goal.hours)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("goal.option.\(goal.hours)")
                }
            }
        }
    }
}
