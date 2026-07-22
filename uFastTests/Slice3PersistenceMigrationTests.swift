import SwiftData
@testable import uFast
import XCTest

@MainActor
final class Slice3PersistenceMigrationTests: XCTestCase {
    func testRecordedAndReconstructedHistorySurviveDiskReopenWithAdditiveDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "uFast-slice3-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "history.store")
        let recordedID = UUID()
        let reconstructedID = UUID()
        let startReference = CaloricBoundaryReference(kind: .food, id: UUID())
        let endReference = CaloricBoundaryReference(kind: .hydration, id: UUID())

        do {
            let container = try PersistenceContainer.make(storeURL: storeURL)
            let context = container.mainContext
            try context.insert(
                FastRecord(
                    id: recordedID,
                    startDate: Date(timeIntervalSince1970: 1000),
                    endDate: Date(timeIntervalSince1970: 50000),
                    goalAtStart: XCTUnwrap(FastingGoal(hours: 16))
                )
            )
            context.insert(
                FastRecord(
                    id: reconstructedID,
                    reconstructedStart: Date(timeIntervalSince1970: 60000),
                    endDate: Date(timeIntervalSince1970: 110_000),
                    boundaries: .init(start: startReference, end: endReference),
                    adjustedByUser: true
                )
            )
            try context.save()
        }

        let reopened = try PersistenceContainer.make(storeURL: storeURL)
        let fasts = try reopened.mainContext.fetch(FetchDescriptor<FastRecord>())
        let recorded = try XCTUnwrap(fasts.first { $0.id == recordedID })
        XCTAssertEqual(recorded.origin, .recorded)
        XCTAssertEqual(recorded.reviewState, .confirmed)
        XCTAssertEqual(recorded.capturedHistoricalGoal?.hours, 16)
        XCTAssertNil(recorded.boundaryPair)

        let reconstructed = try XCTUnwrap(fasts.first { $0.id == reconstructedID })
        XCTAssertEqual(reconstructed.origin, .reconstructed)
        XCTAssertTrue(reconstructed.wasAdjustedByUser)
        XCTAssertNil(reconstructed.capturedHistoricalGoal)
        XCTAssertEqual(
            reconstructed.boundaryPair,
            .init(start: startReference, end: endReference)
        )
    }
}
