import Foundation
import SwiftUI
@testable import uFast
@testable import UFastLockScreenWidget
import UIKit
import WidgetKit
import XCTest

// SwiftFormat requires multiline collection trailing commas; SwiftLint's repository rule forbids them.
// swiftlint:disable trailing_comma

// swiftlint:disable:next type_body_length
final class MNT010DSystemSurfacePresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let locale = Locale(identifier: "en_GB")

    func testCatalogResolverPreservesAcceptedEnglishAndDeterministicTokens() {
        let resolver = uFast.SystemSurfaceTextResolver(locale: locale)

        XCTAssertEqual(resolver(.brand), "uFast")
        XCTAssertEqual(resolver(.compactBrand), "uF")
        XCTAssertEqual(resolver(.elapsed), "Elapsed")
        XCTAssertEqual(resolver(.target(value: "10:30")), "Target 10:30")
        XCTAssertEqual(resolver(.goal(hours: 12)), "12-hour goal")
        XCTAssertEqual(
            resolver(.progress(percent: 50, goalHours: 12)),
            "50 percent of 12-hour goal"
        )
        XCTAssertEqual(resolver(.duration(value: 6, unit: .hour)), "6 hours")
        XCTAssertTrue(uFast.SystemSurfaceText.catalogKeys.contains("system-surface.brand"))
        XCTAssertTrue(uFast.SystemSurfaceText.catalogKeys.contains("system-surface.activity.summary"))
    }

    func testPseudolocalizationIsDeterministicAndPreservesPresentationTokens() {
        let pseudo = uFast.SystemSurfaceTextResolver(locale: locale, pseudolocalizationEnabled: true)
        let first = pseudo(.target(value: "10:30"))
        XCTAssertEqual(first, pseudo(.target(value: "10:30")))
        XCTAssertTrue(first.contains("10:30"))
        XCTAssertNotEqual(first, "Target 10:30")
        XCTAssertTrue(pseudo(.percentage(value: 50)).contains("50"))
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func testAC3PseudolocalizedLargeTextExecutesEverySystemSurfaceLayout() {
        let resolver = uFast.SystemSurfaceTextResolver(
            locale: locale,
            pseudolocalizationEnabled: true
        )
        let projection = projection(
            startDate: now.addingTimeInterval(-6 * 60 * 60),
            goalHours: 12
        )
        guard case let .active(lockPresentation) = uFast.LockScreenFastPresentation.make(
            projectionResult: .success(projection),
            now: now,
            privacyState: .authenticated,
            locale: locale,
            timeZone: .gmt,
            textResolver: resolver
        ) else {
            return XCTFail("Expected deterministic active widget presentation")
        }
        let accessory = uFast.LockScreenWidgetContent.make(
            projectionResult: .success(projection),
            now: now,
            textResolver: resolver
        )
        guard case let .active(accessoryPresentation) = accessory else {
            return XCTFail("Expected deterministic active accessory presentation")
        }

        let entry = UFastLockScreenEntry(
            date: now,
            projectionResult: .success(
                .init(
                    activeRecordIdentifier: projection.activeRecordIdentifier,
                    startDate: projection.startDate,
                    targetDate: projection.targetDate,
                    goalHours: projection.goalHours,
                    generatedAt: projection.generatedAt
                )
            )
        )
        assertRendered(
            UFastLockScreenWidgetView(
                entry: entry,
                textResolver: .init(locale: locale, pseudolocalizationEnabled: true)
            ),
            name: "accessory-rectangular",
            size: CGSize(width: 180, height: 68)
        )

        // swiftlint:disable:next large_tuple
        let widgetFamilies: [(name: String, family: WidgetFamily, size: CGSize)] = [
            ("system-small", .systemSmall, CGSize(width: 158, height: 158)),
            ("system-medium", .systemMedium, CGSize(width: 338, height: 158)),
            ("system-large", .systemLarge, CGSize(width: 338, height: 354)),
        ]
        for family in widgetFamilies {
            assertRendered(
                UFastHomeScreenWidgetView(
                    entry: entry,
                    textResolver: .init(locale: locale, pseudolocalizationEnabled: true),
                    familyOverride: family.family
                ),
                name: family.name,
                size: family.size
            )
        }

        assertRendered(
            UFastActiveFastActivityWidget.compactLeadingContent(),
            name: "activity-compact-leading",
            size: CGSize(width: 24, height: 24),
            expectsVisiblePixels: false
        )
        assertRendered(
            UFastActiveFastActivityWidget.compactTrailingContent(
                contentState: .init(
                    startDate: now.addingTimeInterval(-6 * 60 * 60),
                    targetDate: now.addingTimeInterval(6 * 60 * 60),
                    goalHours: 12,
                    generatedAt: now
                ),
                textResolver: .init(locale: locale, pseudolocalizationEnabled: true),
                now: now
            ),
            name: "activity-compact-trailing",
            size: CGSize(width: 32, height: 32)
        )
        assertRendered(
            UFastActiveFastActivityWidget.minimalContent(
                contentState: .init(
                    startDate: now.addingTimeInterval(-6 * 60 * 60),
                    targetDate: now.addingTimeInterval(6 * 60 * 60),
                    goalHours: 12,
                    generatedAt: now
                ),
                textResolver: .init(locale: locale, pseudolocalizationEnabled: true),
                now: now
            ),
            name: "activity-minimal",
            size: CGSize(width: 32, height: 32)
        )
        assertRendered(
            UFastActiveFastActivityWidget.expandedContent(
                contentState: .init(
                    startDate: now.addingTimeInterval(-6 * 60 * 60),
                    targetDate: now.addingTimeInterval(6 * 60 * 60),
                    goalHours: 12,
                    generatedAt: now
                ),
                textResolver: .init(locale: locale, pseudolocalizationEnabled: true),
                now: now
            ),
            name: "activity-expanded",
            size: CGSize(width: 220, height: 80)
        )

        // The render calls above exercise the actual WidgetKit and ActivityKit
        // production entry points. Keep the shared semantic assertions beside
        // them so every attached render is also tied to pseudolocalized copy.
        let widgetContent = [
            uFast.SystemSurfacePresentationContent.accessoryWidget(
                active: accessoryPresentation,
                resolver: resolver
            ),
            uFast.SystemSurfacePresentationContent.widget(
                layout: .small,
                presentation: lockPresentation,
                resolver: resolver
            ),
            uFast.SystemSurfacePresentationContent.widget(
                layout: .medium,
                presentation: lockPresentation,
                resolver: resolver
            ),
            uFast.SystemSurfacePresentationContent.widget(
                layout: .large,
                presentation: lockPresentation,
                resolver: resolver
            ),
        ]
        for rendered in widgetContent {
            let renderedCopy = rendered.visibleText
            XCTAssertFalse(renderedCopy.isEmpty, "No copy rendered for widget layout")
            XCTAssertTrue(
                renderedCopy.allSatisfy { $0.hasPrefix("［") },
                "Catalog copy was not pseudolocalized: \(renderedCopy)"
            )
        }

        let (source, attributes) = activityFixture()
        let activityPresentation = uFast.ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: .init(source: source, generatedAt: now),
            now: now,
            locale: locale,
            timeZone: .gmt,
            textResolver: resolver
        )
        let compactLeading = uFast.SystemSurfacePresentationContent.activity(
            layout: .compactLeading,
            goal: activityPresentation.stableGoalText,
            target: activityPresentation.targetText,
            hasReachedGoal: activityPresentation.hasReachedGoal,
            resolver: resolver
        )
        // The production Dynamic Island configuration deliberately returns
        // EmptyView for compact-leading; no copy belongs in that region.
        XCTAssertTrue(compactLeading.visibleText.isEmpty)
        for layout in [
            uFast.SystemSurfaceActivityLayout.compactTrailing,
            .minimal,
            .expanded,
        ] {
            let renderedCopy = uFast.SystemSurfacePresentationContent.activity(
                layout: layout,
                goal: activityPresentation.stableGoalText,
                target: activityPresentation.targetText,
                hasReachedGoal: activityPresentation.hasReachedGoal,
                resolver: resolver
            ).visibleText
            XCTAssertFalse(renderedCopy.isEmpty, "No copy rendered for \(layout)")
            XCTAssertTrue(
                renderedCopy.allSatisfy { $0.hasPrefix("［") },
                "Catalog copy was not pseudolocalized for \(layout): \(renderedCopy)"
            )
        }
    }

    @MainActor
    private func assertRendered(
        _ view: some View,
        name: String,
        size: CGSize,
        expectsVisiblePixels: Bool = true
    ) {
        let renderedView = view
            .dynamicTypeSize(.accessibility3)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: renderedView)
        renderer.scale = 1

        guard let image = renderer.uiImage else {
            if !expectsVisiblePixels {
                return
            }
            return XCTFail("Production layout did not render an image: \(name)")
        }
        XCTAssertEqual(image.size, size, "Unexpected rendered size for \(name)")
        if expectsVisiblePixels {
            XCTAssertNotNil(image.cgImage, "Production layout rendered no pixels: \(name)")
        }

        let attachment = XCTAttachment(image: image)
        attachment.name = "MNT-010D-\(name)-accessibility3"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLockScreenKeepsPrivacyAndDurationSemantics() {
        let active = projection(startDate: now.addingTimeInterval(-6 * 60 * 60), goalHours: 12)

        let protected = uFast.LockScreenFastPresentation.make(
            projectionResult: .success(active),
            now: now,
            privacyState: .protected,
            locale: locale,
            timeZone: .gmt
        )
        guard case let .active(protectedPresentation) = protected else {
            return XCTFail("Expected protected active presentation")
        }
        XCTAssertEqual(protectedPresentation.elapsedText, "6 h 0 min")
        XCTAssertEqual(
            protectedPresentation.accessibilitySummary,
            "uFast, elapsed 6 hours 0 minutes, 50 percent of 12-hour goal. Opens uFast."
        )
        XCTAssertNil(protectedPresentation.targetText)
        XCTAssertNil(protectedPresentation.hasReachedGoal)
        XCTAssertFalse(protectedPresentation.accessibilitySummary.contains("seconds"))
    }

    func testLockScreenKeepsGoalReachedAndFailClosedSemantics() {
        let resolver = uFast.SystemSurfaceTextResolver(locale: locale)
        let active = projection(startDate: now.addingTimeInterval(-6 * 60 * 60), goalHours: 12)
        let goalReached = uFast.LockScreenFastPresentation.make(
            projectionResult: .success(active),
            now: active.targetDate,
            privacyState: .authenticated,
            locale: locale,
            timeZone: .gmt
        )
        guard case let .active(goalReachedPresentation) = goalReached else {
            return XCTFail("Expected authenticated active presentation")
        }
        XCTAssertTrue(goalReachedPresentation.hasReachedGoal == true)
        XCTAssertEqual(goalReachedPresentation.elapsedText, "12:00:00")
        XCTAssertEqual(goalReachedPresentation.elapsedAccessibilityValue, "12 hours 0 minutes 0 seconds")

        let unavailable: [uFast.LockScreenFastPresentation] = [
            .make(projectionResult: .success(nil), now: now, privacyState: .protected),
            .make(
                projectionResult: .failure(uFast.ActiveFastWidgetProjectionError.unreadable),
                now: now,
                privacyState: .protected
            ),
            .make(
                projectionResult: .success(
                    uFast.ActiveFastWidgetProjection(
                        activeRecordIdentifier: UUID(),
                        startDate: active.startDate,
                        targetDate: active.startDate,
                        goalHours: 12,
                        generatedAt: now
                    )
                ),
                now: now,
                privacyState: .protected
            ),
        ]
        XCTAssertEqual(unavailable[0], .unavailable(reason: .noActiveFast))
        XCTAssertEqual(unavailable[1], .unavailable(reason: .unreadableProjection))
        XCTAssertEqual(unavailable[2], .unavailable(reason: .invalidProjection))
        XCTAssertEqual(resolver(.unavailableSummary), "uFast. No active fast. Opens uFast.")
    }

    func testActivityPresentationKeepsVisibleGoalReachedSemantics() {
        let (source, attributes) = activityFixture()
        let resolver = uFast.SystemSurfaceTextResolver(locale: locale)
        let goalReached = uFast.ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: .init(source: source, generatedAt: now),
            now: now,
            locale: locale,
            timeZone: .gmt,
            textResolver: resolver
        )
        XCTAssertTrue(goalReached.hasReachedGoal)
        XCTAssertEqual(goalReached.stableGoalText, "12-hour goal")
        XCTAssertEqual(goalReached.elapsedAccessibilityValue, "12 hours 0 minutes 0 seconds")
        XCTAssertTrue(goalReached.accessibilitySummary.contains("Goal time reached"))
    }

    func testActivityPresentationKeepsRedactedAndInvalidSemantics() {
        let (source, attributes) = activityFixture()
        let resolver = uFast.SystemSurfaceTextResolver(locale: locale)
        let redacted = uFast.ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: .init(source: source, generatedAt: now),
            now: now,
            privacyState: .redacted,
            locale: locale,
            timeZone: .gmt,
            textResolver: resolver
        )
        XCTAssertEqual(redacted.accessibilitySummary, "uFast. Opens uFast.")
        XCTAssertNil(redacted.elapsedText)
        XCTAssertNil(redacted.targetText)

        let invalid = uFast.ActiveFastActivityAttributes.ContentState(
            startDate: source.startDate,
            targetDate: source.startDate,
            goalHours: source.goalHours,
            generatedAt: now
        )
        let failedClosed = uFast.ActiveFastActivityPresentation.make(
            attributes: attributes,
            contentState: invalid,
            now: now,
            locale: locale,
            timeZone: .gmt,
            textResolver: resolver
        )
        XCTAssertEqual(failedClosed.accessibilitySummary, "uFast. Opens uFast.")
        XCTAssertNil(failedClosed.progress)
        XCTAssertNil(failedClosed.stableGoalText)
    }

    private func activityFixture() -> (
        source: uFast.ActiveFastActivitySource,
        attributes: uFast.ActiveFastActivityAttributes
    ) {
        let source = uFast.ActiveFastActivitySource(
            activeRecordIdentifier: UUID(),
            startDate: now.addingTimeInterval(-12 * 60 * 60),
            targetDate: now,
            goalHours: 12
        )
        return (
            source: source,
            attributes: uFast.ActiveFastActivityAttributes(
                activeRecordIdentifier: source.activeRecordIdentifier
            )
        )
    }

    private func projection(startDate: Date, goalHours: Int) -> uFast.ActiveFastWidgetProjection {
        uFast.ActiveFastWidgetProjection(
            activeRecordIdentifier: UUID(),
            startDate: startDate,
            targetDate: startDate.addingTimeInterval(TimeInterval(goalHours * 60 * 60)),
            goalHours: goalHours,
            generatedAt: now
        )
    }
}
