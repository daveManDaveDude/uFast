import SwiftUI

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable line_length

struct ReconstructedFastDetailView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    let fast: FastRecord
    let clock: any AppClock
    let repository: SwiftDataReconstructionRepository
    let onClose: () -> Void

    @State private var candidate: ReconstructionCandidate?
    @State private var updatedEvidence: UpdatedReconstructionEvidence?
    @State private var adjustment: ReconstructionAdjustmentPresentation?
    @State private var showsRemoveConfirmation = false
    @State private var showsKeepConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    if fast.reviewState == .needsReview {
                        Label("Needs review", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundStyle(UFastTheme.error)
                        Text("A supporting entry changed. Your saved fast has not been altered.")
                            .foregroundStyle(UFastTheme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                        if fast.reviewState == .needsReview {
                            UFastSectionHeading("Currently saved")
                        }
                        Text("Reconstructed · Confirmed by you")
                            .font(.headline)
                            .foregroundStyle(UFastTheme.action)
                        if fast.wasAdjustedByUser {
                            Label("Adjusted by you", systemImage: "pencil")
                                .foregroundStyle(UFastTheme.secondaryText)
                        }
                        Text(ElapsedTimeFormatter.string(from: fast.duration ?? 0))
                            .font(.uFastDisplay(.title))
                            .foregroundStyle(UFastTheme.primary)
                        Text("\(formatted(fast.startDate)) → \(formatted(fast.endDate ?? fast.startDate))")
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .uFastCard(accent: UFastTheme.sky)

                    if fast.reviewState == .needsReview {
                        updatedEvidenceSection
                    } else if let candidate {
                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            UFastSectionHeading("Supporting entries")
                            boundary(candidate.startBoundary, label: "From")
                            Divider()
                            boundary(candidate.endBoundary, label: "To")
                        }
                        .uFastCard()
                    } else {
                        Label(
                            "A supporting entry is no longer available.",
                            systemImage: "exclamationmark.circle"
                        )
                        .foregroundStyle(UFastTheme.secondaryText)
                        .uFastCard()
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                    }

                    if fast.reviewState == .confirmed, let candidate {
                        Button("Adjust reconstructed fast") {
                            adjustment = ReconstructionAdjustmentPresentation(
                                candidate: candidate,
                                initialStartDate: fast.startDate,
                                initialEndDate: fast.endDate ?? candidate.endDate
                            )
                        }
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("history.reconstructed.adjust")
                    }

                    if fast.reviewState == .needsReview {
                        Button("Update and reconfirm", action: updateAndReconfirm)
                            .buttonStyle(UFastPrimaryButtonStyle())
                            .disabled(!hasAvailableUpdatedEvidence)
                            .accessibilityIdentifier("history.needs-review.update")

                        Button("Keep as recorded fast") {
                            showsKeepConfirmation = true
                        }
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("history.needs-review.keep-recorded")
                    }

                    Button("Remove and leave unknown", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .buttonStyle(UFastDestructiveButtonStyle())
                    .accessibilityIdentifier("history.reconstructed.remove")
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .background(UFastTheme.canvas)
            .navigationTitle(fast.reviewState == .needsReview ? "Review changed history" : "Reconstructed fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onClose) }
            }
            .onAppear(perform: loadEvidence)
            .sheet(item: $adjustment) { presentation in
                ReconstructionAdjustmentView(
                    presentation: presentation,
                    onSave: { startDate, endDate in
                        do {
                            try repository.adjustReconstructedFast(
                                id: fast.id,
                                startDate: startDate,
                                endDate: endDate
                            )
                            adjustment = nil
                            errorMessage = nil
                        } catch {
                            errorMessage = "This reconstructed fast couldn’t be adjusted. Please try again."
                        }
                    },
                    onCancel: { adjustment = nil }
                )
            }
            .alert("Remove and leave this period unknown?", isPresented: $showsRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove fast", role: .destructive, action: remove)
            } message: {
                Text("The reconstructed fast is removed and a bounded Unknown period remains.")
            }
            .alert("Keep this as a recorded fast?", isPresented: $showsKeepConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Keep as recorded fast", action: keepAsRecorded)
            } message: {
                Text("The saved interval stays unchanged. It will no longer depend on supporting entries, and no historical goal will be added.")
            }
        }
    }

    private var updatedEvidenceSection: some View {
        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
            UFastSectionHeading("Updated evidence")
            switch updatedEvidence {
            case let .available(candidate):
                boundary(candidate.startBoundary, label: "From")
                Divider()
                boundary(candidate.endBoundary, label: "To")
                Text(ElapsedTimeFormatter.string(from: candidate.duration))
                    .font(.headline)
            case let .unavailable(reason):
                Label(reason.explanation, systemImage: "exclamationmark.circle")
                    .foregroundStyle(UFastTheme.secondaryText)
            case nil:
                Text("Checking current saved entries…")
                    .foregroundStyle(UFastTheme.secondaryText)
            }
        }
        .uFastCard()
    }

    private var hasAvailableUpdatedEvidence: Bool {
        if case .available = updatedEvidence {
            return true
        }
        return false
    }

    private func loadEvidence() {
        if fast.reviewState == .needsReview {
            do {
                updatedEvidence = try repository.updatedEvidence(for: fast)
            } catch {
                updatedEvidence = .unavailable(.missingSupportingEntry)
                errorMessage = "Updated evidence couldn’t be loaded. Your saved fast is unchanged."
            }
        } else {
            candidate = try? repository.supportingCandidate(for: fast)
        }
    }

    private func updateAndReconfirm() {
        do {
            try repository.updateAndReconfirm(id: fast.id)
            onClose()
        } catch {
            errorMessage = "This fast couldn’t be updated. Your saved fast is unchanged."
            loadEvidence()
        }
    }

    private func keepAsRecorded() {
        do {
            try repository.keepAsRecordedFast(id: fast.id)
            onClose()
        } catch {
            errorMessage = "This fast couldn’t be converted. Your saved fast is unchanged."
        }
    }

    private func boundary(_ boundary: CaloricBoundary, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(UFastTheme.secondaryText)
            Text(boundary.description).font(.headline).foregroundStyle(UFastTheme.primary)
            Text(formatted(boundary.occurredAt))
                .font(.subheadline)
                .foregroundStyle(UFastTheme.secondaryText)
        }
    }

    private func remove() {
        do {
            try repository.removeAndLeaveUnknown(id: fast.id)
            onClose()
        } catch {
            errorMessage = "This reconstructed fast couldn’t be removed. Nothing changed."
        }
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

struct UnknownPeriodDetailView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    let unknown: UnknownPeriodRecord
    let repository: SwiftDataReconstructionRepository
    let onClose: () -> Void
    @State private var showsRemoveConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                        Label("Unknown period", systemImage: "questionmark.circle")
                            .font(.headline)
                        Text("\(formatted(unknown.startDate)) → \(formatted(unknown.endDate))")
                            .foregroundStyle(UFastTheme.primary)
                        Text(unknown.reason.explanation)
                            .foregroundStyle(UFastTheme.secondaryText)
                    }
                    .uFastCard()

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                    }

                    Button("Remove unknown marker", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .buttonStyle(UFastDestructiveButtonStyle())
                    .accessibilityIdentifier("history.unknown.remove")
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .background(UFastTheme.canvas)
            .navigationTitle("Unknown period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onClose) }
            }
            .alert("Remove this unknown marker?", isPresented: $showsRemoveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove marker", role: .destructive, action: remove)
            } message: {
                Text("A later catch-up may offer this bounded period for review again.")
            }
        }
    }

    private func remove() {
        do {
            try repository.removeUnknownMarker(id: unknown.id)
            onClose()
        } catch {
            errorMessage = "This marker couldn’t be removed. Please try again."
        }
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
