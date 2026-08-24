# Post-MVP maintainability sprint — MNT-002 through MNT-008 feasibility

> **Repository classification: Completed.** This MNT-100 predecessor is
> retained as historical evidence. See the [document index](DOCUMENT_INDEX.md)
> for the current authority map and active sprint.

**Sprint:** MNT-100  
**Status:** Ready — Sol readiness gate passed 20 August 2026  
**Prepared:** 20 August 2026  
**Source review:** `docs/POST_MVP_MAINTAINABILITY_CODE_REVIEW.md`  
**Goal:** Make local release evidence truthful, bound lifetime-data work, enforce the most important architecture contracts, reduce the two largest change hotspots, and prepare persistent identity for future user-controlled backup.  
**Stories:** MNT-002, MNT-004, MNT-003, MNT-005, MNT-006, MNT-007A, MNT-007B, MNT-008F

## Controlling workflow

Run this document with `$implement-sprint`. `AGENTS.md` and
`.agents/skills/implement-sprint/SKILL.md` control orchestration, worker
liveness, focused correction budgets, Luna/Terra escalation and independent Sol
acceptance.

Use one Luna xhigh `story_worker` at a time. Every story requires a read-only Sol
story gate. Sol is the technical acceptance authority.

### Mandatory human physical-device progression gate

After Sol accepts each story, Luna must:

1. move the story to `AWAITING HUMAN BUILD CHECK`;
2. run the agreed build gate and, when the configured development iPhone is
   connected, deploy the exact accepted source with `make deploy-iphone`;
3. report the source identity, build/deploy result, story-specific checklist and
   known limitations under `HUMAN BUILD CHECK REQUIRED`;
4. stop without inspecting, delegating or beginning the next story; and
5. continue only after the human replies `HUMAN CHECK PASSED` or explicitly
   authorises a recorded skip.

A successful deployment is not a human pass. If the human reports a defect, the
same story returns to `CHANGES REQUESTED`; any correction receives focused
revalidation, a new Sol verdict and a new human build check. The final sprint
integration gate does not replace these between-story checks.

MNT-008F is test-only feasibility and must leave the deployable app on V4. A
later production MNT-008 implementation sprint will require explicit human
authorization before deploying a schema-migrating build to valuable device
data. Never uninstall the app, erase the device, reset shared DerivedData, or
delete app data to make a check pass.

## Product and engineering constraints

- Preserve the submitted `1.0.0` build 10 behavior and local data.
- Keep uFast calm, local-first, accessible and free.
- Add no CloudKit, sync, backup/restore UI, HealthKit, analytics, AI, coaching,
  health claims or monetisation.
- Do not silently infer, repair, rewrite or delete user history.
- Keep `AppClock` injection and half-open time intervals.
- Keep SwiftData and Apple framework adapters behind testable boundaries where
  practical.
- Preserve released SwiftData schema declarations. Any persistent-model change
  requires a new schema version and on-disk migration evidence.
- Do not hand-edit `uFast.xcodeproj`; regenerate it after `project.yml` changes.
- Run focused tests during stories. Run the full four-worker UI suite exactly
  once after all stories and human gates are complete and source is frozen.
- MNT-001/GitHub Actions is out of scope. The accepted solo-developer policy is
  local quality gates with source-bound evidence.

## Story order and dependencies

1. **MNT-002** makes the local release gate truthful before other changes.
2. **MNT-004** makes caloric-boundary integrity compile-time mandatory and
   restores analyzer health.
3. **MNT-003** bounds the primary Today screen and establishes the first clean
   feature/data seam.
4. **MNT-005** measures and bounds mutation-time lifetime-history work without
   weakening boundary correctness.
5. **MNT-006** turns the proven Today seam into an enforceable architecture
   ratchet and reconciles the architecture document.
6. **MNT-007A** decomposes application commands after the boundary contract and
   bounded-query design are stable.
7. **MNT-007B** gives History explicit state/task ownership independently of the
   command refactor.
8. **MNT-008F** proves or blocks the identity/index migration design without
   changing the production schema, then emits the separately reviewed
   implementation story.

No later story may begin until the preceding story has both an explicit Sol
`ACCEPTED` verdict and a recorded human build-check result.

## Shared baseline and downstream inventory

Before the first Xcode test command, complete the `AGENTS.md` preflight once and
record the simulator, execution security model and active-process check. The
review baseline at `4bcee9a8f50f47331dea108235f13cbd4b562ef1` had:

- 364 app unit tests and 14 `UFastCore` tests passing;
- build and ordinary lint passing;
- two analyzer failures in `CaloricBoundaryIntegrity.swift`;
- a verified existing full UI result containing 105 tests exactly once on four
  workers; and
- release version/privacy checks passing, while the entitlement sub-check was
  silently skipped by the filename-case bug.

Re-establish the actual baseline from the clean-session starting revision; do
not assume these counts are unchanged.

Shared affected suites and fixtures include:

- `uFastTests/ApplicationCommandsTests.swift`;
- `uFastTests/CaloricBoundaryIntegrityTests.swift`;
- `uFastTests/FastStartServiceTests.swift`;
- `uFastTests/CompletedFastServiceTests.swift`;
- `uFastTests/FoodEntryServiceTests.swift`;
- `uFastTests/HydrationEntryServiceTests.swift`;
- `uFastTests/SwiftDataFoodEntryRepositoryTests.swift`;
- `uFastTests/SwiftDataActiveFastRepositoryTests.swift`;
- `uFastTests/TodayTimelineTests.swift`;
- `uFastTests/HistoryDataProviderTests.swift` and History presentation/motion
  suites;
- `uFastTests/PersistenceContainerTests.swift` and
  `uFastTests/Slice3PersistenceMigrationTests.swift`;
- deterministic seeds in `uFast/DevelopmentSupport/UITestSeedFixtures.swift`;
  and
- Today, food, hydration, fast-start/end, inferred-fast and History UI journeys.

Each story narrows this inventory. A worker must inspect the named suites before
editing and must record any deliberately changed fixture assumption.

