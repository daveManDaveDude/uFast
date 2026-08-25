# OW-D102 — Manage favourite foods in Settings

**Status:** Ready — Sol readiness gate passed 25 August 2026  
**Priority:** P1  
**Estimate:** 8 points  
**Milestone:** Manual food convenience  
**Updated:** 25 August 2026

## User story

As a user, I want to save foods I eat often as favourites, so that I can log a
repeat food quickly without re-entering its description and optional nutrition.

## Why now

uFast already supports reusable drink favourites through a local record-backed
Settings list, a Today picker and a historical editor path. Food entry still
starts with a blank editor every time, even when a user repeatedly records the
same food and nutrition values. A matching food-favourite flow reduces manual
entry while keeping every saved food event explicit, caloric and locally owned.

## Context and authority

- uFast is calm, private, local-first and offline-capable. There are no
  accounts, network dependencies, targets, coaching, health claims or
  nutrition estimates in this story.
- MVP scope includes text food events with optional manually entered nutrition;
  photo capture, AI interpretation and generated nutrition remain out of
  scope.
- D-003 defines food detail as a description with optional manual nutrition.
- S2-D1 defines the food description limit and the optional, independently
  validated nutrition fields and defensive numeric bounds.
- S2-D7 is the accepted product decision for food favourites and is recorded
  in `DECISIONS.md` by this story.
- D-013 and BR-07/BR-08 define food as always caloric and require the existing
  **Save and end fast** / **Cancel** atomic choice when a food event enters an
  active fast.
- BR-12, BR-15, BR-26 and BR-27 require absolute-time correctness, neutral
  record-based copy, one local SwiftData store and Delete All Data coverage.
- `docs/FAVOURITE_DRINK_MANAGEMENT_STORY.md` is the interaction and persistence
  baseline for editable record-backed favourites. It does not provide a food
  default or a food migration source.

## Product contract

### Favourite template data

- A food favourite is a reusable template, not a food event. It contains the
  food description and each optional nutrition value supported by the existing
  food editor: energy, protein, carbohydrate, fat, fibre, sugar and salt.
- Food favourites are always caloric. The favourite editor does not expose a
  caloric toggle and cannot create a non-caloric food event.
- The description is trimmed, must contain visible text and is limited to 200
  user-perceived characters. Descriptions are unique among current favourites
  after case-, width- and diacritic-insensitive normalization.
- Nutrition fields remain independently optional. Present values must be
  finite and within the existing 0–1,000,000 defensive range; the app does not
  calculate, estimate or recommend nutrition.
- Favourites retain creation order when edited. Creating, editing or removing
  a favourite never creates, edits or deletes a saved food event.
- A newly initialized store has no seeded food favourites. Existing food
  events are not converted automatically, and an empty favourite list is a
  valid committed state. Delete All Data removes favourite templates; renewed
  onboarding does not recreate one unless a later product decision adds an
  explicit default.

### Settings

- Settings contains a scrollable **Food favourites** section with every current
  template and an **Add food favourite** action.
- Each row shows the description and a concise indication of whether optional
  nutrition details are present. Any row opens the same editor for edit or
  removal.
- The editor titles are **Add food favourite** and **Edit food favourite**.
  Saving updates the same template identifier and order. Removal requires an
  explicit confirmation naming the food; cancelling leaves it unchanged.
- Removing the last template is valid. Settings continues to offer **Add food
  favourite** and the Today/History picker continues to offer **Add another
  food**.

### Today

- The existing **Log food** action opens a food picker when food favourites are
  available or when the empty-state action is needed. The picker lists current
  favourites and **Add another food** for the existing blank food editor.
- Selecting a favourite resolves its persisted identifier immediately before
  projecting a `FoodEntryDraft` with the current `AppClock.now` and stored
  description/nutrition, then uses the existing food save command. A successful
  selection creates one ordinary `FoodEntryRecord`, dismisses the picker and
  refreshes Today with an accessible success announcement.
