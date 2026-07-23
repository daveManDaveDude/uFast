import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable file_length function_body_length line_length type_body_length

struct ReviewReconstructionView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @State private var choices: [ReconstructionBoundaryPair: ReconstructionReviewChoice] = [:]
    @State private var adjustment: ReconstructionAdjustmentPresentation?
    @State private var saveError: String?
    @State private var isSaving = false

    let generation: ReconstructionGeneration
    let onSave: ([ReviewedReconstruction]) throws -> Void
    let onRefresh: () -> Void
    var eyebrow = "Catch up"

    private var reviewableResults: [ReconstructionResult] {
        generation.results.filter { $0.candidate != nil }
    }

    private var reviewedCount: Int {
        reviewableResults.filter { result in
            result.candidate.map { choices[$0.pair] != nil } ?? false
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                UFastSectionHeading("Review fasting history", eyebrow: eyebrow)
                Text("Review each period before anything is saved.")
                    .foregroundStyle(UFastTheme.secondaryText)

                if reviewableResults.isEmpty {
                    noResultsView
                } else {
                    Text("\(reviewedCount) of \(reviewableResults.count) reviewed")
                        .font(.headline)
                        .foregroundStyle(UFastTheme.action)
                        .accessibilityIdentifier("reconstruction.review-progress")

                    ForEach(Array(generation.results.enumerated()), id: \.offset) { _, result in
                        resultView(result)
                    }

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("reconstruction.save-error")
                    }

                    Button("Save reviewed history", action: save)
                        .buttonStyle(UFastPrimaryButtonStyle())
                        .disabled(reviewedCount != reviewableResults.count || isSaving)
                        .accessibilityIdentifier("reconstruction.save")
                }
            }
            .padding(UFastTheme.Spacing.standard)
        }
        .navigationTitle("Review fasting history")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $adjustment) { presentation in
            ReconstructionAdjustmentView(
                presentation: presentation,
                onSave: { startDate, endDate in
                    choices[presentation.candidate.pair] = .adjust(
                        startDate: startDate,
                        endDate: endDate
                    )
                    adjustment = nil
                },
                onCancel: { adjustment = nil }
            )
        }
    }

    @ViewBuilder
    private func resultView(_ result: ReconstructionResult) -> some View {
        switch result {
        case let .proposal(candidate):
            candidateCard(candidate, blockedReason: nil)
        case let .blocked(candidate, reason):
            candidateCard(candidate, blockedReason: reason)
        case let .insufficientEdge(edge):
            Label(
                edge == .start
                    ? "Not enough confirmed information before this range."
                    : "Not enough confirmed information after this range.",
                systemImage: "questionmark.circle"
            )
            .foregroundStyle(UFastTheme.secondaryText)
            .uFastCard()
            .accessibilityIdentifier("reconstruction.insufficient.\(edge.rawValue)")
        }
    }

    private func candidateCard(
        _ candidate: ReconstructionCandidate,
        blockedReason: ReconstructionBlockedReason?
    ) -> some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            Label("Suggested fast · Needs review", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(UFastTheme.action)
                .accessibilityIdentifier("reconstruction.suggested-status")
            Text(ElapsedTimeFormatter.string(from: candidate.duration))
                .font(.uFastDisplay(.title2))
                .foregroundStyle(UFastTheme.primary)
            TemporalProposalRibbon(
                start: candidate.startDate,
                end: candidate.endDate,
                startTitle: candidate.startBoundary.description,
                endTitle: candidate.endBoundary.description
            )
            boundary(candidate.startBoundary, label: "From")
            boundary(candidate.endBoundary, label: "To")
            Text("Between two saved caloric entries.")
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)

            if blockedReason == .savedHistoryConflict {
                Label("A saved fast overlaps this period.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(UFastTheme.error)
                choiceButton(
                    "Leave unknown",
                    symbol: "questionmark.circle",
                    candidate: candidate,
                    choice: .leaveUnknown
                )
            } else {
                choiceButton("Accept", symbol: "checkmark.circle", candidate: candidate, choice: .accept)
                Button {
                    adjustment = ReconstructionAdjustmentPresentation(
                        candidate: candidate,
                        initialStartDate: adjustedDates(candidate)?.start ?? candidate.startDate,
                        initialEndDate: adjustedDates(candidate)?.end ?? candidate.endDate
                    )
                } label: {
                    choiceLabel(
                        "Adjust",
                        symbol: "pencil",
                        selected: isAdjusted(candidate)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reconstruction.adjust.\(candidate.pair.start.id.uuidString)")
                choiceButton(
                    "Leave unknown",
                    symbol: "questionmark.circle",
                    candidate: candidate,
                    choice: .leaveUnknown
                )
            }
        }
        .uFastCard(accent: UFastTheme.sage)
        .accessibilityIdentifier("reconstruction.candidate.\(candidate.pair.start.id.uuidString)")
    }

    private func choiceButton(
        _ title: String,
        symbol: String,
        candidate: ReconstructionCandidate,
        choice: ReconstructionReviewChoice
    ) -> some View {
        Button {
            choices[candidate.pair] = choice
        } label: {
            choiceLabel(title, symbol: symbol, selected: choices[candidate.pair] == choice)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "reconstruction.\(title.lowercased().replacingOccurrences(of: " ", with: "-")).\(candidate.pair.start.id.uuidString)"
        )
    }

    private func choiceLabel(_ title: String, symbol: String, selected: Bool) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(UFastTheme.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, UFastTheme.Spacing.standard)
        .background(selected ? UFastTheme.sage.opacity(0.35) : UFastTheme.raisedSurface)
        .clipShape(RoundedRectangle(cornerRadius: UFastTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: UFastTheme.Radius.control)
                .stroke(selected ? UFastTheme.action : UFastTheme.border, lineWidth: 1)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func boundary(_ boundary: CaloricBoundary, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(UFastTheme.secondaryText)
            Text(boundary.description)
                .font(.headline)
                .foregroundStyle(UFastTheme.primary)
            Text(formatted(boundary.occurredAt))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
        }
    }

    private var noResultsView: some View {
        let message = if generation.caloricBoundaryCount < 2 {
            "Not enough confirmed entries."
        } else if generation.qualifyingPairCount == 0 {
            "No periods of 8 hours or longer."
        } else {
            "This range is already reviewed."
        }
        return Label(message, systemImage: "checkmark.circle")
            .foregroundStyle(UFastTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .uFastCard()
            .accessibilityIdentifier("reconstruction.no-results")
    }

    private func save() {
        let reviewed = reviewableResults.compactMap { result -> ReviewedReconstruction? in
            guard let pair = result.candidate?.pair, let choice = choices[pair] else { return nil }
            return ReviewedReconstruction(result: result, choice: choice)
        }
        guard reviewed.count == reviewableResults.count else { return }

        isSaving = true
        do {
            try onSave(reviewed)
            saveError = nil
        } catch ReconstructionPersistenceError.staleEvidence {
            choices.removeAll()
            isSaving = false
            saveError = "Your entries changed. Review the updated periods before saving."
            onRefresh()
        } catch {
            isSaving = false
            saveError = "Reviewed history couldn’t be saved. Nothing changed. Please try again."
        }
    }

    private func adjustedDates(_ candidate: ReconstructionCandidate) -> (start: Date, end: Date)? {
        guard case let .adjust(startDate, endDate) = choices[candidate.pair] else { return nil }
        return (startDate, endDate)
    }

    private func isAdjusted(_ candidate: ReconstructionCandidate) -> Bool {
        if case .adjust = choices[candidate.pair] {
            return true
        }
        return false
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: timeZone
            )
        )
    }
}

