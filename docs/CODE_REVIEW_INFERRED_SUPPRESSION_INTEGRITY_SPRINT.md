# Inferred suppression integrity review sprint

**Sprint:** ISI-100  
**Status:** Ready — Sol readiness gate passed 28 August 2026  
**Prepared:** 28 August 2026  
**Goal:** Preserve every compatible local store while making inferred-fast suppression reconciliation bounded and free of clock-only launch writes.  
**Stories:** ISI-101, ISI-102  
**Product rules:** BR-12, BR-22 through BR-26, BR-44, BR-49, BR-53 through BR-57  
**Repository guidance:** `AGENTS.md`, `docs/PERSISTENCE_MIGRATIONS.md`

## Review findings and disposition

This sprint captures three code-review findings that are too risky for an
incidental patch:

1. `UFastSchemaV3` through `UFastSchemaV6` reference the mutable current
   `AppSettingsRecord`. Changing that type's inferred-detection default from
   `false` to `true` therefore changes historical schema metadata and can stop
   an existing V6 store before the V6-to-V7 migration runs.
2. `InferredFastSuppressionStore.reconcileInMemory` calls
   `InferredFastSuppressionDecider.decide` once per stored suppression, and
   each decision projects the complete caloric-boundary stream again.
3. app bootstrap runs saving reconciliation with the launch clock. Every
   hidden, unpunctuated in-progress candidate can therefore advance its stored
   projected end and `updatedAt` on every launch even though time alone is
   disposable presentation state.

The schema problem is isolated as ISI-101 because store compatibility is a P1
gate. The two reconciliation findings are one coherent ISI-102 change: compute
one authoritative batch, then decide explicitly which differences are durable
at launch. Neither story changes the user's inferred-fast eligibility,
suppression choice, source events, or recorded fasts.

## Story order

1. ISI-101 must be accepted first. It freezes the source and destination model
   contracts on which all later persistence evidence depends.
2. ISI-102 follows against the accepted schema and changes reconciliation
   behavior without adding or removing stored fields.

---

## ISI-101 — Freeze inferred-setting schemas and preserve migration intent

**Priority:** P1 data availability  
**Status:** Ready  
**Estimate:** 3 points  
**Depends on:** PI-101 release-baseline schema conventions; OW-410 setting contract

### User outcome and why now

As an existing uFast user, I want an update containing inferred-fast suppression
to open my local records without loss or reset, while keeping my saved inferred-
detection choice.

The current V3-through-V6 model lists point at a mutable live settings type. A
source-code default change can therefore alter the checksum SwiftData uses to
recognize an already-created store before migration code can preserve it.

### Authoritative contract

- `docs/PERSISTENCE_MIGRATIONS.md` requires every existing versioned schema to
  remain immutable and requires an independently created preceding-version
  on-disk fixture.
- OW-410 AC1/AC12 and BR-44 require detection on for a new install and for the
  release-baseline migration, while an existing persisted choice remains
  authoritative.
- The independently frozen release baseline has no inferred-detection field.
  Its migration may initialize the newly introduced preference to `true`.
- A source store that already contains the preference must retain its stored
  `true` or `false` value. A schema default is never evidence that an existing
  stored value may be rewritten.

### In scope

- Give every settings-bearing historical schema from V3 through V6 an immutable
  settings declaration matching the exact stored fields, names, types,
  optionality and defaults represented when that version was created. The
  frozen inferred-detection default in each of V3, V4, V5 and V6 is `false`.
- Freeze and preserve V7's existing stored metadata and checksum exactly. Keep
  the current production settings API and its new-record default enabled
  without changing V7's already-represented entity identity or introducing a
  parallel production entity.
- Add the smallest custom migration behavior needed so an independently frozen
  release-baseline store with no preference arrives in V7 enabled.
- Preserve an existing V3/V4/V5/V6 stored `false` as `false` and stored `true`
  as `true`; preserve all other settings and model records byte-for-domain-value.
- Keep production call sites using the current `AppSettingsRecord` API after the
  store opens. Historical model types must not leak into feature or domain code.
- Add independently declared, on-disk V3, V4, V5 and V6 fixtures for both
  preference values. They must not use the live model,
  `PersistenceContainer.schema`, or the matching production model list to
  construct a source schema.
