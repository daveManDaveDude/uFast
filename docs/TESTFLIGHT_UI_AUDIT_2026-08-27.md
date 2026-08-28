# uFast UI Test Audit Report

## Run summary

| Field | Value |
|---|---|
| Run | Final four-worker UI suite |
| Result | Passed |
| Tests | 138 passed, 0 failed, 0 skipped |
| Device | iPhone 17 Pro Simulator, iOS 26.0.1 |
| Parallel clones | 4 |
| Wall-clock duration | 20m 7.3s (1,207.300s) |
| Test execution time summed across clones | 68m 40.4s (4,120.408s) |
| Recorded run | 27 August 2026 |

## Clone summary

The wall-clock duration is determined by the slowest clone plus test-runner overhead. The clone totals below are the sum of the individual test durations assigned to each clone.

| Clone | Tests | Summed test time | Observation |
|---:|---:|---:|---|
| 1 | 28 | 19m 41.7s (1,181.693s) | Bottleneck; ran the full HistoryUITests suite. |
| 2 | 34 | 17m 2.7s (1,022.672s) | Second-longest clone by summed test time. |
| 3 | 41 | 15m 48.8s (948.767s) | Most tests by count, but not the slowest clone. |
| 4 | 35 | 16m 7.3s (967.275s) | Comparable to Clone 3 in total test time. |

## Duration outliers

Xcode identified four test runs longer than 117.10s (three standard deviations above the run mean). They are included in the full inventory below.

- `HydrationFavouriteValidationUITests.testDeleteAllDataSupportsCancelSuccessAndFailure()` - 158.294 s on Clone 3
- `HydrationFavouriteLifecycleUITests.testFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder()` - 157.942 s on Clone 4
- `HydrationFavouriteValidationUITests.testFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState()` - 146.146 s on Clone 3
- `HydrationFavouriteLifecycleUITests.testEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent()` - 126.172 s on Clone 4

## Test inventory

Rows follow the observed xcodebuild execution order. Descriptions are concise explanations derived from each test method name; test identifiers and durations are taken from the passing xcresult, with clone assignment taken from the xcodebuild log.

