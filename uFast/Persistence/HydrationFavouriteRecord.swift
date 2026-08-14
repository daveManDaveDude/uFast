import Foundation
import SwiftData

@Model
final class HydrationFavouriteRecord {
    var id: UUID = UUID()
    var name: String = ""
    var volumeMillilitres: Int = 1
    var isCaloric: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var creationOrder: Int64 = 0

    init(
        id: UUID = UUID(),
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        createdAt: Date,
        updatedAt: Date? = nil,
        creationOrder: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.volumeMillilitres = volumeMillilitres
        self.isCaloric = isCaloric
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.creationOrder = creationOrder
    }

    var snapshot: HydrationFavouriteSnapshot {
        HydrationFavouriteSnapshot(
            id: id,
            name: name,
            volumeMillilitres: volumeMillilitres,
            isCaloric: isCaloric,
            createdAt: createdAt,
            updatedAt: updatedAt,
            creationOrder: creationOrder
        )
    }

    func update(
        name: String,
        volumeMillilitres: Int,
        isCaloric: Bool,
        updatedAt: Date
    ) {
        self.name = name
        self.volumeMillilitres = volumeMillilitres
        self.isCaloric = isCaloric
        self.updatedAt = updatedAt
    }
}