struct ReconstructionAdjustmentPresentation: Identifiable {
    let id = UUID()
    let candidate: ReconstructionCandidate
    let initialStartDate: Date
    let initialEndDate: Date
}

struct ReconstructionAdjustmentView: View {
    let presentation: ReconstructionAdjustmentPresentation
    let onSave: (Date, Date) -> Void
    let onCancel: () -> Void
    @State private var startDate: Date
    @State private var endDate: Date

    init(
        presentation: ReconstructionAdjustmentPresentation,
        onSave: @escaping (Date, Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onSave = onSave
        self.onCancel = onCancel
        _startDate = State(initialValue: presentation.initialStartDate)
        _endDate = State(initialValue: presentation.initialEndDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Start") {
                    DatePicker(
                        "Start",
                        selection: $startDate,
                        in: presentation.candidate.startDate ... presentation.candidate.endDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Section("End") {
                    DatePicker(
                        "End",
                        selection: $endDate,
                        in: presentation.candidate.startDate ... presentation.candidate.endDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                if startDate >= endDate {
                    Label("Start must be before end.", systemImage: "exclamationmark.circle")
                        .foregroundStyle(UFastTheme.error)
                }
            }
            .navigationTitle("Adjust reconstructed fast")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(UFastTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save adjustment") { onSave(startDate, endDate) }
                        .disabled(startDate >= endDate)
                }
            }
        }
    }
}