### Stable UI fixture and selector contract

New UI coverage must reuse or deliberately add these deterministic seeds and
query the named identifiers/scoped containers. Do not infer controls from
English labels.

| Story | Required seed/launch contract | Stable identifiers or scoped selectors |
| --- | --- | --- |
| MNT-004 | `--ui-testing --reset-data --seed-onboarded --fixed-now <epoch> --seed-active-fast-start <epoch>` | `today.content`, `food.add`, `drink.add`, `fast.end`, `fast.end-confirm`, `timeline.entry.<UUID>`, `history.content` |
| MNT-003 | Existing onboarded/food/hydration seeds plus new deterministic `--seed-today-multi-year`; fixed clock | `today.content`, `food.add`, `drink.add`, `timeline.empty`, `timeline.entry.<UUID>` |
| MNT-005 | New deterministic `--seed-caloric-boundary-multi-year` with fixed UUIDs/times; start in History when asserted | `today.content`, `timeline.entry.<UUID>`, `history.content`, `history.list`, `history.fast.<UUID>` |
| MNT-006 | `--ui-testing --reset-data --seed-onboarded --fixed-now <epoch>` | `today.content`, `history.content`, `settings.content`, `drink.add` |
| MNT-007A | Existing onboarded, active-fast, caloric-food and caloric-favourite seeds with fixed clock | `food.add`, `drink.add`, `timeline.entry.<UUID>`, `fast.end`, `history.content`, existing editor save/cancel identifiers |
| MNT-007B | `--ui-testing --reset-data --seed-onboarded --seed-slice3-history --ui-testing-start-history --fixed-now <epoch>` | `history.content`, `history.list`, `history.choose-date`, `history.motion-retry`, `history.motion-extension-retry`, `history.fast.<UUID>` |
| MNT-008F | On-disk unit fixtures are authoritative; no new UI seed is required | Device smoke uses `today.content`, `history.content`, `settings.content`; feasibility assertions query records, not labels |

If an existing affected test uses a narrower stable identifier, retain it and
record it in the story handoff. Any new interactive control requires an
identifier designed with its UI test.

---

## MNT-002 — Make the local release gate authoritative

**Priority:** P0 change safety  
**Status:** Ready  
**Depends on:** None

### User outcome and why now

As the sole developer preparing future builds, I want one local command to prove
the exact source and archive configuration I am about to ship, so that a green
message cannot hide a skipped check and release pressure does not depend on a
remembered command sequence.

### In scope

- Correct the case-sensitive entitlement path and fail when an expected source
  or built entitlement file is absent.
- Verify an explicit allowlist for app and widget entitlements from generated or
  archived products where practical, not only by searching source text.
- Compose build, app/core units, lint, analyzer, local-only verification,
  release-version/privacy verification, UI-verifier self-test and accepted
  source-bound UI evidence behind one `make release-gate` entry point.
- Implement D-036's deterministic content-based source-freeze identity; record
  it with commit SHA, clean/dirty state, tool versions, commands/exit codes,
  version/build and evidence paths in a stable local manifest.
- Make `upload_testflight.sh` call the authoritative gate unless an existing
  explicit, documented override is supplied.
- Require a clean committed tree for actual upload authorization. Permit a
  candidate verification manifest for a frozen dirty sprint tree, clearly mark
  it not upload-authorised, and make the content identity comparable after the
  same tree is committed.
- Increment the build only after preflight passes. On archive/export/upload
  failure, restore the exact pre-run project file when the script's increment is
  the only change; on successful upload retain it; stop on concurrent/unrelated
  edits rather than overwriting them.
- Add deterministic negative-control tests for missing/unexpected entitlements,
  mismatched versions/privacy metadata and missing/incompatible UI evidence.
- Record the local-only solo-developer verification decision in the appropriate
  engineering documentation. Do not re-enable GitHub Actions in this story.

### Out of scope

- A real TestFlight upload, App Store Connect mutation or signing-certificate
  change.
- MNT-001 or mandatory GitHub CI.
- Product entitlement changes, CloudKit, remote notification or networking.
- Modifying submitted build 10.

### Acceptance criteria

1. A single documented local command runs the complete release contract and
   returns nonzero when any component fails.
2. The entitlement verifier inspects the case-correct app/widget inputs or built
   products, requires their presence, and rejects every entitlement outside the
   explicit allowlist.
3. Negative fixtures prove that a missing entitlement, forbidden entitlement,
   version mismatch, missing privacy declaration, stale/unbound UI result or
   failed underlying command cannot produce a passing manifest.
4. A passing manifest identifies the content source-freeze ID, source SHA,
   worktree state, tool versions, version/build, commands, exit codes and stable
   artifacts. A dirty-tree candidate is explicitly not upload-authorised.
5. Actual upload refuses a dirty tree, uses the gate by default and restores the
   pre-run `project.yml` after a simulated archive/export/upload failure; a
   simulated success retains the increment.
6. Existing local-only, release-version and UI-result verifier behavior remains
   available through focused commands and the combined gate.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | One command aggregates all required local gates and propagates failure | Script/Make target self-test | One injected child command exits nonzero | Self-test log and exit code |
| 2 | Exact app/widget entitlement allowlists are inspected | Script fixture plus built-product inspection | Missing file; CloudKit/iCloud/remote-notification added | Verification log and extracted entitlements |
| 3 | Every negative control fails | Script test harness | Stale SHA, missing manifest/result, bad version | Negative-control summary |
| 4 | Pass manifest is content-bound and complete | Manifest schema/content assertion | Dirty candidate versus clean upload-authorised mode | Stable JSON/Markdown manifest |
| 5 | Upload rejects dirty input and rolls back its failed increment | Dry-run/fake tool boundary | Archive/export/upload failure; concurrent edit | Dry-run transcript and diff |
| 6 | Existing focused verifiers still pass independently | Existing Make targets | Direct invocation | Compact command ledger |

### Focused verification and impacted suites

