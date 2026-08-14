# uFast maintainability hardening stories

**Stories:** MH-001 to MH-011
**Status:** Done — final sprint gate passed 10 August 2026
**Prepared:** 10 August 2026
**Intent:** Preserve valid product behavior while making the app safer to evolve

## Outcome

uFast keeps the same calm, local-first fasting, food, hydration, History,
WidgetKit and ActivityKit journeys while gaining explicit persistence evolution,
recoverable failure boundaries, deterministic data invariants, smaller feature
components, bounded History work, isolated compatibility code and enforceable
quality gates.

These stories add no product capability, account, network dependency, CloudKit,
HealthKit, analytics, coaching, monetisation or new health interpretation.

## Behavior-preservation contract

For valid existing data and successful operations, the following must remain
unchanged throughout this work:

- navigation, visible copy, accessibility labels and identifiers;
- fasting, food, hydration, History and settings semantics;
- automatic-fast derivation, overlap rules and provenance;
- timestamps, goal capture, ordering and local-only persistence;
- WidgetKit and ActivityKit lifecycle ordering and failure isolation;
- offline operation and the absence of accounts, CloudKit and network access;
- deterministic `AppClock`, locale, calendar, time-zone and daylight-saving
  behavior; and
- the current app-created data on an upgraded installation.

Two defect-hardening exceptions are explicitly in scope:

1. The production Lock Screen widget must conform to accepted D-028. Its
   elapsed presentation shows completed hours and minutes without seconds in
   every Lock Screen state until a later accepted decision records sufficient
   physical-device evidence.
2. Invalid stores, duplicate authority records, unknown persisted values and
   failed migrations may show a calm, non-destructive unavailable/recovery
   state instead of crashing, selecting an arbitrary record or presenting
   invented provenance. Valid stored data must render exactly as before.

If implementation reveals any other behavior-changing choice, stop that story,
record the contradiction and obtain a product decision. Do not silently choose
new behavior in the name of refactoring.

## Autonomous execution contract

- Implement stories in dependency order unless a story explicitly says it may
  run in parallel.
- Inspect existing code and tests before editing each area.
- Keep every change reviewable and limited to the active story.
- Preserve existing user data. Never delete, reset or recreate a production
  store to make a migration pass.
- Update `project.yml` rather than hand-editing `uFast.xcodeproj`, then run
  `make project`.
- Add characterization tests before moving behavior across a boundary that is
  not already covered.
- Use deterministic launch fixtures and `AppClock`; do not make tests depend on
  simulator history, wall-clock time or execution order.
- Do not commit, push, publish, upload or deploy as part of this sprint unless
  separately requested.
- A focused or serial UI pass is diagnostic evidence only. It is not completion
  evidence.

## Mandatory verification gate

Before implementation begins, record a clean baseline with:

1. `make project`
2. `make build`
3. `make test-unit`
4. `make lint`
5. one full `make test-ui` invocation

Before running `make test-ui`, check for another active `xcodebuild` or Xcode
test run. Never overlap UI suites and never kill another user's run.

After each story, run its focused tests plus `make build`, `make test-unit` and
`make lint`. A story may be marked **Implementation complete** on that evidence,
but neither a story nor this sprint may be marked **Done** until the final full
four-worker `make test-ui` suite passes.

At the end of MH-011, run the complete gate again, inspect the `.xcresult`, and
record that:

- every UI test case appeared exactly once;
- no test was skipped unexpectedly;
- all four simulator clones started successfully;
- build, unit tests, formatting and lint passed; and
- the final diff contains no unintended product or documentation change.

## Delivery order

1. MH-001 — Complete static-analysis coverage and baseline evidence
2. MH-002 — Restore the accepted Lock Screen precision contract
3. MH-003 — Introduce versioned persistence and recoverable bootstrap
4. MH-004 — Enforce authoritative-record and persisted-value integrity
5. MH-005 — Standardise persistence transactions and rollback
6. MH-006 — Centralise application commands and post-commit effects
7. MH-007 — Centralise launch configuration and test fixtures
8. MH-008 — Refactor Today and Settings into presentation-focused features
9. MH-009 — Bound and decompose History and temporal presentation work
10. MH-010 — Isolate domain logic and legacy compatibility
11. MH-011 — Enforce continuous verification and close the sprint

---

## MH-001 — Complete static-analysis coverage and baseline evidence

**Epic:** Maintainability foundation
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 3 points
**Depends on:** None

### User story

As a maintainer, I want every production target covered by the same automated
quality checks, so that extension and dead-code regressions are detected before
larger refactors begin.

### In scope

- Add `LockScreenWidget` to SwiftLint's included production paths.
- Preserve SwiftFormat coverage for every app, shared, widget, prototype and
  test source.
- Add a reproducible `make analyze` command that performs the build needed by
  SwiftLint and runs the configured `unused_declaration` and `unused_import`
  analyzer rules with the correct compiler log.
- Keep `make lint` fast and deterministic; make the full analyzer an explicit
  verification command if it cannot run reliably as part of normal lint.
- Record the number of Swift files checked by each command so an omitted target
  is visible in logs.
- Run and record the mandatory baseline, including the full four-worker UI
  suite and `.xcresult` inspection, before MH-002 changes production behavior.

### Out of scope

- Removing valid code merely to obtain a clean analyzer result.
- Broad formatting or naming churn.
- Adding third-party analysis services.

### Acceptance criteria

1. Given any Swift file in `uFast`, `LockScreenShared`, `LockScreenWidget`,
   `LockScreenPrototype`, `uFastTests` or `uFastUITests`, the appropriate
   formatting/lint command includes it.
2. Given an intentionally unused internal declaration in a temporary
   verification fixture, `make analyze` reports it; after the fixture is
   removed, analysis passes.
