import SwiftUI

struct FastingGoalPicker: View {
    @Binding var selection: FastingGoal

    var body: some View {
        Picker("Fasting goal", selection: $selection) {
            ForEach(FastingGoal.choices) { goal in
                Text("\(goal.hours) hours")
                    .tag(goal)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("goal.picker")
        .accessibilityValue("\(selection.hours) hours")
    }
}
