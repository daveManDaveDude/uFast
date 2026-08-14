# Widget system-surface review hardening

**Sprint status:** Ready  
**Prepared:** 11 August 2026  
**Priority:** Two P1 correctness/privacy fixes and one P2 fail-closed fix  
**Product decisions:** D-028 through D-031  
**Product rules:** BR-33 through BR-42

## Sprint goal

Make the shipped widget and Live Activity projections remain current,
privacy-safe and fail-closed without changing fasting authority, adding
background work or redesigning the working system surfaces.

The 11 August review findings are sensible:

1. The rectangular widget currently creates one active entry and delays reload
   until the target, so fixed elapsed copy, percentage and VoiceOver summary can
   remain at their launch values even though the system progress bar advances.
2. The Live Activity marks timer/detail children sensitive, then discards those
   nodes and installs an unredacted parent accessibility summary. VoiceOver can
   therefore bypass the intended privacy treatment.
3. Launch synchronization detects multiple active fasts but leaves old App
   Group JSON in place. The app fails visibly while a widget may continue to
   show stale data, contrary to BR-35's fail-closed contract.

## Current product surface contract

- Accessory rectangular is the required Lock Screen widget family.
- Small, medium and large are the three required Home Screen widget families;
  all three are implemented and currently work from the shared projection.
- Dynamic Island has no persistent banner requirement. The optional Live
  Activity supplies compact, minimal and expanded regions, and iOS controls
  presentation and fallback.
- This sprint does not remove, redesign or add a widget family or ActivityKit
  region.

## Delivery order and estimate

| Order | Story | Priority | Estimate | Dependency |
| --- | --- | --- | --- | --- |
| 1 | WS-101 Advance fixed widget values | P1 | 3 points | D-028, OW-L102 |
| 2 | WS-102 Redact Live Activity VoiceOver summary | P1 | 2 points | D-029 |
| 3 | WS-103 Invalidate ambiguous projection | P2 | 2 points | MH-004, BR-35 |

The stories are independently reviewable. WS-101 should land first because its
timeline helper can be reused by all four WidgetKit families. WS-102 and WS-103
may then be implemented in either order.

---

## WS-101 — Keep fixed widget elapsed values advancing

**Epic:** Widget system-surface reliability  
**Priority:** P1  
**Status:** Ready  
**Estimate:** 3 points

### User story

As a user observing an active fast in a widget, I want elapsed copy, percentage
and its VoiceOver summary to advance while uFast is suspended, so that the
fixed values agree with the system-driven progress track.

### Why now

A newly started 12-hour fast can retain its launch-time fixed values until its
target. That makes the primary glanceable surface materially stale.

### In scope

- Replace the target-only single-entry active timeline with a deterministic,
  bounded schedule of fixed-value entries.
- Emit active entries every five minutes for a rolling two-hour horizon, plus
  an exact target-boundary entry when it falls inside that horizon.
- Ask WidgetKit to reload at the horizon so longer and beyond-goal fasts receive
  a new bounded schedule.
- Recompute elapsed text, percentage and accessibility summary from each entry's
  date; retain the system date-relative progress bar.
- Keep the existing five-minute fallback reload for no-active, unreadable or
  invalid projection states.
- Share the schedule across accessory rectangular and the small, medium and
  large Home Screen families through their existing provider.

### Out of scope

- Per-second timeline entries, persisted timer ticks, networking, APNs,
  background tasks or a new data field.
- Changing protected hours/minutes precision, the active-fast projection
  schema, widget layouts or the Live Activity timer.
- Promising exact execution time; WidgetKit remains the scheduler.

### Product rules

BR-33 through BR-35 and BR-41.

### Acceptance criteria

1. Given a valid active projection before target, when its timeline is built,
   then it contains the current entry and five-minute entries through a bounded
   two-hour horizon rather than only a target-date reload.
