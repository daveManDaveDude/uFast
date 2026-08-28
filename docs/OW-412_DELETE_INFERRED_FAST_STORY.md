# OW-412 — Delete and re-enable inferred fast visibility

**Slice:** 3.12 — Inferred fast detection refinement  
**Priority:** P0  
**Status:** Ready — Sol readiness gate passed 28 August 2026  
**Story type:** Product behavior, local persistence and History interaction

## User outcome

As a person reviewing an inferred fast, I want to delete it when it does not
represent a fasting period I want to keep, so that my History shows only the
inferred fasts I choose to retain while my food and drink records remain intact.

If I later select the calendar day containing a deleted inferred fast, I want a
clear way to re-enable it, so that I can restore the derived interval without
re-entering any events.

## Why now

OW-410 delivered inferred-fast presentation and explicit Save fast/Start fast
conversion, but an unwanted inferred interval can currently only be left in the
projection or hidden globally by turning detection off. A per-candidate choice
completes user control without turning a derived interval into user-recorded
fasting history.

## Context and authoritative contract

The implementation must preserve these existing contracts:

- `PRODUCT.md` — calm, local-first, private, record-based language; user-recorded
  fasts, inferred fasts and caloric source events remain distinguishable.
- `docs/MVP_SCOPE.md` — inferred fasting history is user-controlled and local.
- `DOMAIN_RULES.md` — BR-06, BR-07, BR-12, BR-15, BR-17, BR-22 through BR-26,
  BR-44 through BR-52.
- `DECISIONS.md` — D-033 inferred detection, D-034 candidate lifecycle and
  conversion boundary, D-035 shared caloric-boundary integrity, and D-036
  local source-bound verification.
- `docs/OW-410_INFERRED_FAST_DETECTION_STORY.md` — delivered source-bound
  projection, Save fast/Start fast actions, exact visible-window behavior and
  no inferred `FastRecord` rule.
- `docs/OW-411_CALORIC_EVENT_FAST_BOUNDARY_STORY.md` — food and explicitly
  caloric hydration are one boundary stream and event mutations refresh inferred
  presentation after a successful local transaction.

This story amends the inferred-fast lifecycle contract with one additional
user-authored state: a suppression record saying not to show one source-bound
inferred candidate. It does not persist the inferred interval as a fast, and it
does not weaken the existing source, punctuation, cap, overlap or conversion
rules. The implementation must record the corresponding accepted decision and
domain-rule amendment in `DECISIONS.md`/`DOMAIN_RULES.md` as part of delivery;
the user request is the product authority for that decision.

## In scope

- A Delete inferred fast action for both historical and in-progress inferred
  candidates in the existing inferred-fast detail/conversion surface.
- A calm confirmation that makes clear the action hides the derived interval,
  leaves its source food/drink event unchanged and does not create or delete a
  recorded fast.
- One local suppression record per `CaloricBoundaryReference` (boundary kind and
  source UUID), carrying the last/current projected interval and punctuation
  metadata needed for deterministic reconciliation and selected-day recovery.
- Atomic creation/update/deletion of suppression records with the relevant
  inferred candidate or caloric-event mutation.
- Reconciliation when a food or explicitly caloric hydration event is added,
  edited, deleted or reclassified, including the requested add-inside-period
  behavior.
- A selected-day History recovery row/action for a suppressed candidate and a
  Re-enable inferred fast action that removes only that suppression record.
- Settled and moving History projection support using the same exact visible
  interval and stable source identity.
- Additive local SwiftData migration, Delete All Data coverage and relaunch
  persistence for suppression records.
- Localized, accessible copy and stable UI identifiers for delete, confirmation,
  hidden-state recovery, re-enable, cancel and failure paths.

## Out of scope

- Persisting an inferred candidate as a `FastRecord`, active fast, completed fast,
  reconstructed fast or unknown period.
- Deleting or editing the source food, hydration event or any recorded fast.
- A global inferred-fast setting change; the existing setting remains the
  separate way to disable or re-enable all inferred presentation.
- Automatic deletion of source events, automatic fast conversion, notifications,
  background timers, network/cloud sync, HealthKit, AI, coaching, analytics or
  health claims.
- A new History date-picker decoration or a second calendar/navigation model.
  Recovery belongs to the existing settled selected-day History details surface.