- Add a current-V7 saved-choice guard proving existing `false` and `true`
  records preserve their values after close/reopen and ordinary app bootstrap.
- Retain the existing independently frozen release-baseline migration fixture
  and prove its inferred setting becomes enabled without fabricating a
  suppression.
- Update `docs/PERSISTENCE_MIGRATIONS.md` if implementation establishes a new
  reusable schema-identity rule.

### Out of scope

- Deleting, replacing, resetting, exporting, repairing or silently recreating a
  store after a checksum failure.
- Renumbering released schemas without evidence, enabling CloudKit, or changing
  any food, hydration, fast, favourite, unknown-period or suppression meaning.
- Treating all stored `false` values as unchosen or overwriting them to satisfy
  the new-install default.
- Changing inferred projection, suppression reconciliation, History UI, copy,
  or the setting toggle interaction.

### Acceptance criteria

1. Given an independently declared V3, V4, V5 or V6 on-disk store whose
   settings preference is `false`, when `PersistenceContainer` opens it through
   the production migration plan, then the store opens successfully and the
   preference remains `false` for every entry version.
2. Given each of the same V3-through-V6 fixtures with preference `true`,
   migration opens it and preserves `true` for every entry version.
3. Given an independently frozen release-baseline store with no inferred-
   detection field, migration opens it with detection enabled, while a fresh V7
   settings record also defaults to enabled.
4. Every fixture preserves settings identity, goal, onboarding, favourite
   values, Live Activity preference and all representative fast, food,
   hydration, favourite and legacy-history records; V6-to-V7 fabricates no
   suppression rows.
5. Historical V3-through-V6 settings declarations no longer reference the
   mutable current settings model, each retains its original `false` default,
   and a source-level or metadata assertion prevents a future current-model
   edit from altering those schema definitions unnoticed.
6. Existing V7 stores with saved `false` and `true` reopen and pass ordinary
   bootstrap unchanged, and V7's stored metadata/checksum remains identical to
   the pre-story contract.
7. A simulated migration failure leaves the entire source store bundle present
   and byte-for-byte unchanged and produces the existing calm persistence-
   unavailable outcome.

### Architecture, data, privacy and compatibility boundaries

- Keep frozen SwiftData declarations private to the persistence compatibility
  layer. Model names and original-name mapping must preserve entity identity;
  do not solve the checksum issue by creating parallel production entities.
- Migration is local, deterministic and idempotent. It emits no user data to
  diagnostics, uses no wall clock for preference choice, and introduces no
  network or CloudKit dependency.
- If an independently generated fixture proves that the assumed V3-through-V6
  field/default history is wrong, stop and report the evidence rather than
  modifying a historical declaration to make a circular fixture pass.

### Focused verification

- Extend `PersistenceContainerTests` and `Slice3PersistenceMigrationTests` with
  parameterized, independently declared V3-through-V6 `false` and `true` stores
  plus the existing release baseline fixture and current-V7 reopen guards.
- Assert post-migration record identities, values, counts and zero fabricated
  suppressions; close and reopen each migrated store once.
- Snapshot every file in the source store bundle before a simulated failure and
  compare its file set and bytes afterward, not only fetched model values.
- Run the smallest migration-focused test target first, then `make analyze`,
  `make test-unit`, `make build` and `make lint`. No UI test is required because
  this story changes no interaction or visible state.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | V3-V6 `false` stores open and stay false | parameterized independent on-disk migration tests | reopen every migrated entry version | focused test log and source store fixtures |
| AC2 | V3-V6 `true` stores open and stay true | parameterized independent on-disk migration tests | reopen every migrated entry version | focused test log and source store fixtures |
| AC3 | release baseline and fresh V7 default on | existing release fixture plus current-container test | no preference field in source | focused test log |
| AC4 | all representative values survive and no suppression appears | `Slice3PersistenceMigrationTests` | empty and populated stores | before/after snapshot assertions |
| AC5 | V3-V6 no longer depend on current settings metadata | persistence source/metadata assertion | future current default edit | unit/static-analysis result |
| AC6 | V7 identity and saved choices remain unchanged | current-V7 on-disk reopen/bootstrap test | saved false and true | schema guard and focused test log |
| AC7 | failed migration is non-destructive | bootstrap failure test | compare whole store bundle and reopen source | failure log and byte snapshot |

