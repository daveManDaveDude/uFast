# OW-D101 — Manage default and custom favourite drinks in Settings

**Status:** Ready — Sol readiness gate passed 25 August 2026
**Priority:** P1  
**Estimate:** 8 points  
**Milestone:** Manual hydration convenience  
**Updated:** 25 August 2026 — default favourites become ordinary editable records

## User story

As a user, I want every drink shortcut to be editable and removable, so that my
favourite list reflects what I actually drink and I am not forced to keep
defaults I do not use.

## Why now

The current app has two competing favourite models: Water, Tea and Coffee are
immutable shortcut types whose amounts live on `AppSettingsRecord`, while
user-created drinks are `HydrationFavouriteRecord` rows. This prevents a user
from renaming, reclassifying or removing a default and makes the default list
different for new and existing installs. One local, record-backed list makes
the Settings and Today/History picker behavior predictable and allows a new
user to start with only the requested Water shortcut at 330 ml.

## Context and authority

- Product promise: calm, private, local-first manual hydration with no targets,
  coaching, health claims, network access or account.
- MVP scope includes Water, tea, coffee and custom hydration events, with
  explicit caloric classification for hydration.
- BR-06, BR-07, BR-08, BR-12, BR-26 and BR-27 remain in force.
- S2-D2 and S2-D3 were amended on 25 August 2026 by OW-D101 to replace the old
  500/300/300 defaults and immutable built-in ownership while retaining the
  existing metric, bounds, classification, Today two-tap and History editor
  rules.
- `docs/PERSISTENCE_MIGRATIONS.md` requires V1–V4 schemas to remain unchanged,
  a higher version for schema changes, and on-disk migration evidence.
- Existing boundaries include `HydrationFavouriteRecord`,
  `HydrationFavouriteSnapshot`, `SwiftDataHydrationFavouriteStore`,
  `HydrationFavouriteProvider`, `AppSettingsRecord`, the Today/History data
  providers and `AppDataDeletionService`.

## Product contract

### New local stores

- A newly initialized local store contains exactly one ordinary favourite:
  **Water**, **330 ml**, **Non-caloric**. Tea and Coffee are not seeded.
- Water is a normal editable/removable favourite record, not a reserved name or
  immutable type. A user may later create a favourite named Tea or Coffee after
  those rows have been removed, subject to ordinary normalized-name uniqueness.
- The initial record is created through the same local persistence boundary as
  the settings authority. It is not a UI-only fallback and is deterministic in
  tests through `AppClock`.

### Existing local stores

- On the first launch of the new behavior, an existing pre-change store's
  current Water, Tea and Coffee amounts are converted into three ordinary,
  non-caloric favourite records named Water, Tea and Coffee. Customized amounts
  are preserved exactly; the old default amounts are not re-applied.
- Existing user-created favourite records are retained. The converted rows are
  ordered Water, Tea, Coffee, then the existing user-created rows in their
  prior relative order. Editing a row never changes its order.
- The conversion is one-time and idempotent. It uses a persistent migration
  marker or an equivalent schema-level guarantee, so deleting a converted row
  never causes it to reappear on relaunch. It must not decide whether to run
  merely from the absence of a row with a particular name.
- A pre-change store with no user-created rows still receives all three
  converted records. A pre-change store with customized defaults and existing
  favourites preserves both sets without changing hydration history.
- A corrupt or conflicting pre-change store that cannot be converted safely
  remains protected by the existing persistence-unavailable/integrity path. It
  must not create duplicate names, partially rewrite the list or rewrite
  history.

### All favourite rows

- Settings shows one scrollable **Drink favourites** list containing every
  current record. Each row exposes its name, amount and **Caloric** or
  **Non-caloric** state and opens the same editor for create and edit.
- Any row, including converted Water, Tea and Coffee, can change name, amount
  or caloric classification, and can be removed after explicit confirmation.
- Names are trimmed, require visible text, allow at most 80 user-perceived
  characters and are unique after case-, width- and diacritic-insensitive
  comparison among current records. There are no reserved built-in names.