- Re-enabling an inferred candidate that no longer exists under authoritative
  source/boundary rules; stale suppression state is cleaned up instead.

## Product decisions for this story

1. **Delete means hide this candidate.** The primary destructive action is
   labelled **Delete inferred fast**. Its confirmation explains that uFast will
   hide this inferred fast from History while keeping the source event and all
   recorded fasts. No `FastRecord` count or system-surface projection changes.
2. **Identity is the source boundary.** A suppression is keyed by the source
   `CaloricBoundaryReference`, including `food` versus `hydration` and the UUID.
   There is never more than one suppression row for one source reference.
3. **The suppressed candidate remains derived.** When the same source still
   produces a qualifying candidate, projection computes its current start/end,
   state, goal and next boundary from authoritative events and `AppClock`. The
   suppression row is updated with that projection metadata when an event or
   goal mutation changes it; foreground clock movement does not require a
   background write.
4. **An inserted boundary reconciles the suppression.** For a suppressed source,
   a new caloric food or explicitly caloric hydration event before the source's
   eight-hour eligibility instant makes the candidate non-qualifying; remove the
   suppression row. An event at or after eligibility and before the candidate's
   current cap keeps the candidate qualifying; retain the suppression and update
   its projected end and next-boundary metadata. An event after the cap does not
   change that candidate. Non-caloric hydration has no effect.
5. **All authoritative mutations use the same rule.** Source edits, deletions,
   hydration reclassification, goal changes and recorded-fast changes reproject
   suppressed candidates. Remove a suppression when its source is gone/non-
   caloric or the candidate is structurally no longer qualifying; otherwise
   update it. A recorded fast is a temporary presentation exclusion under BR-52:
   it does not remove the user's suppression, and no recovery row is shown while
   the recorded overlap prevents the candidate from being restorable. When the
   overlap ends, the prior suppression remains effective. Turning detection off
   also preserves suppressions; turning it on again does not forget them.
6. **Recovery is selected-day based.** When a settled History day’s exact visible
   interval intersects a still-valid suppressed candidate, the existing History
   details/list surface shows a non-timeline recovery row labelled **Hidden
   inferred fast** with **Re-enable inferred fast**. The hidden candidate has no
   timeline bar or ordinary Save fast/Start fast action. Re-enable removes the
   suppression row and refreshes the same derived candidate, offering Save fast
   or Start fast according to its current lifecycle state.
7. **Re-enable is safe and direct.** Re-enable is a non-destructive action and
   need not add a second confirmation. If the candidate became stale before the
   action commits, remove no unrelated data; refresh and report that the hidden
   inferred fast is no longer available.

## Acceptance criteria

1. **Delete either lifecycle state.** Given a visible historical or in-progress
   inferred candidate, when the user opens its existing detail surface, then
   **Delete inferred fast** is available alongside the existing Save fast or
   Start fast action. After confirmation, the candidate disappears from settled
   and moving History, exactly one suppression record exists for its source
   reference, the source event remains unchanged, and no `FastRecord` or
   Today/WidgetKit/ActivityKit state is created, deleted or changed.
2. **Cancel and failure are non-mutating.** Given a visible candidate, when the
   user cancels deletion or the suppression save fails, then the candidate,
   source event, recorded-fast count and suppression-record count remain as
   before; the confirmation/detail surface remains usable and the localized
   failure is accessible.
3. **Stale deletion is safe.** Given a delete confirmation whose candidate has
   become stale because its source, goal, boundary stream, setting or overlap
   state changed, when the user confirms, then no suppression is written or
   unrelated record changed; History refreshes from authoritative state and
   explains that the inferred fast is no longer available when feedback is
   needed.
4. **Selected-day recovery is visible and scoped.** Given a valid suppression
   whose current projected interval intersects the exact settled visible
   interval for the selected calendar day, when that day is selected or
   refreshed, then History shows one accessible **Hidden inferred fast** recovery
   row in its existing details/list area. It does not draw the deleted interval
   on the timeline, does not show the ordinary empty state, and does not expose
   Save fast or Start fast until re-enabled.
