@testable import uFast
import XCTest

final class LocalizationTests: XCTestCase {
    func testAppTextCatalogKeysCoverFormattingAndPluralCases() {
        XCTAssertGreaterThan(AppText.catalogKeys.count, 50)
        XCTAssertTrue(AppText.catalogKeys.contains("food.validation.empty-description"))
        XCTAssertTrue(AppText.catalogKeys.contains("drink.error.combined-save"))
        XCTAssertTrue(AppText.catalogKeys.contains("today.timeline.accessibility-value"))
        XCTAssertTrue(AppText.catalogKeys.contains("today.timeline.load-error"))
        XCTAssertTrue(AppText.catalogKeys.contains("drink.picker.detail.caloric"))
        XCTAssertTrue(AppText.catalogKeys.contains("drink.picker.detail.non-caloric"))
        XCTAssertTrue(AppText.catalogKeys.contains("food.confirmation.completed.message"))
        XCTAssertTrue(AppText.catalogKeys.contains("drink.confirmation.completed.message"))
        XCTAssertTrue(AppText.catalogKeys.contains("caloric.confirmation.active.message.multiple"))
        XCTAssertTrue(AppText.catalogKeys.contains("history.carousel"))
        XCTAssertTrue(AppText.catalogKeys.contains("history.retry"))
        XCTAssertTrue(AppText.catalogKeys.contains("history.extension-retry"))
        XCTAssertTrue(AppText.catalogKeys.contains("duration.minute"))
        XCTAssertTrue(AppText.catalogKeys.contains("history.group.food.title"))
    }

