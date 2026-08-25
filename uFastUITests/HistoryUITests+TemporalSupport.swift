import XCTest

private enum HistoryTemporalIdentifiers {
    static let activeFast = "history.active-fast.10200000-0000-0000-0000-000000000002"
    static let activeFastVisualContent = "history.active-fast-content.10200000-0000-0000-0000-000000000002"
    static let activeFastDetail = "history.fast.10200000-0000-0000-0000-000000000002"
    static let noonMarker = "history.visual-event.10200000-0000-0000-0000-000000000013"
}

extension HistoryUITests {
    struct SettledSeamState {
        let activeFrame: CGRect
        let activeLabel: String
        let visualOwnerLabelCount: Int
        let selectedDateLabel: String
        let noonMarkerVisible: Bool
        let noonMarkerFrameIntersectsCarousel: Bool
    }

    @MainActor
    func settledSeamState(
        in app: XCUIApplication,
        expectedSelectedDate: String
    ) -> SettledSeamState? {
        let carousel = app.scrollViews["history.day-carousel"]
        let selectedDate = app.staticTexts["history.selected-date"]
        let semanticPanel = app.otherElements["history.event-info-panel"]
        let activeFastDetail = semanticPanel.buttons[HistoryTemporalIdentifiers.activeFastDetail]
        guard carousel.waitForExistence(timeout: 5),
              selectedDate.waitForExistence(timeout: 5),
              semanticPanel.waitForExistence(timeout: 5),
              waitForSettledHistory(
                  selectedDate: selectedDate,
                  carousel: carousel,
                  expectedSelectedDate: expectedSelectedDate
              ),
              let activeFast = visibleActiveElement(
                  in: app,
                  carousel: carousel,
                  identifier: HistoryTemporalIdentifiers.activeFast
              ),
              activeFastDetail.waitForExistence(timeout: 5)
        else { return nil }
        let activeFastVisualContent = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@",
                HistoryTemporalIdentifiers.activeFastVisualContent
            )
        )
        let visibleActiveFastVisualContent = Self.visibleElements(
            in: activeFastVisualContent,
            boundedBy: carousel
        )
        let noonMarker = visibleNoonElement(
            in: app,
            carousel: carousel,
            identifier: HistoryTemporalIdentifiers.noonMarker
        )
        return SettledSeamState(
            activeFrame: activeFast.frame,
            activeLabel: activeFastDetail.label,
            visualOwnerLabelCount: visibleActiveFastVisualContent.count,
            selectedDateLabel: selectedDate.label,
            noonMarkerVisible: noonMarker != nil,
            noonMarkerFrameIntersectsCarousel: noonMarker.map {
                carousel.frame.intersects($0.frame)
            } ?? false
        )
    }

    @MainActor
    func visibleActiveElement(
        in app: XCUIApplication,
        carousel: XCUIElement,
        identifier: String
    ) -> XCUIElement? {
        let candidates = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@",
                identifier
            )
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Self.visibleElement(in: candidates, boundedBy: carousel) != nil
            },
            object: app
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            return nil
        }
        return Self.visibleElement(in: candidates, boundedBy: carousel)
    }

    @MainActor
    func visibleNoonElement(
        in app: XCUIApplication,
        carousel: XCUIElement,
        identifier: String
    ) -> XCUIElement? {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier == %@", identifier)
        )
        return (0 ..< candidates.count)
            .map { candidates.element(boundBy: $0) }
            .first {
                $0.exists
                    && $0.label.contains("12:00")
                    && Self.isVisibleFrame($0.frame, boundedBy: carousel.frame)
            }
    }

    @MainActor
    static func visibleElement(
        in query: XCUIElementQuery,
        boundedBy container: XCUIElement
    ) -> XCUIElement? {
        visibleElements(in: query, boundedBy: container).first
    }

    @MainActor
    static func visibleElements(
        in query: XCUIElementQuery,
        boundedBy container: XCUIElement
    ) -> [XCUIElement] {
        (0 ..< query.count)
            .map { query.element(boundBy: $0) }
            .filter {
                $0.exists && isVisibleFrame($0.frame, boundedBy: container.frame)
            }
    }

    static func isVisibleFrame(_ candidate: CGRect, boundedBy container: CGRect) -> Bool {
        guard candidate.origin.x.isFinite, candidate.origin.y.isFinite,
              candidate.size.width.isFinite, candidate.size.height.isFinite,
              container.origin.x.isFinite, container.origin.y.isFinite,
              container.size.width.isFinite, container.size.height.isFinite,
              candidate.width > 0, candidate.height > 0,
              container.width > 0, container.height > 0
        else { return false }
        let visibilityTolerance = 0.5
        return candidate.minX >= container.minX - visibilityTolerance
            && candidate.maxX <= container.maxX + visibilityTolerance
            && candidate.minY >= container.minY - visibilityTolerance
            && candidate.maxY <= container.maxY + visibilityTolerance
    }

    static func intersectsVisibleFrame(_ candidate: CGRect, with container: CGRect) -> Bool {
        guard candidate.origin.x.isFinite, candidate.origin.y.isFinite,
              candidate.size.width.isFinite, candidate.size.height.isFinite,
              container.origin.x.isFinite, container.origin.y.isFinite,
              container.size.width.isFinite, container.size.height.isFinite,
              candidate.width > 0, candidate.height > 0,
              container.width > 0, container.height > 0
        else { return false }
        return candidate.intersects(container)
    }

    @MainActor
    func visibleActiveFast(
        in app: XCUIApplication,
        carousel: XCUIElement
    ) -> XCUIElement? {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.active-fast.")
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Self.visibleElement(in: candidates, boundedBy: carousel) != nil
            },
            object: app
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            return nil
        }
        return Self.visibleElement(in: candidates, boundedBy: carousel)
    }

    @MainActor
    func visibleActiveFastVisualContent(
        in app: XCUIApplication,
        carousel: XCUIElement
    ) -> [XCUIElement] {
        let candidates = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "history.active-fast-content.")
        )
        return Self.visibleElements(in: candidates, boundedBy: carousel)
    }

    @MainActor
    func historyMarkerIdentifiers(in app: XCUIApplication) -> Set<String> {
        let markers = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                "history.event.",
                "history.visual-event."
            )
        )
        return Set((0 ..< markers.count).map { markers.element(boundBy: $0).identifier })
    }

    @MainActor
    func visibleActiveFastFrames(
        in app: XCUIApplication,
        carousel: XCUIElement,
        identifier: String
    ) -> [CGRect] {
        let candidates = app.buttons.matching(
            NSPredicate(format: "identifier == %@", identifier)
        )
        let fragmentsExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                guard candidates.count == 2 else { return false }
                return (0 ..< candidates.count).allSatisfy { index in
                    let candidate = candidates.element(boundBy: index)
                    return candidate.exists
                        && Self.intersectsVisibleFrame(candidate.frame, with: carousel.frame)
                }
            },
            object: app
        )
        guard XCTWaiter.wait(for: [fragmentsExpectation], timeout: 5) == .completed else {
            return []
        }
        return (0 ..< candidates.count).map { candidates.element(boundBy: $0).frame }
    }

    @MainActor
    func waitForSettledHistory(
        selectedDate: XCUIElement,
        carousel: XCUIElement,
        expectedSelectedDate: String
    ) -> Bool {
        let selectedDateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedSelectedDate),
            object: selectedDate
        )
        guard XCTWaiter.wait(for: [selectedDateExpectation], timeout: 5) == .completed else {
            return false
        }
        let settledExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Settled"),
            object: carousel
        )
        return XCTWaiter.wait(for: [settledExpectation], timeout: 5) == .completed
    }
}