### Downstream fixture and legacy-suite impact

- Preserve PI-101's release-baseline fixture and every schema/model-count
  assertion in `PersistenceContainerTests`, `Slice3PersistenceMigrationTests`
  and `MNT008IdentitySchemaFeasibilityTests`.
- Review settings tests that assume a fresh default of `true`; they remain
  correct for V7 and must not be weakened to accommodate a historical model.
- No UI fixture, accessibility selector, widget projection or ActivityKit test
  should change.

### Execution profile

Execution profile:
- Uncertainty: high
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: independently declared on-disk V3-through-V6 stores with explicit `false`/`true`, current-V7 identity/reopen guards, the frozen release fixture, whole-store byte snapshots and schema-source assertions
- Acceptance matrix and downstream fixture/legacy-suite impact: seven criteria above; persistence container, release migration, identity feasibility and fresh-setting defaults are explicit
- Focused correction budget: three persistence-surface corrections or 25 minutes; stop immediately if fixture evidence contradicts the assumed historical contract
- Expected expensive commands: focused Xcode unit tests, `make analyze`, `make test-unit`, `make build`, `make lint`
- Maximum rescue tier: Terra, then read-only Sol diagnosis

### Definition of Ready

- [x] New-install, release-baseline migration and existing saved-choice behavior
      are distinguished explicitly.
- [x] Historical schema identity and independently generated fixtures are named.
- [x] Success, reopen and failure behavior are observable without destructive
      recovery.
- [x] Acceptance criteria map to deterministic artifacts and impacted suites.
- [x] No unresolved product behavior is bundled into implementation.

---

## ISI-102 — Reconcile suppressions once and keep clock movement disposable

**Priority:** P2 performance and persistence integrity  
**Status:** Ready  
**Estimate:** 3 points  
**Depends on:** ISI-101 accepted; OW-412 suppression contract

### User outcome and why now

As a person with a long local history and hidden inferred fasts, I want launch
and caloric-event changes to remain responsive without rewriting local records
merely because time advanced.

Reconciliation currently repeats the complete inferred projection for every
suppression. At launch it also treats the moving end of every unpunctuated
in-progress candidate as durable metadata, causing a save and `updatedAt`
advance on otherwise unchanged launches.

### Authoritative contract

- OW-412 preserves one user-authored suppression choice per source reference;
  its current candidate metadata may be recomputed for presentation.
- BR-24 and BR-49 make `AppClock.now`-driven inferred intervals disposable
  presentation. Event, source, goal and classification mutations remain the
  durable reconciliation triggers.
- Launch must clean malformed or structurally stale suppression rows before
  History consumes them, but wall-clock movement alone is not a mutation.

### In scope

- Project the complete authoritative caloric boundary stream once per
  reconciliation operation and index candidates by
  `sourceBoundaryReference` before scanning suppression records.
- Introduce a pure batch reconciliation input/result (or an equivalently
  testable boundary) so one projection result is reused for every record. Inject
  a counting projector seam at this boundary for deterministic call-count
  verification; do not infer call count from elapsed time.
- Preserve canonical equal-timestamp food/drink identity, eight-hour
  eligibility, goal-plus-12-hour cap, recorded-fast overlap behavior, disabled-
  setting retention and all existing mutation semantics.
- Separate structural/durable differences from clock-only presentation
  differences. Launch may remove malformed/missing/non-qualifying rows and may
  persist boundary-, goal- or source-derived metadata changes, but it must not
  write a new `projectedEndDate` or `updatedAt` when the only change is a later
  `now` for the same unpunctuated in-progress candidate.
- Continue recomputing the current end date in History presentation so avoiding
  a launch write never makes the visible interval stale.
- Make unchanged reconciliation idempotent: no context changes, save call,
  diagnostic failure event or timestamp update.
- Route `UFastApp` bootstrap through an extracted, testable launch
  reconciliation boundary and verify with a save spy that the app selects the
  structural, clock-idempotent behavior rather than authoritative-mutation
  behavior.
- Keep caloric-event, goal, classification and recorded-fast mutation paths
  atomic with their existing rollback snapshots and post-commit invalidation.