- If the selection would enter an active fast, the existing caloric confirmation
  is shown. **Save and end fast** performs the existing atomic event-and-fast
  operation; **Cancel** creates neither record. The exact active-fast start
  remains invalid under the existing food editor/service rule.
- Editing or removing a favourite after a quick add changes only future quick
  adds. The saved food event retains the values used at its save time.

### History

- In the existing selected-date **Add food** journey, the user first sees the
  food picker. Selecting a favourite opens the existing food editor prefilled
  with its current template values and the selected occurrence date/time.
- A History favourite selection never saves immediately. The user must confirm
  the occurrence date/time and press the existing **Save** action. **Add another
  food** opens the same editor with an empty description and the selected time.
  Cancelling creates no event.
- Historical favourite entry uses the existing food validation, selected-day
  range, active-fast confirmation and atomic save behavior. It does not invent a
  timestamp or alter the favourite template.

## In scope

- Add a local record-backed food-favourite model, immutable snapshots, validator,
  CRUD store and draft projection.
- Add Settings create, edit, remove, validation, empty-state and persistence
  failure behavior for food favourites.
- Add Today favourite selection and immediate quick-add using the existing
  caloric food save policy.
- Add History favourite selection that pre-fills the existing food editor while
  requiring explicit occurrence-time save.
- Preserve food event history, active-fast semantics, local-only storage,
  Delete All Data and existing manual food entry.
- Add deterministic fixtures, localized copy, accessibility identifiers and
  focused unit/UI coverage for the new invariant.

## Out of scope

- Seeding a default food favourite or converting existing food events into
  favourites.
- Portion scaling, servings, recipes, categories, icons, reordering, search,
  recent-food suggestions or nutrition calculations.
- Photo capture, AI interpretation, generated nutrition, database lookup,
  coaching, targets, reminders, analytics, accounts, sync, backup, import,
  export, HealthKit, network access or monetization.
- Editing or deleting a saved food event through the favourite editor; existing
  Today and History food-event editors remain responsible for event CRUD.
- A new food-event persistence format or a favourite provenance field on
  `FoodEntryRecord`.

## Acceptance criteria

1. **Fresh-store and empty state.** Given a newly initialized local store with
   no food favourites, when the user opens Settings or Today, then the Food
   favourites section and picker remain usable, no food favourite is fabricated,
   Settings offers **Add food favourite**, and the picker offers **Add another
   food**. The existing blank food editor remains available.

2. **Create and persistence.** Given valid description and optional nutrition
   values, when the user creates a food favourite in Settings, then exactly one
   template is committed in creation order, remains always caloric, appears in
   Settings and both pickers, and survives relaunch. Creating it does not add a
   food event.

3. **Edit without rewriting history.** Given a food favourite and an existing
   food event created from it, when the user edits its description or any
   nutrition value and saves, then the same favourite identifier and order
   remain, the new values appear in Settings and both pickers, and the prior
   event retains its original description and nutrition.

4. **Remove and cancellation.** Given a food favourite, when the user chooses
   **Remove food favourite**, then the confirmation names that food; Cancel
   leaves the template unchanged, while Remove removes only the template from
   Settings and both pickers. The removed template remains absent after
   relaunch, including when it was the last template.

5. **Validation.** Given a blank, invisible, overlong or normalized-duplicate
   description, or a nutrition value that is negative, non-finite or above the
   existing defensive maximum, then Save is disabled or commit validation
   rejects it with an accessible field-specific explanation. Optional fields
   remain optional and valid zero values are retained.

6. **Today quick-add.** Given a current food favourite, when the user opens
   **Log food** and selects its picker row, then the command re-resolves the
   current persisted identifier and creates one ordinary caloric food event at
   `AppClock.now` using the current template values. The picker dismisses, Today
   shows the committed event, and a duplicate tap/callback cannot create a
   second event for the same in-flight selection. The in-flight selection has
   one deterministic operation identity; its UI commit-state identifier reports
   `saving`, `success` or `failure` so the duplicate-callback invariant is
   observable without relying on timing.

