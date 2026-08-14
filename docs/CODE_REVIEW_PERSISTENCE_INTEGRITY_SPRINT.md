# Persistence integrity review sprint

**Sprint:** PI-100  
**Status:** Ready  
**Prepared:** 14 August 2026  
**Goal:** Preserve stores created by the release baseline and fail closed whenever History motion encounters ambiguous active-fast authority.  
**Stories:** PI-101, PI-102  
**Product rules:** BR-03, BR-10, BR-17, BR-26, BR-28, BR-33  
**Repository guidance:** `AGENTS.md`, `docs/PERSISTENCE_MIGRATIONS.md`

## Review findings and disposition

The first P1 finding appears twice in the supplied review. It is one defect and
is covered once by PI-101.

Both distinct findings are valid:

- The production `UFastSchemaV1` currently points at the mutable current
  `AppSettingsRecord`. That model contains
  `automaticLiveActivityPreferenceRawValue`, but the unversioned release
  baseline at merge-base `d63dc026` did not. A store created by that baseline
  therefore does not match the checksum represented by the alleged V1 schema.
  The existing migration fixture is circular because it creates its source
  store from `UFastSchemaV1.models` and even writes the new preference.
- `SwiftDataHistoryMotionDataProvider.fetch` fetches every active
  `FastRecord`, takes `.first`, and can project an arbitrary record when local
  integrity is already broken. Settled History and Today use
  `ActiveFastAuthority` and reject the same state, so the motion runway can
  temporarily contradict the authoritative surfaces.

This sprint changes no product behavior for a valid store. It adds no data
repair, deletion, inference, networking, CloudKit, coaching, or new UI.

## Release-baseline schema evidence

The historical V1 contract is the unversioned production schema at merge-base
`d63dc026`:

- `AppSettingsRecord` has `id`, `fastingGoalHours`,
  `hasCompletedOnboarding`, `waterFavouriteMillilitres`,
  `teaFavouriteMillilitres`, and `coffeeFavouriteMillilitres` only.
- `FastRecord`, `FoodEntryRecord`, `HydrationEntryRecord`, and
  `UnknownPeriodRecord` retain their historical persisted declarations.
- `automaticLiveActivityPreferenceRawValue` does not exist.
- `HydrationFavouriteRecord` does not exist.

The current V2 contract adds the automatic Live Activity preference with its
default of `notAsked` and adds `HydrationFavouriteRecord`. Method-only or
computed-property changes do not define a new stored schema.

If implementation evidence shows that another schema was distributed to real
users, stop and report the evidence rather than inventing or renumbering a
migration path. Repository commit order alone is not evidence of a released
store contract.

## Story order and dependency

1. PI-101 is P1 and must be accepted first because it protects app bootstrap
   and all local user data.
2. PI-102 is P2 and may then reuse the established integrity authority without
   touching schema declarations.

The stories intentionally remain separate so migration review and History
runtime review each have a bounded diff, focused tests, and independent Sol
acceptance. Together they implement this sprint's single persistence-integrity
goal.

---

## PI-101 — Freeze the release schema and prove real V1 migration

**Priority:** P1 data availability  
**Status:** Ready  
**Estimate:** 3 points  
**Depends on:** None

### User story

As an existing uFast user, I want an app update to open my local records
without loss or reset, so that fasting, food, hydration, settings, and legacy
history remain available after upgrading.

### Outcome

`UFastSchemaV1` is an immutable declaration of the actual unversioned release
schema, `UFastSchemaV2` is the current schema, and the migration test starts
from an independently declared historical fixture. Opening the fixture through
`PersistenceContainer` performs the lightweight V1-to-V2 migration, preserves
all historical meaning, initializes the new automatic preference to
`notAsked`, and leaves hydration favourites empty.

### In scope

- Replace references from `UFastSchemaV1` to mutable current model types with
  frozen historical model declarations matching merge-base `d63dc026` exactly.
- Keep historical declarations isolated from production domain behavior. The
  app continues to use current model types after migration.
- Preserve the current V2 production model set and one explicit lightweight
  migration stage from V1 to V2.
- Refactor model placement or add current-model aliases only as required by
  SwiftData's versioned-schema identity rules. Preserve existing production
  call-site names and behavior.
- Rewrite the on-disk migration fixture so its source schema and model types
  are independently frozen test declarations or an equivalent immutable
  historical artifact. It must not use `UFastSchemaV1.models`,
  `UFastSchemaV2.models`, `PersistenceContainer.schema`, or current production
  `AppSettingsRecord` to create the source store.
- Preserve every release-baseline identifier, timestamp, goal, provenance,
  nutrition value, hydration value, onboarding state, and unknown-history
  value through migration.
- Assert additive defaults after migration: automatic Live Activities are
  `notAsked` and no hydration favourites are fabricated.