- Amounts remain integers from 1 through 5,000 ml. New favourites default to
  non-caloric and expose the existing **Counts as caloric** control.
- Removing the last favourite is valid. The Settings list still offers
  **Add favourite**, and the picker remains usable through **Add another drink**.
- A favourite is a reusable template, not hydration history. Creating,
  editing or removing it never adds, rewrites or deletes a hydration event.
- The Today and History drink pickers use the same authoritative record list.
  Today quick-add resolves the current persisted record by identifier before
  saving immediately at `AppClock.now`; History resolves the record into the
  existing historical drink editor, which saves only after explicit occurrence
  time confirmation. Stale values cannot be used after an edit or removal.

## In scope

- Replace the separate immutable Water/Tea/Coffee Settings controls with the
  record-backed favourite list and shared create/edit/remove editor.
- Seed a new local store with only Water at 330 ml, non-caloric.
- Convert pre-change Water, Tea and Coffee settings into ordinary records in a
  safe, idempotent local migration/bootstrap transaction.
- Preserve existing user-created favourites, their relative order, customized
  legacy amounts and all hydration/food/fast history.
- Allow create, edit, reclassify and remove for converted and user-created
  favourites, including deletion of Water, Tea or Coffee.
- Show the same list in Today and History pickers and preserve the existing
  caloric-active-fast confirmation and atomic save behavior.
- Update deterministic fixtures, migration fixtures, localized copy, tests and
  accepted decision references needed to make the new invariant authoritative.

## Out of scope

- Editing or deleting recorded hydration events through the favourite editor;
  existing timeline/history event journeys remain responsible for that.
- Reordering, icons, colors, categories, pinning, hydration targets,
  recommendations, reminders or nutrition estimates.
- Automatically recreating a deleted favourite or automatically favoriting a
  manually entered drink.
- Import, export, sync, backup, accounts, analytics, permissions, network use,
  AI, coaching, monetization or health claims.
- Rewriting old `.water`, `.tea`, `.coffee` or custom hydration records. New
  quick-add events from record-backed favourites may use the existing custom
  hydration representation with the favourite's stored name; their saved
  values and classification are authoritative.

## Acceptance criteria

1. **New-user defaults.** Given a newly initialized local store, when the user
   reaches the main app, then Settings and the Today/History drink pickers show
   exactly one favourite named Water at 330 ml and Non-caloric; Tea and Coffee
   are absent, and the Water row is editable and removable.
2. **Existing-user conversion.** Given a pre-change on-disk store whose
   settings contain customized Water, Tea and Coffee amounts, when the new
   build opens it, then exactly three ordinary records named Water, Tea and
   Coffee exist with those amounts, all Non-caloric, in that order, and the
   existing settings, fasts, food and hydration events retain their prior
   values and identifiers.
3. **Conversion with custom rows.** Given a pre-change store that already has
   user-created favourite records, when conversion completes, then all three
   converted rows appear before the existing rows and the existing rows retain
   their identifiers, values and relative order.
4. **Idempotence and deletion persistence.** Given conversion has completed,
   when the store is reopened and when a converted row is later removed and the
   store is reopened again, then conversion does not duplicate or recreate any
   row and the committed deletion remains absent.
5. **Edit any favourite.** Given any converted or user-created favourite, when
   the user opens its row, changes its name, amount or caloric classification
   and saves, then the same record identifier and order remain, the updated row
   appears in Settings and both pickers, and later quick-add uses the new values.
   Names Water, Tea and Coffee are valid ordinary names when not duplicated.
6. **Remove any favourite.** Given any favourite is open, when the user chooses
   **Remove favourite**, then a confirmation names that favourite; Cancel leaves
   it unchanged, while Remove removes only the template from Settings and both
   pickers. A removed favourite never returns after relaunch.
7. **Create and empty state.** Given zero or more favourites, when the user
   chooses **Add favourite**, enters valid values and saves, then one ordinary
   record is added in creation order. When the last row is removed, Settings
   still offers **Add favourite** and the picker still offers **Add another
   drink** without showing an empty-state error.
