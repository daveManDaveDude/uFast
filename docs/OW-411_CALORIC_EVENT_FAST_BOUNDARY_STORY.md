# OW-411 — Make every caloric event end the fast it enters

**Slice:** 3.13 — Caloric-boundary integrity  
**Priority:** P0 data and History correctness  
**Status:** Ready — Sol readiness gate passed 17 August 2026  
**Story type:** Product behavior and data reconciliation

## User outcome

As a person correcting food or drink history, I want every caloric event to be
treated as a real fasting boundary, so that an active, completed or inferred
fast never continues through an event that breaks it and my History remains
truthful after the change.

For a new or edited event, uFast explains the affected fast before committing
the change. Existing local data is reconciled automatically so persisted fast
records satisfy the same invariant on the first successful launch of the new
version.

## Why now

The current active-fast journey already asks before atomically saving a caloric
food or drink and ending the active fast. Historical entry does not apply the
same protection to a completed recorded fast. Inferred-fast projection also
uses caloric food only, even though the rest of the product defines a caloric
custom drink as a fasting boundary. These differences can leave History
showing a fast through a known caloric event.

## Context and authoritative contract amendments

The implementation must retain the calm, local-only and non-medical boundaries
in `PRODUCT.md` and `MVP_SCOPE.md`.

### Accepted OW-411 product decision

**Accepted:** 17 August 2026, from the user's explicit enhancement request.  
**Supersedes:** the food-only inferred-boundary portions of D-033/D-034 and
BR-22 through BR-24, BR-46 and BR-50 through BR-51; the no-silent-rewrite
portion of BR-21 only for the one-time reconciliation below; and D-013/BR-08
only where they omit completed persisted fasts.

The accepted decision is:

- A caloric boundary is either a food event, which is always caloric, or a
  hydration event explicitly classified as caloric.
- A persisted fast is valid only when it does not extend beyond the earliest
  caloric boundary strictly after its start. For a completed fast, only a
  boundary before its current end shortens it. For an active fast, the first
  later boundary completes it.
- The invariant applies to all persisted `FastRecord` origins, including the
  legacy reconstructed compatibility rows still stored locally. When a
  reconstructed row is shortened, its end-boundary provenance must identify
  the caloric event that now ends it; it must not retain a false boundary.
- A caloric event at the exact fast start is not a positive-duration end. New
  entry against an active fast at that instant keeps the existing
  correct-or-cancel behavior. During reconciliation it is treated as the start
  boundary and does not create or delete a zero-duration fast. A caloric event
  at a completed fast's end is outside the half-open interval `[start, end)` and
  causes no change.
- The existing active-fast confirmation remains. A new or edited historical
  caloric event that would shorten a completed persisted fast also requires a
  confirmation before either change is committed.
- Inferred fasts use the same ordered set of caloric food and caloric hydration
  boundaries. They remain derived, opt-in and unpersisted. A new or edited
  event that would shorten or remove a currently presented inferred interval
  requires a calm confirmation before the event commits; after commit, History
  is recomputed rather than a fast row being written.
- Confirmed event save and all affected persisted-fast changes are one atomic
  user intent. Cancel or failure changes neither the event nor any fast.
- Automatic reconciliation of pre-existing data is an explicit exception to
  the former no-silent-rewrite compatibility rule: it deterministically
  shortens persisted fasts to their earliest qualifying caloric boundary so the
  store does not retain intervals that violate this new invariant.
- Removing, moving later or reclassifying the event that previously ended a
  persisted fast never silently lengthens that fast. A later explicit fast edit
  remains available under the completed-fast rules. Inferred intervals, being
  derived, do recompute from the remaining authoritative caloric events.
- A new or corrected active-fast start cannot cross an already saved caloric
  boundary: reject it with the earliest boundary time and require a start after
  that event. A completed-fast create or edit cannot extend beyond the earliest
  saved caloric boundary strictly after its proposed start: reject it with the
  maximum valid end so the person can correct the proposal explicitly.
- If a reconstructed fast's referenced end event is deleted, moved later or
  made non-caloric, keep its existing end, mark it **Needs review** through the
  compatibility path and retain the former boundary reference only as the
  reason for review; presentation must not claim that reference is a current
  caloric boundary. Do not silently extend or convert the row.

Implementation must add a dated D-035 decision (or the next collision-free
identifier) to `DECISIONS.md`, amend BR-06 through BR-08, BR-21 through BR-24,
BR-45 through BR-52 in `DOMAIN_RULES.md`, update the food-only lines in
`MVP_SCOPE.md`, and amend OW-410's superseded wording. BR-03, BR-04, BR-12,
BR-15, BR-17 and BR-26 remain in force.