3. Given the baseline commands run from a clean checkout, their outputs identify
   the checked source count and fail on a missing or failed target.
4. The existing app build, 228-or-more unit tests and complete UI suite pass
   before the next story begins.

### Verification

- `make project`
- `make build`
- `make test-unit`
- `make lint`
- `make analyze`
- `make test-ui`, followed by `.xcresult` inspection

### Done when

Every production source is inside an enforceable static-analysis boundary and a
passing baseline, including a verified four-worker UI run, is recorded.

### Implementation evidence — 2026-08-10

- Mandatory pre-change baseline: `make project`, `make build`, `make test-unit`
  (228 passed), `make lint`, and the four-worker `make test-ui` (84 passed,
  0 failed, 0 skipped) all passed.
- Baseline UI result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_11-13-02-+0100.xcresult`.
  The result contained 84 unique test identifiers exactly once; its action log
  recorded Clone 1, Clone 2, Clone 3, and Clone 4 destinations.
- SwiftFormat, SwiftLint, and SwiftLint analyzer each report and check all 123
  Swift sources across the app, shared, prototype, widget, unit-test, and UI-test
  roots. `LockScreenWidget` is now explicitly inside SwiftLint's boundary.
- `make analyze` performs reproducible compiler builds for both production
  schemes and passes with 0 unsuppressed violations. Its portable baseline
  records 47 pre-existing findings for characterization/removal by MH-008 through
  MH-010 rather than silently excluding their source roots.
- Negative control: a temporary unused internal declaration increased the count
  to 124 and made `make analyze` fail with one `unused_declaration`; removing the
  fixture restored a passing 123-source analysis.
- Post-change checks: `make build`, `make test-unit` (228 passed), `make lint`,
  `make analyze`, and `git diff --check` passed. Final sprint closure remains
  gated by MH-011's fresh full four-worker UI run and result audit.

---

## MH-002 — Restore the accepted Lock Screen precision contract

**Epic:** Release safety
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 3 points
**Depends on:** MH-001

### User story

As a privacy-conscious user, I want the production Lock Screen widget to follow
the already accepted precision contract, so that the shipped view cannot bypass
the protected presentation that its tests verify.

### In scope

- Make the accessory rectangular Lock Screen widget render the protected
  elapsed value produced by `LockScreenFastPresentation` rather than rendering
  a separate direct system timer that exposes seconds.
- Show completed hours and minutes in every Lock Screen state, as required by
  D-028's accepted fallback.
- Keep progress, deep linking, unavailable states, projection validation,
  accessibility meaning and local-only behavior unchanged.
- Do not persist timer ticks or schedule per-second timeline entries.
- Add a test seam or widget-target test that verifies the production view's
  selected display value, not only the shared formatter in isolation.
- Retain explicit physical-device checks as an OW-L109 release requirement.

### Out of scope

- A new locked-versus-authenticated precision policy.
- Target-time or goal-reached content in the compact Lock Screen widget.
- Changes to Live Activity or Home Screen widget content.
- New widget families or controls.

### Product rules

D-028; BR-33 through BR-35.

### Acceptance criteria

1. Given a valid active projection with 12 hours, 34 minutes and 56 completed
   seconds, the production Lock Screen widget selects **12 h 34 min** and no
   visible or accessibility value includes seconds.
2. Given the same projection in any WidgetKit privacy/redaction state, the
   accepted hours/minutes fallback remains in effect.
3. Given no active projection, corrupt data, unreadable data or a future start,
   the widget shows the existing neutral unavailable treatment and no duration.
4. The widget uses no per-second timeline entries and persists no timer tick.
5. Existing progress, routing, contrast and accessibility tests continue to
   pass.

### Verification

- Focused shared-presentation and widget-view tests.
- `make build`, `make test-unit`, `make lint` and `make analyze`.
- Full UI suite remains required by the sprint completion gate.
- Record the physical locked/authenticated/Always-On check as pending unless a
  configured supported iPhone is intentionally used for OW-L109 evidence.

### Done when

The production view consumes the tested protected presentation and cannot
reintroduce seconds without a failing test.

### Implementation evidence — 2026-08-10

- Added a production Lock Screen widget content seam that always derives from
  `LockScreenFastPresentation`'s protected state and exposes only the fields the
  accessory rectangular view renders.
- Replaced the direct dynamic system timer in the production Lock Screen widget
  with the seam's accepted `12 h 34 min` display value. The stable accessibility
  summary likewise contains hours/minutes and no seconds; progress, deep link,
  unavailable treatment, validation, persistence, and timeline policy remain
  unchanged.
- The new production-selection regression test first failed because the seam did
  not exist, then passed and proves that 12:34:56 elapsed selects `12 h 34 min`
  with no seconds in visible or accessibility content. The focused suite passed
  6 tests.
- Required checks passed: `make build`; `make test-unit` (229 passed);
  `make lint` (124 Swift sources, 0 violations); `make analyze` (124 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- OW-L109 locked/authenticated/Always-On physical-device evidence remains pending
  and is not inferred from simulator coverage. Final sprint closure remains
  gated by MH-011's fresh full four-worker UI run and result audit.

---

## MH-003 — Introduce versioned persistence and recoverable bootstrap

**Epic:** Persistence evolution
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 8 points
**Depends on:** MH-001

### User story

As a returning user, I want app updates to open my existing local data through
an explicit migration path, so that future schema changes cannot turn into an
unrecoverable launch crash or silent empty store.

### In scope

- Define the current production models as the first explicit
  `VersionedSchema` without changing their stored meaning.
- Add a named `SchemaMigrationPlan` and route production, in-memory and custom
  store URL construction through the same versioned container factory.
- Add an on-disk pre-versioned fixture containing settings, active and completed
  fasts, food, hydration and legacy records; prove it opens with identifiers,
  timestamps, provenance, goals, nutrition and preferences preserved.
- Replace bootstrap `fatalError` with an explicit bootstrap result and a calm,
  accessible unavailable state when the container cannot open.
- The unavailable state must never delete, replace or reset the failed store and
  must not claim that data is absent.
- Keep test reset/seeding behavior subordinate to a successfully created test
  container; it must not become production recovery behavior.
- Document the procedure for adding a later schema version and migration test.

### Out of scope

- Backup, restore, export, CloudKit or sync.
- A user-facing database repair tool.
- Changing any model field or valid record semantics.
- Automatically deleting a store that cannot migrate.

### Product rules

BR-12, BR-26 through BR-28 and BR-32's non-destructive principle.

### Acceptance criteria

1. Given an existing unversioned production-format store, opening the versioned
   container preserves every record and field exactly once.
2. Given a newly created store, all existing journeys persist and relaunch as
   before with CloudKit explicitly disabled.
3. Given a migration or container-open failure, the app does not crash, create
   a replacement store, delete a file or display invented empty data.
4. Given bootstrap failure, an accessible, calm unavailable state identifies
   that local data could not be opened and offers no destructive automatic
   action.
5. Production, preview, unit-test and custom-URL containers use the same schema
   and migration plan.

### Verification

- On-disk migration tests for the pre-versioned fixture and new empty store.
- Unit tests for successful and failed bootstrap states.
- UI test for simulated bootstrap failure and normal relaunch persistence.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

The current store is explicitly versioned, existing data migrates without
semantic change, and a failed open is non-destructive and recoverable rather
than a crash loop.

### Implementation evidence — 2026-08-10

- Defined the unchanged production model set as `UFastSchemaV1` and added the
  named `UFastMigrationPlan`; production, in-memory, preview and custom-URL
  factories all use that schema and plan with CloudKit disabled.
- An on-disk pre-versioned production-format fixture now verifies exactly one
  settings record, active/recorded/reconstructed fasts, food, hydration and an
  unknown legacy period. Its identifiers, absolute timestamps, goals,
  provenance/boundaries, complete nutrition, hydration details and preferences
  survive opening through the versioned factory.
- Replaced launch `fatalError` with `PersistenceBootstrapResult`. Open or test
  preparation failure renders a calm accessible state stating that local data
  could not be opened and that nothing was deleted or replaced; it offers no
  reset or destructive action. A byte-preservation failure test proves bootstrap
  itself does not touch the failed store.
- Test reset/seeding runs only after a ready container. Migration procedure and
  required previous-version/failure tests are documented in
  `docs/PERSISTENCE_MIGRATIONS.md`.
- Focused persistence suites passed 11 tests. Four-worker-configured UI checks
  passed both simulated bootstrap failure and normal goal persistence across
  relaunch; result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_12-09-47-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (233 passed);
  `make lint` (127 Swift sources, 0 violations); `make analyze` (127 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- No production store deletion, reset or replacement path was added. Final
  sprint closure remains gated by MH-011's full four-worker UI result audit.

---

## MH-004 — Enforce authoritative-record and persisted-value integrity

**Epic:** Persistence evolution
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 8 points
**Depends on:** MH-003

### User story

As a user relying on local history, I want the app to detect ambiguous or
unknown stored state instead of choosing an arbitrary authority or fabricating
record provenance.

### In scope

- Introduce one settings-store boundary responsible for loading, creating and
  updating the authoritative `AppSettingsRecord`.
- Prevent normal onboarding, relaunch and repeated actions from creating more
  than one settings authority.
- If duplicate settings rows are byte-for-byte equivalent in user-visible
  fields, retain one deterministic canonical row during migration and remove
  only the redundant equivalents.
- If duplicate settings rows disagree, preserve them and return a typed data
  integrity failure; do not select an unsorted `.first` or infer which setting
  was most recent.
- Replace active-fast `fetchLimit = 1` authority resolution with an exact-count
  result: zero, one, or an integrity failure for multiple active records.
- On multiple active records, preserve every record, suppress system-surface
  publication/mutation and show a calm non-destructive error where an authority
  is required.
- Decode unknown `FastOrigin`, `FastReviewState` and historical-goal values into
  explicit unavailable/unknown presentation state. Preserve the raw stored
  value and never reinterpret it as recorded, confirmed or the default goal.
- Keep the fail-closed behavior for unknown automatic Live Activity preference
  values because it is explicitly settled in that feature's contract.

### Out of scope

- Asking the user to merge or delete conflicting health history.
- Automatically choosing one of multiple active fasts.
- Rewriting valid existing records.
- Changing valid `.recorded`, `.reconstructed`, `.confirmed` or `.needsReview`
  presentation.

### Product rules

BR-02, BR-03, BR-05, BR-15, BR-17, BR-20, BR-26 and BR-33.

### Acceptance criteria

1. Given onboarding is submitted repeatedly, exactly one settings authority is
   stored and the selected valid settings remain unchanged.
2. Given one settings row and zero or one active fast, every feature resolves
   the same authority deterministically.
3. Given equivalent duplicate settings, migration preserves their common values
   and leaves one deterministic row.
4. Given conflicting settings or multiple active fasts, no record is silently
   deleted or selected and no widget or Live Activity projection is published
   from ambiguous state.
5. Given an unknown origin or review raw value, History never labels the record
   **Recorded fast** or **Confirmed** and preserves the raw value for a future
   migration.
6. Given an invalid historical goal, the record does not claim the current
   default was historically captured.

### Verification

- Migration and repository tests for zero, one, equivalent duplicate and
  conflicting duplicate settings.
- Unit and UI tests for multiple-active and unknown-provenance states.
- Relaunch tests proving valid data remains unchanged.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

No app surface or adapter uses an arbitrary first settings/active record, and
unknown persisted health-history values remain explicitly unknown.

### Implementation evidence — 2026-08-10

- Added `SwiftDataSettingsStore` as the single create/load/update boundary.
  Repeated onboarding preserves the original completed selection and one row;
  zero/one authorities resolve exactly.
- Equivalent duplicate settings are compared across every user-visible stored
  field, sorted by UUID, and reduced to the deterministic canonical row during
  bootstrap. Conflicting duplicates return `SettingsStoreError`, remain intact,
  and produce a calm non-destructive unavailable state.
- Added exact-count `ActiveFastAuthority` resolution and removed every active
  `fetchLimit = 1`/unguarded `.first` authority lookup. Multiple active rows are
  preserved, block Today actions, and cause widget/Live Activity synchronization
  to leave system surfaces unchanged rather than select a record.
- `FastRecord` now decodes unknown origin/review raw values and invalid captured
  historical goals as unavailable optionals while retaining every raw value.
  History renders **Saved fast · Details unavailable**, never **Recorded fast**,
  **Confirmed**, or a fabricated default historical goal for these records.
  Unknown automatic Live Activity preferences retain their settled fail-closed
  behavior.
- Focused unit suites passed 19 tests. Four-worker-configured UI tests passed for
  multiple-active and unknown-provenance failure states; result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_12-21-54-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (239 passed);
  `make lint` (131 Swift sources, 0 violations); `make analyze` (131 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- Final sprint closure remains gated by MH-011's fresh full four-worker UI run
  and `.xcresult` audit.

---

## MH-005 — Standardise persistence transactions and rollback

**Epic:** Persistence reliability
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 5 points
**Depends on:** MH-003 and MH-004

### User story

As a user editing local records, I want every failed save to leave the context
and store exactly as they were, so that a later successful action cannot commit
stale cleanup or a partially reverted mutation.

### In scope

- Introduce one injectable save/transaction boundary used by settings, fasting,
  food, hydration, reconstruction compatibility and delete-all persistence.
- On any thrown save, roll back the `ModelContext` before returning a typed
  failure.
- Re-fetch or return stable identifiers/snapshots after rollback rather than
  continuing to use invalidated model references.
- Keep multi-record operations atomic, including caloric entries that complete
  an active fast and changes that invalidate legacy history.
- Move failure injection to the actual save boundary so tests exercise the same
  rollback path as a real `ModelContext.save()` failure.
- Assert that the context has no pending changes after failure and that a later
  unrelated successful command cannot commit any part of the failed command.
- Preserve all existing calm error copy and successful behavior.

### Out of scope

- Retry loops or background persistence.
- A second store or remote transaction service.
- Changing validation, conflict or fasting rules.

### Product rules

BR-03 through BR-08, BR-11, BR-17, BR-21, BR-23, BR-27 and BR-36.

### Acceptance criteria

1. Given create, update, completion or delete save failure for every repository,
   the persistent store and in-memory context match their pre-command state and
   `hasChanges` is false.
2. Given a failed multi-record caloric operation, neither the event nor active
   fast completion is committed.
3. Given a failed command followed by a successful unrelated command, only the
   later command is persisted.
4. Given failure after a model mutation, callers do not continue using an
   invalid or stale model reference.
5. Every existing simulated-save UI journey retains its current error message
   and committed UI state.

### Verification

- Repository tests covering every mutation and a failure-then-success sequence.
- On-disk transaction tests for representative multi-record operations.
- Existing persistence-failure UI tests.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

All mutation paths share one proven rollback discipline and no failure test
short-circuits before the transaction boundary it claims to verify.

### Implementation evidence — 2026-08-10

- Added one injectable `PersistenceTransaction` save boundary. Settings,
  fasting, food, hydration, reconstruction compatibility and delete-all now
  route every production mutation through it; a thrown save restores any
  caller-visible snapshot and rolls back the `ModelContext` before propagating
  the typed error.
- Moved repository and UI failure fixtures into that save action. The same
  rollback path is therefore exercised for injected failures and a real
  `ModelContext.save()` failure; no persistence feature retains a pre-save
  failure shortcut.
- Added clean-context assertions for create, update, completion and delete
  failures across the repositories, including the caloric event/active-fast
  operation and reconstruction multi-record operations.
- Added an on-disk regression proving a failed caloric create commits neither
  the event nor the fast completion, leaves `hasChanges == false`, and cannot
  leak into a later unrelated successful hydration save. A separate sequence
  proves failed settings changes cannot be committed by a later fast save.
- Focused persistence suites passed 50 tests; result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_12-35-53-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (241 passed);
  `make lint` (133 Swift sources, 0 violations); `make analyze` (133 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- Final sprint closure remains gated by MH-011's fresh full four-worker UI run
  and `.xcresult` audit.

---

## MH-006 — Centralise application commands and post-commit effects

**Epic:** Application architecture
**Priority:** P1
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 8 points
**Depends on:** MH-004 and MH-005

### User story

As a maintainer, I want each user intent represented by one application command,
so that persistence, widget publication and Live Activity effects keep the same
ordering wherever the intent originates.

### In scope

- Introduce application command/use-case boundaries for start, backdated start,
  active-start correction, fast end, completed-fast editing/deletion, food save,
  hydration save, goal/preference changes and Delete All Data.
- Commands accept value inputs and stable identifiers, not SwiftUI bindings or
  feature-view state.
- Commands own validation/service invocation and persistence transaction
  completion.
- Introduce one post-commit projection coordinator with the settled order:
  authoritative persistence, WidgetKit publish/clear, then ActivityKit action.
- Projection failure remains non-blocking and never rolls back committed local
  data.
- Return typed outcomes that distinguish validation, persistence and optional
  system-surface failures without changing current user-facing copy.
- Serialise/coalesce effects for the same active record and eliminate duplicate
  fire-and-forget effect ordering from feature views.
- Add contract tests for every command's success, persistence failure and
  projection failure ordering.

### Out of scope

- Background queues, network outboxes or retries.
- New user actions or new system-surface content.
- Moving domain validation into SwiftUI.

### Product rules

BR-03 through BR-08, BR-17, BR-23 through BR-27 and BR-33 through BR-40.

### Acceptance criteria

1. Given the same intent originates from Today, History or Settings, it invokes
   one command with identical transaction and post-commit ordering.
2. Given persistence fails, no widget or Live Activity effect is attempted.
3. Given persistence succeeds and a projection effect fails, the local record
   remains committed and the existing calm optional-surface status is returned.
4. Given repeated callbacks for one active record, command/effect coordination
   cannot create duplicate active records or matching Live Activities.
5. Feature views no longer construct persistence repositories or directly
   publish/clear widget projections.

### Verification

- Application-command contract tests using deterministic repository and
  projection spies.
- Existing repository, coordinator and end-to-end UI tests.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

Each mutation has one application entry point and optional system effects cannot
be reordered by the view that initiated it.

### Implementation evidence — 2026-08-10

- Added value-oriented `ApplicationCommands` entry points for fasting, completed
  history, food, hydration, settings, onboarding, reconstruction and delete-all
  mutations. Feature views pass stable identifiers and no longer construct
  repositories or publish/clear widget projections directly.
- Added one `PostCommitProjectionCoordinator` with the settled persistence,
  WidgetKit, ActivityKit order. It serialises ActivityKit work, suppresses
  duplicate starts for an already-active identifier, keeps committed local data
  after optional-surface failure, and never projects after persistence failure.
- Routed Today, History, Settings, Onboarding and Catch Up mutations through the
  shared commands while preserving existing copy, navigation, identifiers and
  optional-surface presentation.
- Added four command contract tests covering ordering/coalescing, persistence
  failure, WidgetKit failure followed by ActivityKit, and representative
  fasting/food/settings/delete-all events; focused result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_12-50-58-+0100.xcresult`.