7. **Today active-fast integrity.** Given a current food favourite and an active
   fast, when the favourite event would be saved after the fast start, then the
   existing food confirmation offers only **Save and end fast** and **Cancel**.
   Cancel leaves both records unchanged; confirming saves the event and ends the
   fast atomically at the event time. A persistence failure leaves the fast and
   event state unchanged and keeps a usable retry/error state.

8. **History explicit time.** Given a selected past day and a food favourite,
   when the user chooses History **Add food** and selects that favourite, then
   the existing food editor opens with the template values and selected date/time.
   Only explicit Save creates the event; editing or removing the template later
   does not change it, and Cancel creates nothing.

9. **Stale and concurrent state.** Given a picker or editor snapshot becomes
   stale because a template was removed or renamed elsewhere, when the user
   attempts to save or quick-add, then the operation re-resolves or rejects the
   stale identifier without creating a ghost event, duplicate template or
   overwriting a newer committed edit. Updates and removals carry the snapshot's
   committed persisted `revision`; every committed update strictly increments
   that token, including when the injected clock does not advance. A mismatch
   returns a stale result, leaves the newer record unchanged and exposes the
   scoped stale-state identifier below. `updatedAt` is descriptive and is not
   the concurrency authority. The committed template/event state stays
   authoritative.

10. **Rollback and Delete All Data.** Given create, edit, remove, quick-add or
    Delete All Data persistence fails, then the last committed favourite list
    and all existing food history remain authoritative and the user receives a
    usable retry/error state. Given both existing Delete All Data confirmations
    complete successfully, all food favourites are deleted with the other local
    app-created records and onboarding returns; cancelling or failing leaves
    them unchanged. Renewed onboarding does not seed a food favourite. A V5
    store that cannot complete the required V5-to-V6 migration remains
    unchanged and presents `persistence.unavailable.title` and
    `persistence.unavailable.message`.

11. **Accessibility and offline use.** Given VoiceOver, Voice Control, large
    Dynamic Type, light/dark mode or no network, Settings rows, editor fields,
    picker rows, confirmations and retry states remain uniquely identifiable,
    readable, scrollable and operable. The local favourite and manual food
    journeys do not request permissions or require network access.

## Architecture, persistence and data boundaries

- Add a `FoodFavouriteRecord` in the current local SwiftData store with a UUID,
  description, the seven optional nutrition values, `createdAt`, `updatedAt`, a
  persisted `creationOrder` and a persisted monotonic `revision`. Add a value
  `FoodFavouriteSnapshot` and a
  store boundary analogous to `HydrationFavouriteRecord` and
  `SwiftDataHydrationFavouriteStore`.
- Add a food-favourite validator that reuses the established description and
  nutrition rules but has no occurrence-time or caloric-classification input.
  The projection creates a normal `FoodEntryDraft` at the caller-supplied
  instant; it must not persist a template reference or a second event type.
- Keep released V1–V5 schema declarations unchanged and add **V6** with the
  new entity plus the smallest suitable V5-to-V6 migration stage. A V5 on-disk
  fixture must open successfully, retain every existing record and produce an
  empty food-favourite list. A forced or simulated migration failure must
  preserve the original V5 store and present the existing
  `persistence.unavailable.title` and `persistence.unavailable.message` state.
  No migration may inspect food history to fabricate templates.
- Include the new entity in `AppDataDeletionService` and preserve the existing
  double-confirmation flow. Deleting all data must not cause a default food
  favourite to appear on relaunch.
- Extend immutable snapshots and composition boundaries for Settings, Today and
  History. Composition hosts may query SwiftData and map records into snapshots;
  feature views must not query SwiftData directly. Picker commands must resolve
  the persisted favourite by identifier immediately before projection.
- Reuse `FoodEntryService`/`CaloricEventCommands` for every food event so food
  remains caloric and active-fast save/end behavior stays atomic. Do not bypass
  inferred/reconstructed boundary reconciliation or the existing rollback path.
- Keep order and validation checks inside the local store/command boundary, not
  only in the editor. Guard duplicate UI callbacks with one deterministic
  operation identity per selection. Create starts the persisted revision at
  zero; every committed update strictly increments it, and update/remove
  commands require the expected revision. A mismatch returns a stale result so
  a stale view cannot create data after removal or overwrite a newer edit.
