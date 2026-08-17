import SwiftUI

struct AddDrinkSheet: View {
    @State private var isSaving = false
    @State private var saveError: String?

    let favourites: [HydrationFavourite]
    let onAdd: (HydrationFavourite) throws -> Void
    var onConfirmationRequired: (HydrationFavourite, CaloricEventConfirmationContext) -> Void = { _, _ in }
    let onChooseAnother: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    UFastSectionHeading("Favourites")
                    ForEach(favourites) { favourite in
                        Button {
                            add(favourite)
                        } label: {
                            HStack(spacing: UFastTheme.Spacing.standard) {
                                Image(systemName: symbol(for: favourite.type))
                                    .font(.title2)
                                    .foregroundStyle(UFastTheme.action)
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(favourite.displayName)
                                        .font(.headline)
                                        .foregroundStyle(UFastTheme.primary)
                                    Text(
                                        "\(favourite.volumeMillilitres) ml · "
                                            + "\(favourite.isCaloric ? "Caloric" : "Non-caloric")"
                                    )
                                    .foregroundStyle(UFastTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(UFastActionRowButtonStyle())
                        .disabled(isSaving)
                        .accessibilityLabel(favourite.displayName)
                        .accessibilityValue("\(favourite.volumeMillilitres) millilitres")
                        .accessibilityHint(favourite.isCaloric ? "Caloric" : "Non-caloric")
                        .accessibilityIdentifier(identifier(for: favourite))
                    }

                    Button("Add another drink") { onChooseAnother() }
                        .buttonStyle(UFastSecondaryButtonStyle())
                        .accessibilityIdentifier("drink.custom")

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(UFastTheme.error)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("drink.save-error")
                    }
                }
                .padding(UFastTheme.Spacing.standard)
            }
            .accessibilityIdentifier("drink.picker")
            .background(UFastTheme.canvas)
            .navigationTitle("Add a drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("drink.cancel")
                }
            }
        }
    }

    private func add(_ favourite: HydrationFavourite) {
        guard !isSaving else { return }
        isSaving = true
        do {
            try onAdd(favourite)
            saveError = nil
        } catch HydrationEntrySaveError.confirmationRequired {
            isSaving = false
            onConfirmationRequired(favourite, .init(fallbackKind: .active))
        } catch let HydrationEntrySaveError.confirmationRequiredWithImpact(context) {
            isSaving = false
            onConfirmationRequired(favourite, context)
        } catch HydrationEntrySaveError.completedFastConfirmationRequired {
            isSaving = false
            onConfirmationRequired(favourite, .init(fallbackKind: .completed))
        } catch let HydrationEntrySaveError.completedConfirmationWithImpact(context) {
            isSaving = false
            onConfirmationRequired(favourite, context)
        } catch HydrationEntrySaveError.inferredFastConfirmationRequired {
            isSaving = false
            onConfirmationRequired(favourite, .init(fallbackKind: .inferred))
        } catch let HydrationEntrySaveError.inferredConfirmationWithImpact(context) {
            isSaving = false
            onConfirmationRequired(favourite, context)
        } catch {
            saveError = "Your drink couldn’t be added. Please try again."
            isSaving = false
        }
    }

    private func identifier(for favourite: HydrationFavourite) -> String {
        favourite.isUserCreated
            ? "drink.favourite.custom.\(favourite.id.uuidString)"
            : "drink.favourite.\(favourite.type.rawValue)"
    }

    private func symbol(for type: HydrationDrinkType) -> String {
        switch type {
        case .water: "drop.fill"
        case .tea: "cup.and.saucer.fill"
        case .coffee: "mug.fill"
        case .custom: "waterbottle.fill"
        }
    }
}
