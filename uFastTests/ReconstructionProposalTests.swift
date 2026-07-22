@testable import uFast
import XCTest

// swiftlint:disable blanket_disable_command superfluous_disable_command
// swiftlint:disable force_unwrapping trailing_comma

final class ReconstructionProposalTests: XCTestCase {
    private let rangeStart = Date(timeIntervalSince1970: 2_000_000_000)

    func testThirteenHourCaloricPairProducesOneTypedProposal() throws {
        let foodID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let drinkID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let boundaries = CaloricBoundaryExtractor.boundaries(
            food: [
                FoodBoundarySnapshot(
                    id: foodID,
                    occurredAt: rangeStart.addingTimeInterval(60 * 60),
                    description: "Dinner",
                    isCaloric: true
                ),
            ],
            hydration: [
                HydrationBoundarySnapshot(
                    id: drinkID,
                    occurredAt: rangeStart.addingTimeInterval(14 * 60 * 60),
                    description: "Caloric drink",
                    isCaloric: true
                ),
            ]
        )

        let generation = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: boundaries,
            savedFasts: []
        )
        let proposal = try XCTUnwrap(
            generation.results.compactMap { result -> ReconstructionCandidate? in
                if case let .proposal(candidate) = result {
                    return candidate
                }
                return nil
            }.first
        )