5. **Re-enable restores the current candidate.** Given a visible recovery row,
   when the user chooses **Re-enable inferred fast**, then the matching
   suppression row is deleted, no source or recorded-fast row is changed, and
   History refreshes to show the current inferred candidate with the existing
   lifecycle label and Save fast/Start fast action. The result survives relaunch.
6. **Re-enable stale and failure paths are safe.** Given a visible recovery row,
   when its source/boundary state becomes stale before re-enable commits or the
   suppression delete fails, then no unrelated record changes, the suppression
   remains when the candidate is still valid, History refreshes from authoritative
   state, and an accessible `history.inferred.reenable-unavailable` or
   `history.inferred.reenable-error` state explains the result.
7. **Recovery is not offered outside the candidate interval.** Given a valid
   suppression, when the selected day’s exact visible interval does not
   intersect its current projected interval, then no recovery row or re-enable
   action appears on that day. Selecting another intersecting day reveals the
   same source-bound recovery row once, without duplicate rows.
8. **Caloric event insertion before eligibility removes suppression.** Given a
   deleted candidate sourced at `T`, when a food or explicitly caloric hydration
   event is committed after `T` but before `T + 8h`, then the source candidate no
   longer qualifies, its suppression row is removed in the same successful local
   mutation, and no hidden recovery row appears. If the mutation is cancelled or
   fails, both the event and suppression state remain unchanged.
9. **Caloric event insertion after eligibility updates suppression.** Given a
   deleted candidate sourced at `T`, when a food or explicitly caloric hydration
   event is committed at or after `T + 8h` and before the source-plus-goal-plus-
   12-hour cap, then the candidate remains hidden, its suppression metadata is
   updated to the new projected end and next boundary, and the recovery row
   reflects the updated interval. An event after the cap leaves the candidate
   and suppression unchanged.
10. **Other boundary mutations reconcile deterministically.** Given a suppressed
   candidate, when its source or later boundary is edited, deleted or hydration
   classification changes, or the current goal changes, then a qualifying
   candidate keeps one updated suppression row and a non-qualifying candidate
   removes that row. A recorded-fast overlap retains the suppression but hides
   recovery until the overlap ends. Food remains caloric; non-caloric hydration
   does not change the candidate. No mutation silently lengthens a persisted
   recorded fast.
11. **Food and drink identity follow canonical ordering.** Given food and
    caloric hydration sources at distinct timestamps, deleting one suppresses
    only its source-bound candidate and re-enabling one restores only that
    candidate. Given equal timestamps, the existing kind/UUID ordering still
    canonicalizes the timestamp to one candidate; deleting or re-enabling it uses
    that canonical source reference and never creates a second candidate.
12. **Persistence and migration are local and safe.** Given a release-baseline
    or current store, when it opens after this story’s schema change, then
    existing settings, events, recorded/legacy fasts and their meaning survive,
    no suppression rows are fabricated, and a created suppression survives
    relaunch. Delete All Data removes suppression rows with every other
    app-created record, and simulated commit/migration failures leave the prior
    store unchanged.
13. **Projection and conversion boundaries remain intact.** Given a suppressed
    or restored candidate, then inferred intervals remain absent/present only
    through the derived History projection, Save fast and Start fast retain OW-
    410/OW-411 revalidation and overlap behavior, and only a successfully
    converted active recorded fast can affect Today, WidgetKit or ActivityKit.
14. **Accessibility remains complete.** Given VoiceOver, accessibility Dynamic
    Type and RTL/pseudolocalized text, then delete, cancel, confirmation, hidden
    recovery, re-enable and stale/error states remain understandable and
    reachable without color or gesture, with the stable identifiers below.
15. **Local-only failure behavior remains safe.** Given offline use or a failed
    History refresh, then the last complete projection is retained, suppression
    writes remain local and transactional, and no network, permission or
    background-delivery dependency is introduced.

## Architecture and data boundaries

- Add a framework-independent suppression value/decision layer that accepts a
  `CaloricBoundaryReference`, projected interval metadata, current authoritative
  boundary stream, recorded-fast exclusions, current goal, setting and
  `AppClock` value. Keep this logic independent of SwiftUI, SwiftData,
  ActivityKit and WidgetKit.