| # | Test | Brief description | Clone | Time taken |
|---:|---|---|---:|---:|
| 1 | `HistoryUITests.testCarouselRailAndHeadingStaySynchronizedAcrossYearBoundary()` | Verifies that carousel rail and heading stay synchronized across year boundary. | 1 | 31.437 s |
| 2 | `FoodFavouriteLifecycleUITests.testDeleteAllCancelPreservesFoodFavourite()` | Verifies that delete all cancel preserves food favourite. | 2 | 23.002 s |
| 3 | `HistoryUITests.testCompletedFastAppearsAndEditorUsesStoredBoundaries()` | Verifies that completed fast appears and editor uses stored boundaries. | 1 | 43.681 s |
| 4 | `FoodFavouriteLifecycleUITests.testDeleteAllFailurePreservesFoodFavourite()` | Verifies that delete all failure preserves food favourite. | 2 | 22.067 s |
| 5 | `FoodFavouriteLifecycleUITests.testDeleteAllSuccessRemovesFoodFavouriteWithoutReseeding()` | Verifies that delete all success removes food favourite without reseeding. | 2 | 23.405 s |
| 6 | `HistoryUITests.testConfirmedDeletePersistsAcrossRelaunch()` | Verifies that confirmed delete persists across relaunch. | 1 | 56.520 s |
| 7 | `FoodFavouriteLifecycleUITests.testFoodFavouriteControlsRemainReadableAtLargeTypeInDarkAppearance()` | Verifies that food favourite controls remain readable at large type in dark appearance. | 2 | 65.156 s |
| 8 | `FoodFavouriteLifecycleUITests.testFoodFavouriteMigrationFailurePresentsUnavailableState()` | Verifies that food favourite migration failure presents unavailable state. | 2 | 6.549 s |
| 9 | `HistoryUITests.testDeleteFailureKeepsEditorAndRecordAvailable()` | Verifies that delete failure keeps editor and record available. | 1 | 51.464 s |
| 10 | `HydrationFavouriteLifecycleUITests.testCustomFavouriteEditAndRemoveCancelThenConfirm()` | Verifies that custom favourite edit and remove cancel then confirm. | 4 | 88.864 s |
| 11 | `FoodFavouriteLifecycleUITests.testFoodFavouriteSaveFailureRetainsEditorForRetryOrCancel()` | Verifies that food favourite save failure retains editor for retry or cancel. | 2 | 18.016 s |
| 12 | `FoodFavouriteLifecycleUITests.testFreshEmptySettingsTodayPickerAndBlankEditorRemainUsable()` | Verifies that fresh empty settings today picker and blank editor remain usable. | 2 | 21.107 s |
| 13 | `HistoryUITests.testDirectHistoryEntryCancellationWritesNothingAndFailedSaveRetainsDraft()` | Verifies that direct history entry cancellation writes nothing and failed save retains draft. | 1 | 44.705 s |
| 14 | `HydrationFavouriteValidationUITests.testDeleteAllDataSupportsCancelSuccessAndFailure()` | Verifies that delete all data supports cancel success and failure. | 3 | 158.294 s |
| 15 | `FoodFavouriteLifecycleUITests.testHistoryFavouriteExplicitSaveRetainsEventValuesAfterTemplateEdit()` | Verifies that history favourite explicit save retains event values after template edit. | 2 | 43.091 s |
| 16 | `FoodFavouriteLifecycleUITests.testHistoryFavouritePrefillsSelectedTimeAndCancelDoesNotCreateEvent()` | Verifies that history favourite prefills selected time and cancel does not create event. | 2 | 20.793 s |
| 17 | `HistoryUITests.testDirectHistoryEntryConfirmsTimeAndSavesFoodAndFavouriteDrink()` | Verifies that direct history entry confirms time and saves food and favourite drink. | 1 | 54.079 s |
| 18 | `HydrationFavouriteLifecycleUITests.testEditingFavouriteChangesSubsequentAddWithoutRewritingEarlierEvent()` | Verifies that editing favourite changes subsequent add without rewriting earlier event. | 4 | 126.172 s |
| 19 | `FoodFavouriteLifecycleUITests.testSettingsCreatesFoodFavouriteAndKeepsItAfterRelaunch()` | Verifies that settings creates food favourite and keeps it after relaunch. | 2 | 50.017 s |
| 20 | `FoodFavouriteLifecycleUITests.testSettingsDuplicateDescriptionHasScopedAccessibleValidation()` | Verifies that settings duplicate description has scoped accessible validation. | 2 | 14.427 s |
| 21 | `HistoryUITests.testDirectHistoryEntrySavesCustomNonCaloricAndCaloricDrinks()` | Verifies that direct history entry saves custom non caloric and caloric drinks. | 1 | 69.435 s |
| 22 | `FoodFavouriteLifecycleUITests.testSettingsFoodFavouriteRemovalFailureUsesRemovalCopyAndRetainsCommittedState()` | Verifies that settings food favourite removal failure uses removal copy and retains committed state. | 2 | 24.404 s |
| 23 | `HistoryUITests.testEditAndDeleteCancellationLeaveCompletedRecordAvailable()` | Verifies that edit and delete cancellation leave completed record available. | 1 | 45.977 s |
| 24 | `HydrationFavouriteValidationUITests.testFavouritePersistenceFailuresRetainCreateEditAndRemovalRetryState()` | Verifies that favourite persistence failures retain create edit and removal retry state. | 3 | 146.146 s |
| 25 | `FoodFavouriteLifecycleUITests.testSettingsRemovalCancelSuccessLastRowPickerAndRelaunch()` | Verifies that settings removal cancel success last row picker and relaunch. | 2 | 41.432 s |
| 26 | `FoodFavouriteLifecycleUITests.testStaleSettingsSaveRetainsCommittedTemplateWithoutGhostWrite()` | Verifies that stale settings save retains committed template without ghost write. | 2 | 21.598 s |
| 27 | `FoodFavouriteLifecycleUITests.testStaleTodayFavouriteSelectionCreatesNoGhostEvent()` | Verifies that stale today favourite selection creates no ghost event. | 2 | 33.334 s |
| 28 | `HydrationFavouriteLifecycleUITests.testFavouritePersistsAfterRelaunchAndAppearsInTodayAndHistoryPickersInOrder()` | Verifies that favourite persists after relaunch and appears in today and history pickers in order. | 4 | 157.942 s |
| 29 | `FoodFavouriteLifecycleUITests.testTodayActiveFastFavouriteStaleAfterConfirmationShowsScopedStateAndRetainsRetry()` | Verifies that today active fast favourite stale after confirmation shows scoped state and retains retry. | 2 | 23.451 s |
| 30 | `HistoryUITests.testEditedActiveFastCrossingMidnightIsCoherentBeforeAnyDrinkMutation()` | Verifies that edited active fast crossing midnight is coherent before any drink mutation. | 1 | 97.920 s |
| 31 | `HydrationFavouriteValidationUITests.testValidationKeepsSaveDisabledAndExplainsEachInvalidFavouriteField()` | Verifies that validation keeps save disabled and explains each invalid favourite field. | 3 | 104.949 s |
| 32 | `FoodFavouriteLifecycleUITests.testTodayActiveFastFoodFavouriteFailureKeepsFastAndProvidesRetry()` | Verifies that today active fast food favourite failure keeps fast and provides retry. | 2 | 17.629 s |
| 33 | `HistoryEventGroupingUITests.testAccessibilitySizeAndMemberActionsRemainUsable()` | Verifies that accessibility size and member actions remain usable. | 3 | 10.247 s |
| 34 | `HistoryEventGroupingUITests.testAddEventRemainsBucketConstrained()` | Verifies that add event remains bucket constrained. | 3 | 13.052 s |
| 35 | `HistoryUITests.testEditFailureKeepsEditorSelectionsAndStoredRowAvailable()` | Verifies that edit failure keeps editor selections and stored row available. | 1 | 46.220 s |
| 36 | `HistoryEventGroupingUITests.testCaloricDrinkGroupUsesHydrationDisclosureAndEditor()` | Verifies that caloric drink group uses hydration disclosure and editor. | 3 | 13.015 s |
| 37 | `FoodFavouriteLifecycleUITests.testTodayFavouriteCreatesSuccessStateAndActiveFastCancelClearsStateBeforeRetryingSelection()` | Verifies that today favourite creates success state and active fast cancel clears state before retrying selection. | 2 | 38.785 s |
| 38 | `HistoryUITests.testEmptyHistoryShowsCompletedOnlyEmptyStateWithoutStartAction()` | Verifies that empty history shows completed only empty state without start action. | 1 | 20.454 s |
| 39 | `HistoryEventGroupingUITests.testDeletingFromThreeMemberGroupReturnsToRemainingTwoMemberDisclosure()` | Verifies that deleting from three member group returns to remaining two member disclosure. | 3 | 21.948 s |
| 40 | `HydrationFavouriteLifecycleUITests.testRemovedFavouriteKeepsHistoricalDrinkAfterRelaunch()` | Verifies that removed favourite keeps historical drink after relaunch. | 4 | 99.778 s |
| 41 | `HistoryEventGroupingUITests.testDeletingFromTwoMemberGroupReturnsToHistoryWithSingleEditableMarker()` | Verifies that deleting from two member group returns to history with single editable marker. | 3 | 25.067 s |
| 42 | `HistoryUITests.testFastHistoryFlickCrossesSeveralDaysAndFutureDaysRemainReadOnly()` | Verifies that fast history flick crosses several days and future days remain read only. | 1 | 51.396 s |
| 43 | `HydrationFavouriteLifecycleUITests.testRemovingLastFavouriteKeepsSettingsAndPickerUsable()` | Verifies that removing last favourite keeps settings and picker usable. | 4 | 44.995 s |
| 44 | `HistoryEventGroupingUITests.testDrinkMemberOpensStoredEditorCancelReturnsDisclosureAndSaveRefreshesAnotherMember()` | Verifies that drink member opens stored editor cancel returns disclosure and save refreshes another member. | 3 | 29.515 s |
| 45 | `FastStartUITests.testActiveFastEditorUsesSaveActionAndCancellationKeepsPresentation()` | Verifies that active fast editor uses save action and cancellation keeps presentation. | 4 | 13.588 s |
| 46 | `HistoryUITests.testFirstBackwardSwipePreservesInitialDateRailAnchor()` | Verifies that first backward swipe preserves initial date rail anchor. | 1 | 24.548 s |
| 47 | `FastStartUITests.testActiveFastElapsedSecondsCountUpWhileTodayIsVisible()` | Verifies that active fast elapsed seconds count up while today is visible. | 4 | 10.242 s |
| 48 | `FastStartUITests.testActiveFastShowsDeterministicElapsedGoalTargetAndProgress()` | Verifies that active fast shows deterministic elapsed goal target and progress. | 4 | 8.158 s |
| 49 | `HydrationQuickAddUITests.testCaloricFavouriteAddsImmediatelyWithoutFastAndUsesActiveFastChoice()` | Verifies that caloric favourite adds immediately without fast and uses active fast choice. | 2 | 109.800 s |
| 50 | `FastStartUITests.testInactivePastStartEditorCanBeCancelledWithoutStartingFast()` | Verifies that inactive past start editor can be cancelled without starting fast. | 4 | 11.015 s |
| 51 | `HistoryEventGroupingUITests.testFailedFoodAndDrinkSavesKeepDraftAndCommittedGroupUnchanged()` | Verifies that failed food and drink saves keep draft and committed group unchanged. | 3 | 39.049 s |
| 52 | `FastStartUITests.testInactiveTodayKeepsPrimaryActionsReachableAtAccessibilityTextSize()` | Verifies that inactive today keeps primary actions reachable at accessibility text size. | 4 | 7.382 s |
| 53 | `HistoryUITests.testHistoricalFoodEditorKeepsStoredLocalDateAndTime()` | Verifies that historical food editor keeps stored local date and time. | 1 | 29.249 s |
| 54 | `HistoryEventGroupingUITests.testFoodMemberOpensExistingFoodEditor()` | Verifies that food member opens existing food editor. | 3 | 11.766 s |
| 55 | `FastStartUITests.testInactiveTodayShowsStateGoalAndDerivedTargetBeforeStarting()` | Verifies that inactive today shows state goal and derived target before starting. | 4 | 6.535 s |
| 56 | `HistoryEventGroupingUITests.testHistoryRowsCanScrollClearOfFloatingTabBar()` | Verifies that history rows can scroll clear of floating tab bar. | 3 | 11.511 s |
| 57 | `HydrationQuickAddUITests.testCaloricFavouriteFailureStaysVisibleAndCanBeRetriedDuringActiveFast()` | Verifies that caloric favourite failure stays visible and can be retried during active fast. | 2 | 33.875 s |
| 58 | `HistoryUITests.testHistoryAlternativesRemainReachableWithAccessibilityTextAndReduceMotion()` | Verifies that history alternatives remain reachable with accessibility text and reduce motion. | 1 | 31.176 s |
| 59 | `HistoryEventGroupingUITests.testInformationPanelReturnsAfterNativeIdle()` | Verifies that information panel returns after native idle. | 3 | 18.257 s |
| 60 | `FastStartUITests.testLegacyActiveFastShowsStoredInvalidDraftAndCanChooseBoundedReplacement()` | Verifies that legacy active fast shows stored invalid draft and can choose bounded replacement. | 4 | 35.121 s |
| 61 | `HistoryEventGroupingUITests.testMovingMemberOutOfBucketDismissesStaleDisclosureAndRecomputesHistory()` | Verifies that moving member out of bucket dismisses stale disclosure and recomputes history. | 3 | 17.775 s |
| 62 | `FastStartUITests.testPastStartConfirmationPersistsAcrossRelaunch()` | Verifies that past start confirmation persists across relaunch. | 4 | 14.995 s |
| 63 | `FastStartUITests.testPastStartEditorPreventsSelectingAFutureTime()` | Verifies that past start editor prevents selecting a future time. | 4 | 10.620 s |
| 64 | `HistoryUITests.testHistoryKeepsActiveFastLabelOnSelectedPageAcrossMidnight()` | Verifies that history keeps active fast label on selected page across midnight. | 1 | 34.207 s |
| 65 | `HistoryEventGroupingUITests.testReclassifyingHydrationMovesItToTheOtherCategory()` | Verifies that reclassifying hydration moves it to the other category. | 3 | 16.043 s |
| 66 | `FastStartUITests.testPastStartSaveFailureKeepsEditorSelectionAvailableForRetry()` | Verifies that past start save failure keeps editor selection available for retry. | 4 | 11.083 s |
| 67 | `HistoryEventGroupingUITests.testRestingGroupsDisclosureAndRemovesGroupManager()` | Verifies that resting groups disclosure and removes group manager. | 3 | 10.746 s |
| 68 | `HydrationQuickAddUITests.testCreateCustomFavouriteShowsClassificationAndQuickAddsIt()` | Verifies that create custom favourite shows classification and quick adds it. | 2 | 59.587 s |
| 69 | `FastStartUITests.testRelaunchAtAdvancedTimeCatchesUpAndShowsReachedTarget()` | Verifies that relaunch at advanced time catches up and shows reached target. | 4 | 12.833 s |
| 70 | `FastStartUITests.testSaveFailureKeepsInactiveStateAndOffersRetry()` | Verifies that save failure keeps inactive state and offers retry. | 4 | 7.349 s |
| 71 | `HistoryEventGroupingUITests.testUngroupedDrinkAndFoodOpenExistingEditorsDirectly()` | Verifies that ungrouped drink and food open existing editors directly. | 3 | 23.114 s |
| 72 | `HydrationQuickAddUITests.testFavouriteDoesNotChangeActiveFast()` | Verifies that favourite does not change active fast. | 2 | 22.844 s |
| 73 | `FastStartUITests.testStartFastPersistsAcrossRelaunch()` | Verifies that start fast persists across relaunch. | 4 | 14.102 s |
| 74 | `HistoryUITests.testHistoryMidnightSeamAccessibilityPresentationAcrossDynamicTypeRTLAndTwelveHourLocale()` | Verifies that history midnight seam accessibility presentation across dynamic type RTL and twelve hour locale. | 1 | 54.374 s |
| 75 | `LiveActivityUITests.testAutomaticOfferUsesExactCopyAndNotNowDoesNotRepeat()` | Verifies that automatic offer uses exact copy and not now does not repeat. | 3 | 22.957 s |
| 76 | `HydrationQuickAddUITests.testNewStoreSeedsOnlyWaterAt330Millilitres()` | Verifies that a new store seeds only water at 330 millilitres. | 2 | 18.668 s |
| 77 | `FastingGoalUITests.testDeleteAllDataFailureKeepsSettingsAvailableAndShowsRetry()` | Verifies that delete all data failure keeps settings available and shows retry. | 4 | 18.459 s |
| 78 | `LiveActivityUITests.testDisabledLiveActivityShowsTheSettledStatusAndDoesNotMutateTheFast()` | Verifies that disabled live activity shows the settled status and does not mutate the fast. | 3 | 21.529 s |
| 79 | `FastingGoalUITests.testDeleteAllDataRequiresTwoConfirmationsAndReturnsToOnboarding()` | Verifies that delete all data requires two confirmations and returns to onboarding. | 4 | 21.851 s |
| 80 | `FastingGoalUITests.testEveryWholeHourChoiceIsAvailableAndSelectedWithoutColourAlone()` | Verifies that every whole hour choice is available and selected without colour alone. | 4 | 5.392 s |
| 81 | `HistoryUITests.testHistoryMidnightSeamRemainsContinuousWhenViewportMovesBothDirections()` | Verifies that history midnight seam remains continuous when viewport moves both directions. | 1 | 40.763 s |
| 82 | `LiveActivityUITests.testRequestFailureUsesSettledCopyAndLeavesActivityAvailableForRetry()` | Verifies that request failure uses settled copy and leaves activity available for retry. | 3 | 20.591 s |
| 83 | `FastingGoalUITests.testFirstUseDefaultsToTwelveAndPersistsSelectedGoalAcrossRelaunch()` | Verifies that first use defaults to twelve and persists selected goal across relaunch. | 4 | 14.555 s |
| 84 | `HydrationQuickAddUITests.testSettingsFavouriteCanBeEditedSavedAndUsedByQuickAdd()` | Verifies that settings favourite can be edited saved and used by quick add. | 2 | 54.936 s |
| 85 | `FastingGoalUITests.testGoalCanBeChangedToEightHoursInSettings()` | Verifies that goal can be changed to eight hours in settings. | 4 | 9.651 s |
| 86 | `LiveActivityUITests.testSettingsToggleCanEnableBeforeAStart()` | Verifies that settings toggle can enable before a start. | 3 | 20.765 s |
| 87 | `FastingGoalUITests.testGoalControlRemainsUsableAtLargestAccessibilityTextSize()` | Verifies that goal control remains usable at largest accessibility text size. | 4 | 6.992 s |
| 88 | `HistoryUITests.testHistoryPresentsAnActiveFastThroughTheCurrentTime()` | Verifies that history presents an active fast through the current time. | 1 | 29.334 s |
| 89 | `FastingGoalUITests.testOnboardingSaveFailureRetainsSelectionAndShowsRetryMessage()` | Verifies that onboarding save failure retains selection and shows retry message. | 4 | 6.197 s |
| 90 | `HydrationQuickAddUITests.testWaterQuickAddTakesTwoTapsAndUpdatesTotalOnce()` | Verifies that water quick add takes two taps and updates total once. | 2 | 17.405 s |
| 91 | `LiveActivityUITests.testShowAutomaticallyStartsOneActivityAndRenamesRemovalControl()` | Verifies that show automatically starts one activity and renames removal control. | 3 | 14.781 s |
| 92 | `CaloricFoodUITests.testCaloricFoodAtExactActiveStartCannotSave()` | Verifies that caloric food at exact active start cannot save. | 2 | 15.146 s |
| 93 | `LiveActivityUITests.testShowDisclosureUsesExactPrivacyCopyAndCancelKeepsActionAvailable()` | Verifies that show disclosure uses exact privacy copy and cancel keeps action available. | 3 | 20.047 s |
| 94 | `FastingGoalUITests.testPseudolocalizedOnboardingTodayAndSettingsRemainActionableInRTLAtAccessibilitySize()` | Verifies that pseudolocalized onboarding today and settings remain actionable in RTL at accessibility size. | 4 | 28.962 s |
| 95 | `CaloricFoodUITests.testCaloricFoodCancelChangesNeitherRecordAndConfirmationHasOnlyRequiredChoices()` | Verifies that caloric food cancel changes neither record and confirmation has only required choices. | 2 | 20.323 s |
| 96 | `FastingGoalUITests.testSettingsExplainsLocalStorageAndOpensPrivacySafety()` | Verifies that settings explains local storage and opens privacy safety. | 4 | 12.516 s |
| 97 | `LiveActivityUITests.testShowHideAndExplicitReshowPreserveTheActiveFast()` | Verifies that show hide and explicit reshow preserve the active fast. | 3 | 25.076 s |
| 98 | `FastingGoalUITests.testSettingsSaveFailureRestoresPreviousGoal()` | Verifies that settings save failure restores previous goal. | 4 | 13.313 s |
| 99 | `HistoryUITests.testHistoryRunwayStaysPopulatedAfterRepeatedFastFlicksBeyondSevenDays()` | Verifies that history runway stays populated after repeated fast flicks beyond seven days. | 1 | 63.732 s |
| 100 | `CaloricFoodUITests.testFoodConfirmationRemainsReachableAtAccessibilityXXXL()` | Verifies that food confirmation remains reachable at accessibility XXXL. | 2 | 22.778 s |
| 101 | `LiveActivityUITests.testUpdateRecoveryUsesDeterministicBuildIdentityAndDoesNotRepeatOnSameBuild()` | Verifies that update recovery uses deterministic build identity and does not repeat on same build. | 3 | 11.943 s |
| 102 | `HydrationCustomAndTimelineUITests.testCaloricCustomDrinkRequiresMandatoryConfirmationAndCancelMutatesNothing()` | Verifies that caloric custom drink requires mandatory confirmation and cancel mutates nothing. | 4 | 17.874 s |
| 103 | `CaloricFoodUITests.testFoodEditorDoesNotOfferNonCaloricClassification()` | Verifies that food editor does not offer non caloric classification. | 2 | 12.164 s |
| 104 | `FastEndUITests.testClockAtStartDisablesEndNowAndExplainsPastEndValidation()` | Verifies that clock at start disables end now and explains past end validation. | 3 | 11.843 s |
| 105 | `FastEndUITests.testEndNowFailureKeepsOriginalFastActiveAndShowsRetryMessage()` | Verifies that end now failure keeps original fast active and shows retry message. | 3 | 14.556 s |
| 106 | `CaloricFoodUITests.testPseudolocalizedFoodConfirmationUsesStableIdentifiers()` | Verifies that pseudolocalized food confirmation uses stable identifiers. | 2 | 21.964 s |
| 107 | `HistoryUITests.testHistorySwipeButtonsAndDateChipShareOneSelectedDay()` | Verifies that history swipe buttons and date chip share one selected day. | 1 | 35.843 s |
| 108 | `HydrationCustomAndTimelineUITests.testCustomDrinkValidationCreateEditAndDeleteUpdatesTimelineAndTotal()` | Verifies that custom drink validation create edit and delete updates timeline and total. | 4 | 24.254 s |
| 109 | `FastEndUITests.testEndNowRequiresConfirmationAndCancellationKeepsFastActive()` | Verifies that end now requires confirmation and cancellation keeps fast active. | 3 | 14.551 s |
| 110 | `HydrationCustomAndTimelineUITests.testExistingDrinkRowOpensFromItsOpenAreaDuringAnActiveFast()` | Verifies that existing drink row opens from its open area during an active fast. | 4 | 10.813 s |
| 111 | `CaloricFoodUITests.testSaveAndEndFastAtomicallyRecordsFoodAndEndsAtEventTime()` | Verifies that save and end fast atomically records food and ends at event time. | 2 | 21.233 s |
| 112 | `FastEndUITests.testEndNowReturnsToInactiveStateAndSessionMessageDoesNotRelaunch()` | Verifies that end now returns to inactive state and session message does not relaunch. | 3 | 19.908 s |
| 113 | `HydrationCustomAndTimelineUITests.testExistingFoodRowOpensFromItsOpenAreaDuringAnActiveFast()` | Verifies that existing food row opens from its open area during an active fast. | 4 | 22.729 s |
| 114 | `HistoryUITests.testHistoryUsesAccessibleTemporalNavigatorAndRibbonAlternative()` | Verifies that history uses accessible temporal navigator and ribbon alternative. | 1 | 39.161 s |
| 115 | `FastEndUITests.testPastEndEditorInitialisesToNowAndCanCompleteFast()` | Verifies that past end editor initialises to now and can complete fast. | 3 | 14.745 s |
| 116 | `HistoryUITests.testLateStartActiveFastUsesReadableUntruncatedTimelineLabel()` | Verifies that late start active fast uses readable untruncated timeline label. | 1 | 13.350 s |
| 117 | `HydrationCustomAndTimelineUITests.testPseudolocalizedCaloricDrinkConfirmationUsesStableIdentifiers()` | Verifies that pseudolocalized caloric drink confirmation uses stable identifiers. | 4 | 21.365 s |
| 118 | `FastEndUITests.testPastEndFailureKeepsEditorAndSelectionAvailable()` | Verifies that past end failure keeps editor and selection available. | 3 | 16.302 s |
| 119 | `FoodEntryUITests.testCreateValidationPartialNutritionEditDeleteCancelAndRelaunch()` | Verifies that create validation partial nutrition edit delete cancel and relaunch. | 2 | 43.104 s |
| 120 | `NavigationShellUITests.testMultipleActiveFastsShowIntegrityErrorWithoutChoosingOne()` | Verifies that multiple active fasts show integrity error without choosing one. | 3 | 4.810 s |
| 121 | `NavigationShellUITests.testPersistenceBootstrapFailureShowsNonDestructiveUnavailableState()` | Verifies that persistence bootstrap failure shows non destructive unavailable state. | 3 | 4.292 s |
| 122 | `HistoryUITests.testManualDateRailSettlementSelectsNearestCenteredChipAndSynchronizesTimeline()` | Verifies that manual date rail settlement selects nearest centered chip and synchronizes timeline. | 1 | 23.150 s |
| 123 | `FoodEntryUITests.testWhitespaceOnlyDescriptionCannotSave()` | Verifies that whitespace only description cannot save. | 2 | 11.547 s |
| 124 | `NavigationShellUITests.testThreePrimaryDestinationsAreReachable()` | Verifies that three primary destinations are reachable. | 3 | 13.238 s |
| 125 | `NavigationShellUITests.testUnknownFastProvenanceIsExplicitlyUnavailable()` | Verifies that unknown fast provenance is explicitly unavailable. | 3 | 6.145 s |
| 126 | `UITestLaunchConfigurationTests.testAccessibilityContentSizeCategoryUsesTheTypedSystemArgument()` | Verifies that accessibility content size category uses the typed system argument. | 3 | 0.047 s |
| 127 | `UITestLaunchConfigurationTests.testEmitsCompleteGrammarInCanonicalOrder()` | Verifies that launch arguments emit complete grammar in canonical order. | 3 | 0.029 s |
| 128 | `UITestLaunchConfigurationTests.testInvalidCombinationsAreRejectedBeforeEmission()` | Verifies that invalid combinations are rejected before emission. | 3 | 0.029 s |
| 129 | `UITestLaunchConfigurationTests.testPseudolocalizationIsEmittedOnlyAfterTheUITestingGate()` | Verifies that pseudolocalization is emitted only after the UI testing gate. | 3 | 0.029 s |
| 130 | `UITestLaunchConfigurationTests.testSingletonFlagsAreEmittedAtMostOnce()` | Verifies that singleton flags are emitted at most once. | 3 | 0.028 s |
| 131 | `UITestLaunchConfigurationTests.testValueFlagsRequireFiniteValuesAndIdentityPairs()` | Verifies that value flags require finite values and identity pairs. | 3 | 0.032 s |
| 132 | `InferredFastUITests.testHistoricalSaveAndCurrentStartUseExplicitAccessibleActionsAtDynamicType()` | Verifies that historical save and current start use explicit accessible actions at dynamic type. | 4 | 37.102 s |
| 133 | `TodayMultiYearUITests.testScaledMultiYearTodayShowsOnlyTodayAndPersistsMutations()` | Verifies that scaled multi year today shows only today and persists mutations. | 2 | 29.036 s |
| 134 | `InferredFastUITests.testInferredFastSettingPersistsAcrossRelaunchAndHasStableAccessibility()` | Verifies that inferred fast setting persists across relaunch and has stable accessibility. | 4 | 14.476 s |
| 135 | `HistoryUITests.testMidnightMarkerRemainsVisibleAtAccessibilityTextSizeInLTRAndRTL()` | Verifies that the midnight marker remains visible at accessibility text size in LTR and RTL. | 1 | 40.989 s |
| 136 | `HistoryUITests.testPseudolocalizedHistoryAtAXXXLRTLAndReduceMotionUsesStableSelectors()` | Verifies that pseudolocalized history at A XXXL RTL and Reduce Motion uses stable selectors. | 1 | 53.978 s |
| 137 | `HistoryUITests.testTodayAlternativeAllowsElapsedEntryWhileFutureHistoryRemainsReadOnly()` | Verifies that today alternative allows elapsed entry while future history remains read only. | 1 | 35.465 s |
| 138 | `HistoryUITests.testTomorrowIsFinalHistoryDisplayDay()` | Verifies that tomorrow is final history display day. | 1 | 19.086 s |

## Evidence

- [xcodebuild log](../.derived-data/sprint-results/ui-20260826T231353Z-59999.log)
- [xcresult bundle](../.derived-data/sprint-results/ui-20260826T231353Z-59999.xcresult)
- Verification: `UI xcresult verified: 138 tests exactly once, 0 skipped, 4 worker clones`

Generated from the final passing four-worker UI run for the uFast TestFlight release candidate.