8. **Quick-add and history integrity.** Given a record-backed favourite, when
   the user selects it in Today's drink picker, then the command resolves the
   current record and saves one hydration event immediately at `AppClock.now`.
   Given the user selects the same kind of favourite from History, then the
   existing historical drink editor opens with the selected date/time and only
   an explicit Save creates the event; Cancel creates nothing. Editing or
   removing the favourite later does not change a saved event. A caloric
   selection during an active fast follows the existing **Save and end fast** /
   **Cancel** atomic choice.
9. **Validation and stale state.** Given a blank, overlong, duplicate,
   normalized-equivalent name or amount outside 1–5,000 ml, Save is disabled or
   commit validation rejects it with an accessible field-specific explanation.
   A stale identifier, duplicate save callback or concurrent rename cannot
   create a duplicate or quick-add a removed record.
10. **Rollback.** Given create, edit, remove or Delete All Data persistence
    fails, the last committed favourite list and all existing history remain
    authoritative; unsaved editor values remain available where applicable and
    the user receives a usable retry/error state. Given conversion/bootstrap
    fails, the app preserves the original local store and presents the existing
    persistence-unavailable state with accessible identifiers
    `persistence.unavailable.title` and `persistence.unavailable.message`.
11. **Delete all data.** Given the user completes both existing Delete All Data
    confirmations, then every favourite record is deleted with the other local
    app-created data and the app returns to onboarding. Cancel or failure leaves
    favourites unchanged. When the user completes onboarding again, exactly one
    new Water/330/non-caloric favourite is seeded; relaunching does not add a
    second Water row.
12. **Accessibility and offline use.** Given VoiceOver, Voice Control, large
    Dynamic Type, light/dark mode or no network, every row and editor control
    remains uniquely identifiable, readable, scrollable and operable; the
    local favourite and quick-add journeys remain available offline.

## Architecture, persistence and data boundaries

- `HydrationFavouriteRecord` is the sole post-migration source of truth for
  favourite names, amounts, classification and order. `AppSettingsRecord` may
  retain legacy fields for schema compatibility, but no runtime shortcut,
  picker or Settings control may continue to use them as a second authority.
- Leave released V1–V4 schema declarations unchanged. If the conversion needs
  a schema change, add the next version and a custom migration stage; if it can
  run as a post-open compatibility transformation, it must still be one-time,
  atomic, idempotent and covered by an on-disk V4 fixture. Do not replace the
  store or use UI-test reset/seeding as a production migration.
- Persist converted identifiers and canonical order. The conversion may use
  migration-time timestamps, but must not use timestamps as its only migration
  marker or reorder existing user-created rows unexpectedly.
- Use immutable snapshots across Settings, Today and History. Quick-add must
  resolve the persisted identifier immediately before creating the draft.
- Keep the existing local SwiftData store, CloudKit-disabled configuration,
  `AppClock` injection, rollback-safe transactions, settings-authority checks,
  active-fast caloric confirmation and Delete All Data transaction. Seed the
  one-Water default only when a new settings authority is created (including
  renewed onboarding after successful Delete All Data), never whenever the
  favourite list happens to be empty.
- No permission, network, analytics or external data access is introduced.

## User-visible interaction and accessibility contract

- Settings retains the **Drink favourites** card and calm action-row treatment.
  Every row is a button with the favourite name as its accessible label and an
  accessible value containing amount and caloric state.
- The editor retains the titles **Add favourite** and **Edit favourite** and
  the existing identifiers `settings.favourite.editor`,
  `settings.favourite.name`, `settings.favourite.amount`,
  `settings.favourite.caloric`, `settings.favourite.save`,
  `settings.favourite.cancel`, `settings.favourite.remove`,
  `settings.favourite.remove-confirm` and `settings.favourite.remove-cancel`.
- All Settings rows use `settings.favourite.<record-id>` and all picker rows
  use `drink.favourite.<record-id>`; tests must not depend on the old
  type-specific `settings.drink.*` or `drink.favourite.water/tea/coffee`
  selectors. The add actions remain `settings.favourite.add` and
  `drink.custom`, and the picker remains `drink.picker`.