- Add an additive SwiftData model for user-authored inferred suppression, with
  source kind/UUID, projected start/end, next-boundary kind/UUID/date where
  applicable, goal-hours snapshot and created/updated timestamps. Enforce one
  logical row per source reference through the repository/application boundary;
  do not add inferred fields to `FastRecord` or persist a derived inferred row.
- Extend settled and motion History value snapshots/providers with suppression
  context. The same exact settled visible interval and source-bound projection
  must drive candidate filtering and the selected-day recovery row. Moving
  History must not mutate or duplicate suppression state merely because the
  viewport moves.
- Route delete, re-enable and event-driven suppression reconciliation through
  the application/persistence transaction boundary. A failed commit rolls back
  the suppression and any paired event mutation; History invalidation occurs
  only after a successful local commit.
- Reuse the existing caloric-boundary extractor, source reference ordering,
  `InferredFastProjector`, `ActiveFastAuthority`, `PersistenceTransaction` and
  post-commit History invalidation. Do not duplicate food-only logic or make
  projection-time data writes on a timer.
- Add the model to a new schema version and migration plan only as an additive
  local migration. Preserve the release-baseline migration fixtures and all
  existing legacy compatibility rows. Include suppression records in
  `AppDataDeletionService`.
- No new diagnostic payload may include food/drink text, full timestamps or
  UUIDs. Ordinary hide/re-enable success remains silent in the existing local
  diagnostic vocabulary.

## Dependencies and downstream fixture/legacy-suite impact

### Dependencies

- OW-410 delivered inferred projection/conversion and `InferredFastUITests`.
- OW-411 delivered the shared food/caloric-hydration boundary and event
  reconciliation paths; this story must preserve its focused acceptance.
- Existing History settled/motion providers, selected-day details/list,
  `AppClock`, local SwiftData migration plan and Delete All Data transaction.
- Existing localization/pseudolocalization and accessibility test conventions.

### Fixtures and legacy suites

- Extend `UITestSeedFixtures.seedInferredFast` or add a dedicated deterministic
  suppressed-inferred seed with stable food and caloric-drink source UUIDs,
  fixed `AppClock` dates and an explicit suppression row. Add reset/launch
  coverage without changing the meaning of `--seed-inferred-fast` for existing
  OW-410 journeys.
- Preserve `UFastCoreTests/InferredFastProjectionTests.swift` and
  `UFastCoreTests/AutomaticFastProjectionTests.swift`: no suppression record
  may become a core inferred or automatic interval, and existing unsuppressed
  projection tests remain valid.
- Extend `uFastTests/ApplicationCommandsTests.swift`,
  `CaloricEventCommandsTests.swift` and `AffectedHistoryTests.swift` for delete,
  re-enable, stale revalidation, event insertion/update/remove and rollback.
  Existing OW-411 food/drink impact tests must continue to pass.
- Extend `HistoryInferredClassificationTests.swift`,
  `HistoryDataProviderTests.swift`, `HistoryMotionStreamingTests.swift`,
  `HistoryMotionAuthorityTests.swift` and `HistoryPresentationModelTests.swift`
  for settled/motion suppression filtering, selected-day intersection and
  duplicate prevention. Existing recorded-fast precedence and legacy rows remain
  unchanged.
- Extend `PersistenceContainerTests.swift`, `Slice3PersistenceMigrationTests.swift`
  and Delete All Data tests for the new additive schema, release-store reopen,
  no fabricated suppressions, rollback and complete deletion. Existing “every
  production model” and schema-count assertions must be deliberately updated.
- Extend `uFastUITests/InferredFastUITests.swift` and the relevant History
  navigation/accessibility journeys for historical/in-progress delete, cancel,
  failure, relaunch, selected-day recovery, food/caloric-drink reconciliation,
  Dynamic Type, RTL and VoiceOver. Existing selectors
  `history.fast.<UUID>`, `history.inferred.save`,
  `history.inferred.start`, `history.inferred.cancel`, `history.list`,
  `history.event-info-panel`, `history.day-carousel` and `history.choose-date`
  remain stable.

## Design, copy and accessibility contract

Use the existing inferred conversion sheet and calm hierarchy. The critical
copy is:

- Action: **Delete inferred fast**
- Confirmation title: **Delete inferred fast?**
- Confirmation message: **This hides the inferred fast from History. Your food
  or drink record will stay.**