## In scope

- One framework-independent caloric-boundary representation shared by
  persisted-fast reconciliation and inferred-fast projection.
- Food creation and edit, hydration creation and edit, History entry and
  Today entry, including a non-caloric drink changed to caloric or moved into a
  fast.
- Food/hydration deletion and caloric-to-non-caloric or move-later edits where
  reconstructed review provenance must be invalidated without extending a
  persisted fast.
- Manual and inferred active-fast creation, active-start correction, completed-
  fast creation and completed-fast edit validation against existing caloric
  boundaries.
- Impact detection before save for the one active fast, completed recorded
  fasts, legacy reconstructed fasts and visible inferred intervals.
- Context-specific, accessible confirmation for an active persisted fast, a
  completed persisted fast, a reconstructed compatibility fast and an inferred
  interval.
- One atomic persistence transaction for the event create/update and every
  affected persisted-fast end/provenance change.
- Post-commit History invalidation and the existing active-fast WidgetKit and
  ActivityKit end path when the affected persisted fast was active.
- Inferred projection and conversion revalidation over caloric food and caloric
  hydration boundaries, including stable generic boundary identity.
- Idempotent, deterministic reconciliation of existing local stores before
  normal app use and before active-fast projections are synchronized.
- Focused domain, persistence, migration/bootstrap and UI coverage.
- Updates to `MVP_SCOPE.md`, `DOMAIN_RULES.md`, `DECISIONS.md`, `BACKLOG.md` and
  OW-410 wording that otherwise states hydration cannot source or terminate an
  inferred interval or misstates the delivered source baseline.

## Out of scope

- Inferring calories, changing the user's explicit drink classification, or
  adding nutrition analysis.
- Automatically starting a persisted fast from any event.
- Silently lengthening a persisted fast after an event is deleted, moved later
  or changed to non-caloric.
- Changing a fast's start, its captured goal, or unrelated provenance.
- Persisting inferred intervals, adding cloud/network work, HealthKit, AI,
  coaching, analytics or health claims.
- Reconstructing missing events or inventing a caloric timestamp.
- Deleting a fast merely because an event shares its start timestamp.
- Broad cleanup of unrelated overlap or legacy integrity defects.

## Final user-visible behavior and edge cases

### New and edited events

- If no persisted or presented inferred fast is affected, save through the
  existing journey with no new interruption.
- If a caloric event is strictly after an active fast's start, retain **Save and
  end fast**. The message identifies that the fast ends at the event time.
- If a caloric event is strictly inside a completed persisted fast, explain
  that saving will update History and end that fast at the event time. Offer
  **Save and update fast** and **Cancel**.
- If the affected persisted row is reconstructed, the confirmation may identify
  it as reconstructed history, but the primary action and atomicity are the
  same. Successful save replaces its end-boundary provenance with the event.
- If only an inferred interval is affected, explain that its derived end or
  visibility will update. Offer **Save and update History** and **Cancel**; do
  not imply that an inferred record is being edited or persisted.
- If one event affects more than one persisted compatibility row, one
  confirmation states the number of fasts that will be updated. Normal stores
  should have at most one because overlap remains forbidden, but impact
  handling must be deterministic for pre-existing anomalous data.
- Persisted impact takes confirmation precedence over inferred impact, matching
  recorded-fast presentation precedence. If anomalous data contains an active
  row plus completed/reconstructed rows, one confirmation leads with **end the
  active fast**, states the total persisted-fast count, and atomically updates
  all affected rows. Do not also describe a suppressed inferred candidate.
- Non-caloric hydration never prompts and never ends, shortens, sources or
  punctuates a fast.

### Ordering and boundaries

- The earliest caloric boundary strictly after a fast start wins, regardless
  of whether it is food or drink. Equal-time boundaries use the repository's
  stable kind-and-identifier ordering for deterministic provenance, without
  applying multiple changes.
- A historical event before a fast start or at/after a completed fast end does
  not affect that fast.
- An event at an active fast start remains invalid in the interactive journey
  because it cannot produce the positive duration required by BR-04.
- Moving an existing caloric event earlier can shorten a fast further and
  requires confirmation. Moving it later, deleting it or making it non-caloric
  does not restore elapsed time to a persisted fast. If it is a reconstructed
  end reference, the same event mutation atomically marks that row **Needs
  review** and presentation identifies the former boundary as unavailable.