- Add a shell/Python verifier self-test that does not require a real upload.
- Run `make verify-local-only`, `make verify-release-versions`,
  `make verify-ui-verifier`, `make lint` and `make analyze` as applicable.
- Do not consume the final full UI suite; use an already verified fixture/result
  to test manifest compatibility. The story's positive path is a deterministic
  fixture/self-test. The first real candidate manifest is produced at final
  source-frozen integration after the one fresh UI result exists; actual upload
  authorization remains deferred until the human commits the accepted tree.
- Inspect `Makefile`, `scripts/verify_local_only_release.sh`,
  `scripts/verify_release_versions.sh`, `scripts/verify_ui_xcresult.py`,
  `scripts/upload_testflight.sh`, `project.yml`, both entitlement files and the
  privacy manifest.

### Human physical-device check

- Launch the accepted development build on the configured iPhone.
- Confirm existing data remains present and Today, History and Settings open.
- Start and end a short test fast or verify the current fast without deleting
  valuable history.
- Confirm no new permission prompt, network dependency or user-visible release
  behavior appeared.

### Execution profile

- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: the filename-case bug and
  analyzer exit are deterministic; release mutation uses a dry-run boundary
- Acceptance matrix and downstream impact: script/Makefile focused; app smoke
  only, no product behavior change
- Focused correction budget: three attempts on the release-gate surface under
  the standard 25-minute circuit breaker
- Expected expensive commands: build, unit, lint and analyzer; no full UI suite
- Maximum rescue tier: Terra, then Sol diagnosis

---

## MNT-004 — Make caloric-boundary integrity compile-time mandatory

**Priority:** P1 data integrity  
**Status:** Ready  
**Depends on:** MNT-002 human verified

### User outcome and why now

As a user editing fasting, food and hydration history, I want every mutation
adapter to apply the same caloric-boundary rules, so that a future repository or
test double cannot silently bypass history integrity.

### In scope

- Replace optional runtime `as? CaloricBoundaryQuerying` capability checks with
  explicit required dependencies or required protocol refinements.
- Remove production fallback paths that omit boundary validation.
- Update lightweight spies/fakes to state their boundary behavior deliberately.
- Remove unused protocol requirements or connect them only when an existing
  command genuinely requires them.
- Use exact error equality/associated-value assertions for affected boundary
  behavior where the current broad equality would hide a mistake; presentation
  category cleanup may remain for MNT-007A.
- Restore `make analyze` to zero violations.

### Out of scope

- Changing BR caloric-boundary behavior, alert copy or accepted mutation order.
- Query optimization from MNT-005.
- Schema or UI redesign.

### Acceptance criteria

1. Every start/edit/end/save/delete service that requires caloric-boundary data
   fails to compile without an explicit authoritative boundary dependency.
2. No production mutation path uses a runtime capability cast or silent basic
   fallback to bypass boundary validation.
3. Existing accepted normal, backdated, inferred, food and caloric-hydration
   outcomes remain unchanged, including rollback on failure.
4. Tests assert the affected boundary/fast identity and timestamps where an
   error carries context.
5. `make analyze`, focused boundary suites, build and unit tests pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Required dependency appears in service/repository API | Compile-time API inspection and focused tests | Fake omits dependency in a compile fixture or reviewer inspection | Sol API review |
| 2 | No optional capability fallback remains | Static search plus service tests | Plain fake attempts a mutation | Search result and test result |
| 3 | Mutation semantics/rollback match baseline | Boundary, start, completed-fast, food/hydration tests | Save failure; equal timestamp; active/recorded conflict | Focused `.xcresult` |
| 4 | Context values are exact | Domain tests | Correct category with wrong affected fast | Focused test failure/pass evidence |
| 5 | Analyzer and units are green | Make targets | Previously unused deletion requirements | Command ledger |

### Focused verification and impacted suites

Run the smallest relevant selections from `CaloricBoundaryIntegrityTests`,
`FastStartServiceTests`, `CompletedFastServiceTests`, `FoodEntryServiceTests`,
`HydrationEntryServiceTests`, `ApplicationCommandsTests`, repository tests and
`PersistenceTransactionTests`, then app/core units, lint and analyzer.

### Human physical-device check

- With a short active test fast, add a caloric food entry and confirm the
  existing warning/blocked behavior is unchanged.
- Repeat with a caloric drink.
- Verify a permitted non-caloric drink still saves.
- End or clean up only the test fast/entries created for this check; confirm
  History remains truthful after relaunch.

### Execution profile

- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: existing boundary suites and
  the two analyzer violations
- Acceptance matrix and downstream impact: all mutation services, repositories,
  fakes and boundary UI journeys named above
- Focused correction budget: three attempts on one boundary contract surface
- Expected expensive commands: focused Xcode tests, full units, lint, analyzer
- Maximum rescue tier: Terra high for architecture/data-integrity rescue, then
  Sol diagnosis

---

## MNT-003 — Bound Today to the active calendar day

**Priority:** P1 lifetime-data scaling  
**Status:** Ready  
**Depends on:** MNT-004 human verified

### User outcome and why now

As a long-term user, I want Today to remain fast and accurate as years of local
history accumulate, so that opening the main screen does not load every food and
drink record ever saved.

### In scope

- Introduce an application-facing Today data source that returns immutable
  snapshots for `[startOfDay, startOfNextDay)`.
- Express lower/upper bounds in SwiftData predicates rather than fetching the
  lifetime store and filtering it in Swift.
- Preserve separate bounded settings, active-fast and favourite behavior.
- Refresh on relevant persistence changes, calendar-day rollover, time-zone
  change and scene lifecycle without wall-clock-dependent tests.
- Use `AppClock` and injected `Calendar` for deterministic midnight/DST tests.
- Preserve Today UI, ordering, copy, identifiers and mutation behavior.
- Add a deterministic multi-year fixture that proves unrelated years are not
  returned or mapped into the feature snapshot.

### Out of scope