- Confirmation action: **Delete inferred fast**
- Recovery row: **Hidden inferred fast**
- Recovery action: **Re-enable inferred fast**
- Recovery hint: **Shows this inferred fast in History again.**

Copy may be localized, but its meaning must remain explicit: this is visibility
of a derived record, not deletion of the source event. Keep the recovery row
out of the timeline bar collection and make its semantic label include the
source, start/end interval and available action. Assign stable identifiers:

- `history.inferred.delete`
- `history.inferred.delete.confirmation`
- `history.inferred.delete.confirm`
- `history.inferred.delete.cancel`
- `history.inferred.delete-error`
- `history.inferred.hidden.<kind>.<sourceUUID>`
- `history.inferred.reenable.<kind>.<sourceUUID>`
- `history.inferred.reenable-unavailable`
- `history.inferred.reenable-error`

The UI-test launch configuration must expose deterministic
`--simulate-inferred-fast-suppression-save-failure` and
`--simulate-inferred-fast-suppression-reenable-stale` scenarios. The first
forces the local suppression write/delete to fail; the second makes the recovery
source stale before the command is evaluated. Application tests may use the
same seams without relying on timing or exploratory gestures.

## Verification

### Focused automated verification

- Pure tests for source identity, one-row suppression, delete/re-enable state,
  exact eight-hour insertion split, cap boundary, food/drink parity, goal
  changes, recorded precedence, DST/absolute instants and no mutation for
  non-caloric hydration.
- Application/persistence tests for candidate revalidation, atomic paired event
  mutation, stale/cancel/failure rollback, relaunch, Delete All Data and
  post-commit History invalidation without system-surface effects.
- Settled/motion History tests for exact visible-window intersection, hidden-row
  observability, selected-day changes, source-kind identity and no duplicate
  recovery rows.
- Focused UI tests using reset/seed fixtures, fixed time, bounded asynchronous
  waits and the stable identifiers above. Include historical and in-progress
  delete, cancel/failure, relaunch re-enable and the before/after-eligibility
  food/caloric-drink journeys.
- Run `make analyze` whenever source changes are made, plus the focused unit,
  build, lint/format and changed UI checks required by the repository workflow.

### Integration and human verification

- After all story sources are frozen, run the repository’s one four-worker
  source-frozen `make test-ui` integration suite and verify its `.xcresult`.
  Do not run the full UI suite during story implementation or overlap UI runs.
- On a connected iPhone, deploy the Sol-accepted source with
  `make deploy-iphone` and manually verify: hide a historical and current
  inferred fast; add food and caloric drink before/after eligibility; select
  the affected day and restore the hidden candidate; relaunch; confirm source
  events and recorded fasts are untouched; repeat with VoiceOver, large text,
  RTL and offline mode.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