- Add no permission, network, analytics, diagnostic user-text, HealthKit or
  CloudKit behavior. Food descriptions and nutrition remain local user data.

## User-visible interaction and accessibility contract

- Settings retains the existing calm card/action-row pattern and adds a
  distinct **Food favourites** card. Rows use the description as their
  accessible label and announce a concise nutrition-present/absent value.
- Use stable identifiers for the new flow:
  `settings.food-favourites`, `settings.food-favourite.<record-id>`,
  `settings.food-favourite.add`, `settings.food-favourite.editor`,
  `settings.food-favourite.description`,
  `settings.food-favourite.details.toggle`,
  `settings.food-favourite.nutrition.<field>`,
  `settings.food-favourite.validation.description`,
  `settings.food-favourite.validation.nutrition.<field>`,
  `settings.food-favourite.stale`, `settings.food-favourite.save-error`,
  `settings.food-favourite.save`, `settings.food-favourite.cancel`,
  `settings.food-favourite.remove`,
  `settings.food-favourite.remove-confirm` and
  `settings.food-favourite.remove-cancel`.
- The Today picker uses `food.picker`, `food.favourite.<record-id>`,
  `food.custom`, `food.cancel`, `food.favourite.commit-state`,
  `food.favourite.success` (the success announcement identifier),
  `food.favourite.stale` and `food.favourite.save-error`.
  History keeps `history.add.food` for entry into the food picker and uses the
  same picker identifiers; the existing editor keeps `food.description`,
  `food.details.toggle`, `food.save` and `food.cancel` for event entry.
- Active-fast confirmation uses the stable food-scoped identifiers
  `food.favourite.confirmation.cancel`,
  `food.favourite.confirmation.primary` and
  `food.favourite.confirmation.consequence`, and must remain operable at large
  Dynamic Type. UI tests must query identifiers or scoped semantic containers
  rather than visible labels alone.

## Dependencies and explicit decisions

- Depends on the delivered manual food event flow (OW-201/OW-202), D-003,
  D-014, S2-D1, S2-D7, D-013, S3-D2, BR-07/BR-08/BR-26/BR-27 and the
  record-backed drink-favourite interaction/persistence baseline in OW-D101.
- S2-D7 is the authoritative product decision: the existing food description
  is the favourite’s label and saved event description; all optional nutrition
  values are reusable template values; Today selection quick-adds immediately
  at the injected clock instant; History selection opens the existing editor
  and requires explicit occurrence-time Save; food favourites have no seeded
  default and no automatic creation from history.
- No discovery story is required. The Sol readiness gate should verify the
  contract is executable as written; it must not leave the Today/History timing
  choice or description/nutrition model for implementation-time invention.

## Focused and integration verification

Run pure/domain and persistence checks before UI checks:

- Add focused `FoodFavouriteManagementTests` for trimming, visible text,
  normalized-description uniqueness, optional nutrition, order preservation,
  snapshot projection, stale IDs, duplicate callbacks and template/event
  isolation.
- Add focused store/repository tests for create, edit, remove, empty state,
  rollback and V5-to-current on-disk opening. Extend
  `PersistenceContainerTests`, `Slice3PersistenceMigrationTests` and
  `AppDataDeletionService` coverage deliberately; preserve all existing schema
  and record-identity assertions.
- Extend `ApplicationCommandsTests`, `FoodEntryServiceTests`,
  `CaloricBoundaryIntegrityTests`, `TodayDataProviderTests`,
  `FeatureControllerTests` and relevant History model tests for current-value
  re-resolution, `AppClock.now`, active-fast atomicity, selected historical
  time, retained events and refresh after mutations.
- Add explicit deterministic fixture states in
  `uFast/DevelopmentSupport/UITestDataReset.swift` and
  `uFast/DevelopmentSupport/UITestSeedFixtures.swift` for empty, populated,
  duplicate/validation, stale/removal, caloric-active-fast, failure and
  Delete All Data journeys. Do not seed food favourites implicitly in every
  test.