- Today visual redesign, pagination or statistics.
- History query changes, backup/import or a new schema version.
- Generic repository/module migration beyond the Today seam.

### Acceptance criteria

1. Today's food/hydration storage query is bounded by the correct half-open
   calendar-day interval and no unbounded Today `@Query` remains for those
   entities.
2. Multi-year records outside the active day are not returned or snapshot-
   mapped, while all same-day records are ordered exactly as before.
3. Midnight, spring-forward/fall-back and time-zone changes select the correct
   absolute interval using the injected clock/calendar.
4. Saves/deletes refresh Today after commit and relaunch persistence remains
   truthful.
5. Existing Today accessibility and user-visible behavior remain unchanged.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Bounded descriptor/data source replaces lifetime food/drink query | Provider unit test and source review | Record immediately outside each boundary | Focused `.xcresult` and Sol finding |
| 2 | Only selected day is mapped and ordered | Multi-year deterministic fixture | Thousands of unrelated records; equal timestamps | Unit result and fixture summary |
| 3 | Correct interval follows calendar/time zone | Pure/provider tests | DST 23/25-hour days; midnight while backgrounded | Focused `.xcresult` |
| 4 | Committed mutations refresh and persist | Controller/provider tests and focused UI | Save failure; delete; relaunch | Focused UI `.xcresult` |
| 5 | Presentation contract unchanged | Existing Today UI journeys | Dynamic Type/RTL where impacted | UI result and accessibility identifiers |

### Focused verification and impacted suites

Inspect and update `TodayFeatureHost`, `TodayFeatureController`, feature
snapshots, `TodayTimeline`, the new/extended persistence provider,
`TodayTimelineTests`, controller tests, `ApplicationCommandsTests`, relevant food
and hydration tests, and focused Today UI journeys. Run focused unit/UI tests,
then units, build, lint and analyzer; do not run the full UI suite.

### Human physical-device check

- Confirm Today opens promptly with the device's existing history.
- Add food, caloric drink and non-caloric drink entries; confirm immediate order
  and display.
- Background/foreground the app and verify Today remains current.
- Change the device time zone only if safe for the test device; otherwise record
  that automated DST/time-zone evidence was used.
- Relaunch and confirm the entries persist and History still contains older data.

### Execution profile

- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: multi-year provider fixture,
  injected clock/calendar and focused Today UI fixture
- Acceptance matrix and downstream impact: Today snapshots/controller/UI plus
  food/hydration mutation refresh
- Focused correction budget: three attempts on Today query/refresh behavior
- Expected expensive commands: focused Today UI test plus build/units/analyzer
- Maximum rescue tier: Terra high for SwiftData/calendar issues, then Sol
  diagnosis

---

## MNT-005 — Bound boundary-sensitive mutation queries

**Priority:** P1 lifetime-data scaling and integrity  
**Status:** Ready  
**Depends on:** MNT-003 human verified

### User outcome and why now

As a long-term user, I want edits to remain responsive as history grows without
weakening fast-boundary correctness, so that adding or correcting one event does
not repeatedly materialize unrelated years.

### In scope

- Add a deterministic multi-year scale fixture and instrumented/query-observable
  baseline for UUID lookups, caloric-boundary planning and inferred-candidate
  revalidation.
- Replace fetch-all-then-first UUID lookups with predicates and fetch limits.
- Implement the settled per-operation neighborhood below and query it in
  storage; do not rediscover or broaden it during implementation.
- Preserve atomic before/after comparison, stable equal-timestamp provenance,
  inferred-fast punctuation and recorded/active fast integrity.
- Record repeatable baseline and post-change measurements. Use structural fetch
  bounds as acceptance; do not invent a fragile wall-clock threshold.

### Out of scope

- Caching boundary results, background indexing, statistics, backup/import or
  changing inferred-fast rules.
- Broad schema/index changes reserved for the follow-up MNT-008 implementation
  story generated by MNT-008F.
- Weakening assertions to accommodate a faster but incomplete result.

### Settled bounded-query contract

Ordinary mutations may use this contract only after the store-open D-035
reconciliation gate has succeeded. The global reconciliation pass remains an
intentional lifetime scan because it repairs every legacy row; it is excluded
from the ordinary-mutation no-lifetime-scan assertion.

- **UUID resolution:** predicate by ID, deterministic sort and `fetchLimit = 2`;
  return missing, unique or duplicate explicitly.
- **Boundary query primitive:** for earliest/nearest results, issue one sorted,
  limited query per food/hydration entity and merge with the shared timestamp,
  kind and UUID ordering.
- **Caloric insertion at `n`:** inspect the canonical exact-time group and fasts
  with `start < n && (end == nil || end > n)`. For inferred confirmation inspect
  the nearest distinct predecessor within `goal + 12` absolute hours and only
  fasts overlapping that predecessor candidate.
- **Caloric move `o → n`:** union the removal neighborhood at `o` and insertion
  neighborhood at `n`; when moved later, also query reconstructed rows whose
  stored end reference is the edited event. Inspect exact-time groups and nearest
  distinct predecessors at both points.
- **Caloric removal/reclassification:** query reconstructed rows whose stored end
  kind/UUID equals the removed reference. Inspect the exact-time group to decide
  whether the removed event was the canonical inferred source. Do not lengthen
  persisted rows or require confirmation for a predecessor that merely lengthens.
- **Non-caloric or description/amount-only changes:** use only bounded target ID
  lookup unless classification/timestamp changes.
- **Manual fast start/correction:** fetch at most the earliest food and earliest
  caloric hydration strictly after the proposed start and merge them. Preserve
  the intentionally unbounded future time horizon for corrupt/future-row
  semantics, but bound result cardinality. Conflict existence uses a limit of 1.
- **Completed-fast create/edit:** fetch at most one boundary of each event type
  strictly inside the proposed half-open interval, merge canonically, and query
  overlap existence with limit 1. Delete uses bounded ID lookup only.
- **Fast end:** preserve current active authority semantics; do not add a caloric
  boundary query. Retain the active-subset scan where exact duplicate count is
  part of the error contract.