### Out of scope

- Persisting a timer, scheduling background work, refreshing from a network, or
  changing inferred-fast eligibility and cap rules.
- Removing suppression metadata fields, adding a schema version, changing the
  suppression's source identity, or converting a suppression into a fast.
- A broad rewrite of `InferredFastProjector`; optimize its internal scan only
  if focused evidence shows the one-projection batch still misses an existing
  bounded performance contract.
- Wall-clock benchmark thresholds that are unstable across CI machines.

### Acceptance criteria

1. Given multiple valid suppressions and a long boundary stream, one call to
   reconciliation constructs one complete inferred projection and reuses its
   source-reference index for every suppression; results match independent
   single-source decisions.
2. Given an unchanged hidden unpunctuated candidate and a later launch clock
   that is still before the cap, exactly at the cap, or after the cap, launch
   reconciliation returns `changedCount == 0`, does not invoke its save action,
   and preserves stored `projectedEndDate` and `updatedAt` in every case.
3. Given the same stored suppression, History presentation at the later clock
   shows the later disposable end (up to its cap) without first saving the
   suppression.
4. Given a missing source, a new pre-eligibility boundary, invalid stored
   suppression, or another structural loss of qualification, launch removes the
   stale row and saves exactly once.
5. Given a new qualifying punctuating boundary or a committed goal/source
   change, authoritative-mutation reconciliation updates the durable candidate
   metadata once in the same transaction; cancellation or simulated save
   failure restores both the source mutation and suppression snapshot.
6. Disabled-setting retention, recorded-fast overlap retention, food/caloric-
   hydration parity, equal-time canonicalization, cap behavior and repeated
   reconciliation remain deterministic and do not duplicate rows.
7. Given app bootstrap with an otherwise unchanged valid suppression, the
   launch coordinator used by `UFastApp` selects structural reconciliation and
   produces zero saves for clock-only before-cap, exact-cap and after-cap input;
   a structurally stale row still produces one save through that same wiring.

### Architecture, data, privacy and accessibility boundaries

- Keep projection/index construction in framework-independent values where
  practical; SwiftData fetch, mutation and save remain in the store adapter.
- Do not add UUIDs, exact event timestamps or food/drink descriptions to
  diagnostics or performance logs.
- There is no new UI control or copy. Existing History accessibility semantics
  and `history.inferred.hidden.<kind>.<sourceUUID>` selectors remain unchanged.
- Batch processing must not weaken transaction recovery: a failed save restores
  the exact pre-reconciliation records and leaves `ModelContext.hasChanges`
  false.

### Focused verification

- Extend `InferredFastSuppressionTests` with a deterministic multi-suppression,
  long-boundary fixture and an injected counting projector that proves exactly
  one projection per reconciliation without timing benchmarks.
- Add a launch-style save spy proving a later `now` alone yields zero changes,
  zero saves and identical stored timestamps before, at and after the candidate
  cap, alongside structural-removal and durable-boundary-update cases.
- Add a bootstrap-level test around the extracted launch coordinator invoked by
  `UFastApp`, with the same save spy, so store-level mode tests cannot pass while
  app launch calls the wrong reconciliation path.
- Extend History presentation tests to prove the current inferred end advances
  from the injected clock even when persisted suppression metadata does not.
- Preserve mutation rollback tests for food and hydration and the existing
  disabled/goal/overlap matrix.
- Run focused suppression, History and mutation suites, then `make analyze`,
  `make test-unit`, `make build` and `make lint`. No changed UI journey is
  required unless implementation changes a visible surface or selector.

### Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | one projection feeds all source decisions | core/store batch test | many suppressions, missing indexed source | focused unit log and call-count assertion |
| AC2 | later launch clock causes no durable mutation | store test with save spy | before cap, exact cap and after cap | record snapshot and zero-save assertion |
| AC3 | presentation still advances disposable end | History presentation test with fixed clocks | exact cap transition | focused History test log |
| AC4 | structural staleness is removed once | store launch-mode tests | malformed, deleted source, pre-eligibility punctuation | changed/save counts and post-state snapshot |
| AC5 | mutation updates atomically and rolls back on failure | food/hydration/settings command tests | cancel and simulated save failure | before/after snapshots and focused log |
| AC6 | existing identity, overlap and setting invariants remain | `InferredFastSuppressionTests` matrix | equal timestamps, detection off, recorded overlap | focused regression log |
| AC7 | `UFastApp` uses structural clock-idempotent launch reconciliation | extracted bootstrap coordinator test with save spy | before cap, exact cap, after cap and structural stale row | zero/one-save assertions and bootstrap test log |

