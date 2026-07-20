import SwiftUI

struct ActiveFastProgressView: View {
    let presentation: ActiveFastPresentation
    let goal: FastingGoal
    let target: String
    let canEndNow: Bool
    let endError: String?
    let onEnd: () -> Void
    let onEditStart: () -> Void
    let onEndAtPastTime: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Fast in progress", systemImage: "timer")
                        .font(.headline)

                    elapsedView

                    ProgressView(value: presentation.progress)
                        .accessibilityLabel("Progress")
                        .accessibilityValue(presentation.progressAccessibilityValue(goal: goal))
                        .accessibilityIdentifier("fast.progress")

                    Text("Goal: \(goal.hours) hours")
                        .accessibilityLabel("Goal")
                        .accessibilityValue("\(goal.hours) hours")
                        .accessibilityIdentifier("fast.goal")
                    Text("Target: \(target)")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Target")
                        .accessibilityValue(target)
                        .accessibilityIdentifier("fast.target")

                    if presentation.hasReachedGoal {
                        Text("Goal time reached")
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("fast.goal-reached")
                    }

                    Button("End fast", action: onEnd)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canEndNow)
                        .accessibilityIdentifier("fast.end")

                    if !canEndNow {
                        Text("This fast can’t end until after its recorded start time.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fast.end-unavailable")
                    }

                    if let endError {
                        Text(endError)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("fast.end-error")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilitySummary)

                Button("Edit start time", action: onEditStart)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("fast.edit-start")

                Button("End at a past time", action: onEndAtPastTime)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("fast.end-past")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private var elapsedView: some View {
        if let elapsedText = presentation.elapsedText {
            let accessibilityText = presentation.elapsedAccessibilityText ?? elapsedText

            Text("Elapsed time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(elapsedText)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(accessibilityText)
                .accessibilityIdentifier("fast.elapsed")
        } else {
            Text("Elapsed time isn’t available while the recorded start is in the future.")
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fast.elapsed-unavailable")
        }
    }

    private var accessibilitySummary: String {
        var components = ["Fast in progress"]

        if let elapsedText = presentation.elapsedAccessibilityText {
            components.append("Elapsed \(elapsedText)")
        } else {
            components.append(
                "Elapsed time isn’t available while the recorded start is in the future."
            )
        }

        components.append("Goal \(goal.hours) hours")
        components.append("Target \(target)")

        if presentation.hasReachedGoal {
            components.append("Goal time reached")
        }

        return components.joined(separator: ", ")
    }
}
