# OW-410 — Detect and explicitly convert inferred fasts

**Slice:** 3.12 — Inferred fast detection
**Priority:** P0
**Status:** Ready — Sol readiness gate passed
**Story type:** Product feature

## User outcome

As a person who sometimes forgets to start a fast, I want uFast to show a
clearly labelled inferred fast after eight hours without a later caloric
boundary,
so that I can understand the gap in my History and choose whether to save it
as a real completed fast or start it as a real active fast.

Detection is enabled by default but remains user-controlled. An inferred
interval is a read-only projection until the person takes an explicit action.
The feature must not silently create fasting history, change Today, or start a
Lock Screen/Live Activity surface.

## Why now

The current blue automatic-fast presentation is a placeholder. OW-410 replaces
that behavior with a local, food-event-anchored inferred-fast projection that
is useful in real time while preserving user control and the distinction
between inferred and recorded history.

## Context and authoritative decisions

### OW-411 supersession amendment — 17 August 2026

OW-411 generalizes the food-only boundary language in this story. Where this
document says that only a caloric food event can source or punctuate an
inferred interval, read it as **a caloric food or explicitly caloric hydration
event**. The shared `CaloricBoundary` representation and extractor are now the
authoritative source for both persisted-fast reconciliation and derived
inference. OW-410 remains the delivered derived, no-inferred-persistence
baseline; it does not authorize a second persistence model or silent fast
lengthening when an event is removed or moved later.

The implementation must follow these repository contracts:

- `PRODUCT.md` — calm, local-first product boundary and no health claims.
- `MVP_SCOPE.md` — user-controlled inferred fasting history is in the History
  scope.
- `DOMAIN_RULES.md` — BR-01 through BR-07, BR-12, BR-15 through BR-17,
  BR-22 through BR-26 and BR-44 through BR-49.
- `DECISIONS.md` — D-001 remains the no-silent-start rule; D-024 documents
  the legacy automatic-gap slice; D-033 is the accepted contract for this
  story.
- `BACKLOG.md` — OW-410 is the Slice 3.12 backlog item.

D-033 is authoritative where the legacy D-024 automatic-gap behavior differs.
Existing legacy data and compatibility behavior remain intact; this story does
not rewrite or remove that data.

## Final behavior

### Detection and presentation

- Add a user-facing setting for inferred fast detection. It is enabled by
  default for new and migrated installs, preserves an existing saved choice
  and persists locally across relaunch.
- When enabled, a saved caloric food or explicitly caloric hydration event can
  be a source. Non-caloric hydration and other non-boundary records cannot
  create or terminate an inferred interval.
- At exactly eight absolute hours after the source caloric event, the interval is
  eligible. The interval starts at the source event's exact timestamp, not at
  the eight-hour threshold. If no later caloric food or hydration event punctuates it before
  the maximum, that maximum is the source timestamp plus the user's current
  fasting goal duration and 12 absolute hours.
- If there is no later caloric food or hydration event, the interval ends at the current
  instant until that maximum and is capped there. It never grows beyond that
  maximum. While the current instant is before the maximum it is labelled
  **Inferred fast in progress**; at the maximum it remains visible as a
  historical **Inferred fast** with Save fast only.
- A later caloric food or explicitly caloric hydration event closes the current inferred interval only when it
  occurs before the maximum. A historical interval remains available when it
  qualifies, ending at that later caloric event or the maximum, whichever applies.
- An inferred interval is shown only when it intersects the exact settled
  History interval. The existing nearest-neighbour loading rules remain the
  source of boundary context. A persisted recorded fast takes precedence over
  an overlapping inferred interval by suppressing the entire candidate; the
  candidate is never clipped into a partial interval.
- Foreground History and fast-detail presentation refreshes the current
  inferred interval in real time using `AppClock`; no background timer,
  notification or remote service is introduced.
- Retain the existing blue/sky visual role for continuity, but show explicit
  copy such as **Inferred fast** and **Inferred fast in progress**. The
  accessibility label and value must identify the interval as inferred; colour
  is never the only distinction.

### Explicit conversion

- Tapping a historical inferred interval offers an explicit **Save fast**
  action. After confirmation and successful revalidation, save one ordinary
  completed recorded `FastRecord` using the goal current at conversion, with
  start equal to the source food timestamp and end equal to the projected
  punctuating-food or goal-plus-12-hour maximum boundary. It is not an inferred
  record, it does not become active and it does not trigger Today-active state,
  WidgetKit or ActivityKit.
- Tapping the current real-time inferred interval offers an explicit
  **Start fast** action. After confirmation and successful revalidation, save
  one active recorded `FastRecord` whose start is the source caloric event's exact
  timestamp. The existing active-fast post-commit path may then update Today,
  WidgetKit and ActivityKit according to their existing contracts.
- **Start fast** is not offered after the goal-plus-12-hour maximum. A capped
  candidate is historical and can only be saved as a completed fast. This also
  prevents an old no-later-food source from bypassing the existing 36-hour
  active-start boundary.