- Extend `uFast/App/AppLaunchConfiguration.swift`,
  `uFastTests/AppLaunchConfigurationTests.swift`,
  `uFastUITests/Support/UITestLaunchConfiguration.swift`,
  `uFastUITests/Support/UITestLaunchConfigurationTests.swift` and
  `uFastTests/FixtureTests.swift` for the food-favourite seed, failure and
  launch-argument contract. The parser, supported-flag set, reset/reseed
  behavior and fixture self-tests are part of the story's validation surface.
- Add story UI coverage in a dedicated food-favourite lifecycle suite and
  extend `FoodEntryUITests.swift`, `CaloricFoodUITests.swift`,
  `HistoryUITests+EntryJourneys.swift` and relevant navigation/accessibility
  journeys for Settings CRUD, Today quick-add, History prefill/Cancel, relaunch,
  active-fast confirmation, rollback, empty state and Delete All Data.
- Use `--ui-testing`, fixed clock values, explicit reset/seed arguments and
  bounded semantic waits for sheets, alerts, saves, dismissal and relaunch.
  Do not run the full UI suite during story work.
- Run `make project`, the focused unit/UI commands, `make analyze`, `make build`,
  `make lint` and the repository formatting check after source changes. After
  source freeze, run exactly one full parallel `make test-ui` invocation and
  inspect its `.xcresult` for four simulator clones and one result per test
  case, then run `make verify-ui-result UI_XCRESULT=<path>`.
- Manually check Settings, Today and History in light/dark mode, VoiceOver,
  Voice Control, increased contrast, large Dynamic Type and offline use. When
  an iPhone is connected, deploy the Sol-accepted build with
  `make deploy-iphone`.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | Empty Settings section and picker actions are usable with no fabricated food rows | Store/bootstrap unit test plus fresh-store food UI journey | Empty list, relaunch and blank-editor fallback | Focused test result and UI `.xcresult` |
| AC2 | One committed template preserves description/nutrition/order across relaunch and creates no event | Favourite store/domain tests and Settings lifecycle UI test | Optional fields omitted and zero values | Unit result, store snapshot and UI `.xcresult` |
| AC3 | Edit preserves favourite ID/order while future quick-add uses new values and prior event is unchanged | Store, command and event-isolation tests plus edit/relaunch UI test | Rename/details edit and saved-history comparison | Focused test log and UI `.xcresult` |
| AC4 | Confirmed removal removes only the template and remains absent | Store/persistence test and Settings/picker UI journey | Cancel, last-row removal and relaunch | Test result and UI `.xcresult` |
| AC5 | Invalid description/nutrition is rejected with field-specific accessible copy | Pure validator/store tests and validation UI test | Unicode normalization, invisible text, non-finite and max+1 values | Unit result and UI `.xcresult` |
| AC6 | Today picker resolves the current record and creates one food event at the fixed clock instant; `food.favourite.commit-state` exposes one operation identity | Application command/provider tests and Today quick-add UI test | Stale ID, duplicate callback and removed row | Focused test result and UI `.xcresult` |
| AC7 | Food active-fast choice is atomic and failure preserves both records | Food service/command tests and caloric-food UI test | Cancel, exact active start and simulated persistence failure | Unit result and UI `.xcresult` |
| AC8 | History favourite prefills the editor at the selected instant and saves only explicitly | History command/editor tests and History entry UI journey | Cancel, changed template after opening and selected-day boundary | Focused test result and UI `.xcresult` |
| AC9 | Stale/concurrent operations return a stale result on persisted `revision` mismatch and cannot create ghost events, duplicates or lost newer edits | Store/command optimistic-concurrency tests and stale UI journey using `settings.food-favourite.stale` / `food.favourite.stale` | Removed ID, concurrent rename at a fixed clock and repeated action | Focused test log, stale-state UI `.xcresult` and committed snapshot |
| AC10 | Write failure preserves committed list/history; V5→V6 migration failure preserves the V5 store and presents `persistence.unavailable.*`; Delete All removes favourites without reseeding | Rollback, V5→V6 migration, deletion tests plus failure UI journey | Cancel/failure, corrupt V5 store and relaunch after onboarding | Test result, original-store snapshot, persistence-unavailable UI `.xcresult` |
| AC11 | Stable IDs and semantics remain usable across accessibility and offline states | Accessibility UI tests plus manual device checklist | VoiceOver, Voice Control, large Dynamic Type, dark mode and no network | UI `.xcresult` and human checklist |