- Keep the existing exact validation, save-failure and removal-failure copy
  unless localization review requires an equivalent translation. Do not add
  celebratory, judgmental or intake-target language.

## Dependencies and explicit decisions

- Delivered OW-202 through OW-205, BR-06 through BR-08, BR-12, BR-26 and BR-27.
- `DECISIONS.md` S2-D2 and S2-D3 now record the new default/ownership contract,
  Today immediate quick-add and History's explicit timestamp-confirmation
  editor. S2-D4 remains the caloric active-fast choice.
- `docs/PERSISTENCE_MIGRATIONS.md` and the existing V4 migration fixtures are
  required implementation references.
- This story refines existing OW-D101 rather than creating a second drink
  management story. The backlog backlink remains the same.

## Focused and integration verification

Focused verification must run pure/domain and persistence checks before UI:

- Extend `uFastTests/HydrationFavouriteManagementTests.swift` for no reserved
  names, all-record ordering, ordinary Water/Tea/Coffee editing/removal,
  stale identifiers, quick-add projection and rollback.
- Update `uFastTests/HydrationFavouriteSettingsTests.swift`,
  `uFastTests/FeatureControllerTests.swift`, `uFastTests/HydrationEntryTests.swift`
  and related provider tests for the removal of the old dual-source defaults.
- Add an on-disk pre-change/V4 migration fixture covering default amounts,
  customized amounts, existing user-created rows, second-open idempotence,
  deletion persistence, migration failure and unchanged history. Assert
  `persistence.unavailable.title` and `persistence.unavailable.message` for
  the failure state. Update
  `uFastTests/PersistenceContainerTests.swift`,
  `uFastTests/Slice3PersistenceMigrationTests.swift` and schema contract tests
  deliberately rather than weakening their existing compatibility assertions.
- Update deterministic seeds and reset behavior in
  `uFast/DevelopmentSupport/UITestDataReset.swift` and
  `uFast/DevelopmentSupport/UITestSeedFixtures.swift` so new-user, migrated,
  populated, duplicate, corrupt, empty and failure states are explicit and
  isolated per test.
- Extend `uFastUITests/HydrationQuickAddUITests.swift`,
  `uFastUITests/HydrationFavouriteValidationUITests.swift` and the relevant
  hydration/history journeys for fresh defaults, migrated defaults, editing and
  removing Water/Tea/Coffee, relaunch, empty picker state, retained events,
  active-fast caloric handling and Delete All Data. After successful Delete All
  Data, complete onboarding again and verify one Water/330 row, then relaunch
  and verify no duplicate. Use waits for navigation, alerts and persistence
  results.
- Run `make test-unit`, `make analyze`, `make build`, `make lint` and the
  repository formatting check after focused changes. After source freeze, run
  one full parallel `make test-ui` invocation and inspect its `.xcresult` for
  all four simulator clones and exactly one result per test case.
- Manually check Settings, Today and History after migration in light/dark
  mode, VoiceOver, Voice Control, increased contrast, large Dynamic Type and
  offline use. On a connected iPhone, deploy the accepted build with
  `make deploy-iphone`.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | New store has only Water/330/non-caloric in Settings and pickers | Unit/bootstrap plus `HydrationQuickAddUITests` fresh-store journey | Tea/Coffee absent; Water edit/remove | Focused test result and UI `.xcresult` |
