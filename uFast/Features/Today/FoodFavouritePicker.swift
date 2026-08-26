import SwiftUI

struct FoodFavouritePicker: View {
    @Environment(\.appTextResolver) private var textResolver
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var commitState: FoodFavouriteCommitState?
    @State private var failedFavourite: FoodFavouriteSnapshot?
    @State private var failedOperation: FoodFavouriteQuickAddOperation?

    let clock: any AppClock
    let favourites: [FoodFavouriteSnapshot]
    let onAdd: (FoodFavouriteSnapshot, FoodFavouriteQuickAddOperation) throws -> Void
    var onConfirmationRequired: (
        FoodFavouriteSnapshot,
        FoodFavouriteQuickAddOperation,
        CaloricEventConfirmationContext
    ) -> Void = { _, _, _ in }
    let onChooseAnother: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    UFastSectionHeading(textResolver(.foodFavouritePickerHeading))
                    ForEach(favourites) { favourite in
                        Button { add(favourite) } label: {
                            HStack(spacing: UFastTheme.Spacing.standard) {
                                Image(systemName: "fork.knife")
                                    .font(.title2)
                                    .foregroundStyle(UFastTheme.action)
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(favourite.description)
                                        .font(.headline)
                                        .foregroundStyle(UFastTheme.primary)
                                    Text(
                                        textResolver(
                                            .foodFavouriteDetail(
                                                hasNutrition: !favourite.nutrition.values.isEmpty
                                            )
                                        )
                                    )
                                    .foregroundStyle(UFastTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(UFastActionRowButtonStyle())
                        .disabled(isSaving)
                        .accessibilityLabel(favourite.description)
                        .accessibilityValue(
                            textResolver(
                                .foodFavouriteAccessibilityValue(
                                    hasNutrition: !favourite.nutrition.values.isEmpty
                                )
                            )
                        )
                        .accessibilityIdentifier("food.favourite.\(favourite.id.uuidString)")
                    }

                    Button(textResolver(.foodFavouriteAddAnother), action: onChooseAnother)
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("food.custom")

                    if let commitState {
                        Text(textResolver(.foodFavouriteCommitState(commitState)))
                            .foregroundStyle(
                                commitState == .failure || commitState == .stale
                                    ? UFastTheme.error
                                    : UFastTheme.secondaryText
                            )
                            .accessibilityIdentifier("food.favourite.commit-state")
                        if commitState == .success {
                            Text(textResolver(.foodFavouriteCommitState(.success)))
                                .accessibilityIdentifier("food.favourite.success")
                        } else if commitState == .stale {
                            Text(textResolver(.foodFavouriteCommitState(.stale)))
                                .accessibilityIdentifier("food.favourite.stale")
                        }
                    }
                    if let saveError {
                        VStack(alignment: .leading, spacing: UFastTheme.Spacing.standard) {
                            Label(saveError, systemImage: "exclamationmark.circle")
                                .foregroundStyle(UFastTheme.error)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("food.favourite.save-error")
                            if let failedFavourite {
                                Button(textResolver(.foodFavouriteRetry)) {
                                    add(failedFavourite, operation: failedOperation)
                                }
                                .buttonStyle(UFastSecondaryButtonStyle())
                                .accessibilityIdentifier("food.favourite.retry")
                            }
                        }
                    }
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .accessibilityIdentifier("food.picker")
            .background(UFastTheme.canvas)
            .navigationTitle(textResolver(.foodFavouritePickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(textResolver(.cancel), action: onCancel)
                        .accessibilityIdentifier("food.cancel")
                }
            }
        }
    }

    private func add(
        _ favourite: FoodFavouriteSnapshot,
        operation: FoodFavouriteQuickAddOperation? = nil
    ) {
        guard !isSaving else { return }
        let operation = operation ?? FoodFavouriteQuickAddOperation(
            favouriteID: favourite.id,
            occurredAt: clock.now
        )
        isSaving = true
        failedFavourite = nil
        failedOperation = nil
        saveError = nil
        commitState = .saving
        do {
            try onAdd(favourite, operation)
            commitState = .success
        } catch let FoodEntrySaveError.confirmationRequiredWithImpact(context) {
            isSaving = false
            commitState = nil
            onConfirmationRequired(favourite, operation, context)
        } catch let FoodEntrySaveError.completedConfirmationWithImpact(context) {
            isSaving = false
            commitState = nil
            onConfirmationRequired(favourite, operation, context)
        } catch let FoodEntrySaveError.inferredConfirmationWithImpact(context) {
            isSaving = false
            commitState = nil
            onConfirmationRequired(favourite, operation, context)
        } catch let FoodFavouriteStoreError.stale {
            isSaving = false
            failedFavourite = favourite
            failedOperation = operation
            commitState = .stale
            saveError = textResolver(.foodFavouriteCommitState(.stale))
        } catch let FoodFavouriteStoreError.recordNotFound {
            isSaving = false
            failedFavourite = favourite
            failedOperation = operation
            commitState = .stale
            saveError = textResolver(.foodFavouriteCommitState(.stale))
        } catch {
            isSaving = false
            failedFavourite = favourite
            failedOperation = operation
            commitState = .failure
            saveError = textResolver(.foodFavouriteAddError)
        }
    }
}