- **Inferred revalidation:** resolve the source by ID, prove canonical identity
  in its exact-time group, fetch the first distinct later boundary before
  `min(now, source + goal + 12h)`, calculate threshold/cap locally, and query
  overlap existence with limit 1.

Implement a framework-independent semantic neighborhood-query adapter with an
injected no-op observation sink. Every request observation records entity,
lower/upper bound and inclusivity, sort keys, fetch limit and returned count.
Differential tests compare the bounded path with the existing full-history pure
analyzer/projector oracle. SwiftData predicate limitations are implementation
risk, not permission to weaken this domain contract.

### Acceptance criteria

1. UUID record lookup uses a predicate/fetch limit and returns an explicit
   missing/duplicate outcome appropriate to the current contract.
2. Boundary-sensitive save/delete/edit paths do not fetch unrelated lifetime
   food, hydration and fast records once the affected interval is known.
3. Inferred candidate revalidation produces identical results for relevant
   neighboring boundaries and ignores unrelated years.
4. Equal timestamps, DST, start/end edits, deletion, active/recorded conflicts
   and transaction rollback remain deterministic and unchanged.
5. A repeatable multi-year fixture records structural fetch bounds and baseline/
   post-change measurements without making timing alone the correctness gate.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | ID query is predicate/limit based | Repository test plus source inspection | Missing ID; deliberate duplicate fixture if current schema permits | Focused result and Sol review |
| 2 | Unrelated years are outside query/result inputs | Instrumented provider/repository test | Large history before/after affected interval | Query-observability log |
| 3 | Projection matches full-history oracle | Pure differential test | First/last neighbor; unrelated distant events | Focused `.xcresult` |
| 4 | Domain invariants remain exact | Existing boundary/inferred/transaction suites | Equal time, DST, deletion, save failure | Focused `.xcresult` |
| 5 | Scale fixture is repeatable and non-flaky | Unit/benchmark support | Cold/warm runs; timing variance | Baseline report and structural assertions |

### Focused verification and impacted suites

Inspect `ApplicationCommands`, `CaloricBoundaryPersistence`, SwiftData food/
hydration/active-fast repositories, `UFastCore` inferred projections, boundary
integrity tests, `HistoryCaloricNeighbourOrderingTests`, inferred-fast tests,
repository tests and transaction tests. Run focused pure tests first, focused
persistence selections next, then units, build, lint and analyzer.

### Human physical-device check

- With representative existing History, add/edit/delete a food entry and a
  caloric drink near a completed or active fast boundary.
- Confirm warnings, affected fasts and History ordering match the prior behavior.
- Relaunch and verify no unrelated older record changed.
- Record a qualitative responsiveness observation only; automated structural
  query evidence remains the acceptance authority for scaling.

### Execution profile

- Uncertainty: high
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: full-history pure oracle versus
  bounded provider results on seeded multi-year data
- Acceptance matrix and downstream impact: caloric mutation repositories,
  inferred projection and transaction/History neighbor suites
- Focused correction budget: three attempts per settled query-neighborhood
  surface; no trial-and-error query narrowing
- Expected expensive commands: scale fixtures, focused persistence tests, units
- Maximum rescue tier: Terra high, then Sol diagnosis

---

## MNT-006 — Enforce the feature/data dependency seam

**Priority:** P1 architecture ratchet  
**Status:** Ready  
**Depends on:** MNT-005 human verified

### User outcome and why now

As the sole maintainer, I want repository architecture rules to match and check
the actual composition model, so that future backup, Health and statistics work
does not add another unreviewed persistence access style.

### In scope

- Reconcile `docs/ARCHITECTURE.md` with the accepted role of app composition
  hosts/adapters under `uFast/App/FeatureHosts` (or one consistently named App
  composition directory).
- Move Today and Settings composition hosts plus persistent-record-to-snapshot/
  editor mapping extensions out of `uFast/Features` into explicit App or
  Application adapter locations without changing target behavior.
- Protect all of `uFast/Features/**` from `import SwiftData`, `@Query`,
  `@Environment(\.modelContext)`, `ModelContext`, `FetchDescriptor` and direct
  current persistent-record type references. The only initial allowlist is:
  `uFast/Features/Fasting/HistoryView.swift`,
  `uFast/Features/Fasting/HistoryView+Data.swift`, and
  `uFast/Features/Fasting/HistoryProjectionRefreshBoundary.swift`.
- Store the allowlist as exact paths with exact forbidden-symbol reasons. Its
  negative-control self-test must fail if a fourth path is added or an allowed
  path adds another forbidden category without an explicit reviewed edit.
- Make `UFastCore` imports explicit in changed files and remove the underscored
  exported import when doing so is bounded and source-compatible.
- Use the MNT-003 Today provider as the proof that the rule is executable.
- Add the architecture check to local lint/analyzer or verification commands.

### Out of scope

- Moving all domain code into `UFastCore`, creating many new modules or rewriting
  History/persistence.
- Eliminating every existing SwiftData composition exception.
- Product behavior or schema changes.

### Acceptance criteria

1. The architecture document names allowed dependency direction, composition
   roots and temporary explicit exceptions without contradicting source.
2. A local automated check fails when a test fixture adds forbidden persistence
   access to a protected presentation/domain path.
3. Current permitted adapters pass through the exact three-path History
   allowlist or an allowed App/Application adapter location; the check cannot
   silently expand its baseline. MNT-007B removes the History exceptions.
4. Today demonstrates immutable snapshot/data-source separation and no protected
   view owns an unbounded persistence query.
5. Build, units, lint and analyzer remain green with no behavior change.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Docs and directory/check policy agree | Sol architecture review | Composition host ambiguity | Criterion-level Sol decision |
| 2 | Forbidden dependency fixture fails | Script negative-control self-test | `import SwiftData`, `@Query`, `ModelContext`, record type | Self-test log |
| 3 | Baseline is explicit and ratcheted | Script/config review | Add an unapproved exception | Diff and failure evidence |
| 4 | Today seam is protected | Existing MNT-003 tests and static check | Reintroduce direct lifetime query | Command output |
| 5 | No behavior regression | Build/units/lint/analyzer | Existing adapters | Command ledger |