2. Given a target between cadence boundaries inside that horizon, then one
   exact target entry is present and dates remain unique and ordered.
3. Given successive entries, fixed elapsed copy, progress percentage and the
   VoiceOver summary are derived from each entry date and advance monotonically.
4. Given a fast longer than the horizon or already beyond target, then the
   reload policy requests another bounded horizon and elapsed remains able to
   advance beyond the goal while progress stays clamped to 100%.
5. Given no active, corrupt, incompatible, unreadable or future projection,
   then no duration is invented and the neutral state retains its bounded
   fallback reload.
6. Inspection proves there are no per-second entries, timer writes, network
   calls or changes to SwiftData authority.

### States and edge cases

- Exact cadence and exact target dates must not produce duplicate entries.
- London daylight-saving and time-zone changes preserve absolute instants.
- A delayed or coalesced WidgetKit reload may reduce freshness but never invent
  a value; an app projection change still requests its existing reload.
- Target attainment remains neutral, and fixed values never exceed 100%.

### Data and privacy

Reads the existing rebuildable projection only. It creates timeline values in
memory and adds no persistence, permission, logging payload or retained data.

### Design and accessibility

No visual change is intended. The existing stable outer VoiceOver summary must
advance with the fixed visual values and must not reintroduce seconds on the
protected Lock Screen widget.

### Verification

- Unit-test cadence, horizon, exact-target insertion, uniqueness and beyond-
  target scheduling with fixed clocks.
- Unit-test that two consecutive entries produce different elapsed and
  accessibility values and nondecreasing percentage.
- Preserve invalid/future/no-active presentation tests.
- On a physical iPhone, observe an active accessory widget and each Home Screen
  size across at least two cadence boundaries with the app suspended.
- Run `make project`, `make format`, `make build`, `make test-unit`, `make lint`
  and the full four-worker `make test-ui` gate.

### Done when

All four widget families keep fixed active values moving under the bounded
timeline contract and every repository Definition of Done check passes.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## WS-102 — Redact the Live Activity VoiceOver summary

**Epic:** Widget system-surface privacy  
**Priority:** P1  
**Status:** Ready  
**Estimate:** 2 points

### User story

As a VoiceOver user with privacy redaction active, I want the Live Activity to
announce only its identity and destination, so that hidden fasting details are
not exposed through accessibility.

### Why now

The outer Lock Screen Live Activity replaces privacy-sensitive children with a
summary containing elapsed time, goal percentage and target time. Visual
redaction therefore does not currently guarantee semantic redaction.

### In scope

- Read the SwiftUI privacy redaction environment at the outer Live Activity
  Lock Screen view.
- Pass `.redacted` into the existing pure presentation when `.privacy` is
  present and `.visible` otherwise.
- Mark the outer accessibility element privacy-sensitive as defence in depth.
- Under privacy redaction, expose exactly **uFast. Opens uFast.** with no
  elapsed, percentage, goal, target or reached state.
- Preserve the full existing summary when privacy redaction is absent.

### Out of scope

- New user privacy settings, custom lock-state inference or changes to visual
  content and Dynamic Island layouts.
- Recurring timer announcements or making child nodes independently focusable.

### Product rules

BR-28, BR-36, BR-41 and BR-42.

### Acceptance criteria

1. Given `.privacy` redaction, when VoiceOver focuses the outer Live Activity,
   then it announces only **uFast. Opens uFast.**
2. Given that state, inspection of the exposed label finds no elapsed duration,
   percentage, goal hours, target time or goal-reached wording.
3. Given no privacy redaction, the existing coherent summary remains available
   without exposing duplicate timer/detail children.
4. Given invalid content, presentation also fails closed to the identity-only
   summary.
5. Compact, minimal and expanded Dynamic Island regions remain present and no
   persistent banner behavior is introduced.

### States and edge cases

Cover active below goal, at goal and beyond goal; privacy redacted and visible;
invalid content; light/dark and reduced-luminance environments.