| AC2 | V4 disk store converts customized legacy defaults into 3 records and preserves history | On-disk migration test in `PersistenceContainerTests`/`Slice3PersistenceMigrationTests` | Migration failure and conflicting authority | Migration test log and store snapshot |
| AC3 | Converted rows precede retained custom rows without changing custom identity/order | Persistence/domain tests plus migrated UI fixture | Empty custom list and multiple custom rows with equal timestamps | Unit result and fixture snapshot |
| AC4 | Reopen is idempotent; deleted converted row stays deleted | Disk reopen test and UI relaunch journey | Partial/duplicate callback and removed Water/Tea/Coffee | Test result and relaunch UI evidence |
| AC5 | Any record opens shared editor, preserves ID/order and changes future quick-add values | `HydrationFavouriteManagementTests`, focused UI edit journey | Rename to Water/Tea/Coffee; cancel/save failure | Unit result and UI `.xcresult` |
| AC6 | Confirmed removal removes row from Settings and pickers | Focused UI removal journey | Cancel, last-row removal, relaunch | UI `.xcresult` |
| AC7 | Valid create adds one record and empty state remains usable | Domain/store tests and favourite UI lifecycle tests | Duplicate callback and zero favourites | Test result and UI `.xcresult` |
| AC8 | Today saves the current snapshot immediately; History opens its timestamp-confirmation editor; history is retained and caloric active-fast choice remains atomic | Application/domain tests plus Today/History UI journeys | History Cancel; edit/delete after prior event; Cancel active-fast confirmation | Unit result and UI `.xcresult` |
| AC9 | Invalid/stale/concurrent operations are rejected without mutation | Validator/store/controller tests | Unicode normalization, stale ID and duplicate save | Focused test log |
| AC10 | Normal write failures preserve the committed list and editor retry state; conversion failure presents `persistence.unavailable.title` and `.message` without replacing the store | Store rollback tests, migration/bootstrap tests and simulated-failure UI tests | Conversion, Delete All and conflicting-authority failure | Focused test result, store snapshot and UI `.xcresult` |
| AC11 | Delete All removes all favourites, returns to onboarding, and renewed onboarding seeds exactly one Water/330/non-caloric row that remains singular after relaunch | `PersistenceContainerTests`/deletion tests and UI Delete All → onboarding → relaunch journey | Cancel, simulated failure and no reseed while the list is merely empty | Test result and UI `.xcresult` |
| AC12 | Identifiers, labels, values and controls remain usable in accessibility/offline states | Accessibility UI journeys plus manual device check | Large Dynamic Type, VoiceOver, no network | UI `.xcresult` and human checklist |

## Downstream fixture and legacy-suite impact inventory

| Existing path | Current assumption | Required treatment |
|---------------|--------------------|--------------------|
| `uFast/Domain/HydrationEntryValidation.swift` | Provider synthesizes three built-ins from settings and reserves their names | Make record snapshots canonical; retain historical event-type compatibility without reserved-name validation |
| `uFast/Persistence/AppSettingsRecord.swift` and `SwiftDataSettingsStore.swift` | Water/Tea/Coffee amounts are mutable shortcut authority | Deprecate/remove runtime use after conversion; keep schema compatibility and migrate values safely |
| `uFast/Persistence/PersistenceContainer.swift`, `uFast/Persistence/PersistenceBootstrap.swift`, `uFast/App/UFastApp.swift` | V1–V4 schemas and bootstrap failure path are fixed | Preserve old schemas; add the smallest new stage/one-time transformation required by the conversion; assert `persistence.unavailable.*` on failure |
| `uFast/Application/ApplicationCommands.swift` | User-created and built-in favourites resolve through different authorities | Resolve every picker identifier through the favourite store and keep caloric event atomicity |
| `uFast/Features/Goal/SettingsSections.swift` and `HydrationFavouriteEditor.swift` | Built-ins use inline fields; only custom rows open editor | Render one editable/removable row model with existing editor identifiers |
| `uFast/Features/Today/AddDrinkSheet.swift`, Today and History hosts | Picker has type-specific built-in IDs plus custom IDs | Use one record-backed list and model-ID selectors |
| `uFast/DevelopmentSupport/UITestDataReset.swift` and `UITestSeedFixtures.swift` | Reset/onboarded seeds rely on old settings defaults and custom-only fixtures | Add explicit fresh, migrated, empty, duplicate, corrupt and failure fixtures with deterministic IDs/clock |
| `uFastTests/HydrationFavouriteManagementTests.swift` | Water is reserved; custom rows are the only editable records | Replace reserved-name assertion and cover converted/default rows |
| `uFastTests/HydrationFavouriteSettingsTests.swift`, `FeatureControllerTests.swift`, `HydrationEntryTests.swift`, `PersistenceTransactionTests.swift` | Old 500/300/300 provider/controller assumptions | Update to record-backed default contract without weakening unrelated hydration validation |
| `uFastTests/PersistenceContainerTests.swift`, `Slice3PersistenceMigrationTests.swift`, `MNT008IdentitySchemaFeasibilityTests.swift` | V4 migration preserves settings and may expect no favourites | Add conversion assertions while preserving every existing record/value check |
| `uFastUITests/HydrationQuickAddUITests.swift` and favourite validation/lifecycle suites | Expect 500/300/300 and old type-specific selectors | Cover Water/Tea/Coffee record rows, edit/remove, fresh/migrated relaunch and new selectors |
| `uFastUITests/HydrationCustomAndTimelineUITests.swift`, `History*` hydration journeys | Use `drink.favourite.water/tea/coffee` and assume built-ins | Update selectors/fixtures and verify old recorded events remain unchanged |