## Downstream fixture and legacy-suite impact inventory

| Existing path | Current assumption | Required treatment |
|---------------|--------------------|--------------------|
| `uFast/Persistence/FoodEntryRecord.swift` and `uFast/Domain/FoodEntryValidation.swift` | Food entries own descriptions, nutrition and occurrence time; food is always caloric | Keep event model and validation authoritative; add a template projection without occurrence time or a second caloric flag |
| `uFast/Persistence/PersistenceContainer.swift` and `docs/PERSISTENCE_MIGRATIONS.md` | V1–V5 schemas and migration plan are fixed | Preserve V1–V5; add V6 and the smallest V5→V6 stage for the new entity; prove empty-list success and original-store preservation on migration failure |
| `uFast/Persistence/AppDataDeletionService.swift` | Delete All Data enumerates current app-created entities | Delete food-favourite records atomically with existing data and preserve rollback |
| `uFast/Features/Goal/SettingsView.swift`, `SettingsSections.swift`, `SettingsFeatureController.swift` | Settings exposes only hydration favourites | Add a separate food-favourite snapshot, section, editor and command boundary without mixing drink fields |
| `uFast/Features/Today/FeatureSnapshots.swift`, `TodayDataProvider.swift`, `TodayGoalView.swift` | Today projects food events and hydration favourites; Log food opens a blank editor | Project food favourites separately; make Log food present the food picker and preserve blank custom entry |
| `uFast/Features/Fasting/DirectHistoricalEntryView.swift`, `HistoryView+Body.swift`, `HistoryPresentationModel+Data.swift` | History direct Add food opens the blank editor; only hydration favourites are loaded for the choice flow | Add food-favourite choice/prefill while preserving selected time, explicit Save and existing History refresh/motion boundaries |
| `uFast/Application/ApplicationCommands.swift` and `CaloricEventCommands.swift` | Food saves go through the caloric event boundary; hydration has ID re-resolution | Add food-favourite CRUD/projection and ID re-resolution; route every selected event through the existing food command |
| `uFastTests/FoodEntryValidationTests.swift`, `FoodEntryServiceTests.swift`, `CaloricBoundaryIntegrityTests.swift` | Tests assume every food draft has an occurrence time and remains caloric | Keep those invariants and add template projection/quick-add/atomicity cases; do not weaken event tests |
| `uFastTests/SwiftDataFoodEntryRepositoryTests.swift`, `PersistenceContainerTests.swift`, `Slice3PersistenceMigrationTests.swift` | Current schemas contain no food-favourite entity | Add V5-open/V6-round-trip and rollback coverage while preserving every legacy model assertion |
| `uFastTests/TodayDataProviderTests.swift`, `FeatureControllerTests.swift` and History tests | Snapshots contain food events and hydration favourites only | Extend snapshots/loaders and verify failed refresh retains authoritative favourite state |
| `uFast/DevelopmentSupport/UITestDataReset.swift` and `UITestSeedFixtures.swift` | Food seeds create events, while favourite seeds are hydration-only | Add explicit food-favourite seeds and reset isolation; never use event history as an implicit template seed |
| `uFast/App/AppLaunchConfiguration.swift`, `uFastTests/AppLaunchConfigurationTests.swift`, `uFastUITests/Support/UITestLaunchConfiguration.swift`, `uFastUITests/Support/UITestLaunchConfigurationTests.swift`, `uFastTests/FixtureTests.swift` | Launch flags, supported-flag validation and reset/reseed self-tests enumerate only current fixtures | Add food-favourite seed/failure flags, parser coverage, supported-flag assertions and no-default/reseed assertions |
| `uFastUITests/FoodEntryUITests.swift`, `CaloricFoodUITests.swift`, `HistoryUITests+EntryJourneys.swift` and navigation/accessibility suites | `food.add` opens a blank editor and History Add food has no favourite choice | Preserve existing selectors and add picker, prefill, active-fast, failure, relaunch and accessibility journeys |
| `uFast/Resources/Localizable.xcstrings` and localization tests | Food copy covers event editor and drink picker only | Add food-favourite Settings/picker/editor/validation/announcement copy and catalog-key tests; keep user descriptions out of catalog content |