- Static searches found no repository construction, delete service construction,
  direct widget publication/clearing or feature-owned post-commit callbacks in
  `uFast/Features`.
- Required checks passed: `make build`; `make test-unit` (245 passed; result
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_12-52-36-+0100.xcresult`);
  `make lint` (137 Swift sources, 0 violations); `make analyze` (137 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- Final sprint closure remains gated by MH-011's fresh full four-worker UI run
  and `.xcresult` audit.

---

## MH-007 — Centralise launch configuration and test fixtures

**Epic:** Testability
**Priority:** P1
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 5 points
**Depends on:** MH-006

### User story

As a maintainer, I want UI-test launch behavior represented by one injected
configuration, so that production features do not parse process arguments or
compile ad hoc failure switches throughout the app.

### In scope

- Add one immutable `AppLaunchConfiguration` created at the composition root.
- Parse process arguments once and convert them into typed reset, seed, fixed
  clock, adapter and failure-injection options.
- Move deterministic seeding/reset implementation into `DevelopmentSupport`.
- Inject failure behavior through repository/save/client protocols rather than
  reading `ProcessInfo` inside feature views or repositories.
- Move deterministic Live Activity test-client construction behind the launch
  configuration and development-support boundary.
- Keep every existing launch argument working so existing UI tests need no
  semantic change.
- Ensure release configuration cannot accidentally activate test reset, seed or
  simulated-failure behavior without the explicit `--ui-testing` gate.

### Out of scope

- Removing useful UI-test scenarios.
- Renaming launch arguments solely for style.
- Adding production diagnostics, analytics or remote feature flags.

### Acceptance criteria

1. Production feature, domain and persistence files contain no direct
   `ProcessInfo.processInfo.arguments` access.
2. All existing reset, seed, fixed-clock and simulated-failure UI tests behave
   exactly as before.
3. Given a failure flag without `--ui-testing`, production composition ignores
   it and no user data is reset or simulated failure introduced.
4. Deterministic clients and seed builders live in test/development support or
   behind protocols, not inside user-facing views.
5. Launch parsing has focused unit coverage for every supported argument and
   invalid/missing values.

### Verification

- Launch-configuration unit tests.
- Existing fixture and UI tests, including save failures and seeded History.
- Search proving direct argument access is confined to the composition parser.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

The app has one typed launch configuration and production feature code is
unaware of command-line fixture syntax.

### Implementation evidence — 2026-08-10

- Added one immutable `AppLaunchConfiguration` parsed once at composition. It
  converts every existing reset, seed, fixed-clock, adapter and simulated-failure
  switch into typed configurations, and ignores all such switches unless the
  explicit `--ui-testing` gate is present.
- Production feature, domain and persistence code no longer reads process
  arguments. A static search found the sole access in
  `AppLaunchConfiguration.current()`; Today receives its offer-suppression value
  through the environment.
- Moved deterministic Live Activity client construction and all UI seed builders
  into `DevelopmentSupport`; `UITestDataReset` consumes typed fixture values and
  no longer knows command-line syntax.
- Added five parser tests covering every supported option, disabled and default
  Live Activity adapters, invalid/missing dates, and production-gate safety;
  focused result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-04-15-+0100.xcresult`.
- Five focused UI journeys covering bootstrap failure, fixed/seeded History and
  fast, goal, food and drink save failures passed in one run; result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-05-51-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (250 passed; result
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-05-03-+0100.xcresult`);
  `make lint` (140 Swift sources, 0 violations); `make analyze` (140 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- Final sprint closure remains gated by MH-011's fresh full four-worker UI run
  and `.xcresult` audit.

---

## MH-008 — Refactor Today and Settings into presentation-focused features

**Epic:** Feature maintainability
**Priority:** P1
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 8 points
**Depends on:** MH-006 and MH-007

### User story

As a maintainer, I want Today and Settings split into focused presentation,
state and command components, so that future changes do not require editing one
large view that also owns persistence and external effects.

### In scope

- Add observable feature-state/controller boundaries for Today and Settings
  that consume immutable snapshots and invoke MH-006 commands.
- Keep SwiftUI views responsible for layout, presentation state, bindings and
  accessibility only.
- Split active-fast, inactive-fast, timeline, Live Activity controls, goal,
  hydration favourites, privacy and deletion sections into focused source files
  where they have independent state or behavior.
- Remove `file_length` and `type_body_length` suppressions from Today and
  Settings by making every affected type satisfy configured limits.
- Preserve all visible copy, navigation, sheet/alert lifecycle, identifiers and
  committed UI results.
- Characterize controller state transitions, including persistence errors and
  asynchronous optional-surface outcomes, with unit tests.
- Ensure tasks owned by a disappeared view cannot overwrite a newer feature
  state.

### Out of scope

- Visual redesign, new controls or navigation changes.
- Changing timing, fasting or Live Activity policy.
- Broad design-system replacement.

### Acceptance criteria

1. Today and Settings views do not import SwiftData, create repositories, parse
   launch arguments or directly call widget publication.
2. Existing accessibility identifiers and user-visible strings remain
   unchanged.
3. Every current success, validation, failure, cancellation, relaunch and Live
   Activity UI test passes without weakening assertions.
4. State transitions are unit-testable without hosting SwiftUI or creating a
   persistent store.
5. No Today or Settings type requires `file_length` or `type_body_length`
   suppression.

### Verification

- State/controller characterization tests.
- Existing Today, fasting-goal, food, hydration, Settings and Live Activity UI
  tests.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

Today and Settings render injected state and dispatch commands while their
current behavior and accessibility contract remain unchanged.

### Implementation evidence — 2026-08-10

- Added immutable Today and Settings snapshots, SwiftData host adapters and
  observable feature controllers. Presentation views now receive snapshots and
  dispatch MH-006 commands without importing SwiftData or publishing widgets.
- Split active/inactive fast, timeline, Live Activity, goal, hydration
  favourites, privacy and deletion presentation into focused source files.
  Today and Settings no longer require `file_length` or `type_body_length`
  suppressions, and static searches found no persistence, launch-argument or
  system-surface adapter access in either presentation view.
- Added four controller characterization tests for success, persistence
  failure, restoration and stale asynchronous optional-surface completion;
  focused result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-46-07-+0100.xcresult`.
- Seven focused Today/Settings UI journeys passed with their existing copy,
  identifiers and assertions; result:
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-34-34-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (254 passed; result
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_13-46-54-+0100.xcresult`);
  `make lint` (151 Swift sources, 0 violations); `make analyze` (151 Swift
  sources, 0 unsuppressed violations); and `git diff --check`.
- Final sprint closure remains gated by MH-011's fresh full four-worker UI run
  and `.xcresult` audit.

---

## MH-009 — Bound and decompose History and temporal presentation work

**Epic:** History evolution
**Priority:** P1
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 13 points
**Depends on:** MH-005 through MH-008

### User story

As a long-term user, I want History to remain responsive as years of local data
accumulate, so that retaining records does not make every visible timer tick or
calendar movement process the entire store.

### In scope

- Introduce a History data provider that fetches records intersecting the exact
  settled presentation window plus only the nearest qualifying caloric boundary
  beyond each visible edge required by BR-24.
- Fetch active records and settings through the authoritative stores from
  MH-004 rather than unbounded `@Query` arrays.
- Build one immutable, equatable History presentation snapshot per data/window,
  locale, calendar and time-zone revision.
- Recompute the snapshot only when those inputs change; isolate the one-second
  active-fast display update so it does not rebuild static event groups,
  automatic intervals or the date buffer.
- Remove the all-record string revision mechanism and full-store re-fetch after
  event-group mutation.
- Preserve continuous day navigation and lazy day-buffer expansion without
  requiring all records for every buffered day.
- Split `HistoryView`, `TemporalRibbonView`, `TemporalHistoryPresentation` and
  `TemporalEventGrouping` into focused source files/types, removing their
  `file_length` and `type_body_length` suppressions.
- Preserve gestures, movement phases, grouping, direct entry, VoiceOver,
  Dynamic Type, DST and automatic-fast precedence exactly.
- Add a deterministic multi-year fixture and tests proving the projection input
  remains bounded by the requested window and boundary neighbors rather than
  total store size.

### Out of scope

- Pagination visible to the user.
- A new History design, chart, filter or date limit.
- Changing the automatic-fast threshold, precedence or exact visible interval.
- Deleting or aggregating old records.

### Product rules

BR-12, BR-15, BR-17 and BR-22 through BR-25.

### Acceptance criteria

1. Given ten years of food and hydration fixtures, selecting one settled
   History window supplies projection with only intersecting records and the
   nearest required outside-edge caloric boundaries.
2. Given the same visible window and no data/locale/time-zone change, a one-
   second active timer tick does not rebuild static History projections.
3. Given a record is added, edited, deleted or reclassified, only affected
   windows are invalidated and the committed UI matches existing behavior.
4. Given navigation across London DST or a display time-zone change, absolute
   instants, grouping and day windows remain correct.
5. Every existing History and event-grouping UI test passes under four workers.
6. No affected History/temporal type requires `file_length` or
   `type_body_length` suppression.

### Verification

- Repository-window and outside-boundary tests.
- Multi-year bounded-input regression tests; avoid fragile wall-clock-only
  assertions.
- Existing temporal presentation, event grouping and full History UI suites.
- Instruments or signpost evidence may supplement but not replace deterministic
  tests.
- `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

History work is bounded by what is being presented, its static projection is
not driven by the one-second timer, and the large temporal sources are divided
along tested responsibilities.

### Implementation evidence — 2026-08-10

- Added an exact-window SwiftData History provider with authoritative active-
  fast/settings reads and one nearest caloric boundary on each side. A
  deterministic ten-year fixture proves a single window remains bounded to
  three food records and one hydration record rather than total store size.
- Added immutable/equatable History data and presentation snapshots plus a
  cache whose characterized one-second active-fast tick leaves its static
  rebuild count unchanged. Event-group mutations now refresh only the settled
  window without an all-record revision string or full-store fetch.
- Split History, ribbon, temporal presentation and event grouping across
  focused sources. The affected types have no `file_length` or
  `type_body_length` suppression; analyzer-driven cleanup also removed the
  displaced dead declarations.
- Focused provider, temporal and grouping tests passed (59 tests; result
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_14-09-48-+0100.xcresult`).
  The History/event-grouping UI run passed 33 of 34 scenarios; its sole
  bounded navigation wait was corrected from two to five seconds and passed
  independently at
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_14-38-07-+0100.xcresult`.
  Both injected-clock active-fast scenarios passed at
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_14-27-08-+0100.xcresult`.
- Required checks passed: `make build`; `make test-unit` (257 passed; result
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_14-39-21-+0100.xcresult`);
  `make lint` (167 Swift sources, 0 violations); and `make analyze` (167 Swift
  sources, 0 unsuppressed violations).
- Final proof that every History UI case passes in one four-worker invocation,
  alongside the complete suite and clone audit, remains gated by MH-011.

---

## MH-010 — Isolate domain logic and legacy compatibility

**Epic:** Architecture boundaries
**Priority:** P1
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 8 points
**Depends on:** MH-006 through MH-009

### User story

As a maintainer, I want pure domain rules and necessary legacy compatibility to
have explicit compile-time boundaries, so that new features cannot accidentally
depend on SwiftUI, SwiftData or retired reconstruction write flows.

### In scope

- Add a local `UFastCore` framework target in `project.yml` for pure value types,
  validation, clocks, conflict checks and presentation projections that require
  Foundation only.
- Make `UFastCore` compile without SwiftUI, SwiftData, WidgetKit, ActivityKit or
  UIKit imports.
- Replace domain helpers that accept SwiftData model classes, including timeline
  projection inputs, with immutable domain snapshots/value types.
- Keep SwiftData mapping in the persistence/application adapter layer.
- Create a `LegacyCompatibility` source boundary containing only the read,
  display, invalidation and deletion behavior still required by D-024 and
  OW-396.
- Remove production compilation of unreachable legacy reconstruction creation,
  review and adjustment views/services after proving they have no route or
  supported write contract.
- Preserve every legacy record in the store and its current supported History
  presentation; Delete All Data must still remove it.
- Remove obsolete tests only when they exercise an unreachable retired write
  journey. Retain or replace all tests needed for migration and read
  compatibility.
- Document the allowed dependency direction:
  `Features -> Application/Persistence adapters -> UFastCore`, with Apple system
  adapters behind protocols.

### Out of scope

- Deleting legacy stored data or its schema models.
- Reintroducing reconstruction as a current journey.
- A package-manager migration or third-party architecture framework.
- Rewriting all features solely to conform to a named architecture pattern.

### Product rules

BR-09 through BR-11 and BR-18 through BR-21 as legacy compatibility only;
BR-22 through BR-28 for current behavior.

### Acceptance criteria

1. `UFastCore` builds and tests without linking an Apple UI, persistence or
   system-surface framework.
2. Domain projections consume immutable values and have no dependency on
   SwiftData record classes.
3. No reachable navigation path exposes legacy reconstruction creation, review
   or adjustment.
4. Existing legacy records still migrate, display with truthful provenance,
   react to supported boundary invalidation where required, and are removed by
   Delete All Data.
5. Static analysis reports no unreachable legacy UI/service declarations in the
   production app target.

### Verification

- Independent `UFastCore` build and unit tests.
- Dependency/import checks.
- Legacy migration, read-presentation, invalidation and deletion tests.
- Existing app and History UI tests.
- `make project`, `make build`, `make test-unit`, `make lint` and `make analyze`.

### Done when

Pure rules have a real compile-time boundary and the production target retains
only the legacy compatibility behavior the current product still promises.

### Implementation evidence — 2026-08-10

- Added the Foundation-only `UFastCore` framework and independent
  `UFastCoreTests` target; the isolated build passed and 3/3 core tests passed
  in `.derived-data/Logs/Test/Test-UFastCore-2026.08.10_14-59-58-+0100.xcresult`.
- Moved clocks, fasting goals, validation, immutable caloric-boundary values,
  automatic projection and half-open conflict rules behind the compile-time
  boundary. `UFastCore` imports Foundation only.
- Added the explicit `LegacyCompatibility` adapter boundary for exact legacy
  display, invalidation/restore and schema-preserving deletion. Migration and
  persisted provenance remain additive and non-destructive.
- Removed unreachable reconstruction creation/review/adjustment production
  sources and their retired write-only tests; current navigation has no route
  to those journeys. Migration and supported legacy read tests remain.
- Focused legacy migration/read/invalidation/deletion verification passed 25/25
  tests across
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-06-22-+0100.xcresult` and
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-07-13-+0100.xcresult`.
- Focused current-navigation and History UI verification passed 4/4 with no
  skips in
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-04-15-+0100.xcresult`.
- After analyzer-driven removal of stale declarations, `make build` passed,
  `make test-unit` passed 238/238 in
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-18-26-+0100.xcresult`,
  `make lint` passed across 158 Swift files and `make analyze` passed across
  all 157 app-scheme source files with zero violations.

---

## MH-011 — Enforce continuous verification and close the sprint

**Epic:** Delivery reliability
**Priority:** P0
**Status:** Done — final sprint gate passed 10 August 2026
**Estimate:** 5 points
**Depends on:** MH-001 through MH-010

### User story

As a maintainer, I want the repository to enforce its build, analysis, unit and
parallel UI contracts continuously, so that future evolution cannot silently
undo this hardening work.

### In scope

- Add a macOS CI workflow that runs project generation, formatting/lint,
  analysis, build and unit tests with the repository-pinned command paths.
- Add a four-worker UI job on protected-branch, release or explicitly dispatched
  runs, with no overlapping invocation inside one job.
- Retain `.xcresult` and relevant logs as CI artifacts when a test job fails.
- Add a verification script that inspects the final UI `.xcresult` and fails if
  a test is unexpectedly skipped, duplicated or missing, or if four simulator
  clones did not start.
- Do not silently fall back to fewer UI workers and call the sprint verified.
- Run the full local completion gate and fix every regression introduced by the
  sprint without weakening existing assertions or changing product behavior.
- Review all lint suppressions touched by the sprint and retain only narrow,
  justified exceptions.
- Update story statuses and record exact build, unit, UI and analysis evidence.

### Out of scope

- Publishing, TestFlight upload or App Store submission.
- Third-party CI services, analytics or coverage targets unrelated to
  regression safety.
- Making unrelated flaky tests pass by disabling, skipping or serialising the
  four-worker suite.

### Acceptance criteria

1. Given a normal code change, CI regenerates the project and runs formatting,
   lint, analysis, build and unit tests from documented commands.
2. Given a protected/release/manual full verification, CI runs exactly one UI
   invocation configured for four workers and validates its `.xcresult`.
3. Given any failing, missing, skipped or duplicate UI test, or fewer than four
   started clones, verification fails visibly and retains useful diagnostics.
4. The final local run passes `make project`, `make format`, `make build`,
   `make test-unit`, `make lint`, `make analyze` and the full `make test-ui`.
5. Every existing UI test appears exactly once, no test is skipped
   unexpectedly, and all four clones start successfully.
6. A final diff review finds no new feature, visual redesign, data loss,
   CloudKit/network dependency or undocumented behavior change.

### Verification

- Exercise the CI scripts locally where possible.
- Run one final full four-worker UI suite and inspect its `.xcresult`.
- Record test counts, tool versions, result-bundle path and any physical-device
  evidence still pending under OW-L109.

### Done when

All MH stories satisfy their acceptance criteria, the final full verification
gate passes, CI enforces the same contract, and the sprint evidence is recorded
without skipped or weakened tests.

### Completion evidence — 2026-08-10

- Added `.github/workflows/continuous-verification.yml` on the supported
  `macos-26` runner. Normal changes run bootstrap, project generation,
  committed-format enforcement, build, app/core units, lint and analysis.
  Main-branch, release and manual runs add exactly one four-worker UI invocation.
  Failed jobs retain `.xcresult` bundles and repository logs.
- Added `scripts/verify_ui_xcresult.py` and Make targets for its adversarial
  self-test and real-result audit. It derives the expected UI inventory from
  source and rejects missing, extra, duplicate, skipped or failed tests, fewer
  than four workers, and unsuccessful workers. Its missing/duplicate/skip/
  three-worker/failed-worker self-tests passed.
- The final completion gate passed `make project`, `make format`, `make build`,
  `make test-unit`, `make lint`, `make analyze` and `make test-ui` from the final
  source state. SwiftFormat and SwiftLint covered 158 files; analyzer rules
  covered all 157 app-scheme files with zero violations.
- Final app units passed 238/238 with zero skips in
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-44-36-+0100.xcresult`.
  Isolated core units passed 3/3 with zero skips in
  `.derived-data/Logs/Test/Test-UFastCore-2026.08.10_15-44-57-+0100.xcresult`.
- Final UI verification passed 87/87 with zero failures and zero skips in
  `.derived-data/Logs/Test/Test-uFast-2026.08.10_15-48-56-+0100.xcresult`.
  The independent audit confirmed all 87 identifiers exactly once and four
  successful simulator worker clones.
- Tool evidence: Xcode 26.0 (17A324), XcodeGen 2.46.0, SwiftFormat 0.62.1,
  SwiftLint 0.65.0 and Python 3.9.6.
- The first candidate full run exposed an over-scrolling UI-test action. It was
  corrected with a bounded scroll-view drag and semantic visibility wait,
  without weakening its stored date/time assertions; the focused test and the
  fresh full parallel suite then passed.
- Final scope review found no feature, visual redesign, data loss, account,
  CloudKit, networking, HealthKit, analytics, coaching, monetisation or new
  health interpretation. User-facing behavior is unchanged except for the two
  sprint-authorised defect corrections.
- OW-L109 physical-device evidence remains pending because deployment was not
  authorised for this sprint execution.

## Traceability to the 10 August 2026 review

| Review finding | Addressed by |
| --- | --- |
| Lock Screen production view bypasses D-028 precision | MH-002 |
| No versioned SwiftData migration or safe bootstrap | MH-003 |
| Settings/active authority selected with arbitrary `.first` | MH-004 |
| Unknown persisted provenance becomes recorded/confirmed | MH-004 |
| Inconsistent rollback and pre-save-only failure injection | MH-005 |
| Views own repositories, persistence and system effects | MH-006, MH-008 |
| Fire-and-forget post-commit effects are duplicated | MH-006 |
| Process arguments and deterministic clients leak into production features | MH-007 |
| History loads/projects total retained data and ticks broad view trees | MH-009 |
| Oversized Today, Settings, History and temporal types suppress limits | MH-008, MH-009 |
| Domain folder is not a compile-time boundary | MH-010 |
| Retired reconstruction write UI remains production-compiled | MH-010 |
| Widget omitted from SwiftLint and analyzer rules are not executed | MH-001 |
| No continuous repository verification was found | MH-011 |