## Execution profile

- **Uncertainty:** high
- **Initial implementer:** Luna xhigh
- **Deterministic reproduction and observability:** Use a fixed `AppClock`, a
  clean local store for the one-Water seed, an independent V4 on-disk fixture
  with customized settings and optional custom rows for conversion, and a
  second-open/delete/reopen sequence. Observe the persisted record IDs,
  canonical order, values, migration marker, picker snapshots and hydration
  event snapshots. UI tests use `--ui-testing`, reset/seed fixtures, stable
  record-ID accessibility identifiers and bounded semantic waits.
- **Acceptance matrix and downstream fixture/legacy-suite impact:** All AC1–AC12
  have a verification row above; every known old default/selector assumption is
  listed in the downstream inventory.
- **Focused correction budget:** One bounded diagnostic pass, then at most
  three focused correction attempts per acceptance surface; stop on repeated
  failures or scope expansion and use the repository circuit breaker.
- **Expected expensive commands:** `make project`, focused Xcode unit tests,
  focused UI tests, `make analyze`, `make build`, `make lint`, and one final
  four-worker `make test-ui` after source freeze.
- **Maximum rescue tier:** Terra rescue for an unresolved implementation
  surface, then read-only Sol diagnosis if the migration/source-of-truth root
  cause remains ambiguous.

## Definition of Ready

- [x] One coherent outcome: all favourite drinks are record-backed and
  editable/removable, with explicit new/existing default behavior.
- [x] Existing-user conversion, idempotence, deletion persistence and history
  preservation are observable.
- [x] Acceptance criteria map to test layers, negative paths and artifacts.
- [x] Stable accessibility identifiers and deterministic fixture requirements
  are named.
- [x] Persistence, privacy, offline, accessibility and Delete All boundaries are
  explicit.
- [x] Downstream fixtures and legacy suites are inventoried.
- [x] S2-D2, S2-D3 and affected decision references have been amended in the
  authoritative decision record.
- [x] Sol readiness gate has returned an explicit READY verdict.

## Sol readiness gate

**Verdict:** READY

**Reviewer:** Read-only Sol gate, medium reasoning, 25 August 2026

**Product decision status:** Accepted and authoritative; S2-D2 and S2-D3 align
with the story and existing domain rules.

**Scope and acceptance status:** Complete, coherent, bounded and independently
testable across AC1–AC12.

**Test observability and fixture-impact status:** Complete, including Delete All
Data, renewed onboarding, exactly-once Water seeding and relaunch checks.

**Architecture/data/accessibility/privacy status:** Ready; no missing boundary.

**Execution profile and testability status:** Ready; no discovery split required.

**Missing evidence or contradictions:** None.

**Required changes:** None.
**Recommended initial implementer:** Luna xhigh.

## Done when

All acceptance criteria and the repository Definition of Done pass, S2-D2 is
updated, the accepted source has focused and integration evidence, the local
store remains backward compatible, and a connected iPhone receives the
verified build when available.
