import SwiftUI

struct AddDrinkSheet: View {
    @State private var isSaving = false
    @State private var saveError: String?

    let favourites: [HydrationFavourite]
    let onAdd: (HydrationFavourite) throws -> Void
    let onChooseAnother: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UFastTheme.Spacing.generous) {
                    UFastSectionHeading("Favourites")
                    ForEach(favourites, id: \.type) { favourite in
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
                                    Text(favourite.type.displayName)
                                        .font(.headline)
                                        .foregroundStyle(UFastTheme.primary)
                                    Text("\(favourite.volumeMillilitres) ml")
                                        .foregroundStyle(UFastTheme.secondaryText)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(UFastActionRowButtonStyle())
                        .disabled(isSaving)
                        .accessibilityLabel(favourite.type.displayName)
                        .accessibilityValue("\(favourite.volumeMillilitres) millilitres")
                        .accessibilityIdentifier("drink.favourite.\(favourite.type.rawValue)")
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
        } catch {
            saveError = "Your drink couldn’t be added. Please try again."
            isSaving = false
        }
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