### Focused verification and impacted suites

Focus on `docs/ARCHITECTURE.md`, app/composition hosts, `UFastCoreExports.swift`,
the architecture-check script/self-tests, Makefile verification targets and the
MNT-003 Today tests. Run negative-control script tests, build, units, lint and
analyzer. UI source should not need to change beyond moves/imports; run the
smallest navigation smoke UI test if target membership changes.

### Human physical-device check

- Launch the app and open Today, History and Settings.
- Add one non-caloric drink and verify it appears in Today and History.
- Confirm navigation, existing data and Live Activity/widget-facing behavior
  show no visible regression.

### Execution profile

- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: architecture negative-control
  fixtures plus existing Today seam tests
- Acceptance matrix and downstream impact: target membership/imports,
  composition hosts and local verification commands
- Focused correction budget: three attempts on architecture check/build surface
- Expected expensive commands: project regeneration if membership changes,
  build, units, lint, analyzer
- Maximum rescue tier: Terra high, then Sol diagnosis

---

## MNT-007A — Decompose application commands by use case

**Priority:** P1 change-coupling reduction  
**Status:** Ready  
**Depends on:** MNT-006 human verified

### User outcome and why now

As the maintainer, I want food and hydration caloric-event commands to have one
cohesive owner, so that changing event-boundary behavior does not require editing
and reviewing the full multi-domain command object.

### In scope

- Preserve `ApplicationCommands` as a temporary façade for call-site stability.
- Extract only food/hydration create, edit, delete, reclassification, lookup,
  boundary-impact confirmation and their post-commit effects into one bounded
  injected caloric-event command owner.
- Share food/hydration orchestration only where transaction and boundary
  semantics are genuinely identical; retain typed differences otherwise.
- Centralize semantic error-to-presentation categorization while preserving
  exact domain error equality and associated-value tests.
- Reduce broad file/type/function lint suppressions in the changed command
  surface and prohibit a net increase.
- Preserve post-commit projection ordering, rollback and public feature-command
  protocols.
- Reduce `ApplicationCommands.swift` by at least 180 non-comment lines from the
  story baseline. Keep the extracted production file at or below 400 lines with
  no `file_length` or `type_body_length` suppression. Record exact before/after
  line and suppression counts.

### Out of scope

- Fasting/inferred, settings/favourites/data-management extraction; History
  state/task changes; UI redesign; schema migration; or behavior/copy changes.
- Replacing SwiftData or removing the façade in one pass.

### Acceptance criteria

1. One extracted caloric-event command owner contains the food/hydration family
   and has focused tests; the façade delegates without duplicating behavior.
2. Existing feature command protocols and call sites continue to compile and
   produce identical success/error outcomes.
3. Transaction commit/rollback and post-commit widget/Live Activity projection
   ordering remain exact for every extracted mutation family.
4. Domain error equality is exact; UI sharing uses an explicit presentation
   category rather than equality that discards context.
5. `ApplicationCommands.swift` loses at least 180 non-comment lines; the new
   owner is at most 400 lines with no file/type-length suppression; no changed
   command file adds a broad suppression; build, units, lint and analyzer pass.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Thin façade delegates to cohesive use cases | API/source review and focused tests | One family unavailable/failing | Sol decision and diff summary |
| 2 | Feature behavior unchanged | Controller/ApplicationCommands tests | Every mapped error category | Focused `.xcresult` |
| 3 | Commit precedes projections; failures roll back | Transaction/projection coordinator tests | Save/projection failure | Focused `.xcresult` |
| 4 | Exact context is test-visible | Food/hydration error tests | Same category, wrong fast/impact | Focused result |
| 5 | Recorded line/suppression thresholds pass | Scripted line inventory plus lint | Threshold miss or new blanket suppression | Before/after inventory and command ledger |

### Focused verification and impacted suites

Inspect the food/hydration `ApplicationCommands` methods and controller
extensions, post-commit projection coordinator, caloric mutation services,
food/hydration repositories, `ApplicationCommandsTests`, transaction tests,
boundary tests and relevant active-fast projection tests. Run those focused
families after extraction, then units, build, lint and analyzer.

### Human physical-device check

- With a disposable active test fast, add, edit and delete food plus
  caloric/non-caloric hydration and exercise the existing boundary warnings.
- Relaunch and verify Today/History persistence and widget/Live Activity status
  remain truthful.

### Execution profile

- Uncertainty: high
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: existing command/controller,
  transaction and projection tests characterize the façade
- Acceptance matrix and downstream impact: every ApplicationCommands extension,
  controller and mutation suite
- Focused correction budget: three attempts per extracted command-family
  acceptance surface; stop if the façade contract expands
- Expected expensive commands: several focused unit selections, build, all
  units, lint, analyzer
- Maximum rescue tier: Terra high, then Sol diagnosis

---

## MNT-007B — Give History explicit state and task ownership

**Priority:** P1 concurrency/change-coupling reduction  
**Status:** Ready  
**Depends on:** MNT-007A human verified

### User outcome and why now

As a user navigating long History, I want loading and cancellation to remain
deterministic during rapid movement and lifecycle changes, while the maintainer
can reason about that behavior outside a view with dozens of state properties.

### In scope

- Move History loading, generation identity, prefetch and asynchronous task
  ownership into one `@MainActor` observable presentation model or equivalent
  tested owner.
- Retain immutable presentation snapshots, bounded providers, generation guards,
  settled/motion authority and existing cache behavior.
- Store task handles and cancel/replace obsolete initial, extension and prefetch
  work explicitly.
- Keep view-local transient visual state in the SwiftUI view when it does not
  belong to loading/application state.
- Move the three MNT-006 History persistence/composition exceptions to an
  allowed App/Application adapter so the `uFast/Features/**` architecture
  allowlist becomes empty.