- Both actions revalidate the source event, inferred boundaries, current goal,
  active-fast authority and overlap constraints immediately before commit.
- Cancellation, stale candidates, conflicts, validation errors and persistence
  failures leave local state unchanged. The History projection refreshes from
  authoritative state after the operation.
- History's ordinary **Add at selected time** journey remains the food/drink
  journey. It is not repurposed to create a completed fast.

## In scope

- A user-controlled setting enabled by default with migration behavior.
- A framework-independent inferred-fast projector over local caloric food and
  explicitly caloric hydration events,
  recorded fasts, the current goal, the setting and an injected `AppClock`.
- Settled History and current/motion History presentation using the same
  projection and exact visible interval rules.
- Real-time foreground updates at the eight-hour threshold and goal-plus-
  12-hour maximum.
- Distinct inferred labels, accessibility semantics and stable identifiers for
  the setting, inferred rows and conversion actions.
- Historical Save fast and current Start fast confirmation/conversion flows.
- Transactional revalidation and invalidation after successful food create,
  edit, reclassification or deletion; goal changes; setting changes; and
  recorded-fast changes.
- Post-commit integration with the existing active-fast Today, WidgetKit and
  ActivityKit paths only after an active recorded fast exists.
- Focused unit, persistence/application and UI coverage plus product decision
  documentation.

## Out of scope

- Inferring calories, changing explicit hydration classification, HealthKit,
  external health data or missing events.
- A SwiftData entity, cache, CloudKit record, account, network request or
  background delivery mechanism for inferred intervals.
- Automatically persisting, starting, ending or rewriting a recorded fast.
- Notifications, background refresh, widgets or Live Activities for inferred
  presentation alone.
- AI interpretation, coaching, streak pressure, medical or physiological
  claims.
- Editing an inferred interval's source or boundaries directly.
- Changing the existing ordinary History Add journey.
- Removing or silently migrating legacy automatic/reconstructed history rows.

## Edge cases and interaction contract

- **Historical save:** use a calm confirmation that identifies the source and
  interval. A successful save is a normal completed recorded fast with the
  exact projected start/end and is not displayed as an inferred row afterward.
- **Current start:** use a calm confirmation that explains the active fast will
  start from the source food time. The action is available only before the
  goal-plus-12-hour maximum, so the source is necessarily inside the existing
  36-hour active-start boundary for the current 8–24 hour goal range.
- **Stale candidate:** if the source is edited, deleted or reclassified, a
  later caloric event is added, the goal or setting changes, or a conflicting
  fast appears, do not save the old candidate. Refresh and explain that it is
  no longer available when user feedback is needed.
- **Goal change:** recompute the inferred maximum immediately. A completed fast
  saved from a candidate retains the goal captured at conversion under the
  existing recorded-fast rule.
- **Overlap:** enforce the existing half-open recorded-fast conflict rules.
  Recorded-fast precedence suppresses the whole inferred candidate; it is not
  a clipping rule or permission to create an overlap.
- **Threshold and maximum:** exactly eight hours is eligible; one second earlier
  is not. A current interval stops at the source plus the current goal and 12
  absolute hours even if the user leaves the app open longer.
- **Time:** use absolute instants and injected `AppClock` values across time
  zones and daylight-saving changes. Do not use fixed local-day arithmetic.
- **Opt-out:** disabling the setting removes derived inferred rows and actions
  after the committed setting change but preserves all source events and real
  fasts. Re-enabling recomputes them.
- **Failure/cancel:** a failed or cancelled source-event or setting mutation
  leaves the previous complete projection intact until authoritative state can
  be refreshed.
- **Accessibility:** inferred status, in-progress status, interval, source
  food and available action must be understandable without colour or gestures;
  Dynamic Type and VoiceOver must not hide the conversion action.

## Acceptance criteria

1. The inferred-fast setting is enabled by default for a new install and for a
   migrated release-baseline store, persists across relaunch, and can be
   disabled without deleting source events or recorded fasts. An existing
   saved disabled choice remains disabled.
2. With the setting disabled, no inferred interval or inferred conversion
   action appears anywhere in History or fast detail.
3. With the setting enabled, a caloric food or explicitly caloric hydration event at `T` produces no inferred
   interval at `T + 8h - 1s`, and becomes eligible at exactly `T + 8h`.
4. A current inferred interval starts at `T`, advances with the injected
   current time, and ends at `min(now, T + currentGoal + 12h)` when no later
   caloric food or hydration event punctuates it.
5. When the next caloric food or hydration event is at `N` before `T + currentGoal + 12h`, a
   qualifying historical interval is `[T, N)`; otherwise it ends at
   `[T, T + currentGoal + 12h)`. A next food before eight hours produces no
   inferred interval.
6. Explicitly caloric hydration can create, split or close an inferred interval;
   non-caloric hydration and other non-boundary records cannot. Food remains
   caloric regardless of optional nutrition details.
7. An overlapping persisted recorded fast takes presentation precedence, and
   conversion still rejects any recorded-fast conflict through normal domain
   validation.