- Starting a backdated active fast or correcting its start across an existing
  caloric event is rejected with the earliest blocking event time. Creating or
  editing a completed fast past its earliest later event is rejected with that
  event time as the maximum valid end; these fast-side journeys do not silently
  clamp or create immediately completed records.
- Inferred projection recomputes in both directions because it has no stored
  interval. Caloric hydration can be a source or the next punctuating boundary,
  follows the same eight-hour eligibility and goal-plus-12-hour cap, and uses
  generic food/drink source copy in conversion UI.

### Existing data reconciliation

- After the existing schema migration opens the store, but before settings,
  widgets, Live Activities or feature controllers consume it, reconcile every
  persisted fast against all saved caloric food and caloric hydration events.
- A completed fast ending after its earliest later caloric boundary is
  shortened to that boundary. An active fast with a later caloric boundary is
  completed there and captures the authoritative current goal, exactly like the
  existing interactive active-fast completion path. Already completed recorded
  goals and reconstructed no-goal provenance are not replaced.
- A reconstructed row shortened by reconciliation receives matching end-event
  provenance and remains distinguishable as reconstructed history.
- The pass is atomic, idempotent and deterministic. Running it again produces
  no writes. If it cannot validate or commit the complete reconciliation, app
  bootstrap fails closed through the existing persistence-unavailable state;
  it must not expose a partly reconciled store.
- Reconciliation does not create inferred rows. Once enabled, inferred History
  is simply projected from the reconciled store and the complete caloric event
  stream.

## Acceptance criteria

1. **Active food:** Given one active fast starting at `S`, when the user saves
   food at `E > S`, then uFast requires **Save and end fast**; confirming
   atomically creates/updates the food and completes the fast at `E`, while
   cancelling changes neither.
2. **Active caloric drink:** The same behavior and atomicity apply to hydration
   explicitly classified as caloric; non-caloric hydration saves without
   changing the fast.
3. **Completed persisted fast:** Given a completed persisted fast `[S, F)` and
   no earlier caloric boundary, when food or caloric hydration is entered or
   moved to `E` where `S < E < F`, then uFast requires confirmation and, on
   confirm, atomically saves the event and changes the fast to `[S, E)`.
4. **Reconstructed compatibility row:** The behavior in criterion 3 also
   shortens a reconstructed row and records the new event's kind and identifier
   as its truthful end-boundary provenance.
5. **Cancel and failure:** Cancelling any impact confirmation, failing
   validation or simulating persistence failure preserves the complete prior
   event and fast snapshots, including active state, end date, goal and
   provenance.
6. **Boundary instants:** Events before or exactly at `S`, and events at or
   after completed `F`, do not shorten a completed persisted fast. Interactive
   caloric entry at an active fast's exact `S` retains the current validation
   error and cannot create a zero-duration fast.
7. **Earliest wins:** With several caloric food/drink events after `S`, a
   persisted fast ends at the earliest timestamp. Equal timestamps select one
   provenance boundary deterministically. Reprocessing does not move the end
   later or duplicate records.
8. **No silent extension:** Deleting, moving later or making non-caloric the
   event at a persisted fast's end does not lengthen that fast. Existing
   explicit completed-fast edit behavior remains usable. If the event is a
   reconstructed end reference, the event mutation atomically marks the fast
   **Needs review**, retains the former reference only as review evidence and
   no longer presents it as a current caloric boundary.
9. **Inferred food/drink consistency:** With detection enabled, ordered caloric
   food and caloric hydration events can each source or punctuate an inferred
   interval under the existing exact-eight-hour and goal-plus-12-hour rules;
   non-caloric hydration does neither.
10. **Inferred historical impact:** Adding or moving a caloric food/drink into
    a presented inferred interval requires **Save and update History**. Confirm
    saves only the event and refreshes the derived interval to the new boundary
    or removes it if it no longer qualifies; cancel changes both event state and
    presentation inputs by zero records.
11. **Inference remains derived:** Inferred conversion revalidates a generic
    caloric boundary source, creates no inferred SwiftData entity/cache, and
    continues to create a normal completed or active `FastRecord` only after
    the existing explicit conversion action.
12. **Existing store:** A seeded pre-upgrade store containing active, completed
    recorded and reconstructed fasts that cross food and caloric-drink events is
    reconciled on first successful launch to the earliest later boundary. The
    resulting store contains no persisted fast extending across a caloric event.