## Execution profile

- **Uncertainty:** medium
- **Initial implementer:** Luna xhigh
- **Deterministic reproduction and observability:** Use a fixed `AppClock`, an
  empty in-memory store for Settings/Today, a V5 on-disk store containing food
  history but no favourites, and explicit populated/active-fast/failure seeds.
  Observe favourite IDs, creation order, persisted revisions, optional nutrition, event snapshots,
  active-fast state, selected History instant, picker identifiers and relaunch
  state. UI tests use `--ui-testing` and stable record-ID selectors.
- **Acceptance matrix and downstream fixture/legacy-suite impact:** AC1–AC11
  each have a test layer, negative path and artifact above; all current food,
  persistence, deletion, fixture, History and accessibility assumptions are
  inventoried.
- **Focused correction budget:** One bounded diagnostic pass, then at most
  three focused correction attempts per acceptance surface; stop on repeated
  failures, fixture broadening or scope expansion and use the repository
  circuit breaker.
- **Expected expensive commands:** `make project`, focused Xcode unit tests,
  focused story UI tests, `make analyze`, `make build`, `make lint` and one
  final four-worker `make test-ui` after source freeze.
- **Maximum rescue tier:** Terra rescue for an unresolved implementation
  surface, then read-only Sol diagnosis if the schema/source-of-truth or
  active-fast boundary remains ambiguous.

## Definition of Ready

- [x] One coherent outcome: reusable local food templates with Settings CRUD,
  Today quick-add and explicit-time History entry.
- [x] Food fields, caloric semantics, no-default behavior and event isolation
  are explicit.
- [x] Acceptance criteria map to observable tests, negative paths and
  artifacts.
- [x] Stable accessibility identifiers and deterministic fixture requirements
  are named.
- [x] Persistence, migration, deletion, rollback, privacy, accessibility and
  offline boundaries are explicit.
- [x] Downstream fixtures and legacy suites are inventoried.
- [x] S2-D7 records the accepted food-favourite product contract.
- [x] V6/V5 migration preservation and failure behavior are observable.
- [x] Operation identity, stale revision behavior and all new test selectors
  are explicit.
- [x] Sol readiness gate has returned an explicit READY verdict.

## Sol readiness gate

**Verdict:** READY

**Reviewer:** Read-only Sol gate, medium reasoning, 25 August 2026

**Product decision status:** S2-D7 is accepted, authoritative and consistent
with existing product and domain rules.

**Scope and acceptance status:** Complete, coherent, bounded and independently
testable across AC1–AC11.

**Test observability and fixture-impact status:** Complete; deterministic
operation identity, monotonic revision checks, exact selectors, migration
artifacts and downstream fixture/configuration impacts are explicit.

**Architecture/data/accessibility/privacy status:** Complete; V6 compatibility,
rollback, deletion, snapshot boundaries, local-only data, accessibility and
privacy constraints are clear.

**Execution profile and testability status:** Ready; medium uncertainty,
deterministic evidence and bounded correction/escalation are appropriate.

**Missing evidence or contradictions:** None.

**Required changes:** None.
**Recommended initial implementer:** Luna xhigh.

## Done when

All acceptance criteria and the repository Definition of Done pass, the food
favourite schema and local store remain backward compatible, existing food
history and caloric-boundary behavior remain intact, focused and integration
evidence is recorded, and a connected iPhone receives the verified build when
available.