|----|-------------------|-----------------|--------------------|----------|
| AC1 | Delete hides one source-bound candidate and writes one suppression without changing source/fast/system state | `ApplicationCommandsTests`; `InferredFastUITests` | Historical and in-progress candidates; food and caloric hydration | Focused unit/application log and UI `.xcresult` |
| AC2 | Cancel/failure leaves all prior snapshots and keeps the surface usable | `PersistenceTransactionTests`; `ApplicationCommandsTests`; UI failure journey | Simulated save failure and cancel | Focused test result and UI failure artifact |
| AC3 | Stale confirmation writes nothing and refreshes authoritative History | `ApplicationCommandsTests`; History refresh tests | Source edit/delete, goal change, overlap | Focused application/History result |
| AC4 | Selected day shows one hidden recovery row, no bar/empty state/convert action | `HistoryDataProviderTests`; `HistoryPresentationModelTests`; UI | Hidden-only day and Dynamic Type | Focused unit result and UI `.xcresult` |
| AC5 | Re-enable deletes matching suppression and restores current candidate across relaunch | Application/persistence tests; `InferredFastUITests` | Candidate changes lifecycle while hidden | Relaunch UI `.xcresult` and persistence test result |
| AC6 | Re-enable stale/failure leaves safe state and exposes stable feedback | Application tests; `InferredFastUITests` with explicit launch scenarios | Stale source and simulated suppression save/delete failure | Focused result and UI `.xcresult` |
| AC7 | Recovery appears only for intersecting exact visible interval and never duplicates | History settled/motion tests; History navigation UI | Non-intersecting day, cross-midnight candidate, repeated day selection | History test result and UI `.xcresult` |
| AC8 | Pre-eligibility caloric event removes suppression atomically | `CaloricEventCommandsTests`; `AffectedHistoryTests`; UI | Food vs caloric hydration; cancel/failure | Focused transaction/application and UI result |
| AC9 | Post-eligibility in-cap event updates hidden interval metadata; after-cap event is ignored | Core projector and persistence tests; UI | Exactly eligibility, exactly cap, DST | Pure/application result and UI `.xcresult` |
| AC10 | Source/boundary/goal mutations update or remove suppression while overlap/global-off retention is preserved | Core, application and History tests | Non-caloric hydration, source disappearance, recorded overlap, setting off/on | Focused unit/application/History logs |
| AC11 | Distinct source identity is isolated and equal-time canonicalization is preserved | Core and History tests; UI | Food/drink at distinct times; equal timestamps; repeated reconciliation | Focused test result |
| AC12 | Additive migration/relaunch/Delete All Data preserve or remove only intended local records | `PersistenceContainerTests`; `Slice3PersistenceMigrationTests` | Release store, empty store, migration/save failure | Migration test result and store snapshot |
| AC13 | Suppression never creates a fast or system projection; restored conversion keeps existing contracts | `ApplicationCommandsTests`; OW-410/OW-411 focused suites | Save-only cap, active Start fast and overlap conflict | Focused application/core result |
| AC14 | All delete/recovery controls and errors remain accessible across content variants | UI accessibility tests; `InferredFastUITests` | VoiceOver, AXXXL, RTL, pseudolocalization, stale/error feedback | UI `.xcresult` and analysis log |
| AC15 | Offline and failed refresh retain local authoritative state without new dependencies | History projection tests; persistence failure tests; `make analyze` | Offline, failed History refresh, failed local commit | Focused result and analysis log |

## Execution profile

- **Uncertainty:** high
- **Initial implementer:** Luna xhigh
- **Deterministic reproduction and observability:** fixed `AppClock.now`, reset
  local store, stable food/hydration source UUIDs, a seeded hidden suppression,
  pure projection/reconciliation outputs, before/after SwiftData snapshots and
  counts, transaction-failure injection, exact selected-day windows, settled/
  motion snapshots and stable accessibility identifiers. No network or denied
  permission state is required.
- **Acceptance matrix and downstream fixture/legacy-suite impact:** fifteen
  criteria above; core inference, event-boundary, persistence/migration, settled
  and moving History, Delete All Data, OW-410/OW-411 conversion and UI
  accessibility suites are explicit dependencies.
- **Focused correction budget:** three story-surface corrections or 25 minutes;
  stop sooner for the same failure twice without new evidence or for scope
  expansion beyond the recorded persistence/History boundary.
- **Expected expensive commands:** project generation, focused core/unit tests,
  focused UI tests, `make analyze`, build/lint/format, then one source-frozen
  four-worker UI suite at integration.
- **Maximum rescue tier:** Terra rescue, then read-only Sol diagnosis.

## Definition of Ready

- [x] Delete is defined as per-candidate visibility suppression, not fast CRUD.
- [x] Source identity, event-reconciliation and selected-day recovery rules are
      explicit for food and caloric hydration.
- [x] Acceptance criteria cover successful, cancel, stale, failed, migration,
      relaunch, delete-all, time, overlap and accessibility behavior.
- [x] The additive persistence boundary and no-`FastRecord` rule are explicit.
- [x] Existing fixtures, OW-410/OW-411 suites and History motion/settled paths
      have a deliberate impact inventory.
- [x] Every criterion maps to an observable result, test surface, edge path and
      artifact.
- [x] Static analysis, focused tests, source-frozen integration and human-device
      checks are defined.
- [x] A read-only Sol readiness gate returns **READY**.

## Sol readiness gate

**Verdict:** READY  
**Reviewed:** 28 August 2026  
**Reasoning effort:** medium  
**Recommended initial implementer:** Luna xhigh  
**Split required:** no  
**Missing evidence or contradictions:** None material.  
**Required changes:** None.