- Update `docs/PERSISTENCE_MIGRATIONS.md` only if the implementation reveals a
  reusable rule not already recorded there.

### Out of scope

- A V3 schema without evidence of a distinct released intermediate schema.
- Destructive recovery, store replacement, reset, deletion, silent rewriting,
  or repair of existing user records.
- CloudKit, backup, restore, import, export, or a second store.
- Changing automatic Live Activity consent behavior or creating default
  hydration favourite records.
- Hand-editing `uFast.xcodeproj`.

### Acceptance criteria

1. Given a disk store created from an independent declaration of the exact
   unversioned release schema, when `PersistenceContainer.make(storeURL:)`
   opens it, then bootstrap succeeds through the V1-to-V2 migration and does
   not return or require the unavailable fallback.
2. Given that legacy store contains settings, recorded/active/reconstructed
   fasts, food with complete nutrition, caloric hydration, and an unknown
   period, after migration every original identifier, stored absolute instant,
   goal, provenance field, boundary reference, classification, quantity, and
   onboarding value is unchanged.
3. Given the V1 settings row has no automatic preference column, after
   migration its current `automaticLiveActivityPreference` is `notAsked`; it
   is never inferred as enabled or disabled.
4. Given V1 has no hydration-favourite entity, after migration fetching
   `HydrationFavouriteRecord` returns zero records and all existing hydration
   entries remain unchanged.
5. Given the migration test source is inspected, it has no dependency on any
   production V1/V2 model list or current production settings model that could
   make the fixture checksum drift with the destination schema.
6. Given `UFastSchemaV1` is inspected, its stored declarations exactly match
   merge-base `d63dc026` and contain neither
   `automaticLiveActivityPreferenceRawValue` nor
   `HydrationFavouriteRecord`; `UFastSchemaV2` remains the only current schema
   used for new stores.
7. Given a simulated open failure, existing store bytes remain untouched and
   the current calm unavailable behavior remains unchanged.
8. Given a fresh V2 in-memory or disk store, all production model types remain
   available, CloudKit remains disabled, and ordinary current settings and
   hydration-favourite round trips still pass.

### Implementation notes

- Use the standard SwiftData pattern of immutable versioned model
  declarations. Do not attempt to emulate a legacy checksum with conditional
  fields or runtime schema mutation.
- Treat entity and property names, types, optionality, defaults, and uniqueness
  metadata as part of the frozen contract. Copy them from `d63dc026`; do not
  reconstruct them from memory.
- A test that calls `Schema(UFastSchemaV1.models)` is not evidence for this
  finding because production V1 and the fixture can drift together.
- Keep migration stages ordered and keep all `PersistenceContainer` entry
  points on the same current schema and plan.

### Verification

- Add or correct focused tests in `uFastTests/Slice3PersistenceMigrationTests.swift`
  for the independent on-disk release fixture and additive defaults.
- Update `uFastTests/PersistenceContainerTests.swift` to verify the exact schema
  order, stage count, current entity count, local-only configuration, and
  non-destructive failure behavior without asserting implementation trivia.
- Run the smallest migration-focused XCTest selection first, then the full unit
  suite after review.
- Run `make project` only if `project.yml` changes; never hand-edit the generated
  project.

### Sol review focus

- Compare frozen declarations directly with `git show
  d63dc026:<historical-file>` rather than trusting the test fixture.
- Confirm the source fixture is independent and genuinely on disk.
- Inspect the migrated values and negative assertions, especially `notAsked`,
  zero favourite rows, and preservation of the original store on failure.
- Reject any path that opens a fresh replacement store after migration failure.

---

## PI-102 — Reject ambiguous active fasts in History motion loads

**Priority:** P2 integrity consistency  
**Status:** Ready  
**Estimate:** 1 point  
**Depends on:** PI-101 accepted

### User story

As a user browsing History, I want the moving timeline to show active-fast
information only when one record is authoritative, so that corrupt local state
is never presented as an arbitrary truth.

### Outcome

The background motion provider accepts zero or one active `FastRecord` and
throws the existing `ActiveFastIntegrityError.multipleActiveFasts(count:)` for
two or more. The range loader propagates the error into the existing
initial/extension failure handling, which retains prior complete presentation
or shows the calm retry state; it never chooses one record, rewrites either
record, or converts ambiguity into an empty-history claim.

### In scope

- Fetch all active-fast candidates required to determine authority.
- Reuse `ActiveFastAuthority.resolve(_:)` or a shared non-main-actor pure
  resolver so Today, settled History, widget projection, and motion History
  apply the same zero/one/many rule.
- Keep `SwiftDataHistoryMotionDataProvider` background-safe and return only
  value snapshots across its boundary.