        XCTAssertEqual(proposal.duration, 13 * 60 * 60)
        XCTAssertEqual(proposal.pair.start, .init(kind: .food, id: foodID))
        XCTAssertEqual(proposal.pair.end, .init(kind: .hydration, id: drinkID))
    }

    func testNonCaloricHydrationNeverSplitsEvidence() {
        let dinner = boundary(.food, 1, hours: 1)
        let water = HydrationBoundarySnapshot(
            id: uuid(2),
            occurredAt: rangeStart.addingTimeInterval(6 * 60 * 60),
            description: "Water",
            isCaloric: false
        )
        let breakfast = boundary(.food, 3, hours: 14)
        let extracted = CaloricBoundaryExtractor.boundaries(
            food: [snapshot(dinner), snapshot(breakfast)],
            hydration: [water]
        )

        let candidates = proposalCandidates(
            ReconstructionProposalGenerator.generate(
                range: range,
                boundaries: extracted,
                savedFasts: []
            )
        )
        XCTAssertEqual(candidates.map(\.duration), [TimeInterval(13 * 60 * 60)])
    }

    func testThresholdIsAbsoluteAndUnderEightHoursProducesNothing() {
        let under = [boundary(.food, 1, hours: 1), boundary(.food, 2, seconds: 9 * 60 * 60 - 1)]
        let exact = [boundary(.food, 1, hours: 1), boundary(.food, 2, hours: 9)]

        XCTAssertTrue(
            proposalCandidates(
                ReconstructionProposalGenerator.generate(
                    range: range,
                    boundaries: under,
                    savedFasts: []
                )
            ).isEmpty
        )
        XCTAssertEqual(
            proposalCandidates(
                ReconstructionProposalGenerator.generate(
                    range: range,
                    boundaries: exact,
                    savedFasts: []
                )
            ).count,
            1
        )
    }

    func testOutsideRangeNeighboursCanCloseCandidatesAndMissingEdgesRemainInsufficient() {
        let before = boundary(.food, 1, hours: -2)
        let inside = boundary(.food, 2, hours: 10)
        let after = boundary(.hydration, 3, hours: 26)
        let complete = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [before, inside, after],
            savedFasts: []
        )

        XCTAssertEqual(proposalCandidates(complete).count, 2)
        XCTAssertFalse(complete.results.contains(.insufficientEdge(.start)))
        XCTAssertFalse(complete.results.contains(.insufficientEdge(.end)))

        let open = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [inside],
            savedFasts: []
        )
        XCTAssertTrue(open.results.contains(.insufficientEdge(.start)))
        XCTAssertTrue(open.results.contains(.insufficientEdge(.end)))
    }

    func testConflictsBlockRecordedReconstructedNeedsReviewAndActiveButTouchingDoesNot() {
        let boundaries = [boundary(.food, 1, hours: 1), boundary(.food, 2, hours: 14)]
        let candidateStart = boundaries[0].occurredAt
        let candidateEnd = boundaries[1].occurredAt

        for interval in [
            RecordedFastInterval(id: uuid(10), startDate: candidateStart, endDate: candidateEnd),
            RecordedFastInterval(id: uuid(11), startDate: candidateStart.addingTimeInterval(1), endDate: candidateEnd),
            RecordedFastInterval(id: uuid(12), startDate: candidateStart, endDate: nil),
        ] {
            let result = ReconstructionProposalGenerator.generate(
                range: range,
                boundaries: boundaries,
                savedFasts: [interval]
            )
            XCTAssertTrue(result.results.contains {
                if case .blocked = $0 {
                    true
                } else {
                    false
                }
            })
        }

        let touching = RecordedFastInterval(
            id: uuid(13),
            startDate: candidateEnd,
            endDate: candidateEnd.addingTimeInterval(60 * 60)
        )
        XCTAssertEqual(
            proposalCandidates(
                ReconstructionProposalGenerator.generate(
                    range: range,
                    boundaries: boundaries,
                    savedFasts: [touching]
                )
            ).count,
            1
        )
    }

    func testRepresentedPairSuppressesDuplicateAndFetchOrderDoesNotMatter() {
        let first = boundary(.food, 9, hours: 1)
        let second = boundary(.hydration, 2, hours: 14)
        let expectedPair = ReconstructionBoundaryPair(start: first.reference, end: second.reference)
        let suppressed = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [second, first],
            savedFasts: [],
            representedPairs: [expectedPair]
        )
        XCTAssertEqual(suppressed.suppressedPairCount, 1)
        XCTAssertTrue(proposalCandidates(suppressed).isEmpty)

        let forward = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [first, second],
            savedFasts: []
        )
        let reverse = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [second, first],
            savedFasts: []
        )
        XCTAssertEqual(forward, reverse)
    }

    func testEqualTimestampsAndDuplicateIdentityNeverProducePositiveDuration() {
        let first = boundary(.hydration, 2, hours: 4)
        let second = boundary(.food, 1, hours: 4)
        let duplicate = CaloricBoundary(
            reference: first.reference,
            occurredAt: rangeStart.addingTimeInterval(16 * 60 * 60),
            description: "Duplicate"
        )
        let generation = ReconstructionProposalGenerator.generate(
            range: range,
            boundaries: [first, second, duplicate],
            savedFasts: []
        )
        XCTAssertTrue(proposalCandidates(generation).isEmpty)
        XCTAssertEqual(
            ReconstructionProposalGenerator.sortedBoundaries([first, second]).first?.reference.kind,
            .food
        )
    }

    func testDSTDoesNotChangeAbsoluteDuration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        let start = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 20))
        )
        let end = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 9))
        )
        let generation = ReconstructionProposalGenerator.generate(
            range: start.addingTimeInterval(-60) ..< end.addingTimeInterval(60),
            boundaries: [
                CaloricBoundary(reference: .init(kind: .food, id: uuid(1)), occurredAt: start, description: "Dinner"),
                CaloricBoundary(reference: .init(kind: .food, id: uuid(2)), occurredAt: end, description: "Breakfast"),
            ],
            savedFasts: []
        )
        XCTAssertEqual(try XCTUnwrap(proposalCandidates(generation).first).duration, 12 * 60 * 60)
    }

    private var range: Range<Date> {
        rangeStart ..< rangeStart.addingTimeInterval(24 * 60 * 60)
    }

    private func boundary(
        _ kind: CaloricBoundaryKind,
        _ identifier: Int,
        hours: Int
    ) -> CaloricBoundary {
        boundary(kind, identifier, seconds: hours * 60 * 60)
    }

    private func boundary(
        _ kind: CaloricBoundaryKind,
        _ identifier: Int,
        seconds: Int
    ) -> CaloricBoundary {
        CaloricBoundary(
            reference: .init(kind: kind, id: uuid(identifier)),
            occurredAt: rangeStart.addingTimeInterval(TimeInterval(seconds)),
            description: kind.rawValue
        )
    }

    private func snapshot(_ boundary: CaloricBoundary) -> FoodBoundarySnapshot {
        FoodBoundarySnapshot(
            id: boundary.reference.id,
            occurredAt: boundary.occurredAt,
            description: boundary.description,
            isCaloric: true
        )
    }

    private func proposalCandidates(_ generation: ReconstructionGeneration) -> [ReconstructionCandidate] {
        generation.results.compactMap {
            if case let .proposal(candidate) = $0 {
                return candidate
            }
            return nil
        }
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