    func testEnglishValidationAndAccessibilityCopyRemainExact() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            resolve(.foodValidation(.emptyDescription)),
            "Enter what you ate."
        )
        XCTAssertEqual(
            resolve(.drinkConflictError),
            "This fast overlaps another recorded fast. Correct the fast before saving."
        )
        XCTAssertEqual(
            resolve(.drinkAddedAnnouncement(name: "Juice", volumeMillilitres: 200)),
            "Juice, 200 millilitres, added."
        )
        XCTAssertEqual(
            resolve(.drinkPickerDetail(volumeMillilitres: 250, isCaloric: true)),
            "250 ml · Caloric"
        )
        XCTAssertEqual(
            resolve(.drinkPickerDetail(volumeMillilitres: 250, isCaloric: false)),
            "250 ml · Non-caloric"
        )
        XCTAssertEqual(
            resolve(.todayTimelineAccessibilityValue(detail: "250 ml · Non-caloric", time: "10:30")),
            "250 ml · Non-caloric, 10:30"
        )
    }

    func testEnglishSingularImpactTitleRemainsExact() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            resolve(.confirmationTitle(.completed, noun: .drink, count: 1)),
            "This drink updates 1 recorded fast."
        )
    }

    func testEnglishPluralImpactTitleRemainsExact() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            resolve(.confirmationTitle(.completed, noun: .drink, count: 3)),
            "This drink updates 3 recorded fasts."
        )
    }

    func testEnglishPluralImpactMessageRemainsExact() {
        let resolve = AppTextResolver()

        XCTAssertEqual(
            resolve(
                .confirmationMessage(
                    action: .saving,
                    kind: .completed,
                    noun: .food,
                    count: 2,
                    time: "10:30"
                )
            ),
            "Saving this caloric event updates 2 recorded fasts at 10:30."
        )
    }

    @MainActor
    func testFoodFavouriteConfirmationPreservesBothImpactDetails() {
        let resolve = AppTextResolver()
        let context = CaloricEventConfirmationContext(
            persistedImpact: CaloricEventImpact(
                activeFastIDs: [UUID()],
                completedFastIDs: [],
                reconstructedFastIDs: [],
                reconstructedReviewIDs: [UUID()]
            ),
            includesInferredInterval: true
        )

        let message = TodayGoalView.savingConfirmationMessage(
            context: context,
            noun: .food,
            time: "10:30",
            textResolver: resolve
        )

        XCTAssertTrue(message.contains(resolve(.reconstructedReviewDetail)))
        XCTAssertTrue(message.contains(resolve(.inferredIntervalDetail)))
    }

    func testPseudolocalizationIsDeterministicAndPreservesInterpolationTokens() {
        let source = "Save and update 3 recorded fasts at 10:30."
        let first = AppTextPseudolocalizer.resolve(source)
        let second = AppTextPseudolocalizer.resolve(source)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, source)
        XCTAssertTrue(first.hasPrefix("［"))
        XCTAssertTrue(first.hasSuffix(" ··］"))
        XCTAssertTrue(first.contains("3"))
        XCTAssertTrue(first.contains("10:30"))
        XCTAssertTrue(first.contains("Š"))
    }

    func testPseudolocalizedResolverPreservesRepresentativeAppTextInterpolations() {
        let resolve = AppTextResolver(pseudolocalizationEnabled: true)

        let confirmation = resolve(
            .confirmationMessage(
                action: .saving,
                kind: .completed,
                noun: .food,
                count: 3,
                time: "10:30"
            )
        )
        XCTAssertTrue(confirmation.contains("3"))
        XCTAssertTrue(confirmation.contains("10:30"))

        let announcement = resolve(.drinkAddedAnnouncement(name: "Juice", volumeMillilitres: 200))
        XCTAssertTrue(announcement.contains("Juice"))
        XCTAssertTrue(announcement.contains("200"))

        let fluidTotal = resolve(.todayFluidTotal(250))
        XCTAssertTrue(fluidTotal.contains("250"))
    }

    func testPseudolocalizedResolverOnlyChangesTestResolverOutput() {
        let source = AppTextResolver()(.drinkSaveError)
        let pseudo = AppTextResolver(pseudolocalizationEnabled: true)(.drinkSaveError)

        XCTAssertEqual(source, "Your drink couldn’t be saved. Please try again.")
        XCTAssertTrue(pseudo.hasPrefix("［"))
        XCTAssertNotEqual(pseudo, source)
        XCTAssertTrue(pseudo.contains("ï"))
    }

    func testEnglishPrimaryContentRemainsExact() {
        let resolve = AppTextResolver()

        XCTAssertEqual(resolve(.onboardingTitle), "Your fasting goal")
        XCTAssertEqual(
            resolve(.onboardingSelectionSummary(hours: 16)),
            "16 hours is selected. You can change this later."
        )
        XCTAssertEqual(resolve(.inactiveNoFast), "No fast is running.")
        XCTAssertEqual(resolve(.settingsDeleteFirstTitle), "Delete all uFast data?")
        XCTAssertEqual(
            resolve(.todayTimelineLoadError),
            "Your timeline couldn’t be loaded. Please try again."
        )
        XCTAssertEqual(
            resolve(.settingsFavouriteDetail(volumeMillilitres: 330, isCaloric: true)),
            "330 ml · Caloric"
        )
        XCTAssertEqual(
            resolve(.settingsFavouriteDetail(volumeMillilitres: 330, isCaloric: false)),
            "330 ml · Non-caloric"
        )
        XCTAssertEqual(
            resolve(.settingsFavouriteAccessibilityValue(volumeMillilitres: 330, isCaloric: true)),
            "330 millilitres, Caloric"
        )
        XCTAssertEqual(
            resolve(.settingsFavouriteAccessibilityValue(volumeMillilitres: 330, isCaloric: false)),
            "330 millilitres, Non-caloric"
        )
        XCTAssertEqual(
            resolve(.privacyBody(.safety)),
            "uFast records information you choose to enter and displays patterns in those records. "
                + "It is not medical advice and does not diagnose, treat or guarantee a health outcome."
        )
        XCTAssertEqual(
            resolve(.liveActivityStatus(.requestFailed)),
            "The Live Activity couldn’t be started. Please try again."
        )
    }

    func testPseudolocalizedPrimaryContentPreservesNumericAndUserTokens() {
        let resolve = AppTextResolver(pseudolocalizationEnabled: true)

        let goal = resolve(.goalSelectionSummary(hours: 24))
        XCTAssertTrue(goal.contains("24"))
        XCTAssertNotEqual(goal, "24 hours selected")

        let favourite = resolve(.favouriteRemoveConfirmation(name: "Sparkling water"))
        XCTAssertTrue(favourite.contains("Sparkling water"))
        XCTAssertTrue(favourite.hasPrefix("［"))
    }

    func testPseudolocalizedHistoryFormattingPreservesDurationAndDateTokens() {
        let resolve = AppTextResolver(pseudolocalizationEnabled: true)
        let duration = resolve(.durationComponent(value: 2, unit: .hour))
        let date = resolve(.historyDate(value: "24 Jul 2026"))

        XCTAssertTrue(duration.hasPrefix("［"))
        XCTAssertTrue(duration.contains("2"))
        XCTAssertTrue(date.contains("24 Jul 2026"))
    }
}