- Propagate ambiguity through `SwiftDataHistoryMotionRangeLoader.load` without
  swallowing or translating it into an arbitrary active fast.
- Preserve the existing initial-load and extension failure behavior in
  `HistoryView+Data`: prior complete motion data remains installed; with no
  prior runway the existing unavailable/retry treatment is used.
- Add focused zero-, one-, and multiple-active-record coverage for the motion
  provider or loader.

### Out of scope

- Choosing the oldest, newest, first, or last active fast.
- Deleting, completing, merging, or otherwise repairing conflicting records.
- Changing BR-03 enforcement on valid write paths.
- New alerts, diagnostics UI, telemetry, user-facing corruption copy, or a new
  History empty state.
- Changes to completed-fast, food, hydration, neighbour, automatic-fast, chunk
  seam, scrolling, or cache semantics.

### Acceptance criteria

1. Given no active `FastRecord`, when a motion slice loads, then it succeeds
   with `activeFast == nil` and otherwise unchanged presentation input.
2. Given exactly one active `FastRecord`, when a motion slice loads, then it
   succeeds with that record's stable identifier, start instant, captured goal,
   and integrity snapshot.
3. Given two or more active `FastRecord` rows, when the motion provider or
   range loader loads, then it throws
   `ActiveFastIntegrityError.multipleActiveFasts(count: actualCount)` and no
   arbitrary active interval is returned.
4. Given the multiple-active load fails during an initial runway request, then
   no conflicting active interval is installed and the existing calm
   unavailable/retry state remains available; the UI does not claim that the
   requested range contains no history.
5. Given the same failure occurs while extending or refreshing an already
   complete runway, then the prior complete presentation and records remain
   unchanged and the existing retryable failure state is recorded.
6. Given ambiguity is detected, then neither active record nor any settings,
   event, history, widget projection, or persistence row is mutated or deleted.
7. Given settled History and motion History inspect the same zero/one/many
   candidate sets, then both use the same authority rule and cannot diverge by
   ordering of SwiftData fetch results.

### Implementation notes

- Do not use `fetchLimit = 1` or `.first`; detecting an integrity conflict
  requires distinguishing one row from at least two. Fetching the candidate
  set is acceptable because BR-03 constrains the valid cardinality to one.
- `ActiveFastAuthority.resolve(_:)` is already a pure resolver and its error
  includes the actual count. Prefer it over adding another error type or
  duplicating the guard.
- The existing motion-loading catch paths are the product treatment. This
  story should test and preserve them, not redesign them.

### Verification

- Add focused provider/loader tests in
  `uFastTests/HistoryDataProviderTests.swift` or
  `uFastTests/HistoryMotionStreamingTests.swift` for zero, one, and at least
  two active rows.
- Assert the exact error and count, not merely that some error was thrown.
- Assert both conflicting rows remain persisted after the failed load.
- Retain existing chunk, neighbour, DST, and streaming tests.
- No new UI test is required if no UI code changes and the existing failure
  treatment is preserved. If UI failure handling changes, add a deterministic,
  parallel-safe UI test and then run the full four-worker UI suite under the
  repository rules.

### Sol review focus

- Search the motion path for remaining `.first` or limited fetches of active
  fasts.
- Confirm the background boundary does not pass SwiftData model objects across
  isolation.
- Verify the error reaches the existing failure state and that no catch block
  substitutes an empty or arbitrary presentation.
- Inspect persistence after the negative test to prove fail-closed behavior is
  non-destructive.

---

## Sprint integration and Definition of Done

The sprint is complete only when both stories are accepted by Sol and the
combined implementation meets all of the following:

- The duplicated P1 review comment is closed by one verified migration fix.
- A real release-baseline disk fixture migrates to current V2 with all meaning
  preserved and additive defaults proven.
- Valid zero/one active-fast motion loads still work; ambiguous loads fail
  closed and preserve every record.
- `make build`, `make test-unit`, `make lint`, and `make analyze` pass.
- If any UI test source changes, the story-specific UI test passes first and
  the final four-worker `make test-ui` result is verified with
  `make verify-ui-result UI_XCRESULT=<path>` under `AGENTS.md` rules.
- Before the first Xcode test command, complete and record the test preflight in
  `AGENTS.md`; do not overlap another Xcode/UI run.
- The combined diff contains no unrelated product behavior, destructive
  recovery, migration reset, new persistent model beyond current V2, CloudKit,
  or hand-edited generated project changes.
- Accessibility and privacy behavior are unchanged; failure remains calm,
  local-only, and non-destructive.
- `docs/PERSISTENCE_MIGRATIONS.md` and any touched delivery ledger accurately
  describe the immutable-schema rule.

## Suggested implementation command

```text
$implement-sprint docs/CODE_REVIEW_PERSISTENCE_INTEGRITY_SPRINT.md
```