13. **Reconciliation safety:** The existing-data pass is atomic, idempotent,
    deterministic across insertion order, survives relaunch, preserves record
    identifiers/start dates, already completed goals, reconstructed no-goal
    state and unrelated data, and fails closed without partial writes when
    commit is simulated to fail. An active row completed by reconciliation
    captures the authoritative current goal.
14. **Post-commit surfaces:** Ending an active persisted fast through either
    interactive save or launch reconciliation clears/synchronizes Today,
    WidgetKit and matching Live Activity projections through existing
    post-commit boundaries. Shortening completed or inferred History does not
    request a Live Activity.
15. **History and accessibility:** Successful changes refresh settled and
    moving History. Confirmation title, consequence, event time, fast kind and
    actions are understandable with VoiceOver, at accessibility Dynamic Type,
    without color, and have stable identifiers suitable for four-worker UI
    tests.
16. **Time and local-only behavior:** All comparisons use absolute instants and
    injected `AppClock` where current time is needed, remain correct across DST
    and time-zone changes, and add no permission, network or background-delivery
    dependency.
17. **Fast-side invariant:** A manual or inferred active-fast start and an
    active-start correction are rejected if the proposed open interval crosses
    an existing later caloric event. Completed-fast creation or edit is rejected
    if its proposed end is after the earliest caloric event later than its
    proposed start. The error exposes the blocking time, and no fast/event or
    projection changes on rejection.
18. **Combined impact:** For anomalous overlapping persisted rows, one event
    produces one confirmation, active impact takes copy precedence, the total
    affected persisted-fast count is stated, and confirm/cancel applies to the
    whole transaction. A suppressed inferred candidate is not separately
    announced.

## Architecture and data boundaries

- Keep boundary ordering, impacted-fast calculation and reconciliation in pure
  domain values/services independent of SwiftUI, SwiftData, WidgetKit and
  ActivityKit. Reuse `CaloricBoundary`, `CaloricBoundaryExtractor`,
  `RecordedFastInterval` and half-open conflict semantics rather than creating
  a second definition.
- Generalize the food-only inferred projector input and source identity to a
  caloric boundary reference without losing deterministic `Sendable` behavior.
- Application commands must calculate impact from authoritative records again
  immediately before commit. Presentation-time detection alone cannot authorize
  a write.
- Repository operations must update the event and every affected persisted fast
  in one `PersistenceTransaction`, including rollback snapshots for end dates,
  goals and reconstructed provenance.
- Fast start/correction and completed create/edit services must use the same
  authoritative caloric-boundary query and pure validator before persistence;
  UI picker limits alone are not sufficient enforcement.
- Existing reconstructed invalidation remains atomic with event deletion,
  move-later and caloric-to-non-caloric edits. Review presentation must
  distinguish a retained former reference from a current valid boundary.
- The bootstrap reconciler runs only after a store opens successfully and
  before any projection consumer. It must expose a compact result for tests
  (scanned count, changed count and active fast ended) without retaining health
  or event content outside the local store.
- Do not add an inferred persistence model. A schema/version marker is allowed
  only if repository inspection proves it is needed for safe one-time data
  reconciliation; the reconciliation algorithm itself must remain idempotent.
- Continue to isolate WidgetKit/ActivityKit as post-commit projections. A
  projection failure cannot roll back the already committed local event/fast
  transaction, but local persistence failure must prevent projection work.
- Preserve offline operation, local SwiftData storage, privacy copy and Delete
  All Data behavior. No new sensitive fields, permissions or telemetry are
  introduced.

## Dependencies and explicit decisions

- Existing D-013 active-fast event confirmation and atomic transaction.
- Existing D-033/D-034 inferred lifecycle, conversion and recorded-fast
  precedence, amended from food-only to all explicit caloric boundaries.
- Existing BR-17 half-open overlap rules and `ActiveFastAuthority`.
- Existing legacy reconstructed provenance and compatibility presentation.
- Existing persistence bootstrap, `PersistenceTransaction`, `AppClock`,
  History invalidation and post-commit projection coordinator.
- Accepted product decision supplied by this story: existing records are
  automatically reconciled even though prior rules protected them from silent
  rewriting.
- OW-410 is implemented in the current source baseline by commits `31c5586`,
  `fac8361` and `c55f052`, with focused core/unit/UI coverage present. Its
  backlog label still says **Ready** and is stale ledger metadata, not evidence
  of a Sol implementation acceptance. OW-411 must first run the smallest
  existing OW-410 focused tests to freeze that implemented behavior as its
  baseline; its Sol story gate must review all hydration generalization and
  conversion changes. No unimplemented OW-410 work is bundled into this story.