- Reduce broad suppressions in changed History files and remove deprecated test
  support/warnings encountered on the changed surface.
- Preserve accessibility identifiers, motion semantics and error/retry states.
- Reduce `HistoryView.swift` to at most 300 non-comment lines and the replacement
  loading/orchestration owner to at most 400, with no `file_length` or
  `type_body_length` suppression in either. Record exact before/after counts.

### Out of scope

- History visual redesign, gesture changes, new animation, new cache policy,
  data schema or Today changes.
- Removing generation guards merely because cancellation exists.

### Acceptance criteria

1. One explicit owner controls History load/prefetch task lifecycle and exposes
   immutable state to the view.
2. Replaced/cancelled tasks cannot publish stale snapshots or errors; generation
   guards remain a second line of defense.
3. Initial load, range extension, rapid adjacent-day movement, scene transition,
   error/retry and persistence invalidation preserve current semantics.
4. Existing History UI identifiers and user-visible timeline behavior remain
   unchanged under four-worker-safe focused tests.
5. The MNT-006 History allowlist is empty; `HistoryView.swift` is at most 300
   non-comment lines and its loading owner at most 400 without file/type-length
   suppressions; affected actor/deprecation warnings are removed.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Observable owner contains task/state lifecycle | Unit/API review | View deallocation/recreation | Sol source review |
| 2 | Stale task cannot publish | Deterministic async unit tests | Old task completes after replacement/cancel | Focused `.xcresult` |
| 3 | Current History states preserved | History data/motion/cache tests | Initial/extension failure, scene churn, invalidation | Focused results |
| 4 | UI journeys unchanged | Focused History UI selections | Rapid navigation, below-viewport error/retry | Stable UI `.xcresult` |
| 5 | Architecture and numeric ratchets pass | Architecture check plus line inventory/analyzer | Reintroduced persistence access, actor isolation, deprecated buffer | Command ledger and before/after inventory |

### Focused verification and impacted suites

Inspect `HistoryView.swift`, `HistoryView+Data.swift`, presentation extensions,
snapshot/cache/coordination types, History projection refresh boundary,
`HistoryDataProviderTests`, motion authority/streaming/presentation/cache tests,
temporal presentation tests and focused History UI journeys. Run pure/unit tests
first, changed History UI tests second, then build, units, lint and analyzer. Do
not run the full UI suite during the story.

### Human physical-device check

- Open History with existing multi-day data and navigate rapidly backward and
  forward across several days.
- Select/edit/cancel records and verify the correct day remains selected.
- Background/foreground during or after navigation, then retry any visible error
  state if safely reproducible.
- Confirm there is no stale flash, incorrect selected record, lost data or stuck
  loading state.

### Execution profile

- Uncertainty: high
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: controllable async providers and
  generation/cancellation tests, plus seeded History UI journeys
- Acceptance matrix and downstream impact: History view/data/presentation,
  motion/cache suites and all History UI selectors
- Focused correction budget: three attempts per task-lifecycle acceptance
  surface; no gesture-driven trial-and-error
- Expected expensive commands: focused History UI tests, units, build, analyzer
- Maximum rescue tier: Terra high, then Sol diagnosis

---

## MNT-008F — Prove the backup-ready identity/schema migration design

**Priority:** P1 future data-safety feasibility  
**Status:** Ready  
**Depends on:** MNT-007B human verified

### User outcome and why now

As a future backup user, I need a proven persistent-identity design before the
production schema changes, so that a uniqueness migration cannot strand or
silently alter existing local history.

### Settled identity contract

- Existing UUIDs remain canonical and uniqueness is **per entity**, not global.
  A backup identity is `(entity kind, UUID)`; the same UUID in food and hydration
  is valid.
- App settings singleton authority remains separate from ID uniqueness. Preserve
  the current zero/one/many authority behavior; do not introduce a sentinel ID or
  silently rewrite existing settings IDs.
- V1-V4 declarations and all current global model types referenced by those
  schemas are frozen. This feasibility story must not annotate or rebind them.
- Duplicate IDs within one entity are integrity failures. They must never be
  merged, renumbered, skipped, overwritten or selected arbitrarily.
- Backup archive/import/restore behavior remains out of scope.

### In scope

- Build a test-only V5 prototype with six isolated nested current-equivalent
  model types. Do not point production `PersistenceContainer` at it.
- Prove whether V4 global entity types can migrate to isolated V5 nested types
  with the same simple entity names while adding one per-entity unique ID
  constraint and candidate indexes supported by the Xcode 26 SDK.
- Candidate indexes to test: food `occurredAt`; hydration `occurredAt` and
  `(isCaloric, occurredAt)`; fast `startDate` and `endDate` separately;
  hydration favourite `(createdAt, creationOrder, id)`. Do not add a redundant
  ID index, settings index or unknown-period index without new evidence.
- Create an independent clean V4 disk fixture containing every entity and value
  category, plus an independent duplicate-ID V4 fixture.
- Compare lightweight migration with a custom `willMigrate` duplicate preflight.
  Record exact error chains, atomicity and whether the original V4 store family
  remains reopenable under V4 after failure.
- Prove fresh V5 duplicate-against-existing and duplicate-in-one-transaction
  behavior is throw plus rollback, not merge/upsert; prove the same UUID across
  two entity types succeeds.
- Inspect generated schema uniqueness/index metadata and measure representative
  queries; index presence alone is not proof of use.
- Produce `docs/MNT-008_IDENTITY_SCHEMA_IMPLEMENTATION_STORY.md` with an explicit
  `GO` strategy or `BLOCKED` alternative. A `GO` artifact must receive an
  explicit Sol readiness decision before any production V5 work starts.

### Out of scope

- Changing production model types, migration plan, repositories or app behavior.
- Deploying a V5 schema to a physical device.
- Backup/import/restore UI, conflict policy, CloudKit or sync.
- Byte-for-byte SQLite equality as the preservation contract. Preserve logical
  values and protect an untouched original store-family artifact; only record a
  stable hash when the feasibility run proves it meaningful.