8. Saving a historical candidate creates exactly one completed recorded
   `FastRecord` with the current goal, creates no active fast, and causes no
   Today-active state or Live Activity request.
9. Starting the current candidate creates exactly one active recorded
   `FastRecord` at the source food timestamp; only after that commit may the
   existing active-fast path update Today, WidgetKit or ActivityKit.
10. Cancelling or attempting to convert a stale, conflicting or invalid
    candidate changes neither the food events nor the recorded-fast count.
11. Successful source-event create/edit/reclassification/delete, goal changes,
    setting changes and recorded-fast changes refresh both settled and current
    inferred presentation. Failed or cancelled mutations do not partially
    update it.
12. Migration preserves the release baseline and legacy rows, defaults the new
   setting to on, and creates no inferred SwiftData rows, cache entries or
   network records. An existing saved disabled choice remains disabled.
13. Focused tests cover absolute time, DST/time-zone changes, exact threshold,
    goal-plus-12-hour transition to historical Save-only state, opt-out, empty and
    offline/no-network state, Dynamic Type, VoiceOver and stable UI interaction
    under the repository's parallel UI-test runtime.

## Architecture and data boundaries

- Keep inference in a pure domain service or projector with immutable,
  `Sendable` inputs and outputs. It must not import SwiftUI, SwiftData,
  ActivityKit or WidgetKit.
- Supply local caloric food/hydration boundaries, recorded-fast intervals, current goal, setting,
  settled visible interval and `AppClock.now` through existing application
  boundaries. Fetch enough nearest caloric context for crossing intervals.
- Do not add an inferred-fast persistence model or write derived rows to the
  store. A new setting schema/version must preserve existing model declarations
  and migrate safely.
- Use the existing recorded-fast service for conversion so active-fast
  authority, overlap checks, current-goal capture and transaction behavior are
  not duplicated in the projection layer.
- Refresh derived presentation after committed local mutations and after
  foreground/motion reference-time changes. Do not add a background execution
  dependency merely to cross the threshold.
- Call existing Today, WidgetKit and ActivityKit integrations only from the
  successful active recorded-fast post-commit path. Inferred rows and
  completed conversions must be inert to those surfaces.
- Keep inferred status in the semantic model and accessibility tree, not only
  in the blue/sky color token. Existing **Delete all data** behavior requires
  no special inferred cleanup because inferred intervals are not persisted.

## Dependencies

- Existing food/hydration event model and caloric classification.
- Existing recorded-fast start, completed-fast persistence and overlap rules.
- Existing History settled/motion projection and nearest-boundary loading.
- Existing local settings persistence and migration framework.
- Existing `AppClock` injection and Today/WidgetKit/ActivityKit post-commit
  adapters.

## Focused verification

- Pure domain tests for source selection, exact eight-hour threshold, current
  goal-plus-12-hour maximum, later-food termination, non-caloric-event behavior,
  overlap precedence, DST/time-zone changes and opt-out.
- Persistence/application tests for default and migrated settings, no inferred
  rows, transactional conversion, stale revalidation, failure/cancel behavior,
  recorded-fast counts and post-commit surface spies.
- Focused UI tests for the setting, settled historical Save fast, current Start
  fast, disabled/empty states, stale candidate handling, accessibility labels,
  Dynamic Type and relaunch persistence. Use reset/seed fixtures, a fixed
  clock and stable identifiers.
- Build, lint/format and the required final source-frozen parallel UI suite
  follow the repository sprint verification workflow. The implementation
  worker runs focused tests and changed UI tests; the integration gate runs the
  full suite only after all sprint sources are frozen.

## Execution profile

- **Uncertainty:** high
- **Initial implementer:** Luna xhigh
- **Deterministic reproduction and observability:** fixed `AppClock.now`,
  reset local store, seeded release-baseline migration fixture with an
  idempotent off-by-default assertion, seeded food/settings, pure projector
  outputs, stable source identifiers, SwiftData record counts, post-commit
  spies and accessibility identifiers. Offline/no-network behavior is
  observable because no network dependency is installed; there is no denied
  permission state in this local-only feature.
- **Focused correction budget:** three story-surface corrections or 25 minutes;
  stop earlier for repeated failures without new evidence.
- **Expected expensive commands:** project generation, focused unit tests,
  focused UI tests, build/lint, then one source-frozen full parallel UI suite.
- **Maximum rescue tier:** Terra rescue, then read-only Sol diagnosis.

## Definition of Ready

- D-033, D-034 and BR-22 through BR-26 and BR-44 through BR-52 are recorded in the
  product documents.
- Scope exclusions and the legacy compatibility boundary are explicit.
- Acceptance criteria cover detection, conversion, persistence, invalidation,
  live surfaces, accessibility, migration and deterministic time.
- The local authority, post-commit boundaries and no-inferred-persistence rule
  are explicit.
- The execution profile and focused-test observability are explicit.
- The required read-only Sol readiness gate returns **READY**. The OW-410 gate
  returned READY after the D-034/BR-50 through BR-52 lifecycle clarification.
