import Foundation
import SwiftData

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable function_parameter_count

enum HydrationDrinkType: String, CaseIterable {
    case water
    case tea
    case coffee
    case custom

    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class HydrationEntryRecord {
    var id: UUID = UUID()
    private(set) var drinkTypeRaw: String = HydrationDrinkType.water.rawValue
    private(set) var customName: String?
    private(set) var volumeMillilitres: Int = 500
    private(set) var occurredAt: Date = Date.now
    private(set) var isCaloric: Bool = false
    private(set) var createdAt: Date = Date.now
    private(set) var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        type: HydrationDrinkType,
        customName: String? = nil,
        volumeMillilitres: Int,
        occurredAt: Date,
        isCaloric: Bool,
        createdAt: Date
    ) {
        self.id = id
        drinkTypeRaw = type.rawValue
        self.customName = customName
        self.volumeMillilitres = volumeMillilitres
        self.occurredAt = occurredAt
        self.isCaloric = isCaloric
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    var drinkType: HydrationDrinkType {
        HydrationDrinkType(rawValue: drinkTypeRaw) ?? .custom
    }

    var displayName: String {
        drinkType == .custom ? (customName ?? "Drink") : drinkType.displayName
    }

    var draft: HydrationEntryDraft {
        HydrationEntryDraft(
            type: drinkType,
            customName: customName,
            volumeMillilitres: volumeMillilitres,
            occurredAt: occurredAt,
            isCaloric: isCaloric
        )
    }

    func update(from draft: HydrationEntryDraft, at updatedAt: Date) {
        update(
            type: draft.type,
            customName: draft.customName,
            volumeMillilitres: draft.volumeMillilitres,
            occurredAt: draft.occurredAt,
            isCaloric: draft.isCaloric,
            updatedAt: updatedAt
        )
    }

    func update(
        type: HydrationDrinkType,
        customName: String?,
        volumeMillilitres: Int,
        occurredAt: Date,
        isCaloric: Bool,
        updatedAt: Date
    ) {
        drinkTypeRaw = type.rawValue
        self.customName = customName
        self.volumeMillilitres = volumeMillilitres
        self.occurredAt = occurredAt
        self.isCaloric = isCaloric
        self.updatedAt = updatedAt
    }
}