### Data and privacy

No data, schema, permission or retention change. This closes an accessibility
path around existing system privacy redaction.

### Verification

- Retain the pure redacted-presentation unit test and add a view-level test or
  inspectable helper proving environment-to-privacy-state mapping.
- Verify the unredacted summary regression path.
- On a supported physical iPhone, use VoiceOver to inspect the redacted Lock
  Screen activity and record that no sensitive values are spoken.
- Run the standard build, unit, lint and full four-worker UI gates.

### Done when

Visual and semantic redaction agree and all Definition of Done checks pass.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## WS-103 — Fail closed when active-fast authority is ambiguous

**Epic:** Widget system-surface integrity  
**Priority:** P2  
**Status:** Ready  
**Estimate:** 2 points

### User story

As a user whose local store has an integrity conflict, I want widgets to hide
stale fasting values, so that no system surface presents one record as
authoritative while the app reports ambiguity.

### Why now

Launch synchronization returns on multiple active fasts without touching the
old App Group JSON. That violates the accepted fail-closed projection contract.

### In scope

- On `ActiveFastAuthority.fetch` ambiguity, clear the projection through
  `ActiveFastProjectionCoordinator` before returning.
- Preserve the coordinator's existing fallback: if JSON removal fails, write
  the invalidation marker and request a widget reload after either successful
  clear or successful invalidation.
- Add a narrow coordinator injection seam to make launch synchronization
  deterministic in unit tests.
- Leave both conflicting `FastRecord` values untouched for the app's existing
  integrity-error handling.

### Out of scope

- Choosing, merging, deleting or repairing an active fast automatically.
- Changing the SwiftData schema, the integrity error UI or the committed-write
  rule for normal projection publication.
- Treating a failed SwiftData commit as ambiguity; failed commits continue to
  leave the prior projection unchanged.

### Product rules

BR-03, BR-33, BR-35 and BR-41.

### Acceptance criteria

1. Given two active `FastRecord` values and an old projection, when launch
   synchronization runs, then the derived projection reads as unavailable and
   a widget reload is requested.
2. Given physical removal fails, when invalidation succeeds, then the old JSON
   remains hidden and one reload is requested for the successful invalidation.
3. Given clear and invalidation both fail, then the error is logged without
   mutating either `FastRecord` or crashing/claiming an authority.
4. Given exactly one active fast and one settings authority, normal publication
   remains unchanged; given no active fast, normal clear remains unchanged.
5. Given a persistence save fails before synchronization, the last committed
   projection remains unchanged under D-028.

### States and edge cases

Cover zero, one and multiple active records; successful clear; clear failure
with successful invalidation; total projection-store failure; and ambiguous
settings as a separate unchanged behavior unless a later review expands scope.

### Data and privacy

Only disposable App Group projection state is cleared or invalidated. No
authoritative local history is selected, rewritten or deleted.

### Verification

- Add in-memory SwiftData tests for zero, one and two active records using a
  projection-store and reloader spy.
- Assert ambiguity clears/invalidate-hides stale data, reload ordering and no
  mutation of either active record.
- Preserve coordinator write/clear failure regression tests.
- Run the standard build, unit, lint and full four-worker UI gates.

### Done when

Ambiguous active-fast authority cannot leave a readable stale widget projection,
and all Definition of Done checks pass.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## Sprint release gate

- All three stories meet their acceptance criteria with no scope expansion.
- `make project`, `make format`, `make build`, `make test-unit`, `make lint` and
  one full parallel `make test-ui` invocation pass.
- The UI result bundle contains every UI test exactly once, no unexpected skip
  and four successful worker clones.
- Physical-device evidence covers widget cadence and redacted VoiceOver.
- The final diff contains no new health claim, persistence authority, network,
  notification, background restart, widget family or Dynamic Island banner.
- If a configured iPhone is connected, deploy the verified build with
  `make deploy-iphone`.