### Downstream fixture and legacy-suite impact

- Preserve `InferredFastProjectionTests`, `AutomaticFastProjectionTests`,
  `InferredFastSuppressionTests`, `ApplicationCommandsTests`,
  `CaloricEventCommandsTests`, `AffectedHistoryTests`,
  `HistoryDataProviderTests`, `HistoryMotionStreamingTests` and
  `HistoryPresentationModelTests`.
- Reuse deterministic food and caloric-hydration source UUIDs and fixed clocks;
  do not change `--seed-inferred-fast` or suppressed-inferred UI fixture meaning.
- Review launch/bootstrap tests around `UFastApp` and persistence diagnostics.
  No accessibility identifier, localization entry, widget fixture or Live
  Activity expectation should change.

### Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: fixed clocks, long ordered boundary fixtures, multiple source-bound suppressions, an injected counting projector, before/exact/after-cap clocks, store and bootstrap save spies, record snapshots and existing rollback injection
- Acceptance matrix and downstream fixture/legacy-suite impact: seven criteria above; core projection, suppression store, mutation commands, bootstrap and History presentation suites are explicit
- Focused correction budget: three reconciliation-surface corrections or 25 minutes; one unchanged-source rerun is allowed only as an explicit flake check
- Expected expensive commands: focused Xcode unit tests, `make analyze`, `make test-unit`, `make build`, `make lint`
- Maximum rescue tier: Terra, then read-only Sol diagnosis

### Definition of Ready

- [x] Clock-only and structural changes have distinct durable behavior.
- [x] One-projection observability does not rely on wall-clock performance.
- [x] Launch, mutation, rollback, presentation freshness and compatibility are
      independently testable.
- [x] Existing fixtures and legacy suites are inventoried.
- [x] No schema or user-visible behavior change is hidden in this story.

## Sprint integration and human check

After both stories are independently accepted and source is frozen, run
`make analyze`, `make test-unit`, `make build` and `make lint` once against the
combined source. Run the full four-worker UI suite only if either story changes
UI source/tests or the Sol integration gate requests it; otherwise preserve the
most recent source-compatible UI evidence and record why no UI surface changed.

If a configured iPhone is connected, deploy the Sol-accepted source with
`make deploy-iphone`. Confirm the app opens the existing local store, the saved
inferred-detection choice is unchanged, hidden candidates remain hidden, and a
relaunch without event/goal changes causes no visible regression. Deployment is
evidence; the human check remains a separate progression gate when requested by
the controlling sprint.

## Sprint Definition of Ready

- [x] P1 schema compatibility is isolated from P2 reconciliation behavior.
- [x] Every acceptance criterion has a deterministic verification surface and
      artifact.
- [x] Migration fixtures are independently declared and non-circular.
- [x] Accessibility, privacy, compatibility and downstream suite impacts are
      explicit.
- [x] Each story has a bounded correction budget and rescue tier.
- [x] A read-only Sol readiness gate returns **READY**.

## Sol readiness gate

**Verdict:** READY  
**Reviewed:** 28 August 2026  
**Reasoning effort:** high  
**Recommended initial implementer:** Luna xhigh  
**Split required:** no  
**Product decision status:** Complete and coherent; release-baseline stores without the preference become enabled, while persisted V3-through-V7 choices remain authoritative.  
**Scope and acceptance status:** Both stories are bounded, correctly ordered and implementation-ready.  
**Test observability and fixture-impact status:** Complete; independent schema fixtures, V7 guards, bundle snapshots, counting projection, cap-boundary save spies and bootstrap wiring provide deterministic evidence.  
**Architecture/data/accessibility/privacy status:** Local-only entity identity and transaction recovery remain protected; accessibility and privacy contracts are unchanged.  
**Execution profile and testability status:** Complete and bounded.  
**Missing evidence or contradictions:** None.  
**Required changes:** None.