## Focused verification

- Pure domain tests: impacted-fast selection; food/drink parity; strict start
  and half-open end boundaries; earliest/equal-time ordering; no-extension;
  reconstructed end provenance; inferred threshold/cap/source/punctuation; DST
  and time-zone invariance.
- Fast-side validation tests: manual/inferred start, active-start correction,
  completed creation/edit, blocking boundary time and zero-mutation rejection.
- Application/persistence tests: create and edit paths; food, caloric hydration
  and non-caloric hydration; active/completed/reconstructed rows; stale impact
  revalidation; atomic rollback; History invalidation; post-commit projection
  spies; no inferred rows.
- Bootstrap/migration tests: seeded current and release-baseline stores with
  crossing events; active completion; deterministic result independent of
  insertion order; idempotent second launch; simulated failure with unchanged
  reopened store; unrelated settings, favourites, events and fast fields
  preserved.
- Reconstructed invalidation tests: deleting, moving later and making the end
  event non-caloric retains the end, marks **Needs review**, keeps former
  reference only as invalidation evidence and rolls back both event and fast on
  save failure.
- Focused UI tests: historical food and drink confirmations, inferred update
  confirmation, cancel, persistence failure, committed History result after
  relaunch, stable accessibility identifiers, VoiceOver copy and accessibility
  Dynamic Type. Each test uses reset/seed fixtures and fixed time.
- Run project generation, focused unit/core tests, changed focused UI tests,
  build and lint/format. Run one complete four-worker UI suite only at the
  source-frozen sprint integration gate and verify its `.xcresult` with the
  repository helper.

## Human checks

- Add food and a caloric custom drink into active, completed and inferred fasts;
  verify that each confirmation describes the actual consequence without
  judgmental or physiological language.
- Relaunch after each confirmed mutation and verify the shortened History and
  active-surface cleanup persist.
- Inspect an upgraded store with mixed recorded/reconstructed rows and confirm
  the visible end times and reconstructed provenance match the earliest events.
- Repeat with VoiceOver and an accessibility text size; ensure Cancel and the
  primary action remain obvious and reachable.

## Execution profile

- **Uncertainty:** high
- **Initial implementer:** Luna xhigh
- **Deterministic reproduction and observability:** fixed `AppClock`, seeded
  food/hydration/fast identifiers and timestamps, pure impact/reconciliation
  outputs, before/after SwiftData snapshots and counts, reconstructed boundary
  references, transaction-failure injection, projection spies, stable UI
  identifiers, relaunch fixtures and compact bootstrap reconciliation result.
- **Focused correction budget:** three corrections on the same acceptance
  surface or 25 minutes; stop earlier after the same failure repeats twice
  without new evidence.
- **Expected expensive commands:** project generation, focused core/unit tests,
  focused UI tests, build/lint, and one source-frozen full four-worker UI suite
  at integration.
- **Maximum rescue tier:** Terra, then read-only Sol diagnosis.

## Definition of Ready

- The caloric-boundary invariant and exact start/end semantics are explicit.
- Every event-side and fast-side mutation that could violate the invariant is
  covered by atomic update or deterministic rejection.
- Interactive confirmation, atomicity, inferred recomputation and
  no-silent-extension behavior are independently testable.
- Existing-data reconciliation covers all persisted fast origins, truthful
  reconstructed provenance, active projections, idempotence and failure.
- Food-only OW-410 contracts that must be amended are identified.
- Persistence, migration, accessibility, privacy and compatibility boundaries
  are explicit.
- Deterministic fixtures expose every acceptance surface without exploratory
  gestures or network state.
- A read-only Sol gate returns **READY** and confirms that implementation need
  not be split from discovery.

## Sol readiness gate

**Verdict:** READY  
**Reviewed:** 17 August 2026  
**Reasoning effort:** high  
**Recommended initial implementer:** Luna xhigh  
**Split required:** no

The gate found the accepted superseding product decision, scope, acceptance
criteria, architecture/data boundaries, accessibility/privacy constraints and
execution profile complete and independently testable. No material evidence or
contradictions remain. OW-410's missing historical implementation acceptance is
disclosed and bounded by the required focused baseline check; implementation
must preserve that check, the authoritative documentation amendments, the
focused correction budget and independent Sol acceptance gates.
