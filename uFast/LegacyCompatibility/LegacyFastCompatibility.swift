import Foundation

typealias ReconstructionBoundaryPair = CaloricBoundaryPair

/// The only supported compatibility contract for pre-D-024 reconstruction
/// records. New application flows must not create or repair these records.
enum LegacyFastCompatibility {
    static func isExactlyReproducible(
        startDate: Date,
        endDate: Date,
        boundaries: ReconstructionBoundaryPair?,
        caloricBoundaries: [CaloricBoundary]
    ) -> Bool {
        AutomaticFastProjector.isExactProjection(
            startDate: startDate,
            endDate: endDate,
            boundaries: boundaries,
            caloricBoundaries: caloricBoundaries
        )
    }
}

extension FastRecord {
    var recordedInterval: RecordedFastInterval {
        RecordedFastInterval(id: id, startDate: startDate, endDate: endDate)
    }
}