### Acceptance criteria

1. A test-only V5 prototype compiles without changing V1-V4/current global model
   declarations and exposes the expected unique/index metadata.
2. An independently declared clean V4 disk fixture either migrates to the test
   V5 prototype with every logical value/ID preserved or yields repeatable
   evidence that the type-isolation strategy is unsupported.
3. Duplicate migration/save behavior, rollback, error chains, V4 reopenability
   and valid cross-entity UUID reuse are directly observed.
4. Settings singleton authority and per-entity identity are recorded separately;
   no sentinel or global UUID registry is introduced.
5. The generated implementation story names exact model/type aliases, migration
   stage, constraints, indexes, typed errors, independent fixtures and device
   safety gate, or is marked Blocked with the smallest safe alternative.
6. Production build, units, lint and analyzer remain green and the deployable app
   still uses V4.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Isolated prototype compiles and metadata matches | Test-only schema tests | Accidental V1-V4/global diff | Focused `.xcresult` plus git diff |
| 2 | Clean independent V4 migration is proven or disproven | On-disk feasibility test | Every entity/value category | Logical before/after report and protected fixture |
| 3 | Duplicate semantics are observed | Disk/save tests | Legacy duplicate, same transaction, existing row, cross-entity reuse | Error-chain and rollback evidence |
| 4 | Identity scopes stay separate | Settings/identity tests and decision review | Multiple different settings IDs | Sol criterion decision |
| 5 | Follow-up story is executable | Create-sprint-ready-story/Sol gate | GO versus blocked fallback | Follow-up Markdown and readiness verdict |
| 6 | Production remains V4 and green | Schema assertion/build/units/lint/analyzer | Prototype accidentally enters app target | Command ledger |

### Focused verification and impacted suites

Add isolated feasibility support/tests near `PersistenceContainerTests` and
`Slice3PersistenceMigrationTests` without changing production target membership.
Inspect Xcode 26 SwiftData constraint/index metadata, independently declare V4
fixtures, run the smallest feasibility tests, then production persistence suites,
all units, build, lint and analyzer. Sol must inspect the actual schema metadata,
error chains and generated follow-up story.

### Human physical-device check

- Deploy the still-V4 accepted app build only after Sol confirms the prototype is
  test-target-only.
- Launch Today, History and Settings and confirm existing records remain present.
- Add and relaunch one disposable test record if desired.
- Confirm no migration/unavailable screen appears. No V5 device migration is
  authorised by this feasibility story.

### Execution profile

- Uncertainty: high
- Initial implementer: Luna xhigh with one bounded compile/on-disk spike
- Deterministic reproduction and observability: isolated schema metadata,
  independent clean/duplicate V4 fixtures and exact NSError chains
- Acceptance matrix and downstream impact: test-only models/fixtures,
  persistence tests and the generated follow-up story; production stays V4
- Focused correction budget: one feasibility hypothesis plus at most two test-
  harness corrections; repeated type/checksum failure ends in a Blocked decision
- Expected expensive commands: focused disk migration tests, units, build,
  analyzer; ordinary V4 device deployment only
- Maximum rescue tier: Terra high, then Sol diagnosis

## Sprint integration and Definition of Done

After all eight stories have explicit Sol `ACCEPTED` decisions and recorded
human build checks:

1. Review the combined diff against the recorded baseline for scope drift,
   duplicated seams, schema edits, broad suppressions, temporary instrumentation,
   debug code and unintended product behavior.
2. Confirm every acceptance-matrix row and downstream fixture has evidence.
3. Establish a unique source-freeze ID tied to the final SHA/worktree state.
4. Use a fresh read-only Luna verifier to run the complete appropriate gate:
   project generation, committed formatting check, build, app/core units, lint,
   analyzer, local-only verification, release-version/privacy verification,
   release-verifier self-tests and exactly one four-worker UI suite.
5. Run `make verify-ui-result UI_XCRESULT=<stable-path>` and preserve the compact
   output, underlying exit code, logs and `.xcresult` in a stable sprint path.
6. Give a fresh read-only Sol integration reviewer the combined diff, story
   decisions, all human check outcomes, source-freeze ID and artifacts. Only an
   explicit Sol integration `ACCEPTED` verdict completes the sprint.
7. Do not upload, commit, push, open a PR or modify App Store Connect without a
   separate human request.

The sprint is not complete with a pending/failed human build check, a blocked
story, analyzer warning/violation, incomplete MNT-008F feasibility evidence,
unbound UI result or unreviewed source change.

## Definition of Ready

- MNT-001 is explicitly excluded and D-036 makes local source-bound gates the
  accepted solo-developer verification policy.
- D-036 records the clean/dirty, source-freeze and build-increment policy; those
  choices are not delegated to implementation.
- Story order, dependencies, scope and non-goals are explicit.
- Every criterion maps to an observable test/review artifact.
- Affected fixtures and suites are named.
- Luna xhigh is the initial implementer, with bounded Terra/Sol escalation.
- The human physical-device pause and response contract are mandatory after
  every story.
- MNT-008F proves or blocks the production identity migration before valuable
  device data can be exposed; production V5 implementation is a separate Sol-
  ready sprint generated from that evidence.
- No unresolved product choice is delegated to the implementation worker.

## Sol readiness gate

**Verdict:** READY  
**Reviewed:** 20 August 2026  
**Reasoning:** medium  
**Recommended initial implementer:** Luna xhigh  
**Split required:** no

Sol confirmed that all eight stories are coherent, sequential and independently
testable; D-036 settles the local verification policy; MNT-005 delegates no
unresolved query discovery; MNT-007A is bounded to one command family; and
MNT-008F is a safe test-only feasibility outcome with production V5 explicitly
deferred. It found no blocking product, architecture, persistence,
accessibility, privacy, fixture or observability contradiction.

## Suggested implementation command

```text
$implement-sprint docs/POST_MVP_MAINTAINABILITY_SPRINT.md
```
