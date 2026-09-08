# BF-105 — Make fast durations glanceable in History

**Slice:** History visual reliability  
**Priority:** P1 UX clarity and motion performance  
**Status:** Ready 31 August 2026 — continuous-motion timer revision  
**Story type:** Bounded History presentation refinement

## User outcome

As a user glancing at History, I want to see how long each previous fast lasted
and the current length of an active recorded or inferred fast, so that I can
understand my fasting history without opening each fast.

## Why now

History currently preserves duration in the settled **Fasts in this view**
cards and accessibility descriptions, but BF-104 intentionally reduced the
continuous timeline decoration to **Fast**, **Inferred fast** or **Active fast**
and prohibited a live duration inside the timeline label. That protects the
native free-scrolling path, but it makes the timeline less useful at a glance.

This story restores duration as compact timeline information without restoring
page-fragment label ownership or coupling second-level updates to scrolling,
layout measurement, interval projection, persistence or History queries.

## Context and authoritative rules

- PRODUCT requires calm, honest presentation and keeps recorded and inferred
  fasts distinguishable.
- MVP scope includes active-fast elapsed time, target and history.
- D-009 requires completed-second precision for an active-fast timer and allows
  completed History duration to retain whole-minute precision.
- D-015 treats one fast as one absolute interval when clipped by the viewport or
  calendar days.
- D-021 and D-022 preserve the native, free-scrolling continuous History
  timeline and prohibit custom scrolling physics, display-link sampling and
  timer-driven motion authority.
- D-038 and BF-104 keep one visual label in continuous runway coordinates,
  prohibit page-fragment ownership and prohibit per-second label projection or
  placement work. BF-105 supersedes only D-038's prohibition on displaying a
  live duration.
- BR-12 and BR-49 require absolute-instant calculations through the injected
  `AppClock`, including time-zone and daylight-saving changes.
- BR-23 and BR-50 cap an inferred interval at the first later caloric boundary
  or the source instant plus the current goal duration plus 12 absolute hours.
- BR-24, BR-48 and BR-52 preserve derived inferred presentation, explicit
  inferred copy and recorded-fast precedence.

## Product decision

The one continuous timeline label for a fast may show two compact lines:

1. its existing kind title: **Fast**, **Inferred fast** or **Active fast**;
2. its duration.

Completed recorded, reconstructed, retained legacy and historical inferred
intervals show a static locale-aware duration to completed-minute precision.
An active recorded fast and a current inferred fast show elapsed duration to
completed-second precision. Examples in English are `12 h 30 min` for a
completed interval and `08:12:34` for a current interval; exact localized copy
comes from the app text catalog and existing duration-formatting conventions.
Durations derive from absolute instants, not calendar component subtraction.

The duration line is glanceable decoration, not a second semantic fast. The
settled **Fasts in this view** card remains the complete accessible and
actionable representation. While that card is actually presented, its isolated
duration leaf uses the same completed-second value. Hidden settled-detail
content does not redraw during motion; when details return, its leaf derives the
current value directly without replay.

One History-owned injectable cadence driver remains active while History is
visible and updates only the lightweight duration-text leaf for current
intervals. Seconds continue advancing during direct tracking, deceleration,
alignment, programmatic movement and coupled date-rail motion. A tick does not
rebuild the label descriptor or parent carousel, remeasure text, reproject
intervals, query persistence, mutate models, publish scroll state or change
content size. If the main actor coalesces a delayed pulse, the next delivered
value derives directly from `AppClock.now`; missed values are never replayed in
a burst.

The exact current format is the existing localized
`[<days>d ]HH:MM:SS` style: omit the day field below 24 hours, use two-digit
hours within a day, and show completed whole days plus two-digit residual hours,
minutes and seconds at 24 hours or longer. Localized punctuation and the day
unit come from explicit text-catalog keys; digits remain monospaced. The
duration region has a stable width for its presentation generation. That
generation measures `88:88:88`, `88d 88:88:88`, `888d 88:88:88` and successive
localized day-digit templates only until the next template cannot fit inside
the complete projected bar. The fixed slot reserves the widest fitting
template independently of the current value. A tick selects among those
already-measured templates using digit-count arithmetic, so 23:59:59→1d
00:00:00, 99→100 days and later fitting boundaries continue during motion with
no measurement, projection or frame change. If the exact current string
exceeds the widest fitting template, the duration decoration is omitted by the
leaf while the kind/glyph fit policy and settled semantic card retain truthful
information. No text is truncated or scaled below the accepted type size.
Locale, Dynamic Type, layout direction, runway or interval-data changes may
create a new ordinary label generation outside a scroll-geometry callback.

For a current inferred interval, BR-50 classification changes at the cap
instant itself and elapsed display is clamped to that authoritative maximum.
Reaching the cap schedules at most one derived-presentation transition; it
never persists an inferred record. If the boundary is reached during motion,
the fixed duration leaf clamps immediately while timeline reprojection is
deferred until settlement; the displayed duration never exceeds the cap. This
exceptional settled transition may increment the
interval/label presentation-generation and cap-transition counters exactly
once; it remains distinct from the tick path and performs no persistence write
or SwiftData query. The already-loaded source, goal and cap are sufficient to
reclassify the candidate. A later caloric event or recorded-fast mutation
continues through existing post-commit History invalidation rather than timer
inference.

Presenting an inferred conversion sheet ends the underlying History label
cadence because the timeline is no longer visible,
but the sheet retains one injectable, cancellable, one-shot cap deadline based
on the candidate's already-known maximum. At or after that instant **Start
fast** becomes unavailable immediately, the clamped final duration remains
visible, and the sheet presents a calm stale-state message with **Return to
History**. It does not silently change the action to **Save fast** or commit a
record. Returning dismisses the sheet and publishes the one derived History
cap transition; if History is moving, visual reprojection waits for settlement.
Revalidation on any racing Start action must also reject current conversion at
or after the cap, so scheduler delay cannot violate BR-50.

## In scope

- Add compact static duration text to completed fast labels on the continuous
  History timeline.
- Add completed-second elapsed duration to active recorded and current inferred
  timeline labels and settled detail cards.
- Use one shared History duration pulse rather than one timer per interval or
  page fragment.
- Keep completed-second timeline ticks running through every timeline/date-rail
  movement phase without coupling them to motion callbacks or carousel state.
- Keep duration measurement, label frame and projection stable across ticks.
- Handle the one-shot current-inferred cap transition without persistence.
- Make an already-presented current-inferred conversion sheet fail closed at
  its cap without leaving **Start fast** available.
- Add an injectable cadence driver and mandatory UI-test-only clock-advance
  command so second, motion and cap tests never depend on wall-clock sleeps.
- Extend deterministic unit, state, UI and performance observability for
  historical, active recorded and current inferred durations.
- Add the smallest accepted amendment to `DECISIONS.md` during implementation
  so D-038 cannot later be read as prohibiting this bounded duration surface.

## Out of scope

- Changing fast boundaries, goals, inference, overlap precedence, event
  semantics, conversion actions, editors or persistence.
- Updating bar length once per second; bars continue to use the coherent History
  projection and refresh boundaries already owned by History.
- Adding duration to event markers, date chips, widgets or Live Activities.
- Restoring label ownership to calendar pages or fragments, following/clamping
  a label to the viewport, or changing midpoint placement.
- Custom scroll physics, gesture handling, snapping, display links, per-frame
  sampling or high-frequency geometry observation.
- A timer per fast, per label, per page or per detail row.
- Persisted timer ticks, inferred records, caches, migrations, analytics,
  networking, CloudKit, HealthKit, AI, coaching or health claims.

## Final user-visible behavior and edge cases

- A completed recorded fast shows **Fast** and its completed duration directly
  on its one continuous label; an inferred historical interval shows
  **Inferred fast** and its completed duration.
- An active recorded fast shows **Active fast** and an elapsed value advancing
  once per second while History is visible, including while the timeline or
  date rail is moving.
- A current inferred interval shows **Inferred fast** and an elapsed value
  advancing once per second while History is visible, including while the
  timeline or date rail is moving.
- Slow drags, fast swipes, reversals, deceleration, programmatic alignment and
  coupled date-rail motion continue to show successive completed-second values.
  Ticks neither jump nor move the label and never replay intermediate values.
- A completed interval never changes merely because time passes, History moves,
  the current goal changes or the app crosses midnight.
- An active duration uses the stored start and `AppClock.now`. It may exceed the
  goal without implying a health outcome and is never negative.
- A current inferred duration never exceeds its source-bound cap. At the cap it
  stops advancing and becomes the historical inferred presentation at the next
  safe settled refresh.
- If its conversion sheet is open at the cap, **Start fast** becomes unavailable
  at that instant and a stale-state message returns the user to refreshed
  History without mutation.
- Durations spanning 24 hours remain unambiguous. Premeasured fitting day-digit
  templates prevent day changes from wrapping, resizing or reprojecting the
  label, including during motion. When the next exact template cannot fit the
  complete bar, the duration leaf is deterministically omitted without showing
  partial or stale digits.
- Spring-forward, autumn-fallback and time-zone changes preserve elapsed
  absolute seconds.
- If a label cannot fit its title and duration, the deterministic priority is:
  title plus duration, duration only, existing glyph only, then no decoration.
  The complete duration remains available in the settled card and semantic
  accessibility representation. Text never escapes the complete bar.
- Dynamic Type may reduce how much decoration fits but never changes interval
  geometry, scroll content size or action hit targets.
- VoiceOver encounters one semantic fast, not separate decorative title and
  duration elements. The semantic duration is refreshed while History is
  visible and the
  decorative continuous layer remains accessibility-hidden in production.
- Leaving History, backgrounding, presenting an editor or losing the required
  current interval stops the pulse; return/foreground derives one authoritative
  current value and resumes without persisting or replaying ticks.

## Acceptance criteria

1. **Completed durations are glanceable and static**  
   Given completed recorded, reconstructed, retained legacy and historical
   inferred intervals, when their continuous labels have enough room, then each
   shows its existing kind title and a locale-aware duration rounded down to
   completed minutes. Advancing `AppClock.now`, scrolling or changing the
   current goal does not change that duration.

2. **Current recorded and inferred durations advance by second**  
   Given an active recorded fast or current inferred interval while History is
   visible in any settled or moving phase, when `AppClock` advances across
   successive whole-second boundaries, then the timeline duration advances to
   the completed-second value. When the settled semantic card is presented, its
   duration leaf shows the same current value, with no negative or
   future-rounded value; hidden detail content does not redraw during motion.

3. **Seconds continue throughout motion**  
   Given a current duration and any tracking, decelerating, aligning,
   programmatic or date-rail movement phase lasting across multiple whole-second
   boundaries, when the cadence fires, then the fixed duration leaf presents
   each newly completed second during that motion. No tick is sourced from a
   scroll callback, no label/frame/offset changes because of the tick, and a
   delayed pulse catches up directly to `AppClock.now` without replay.

4. **Ticks cannot disturb label or scroll geometry**  
   Given a visible current duration crossing second, minute, hour and day
   boundaries, then label descriptor identity, frame, midpoint, measured
   metrics, interval projection, runway width, day stride, selected-day centre
   and scroll content offset remain unchanged within BF-104 tolerances. A
   fitting day-digit boundary uses premeasured metrics inside the same fixed
   slot and must leave runway and scroll geometry unchanged. Crossing beyond
   the widest fitting template omits only the duration leaf.

5. **No tick performs expensive or authoritative work**  
   Given five settled seconds and ten alternating swipes spanning multiple
   seconds, then duration ticks
   perform only bounded duration-value derivation and text invalidation. They
   perform zero label projection/measurement, History query/reload, SwiftData
   access, persistence mutation, interval projection, scroll-geometry callback
   work, parent-carousel invalidation, task fan-out or diagnostic event
   emission. Tick work remains outside scroll-geometry callback intervals.

6. **Current inferred cap is honest and bounded**  
   Given a current inferred interval approaching its goal-plus-12-hour maximum,
   when time reaches or passes that instant, then displayed elapsed time never
   exceeds the cap, at most one derived refresh changes it to historical state,
   and no `FastRecord` or inferred entity is persisted. Motion may defer visual
   reprojection but not BR-50 classification or display a value beyond the cap.
   The exceptional settled transition may increment its documented generation
   counters once and performs no data query.

7. **An open inferred conversion fails closed at the cap**  
   Given a current inferred conversion sheet is already visible, when its cap
   instant arrives or a racing Start action revalidates at/after that instant,
   then **Start fast** is unavailable, no record is created, the final clamped
   duration is shown and **Return to History** produces the historical inferred
   presentation at the next safe settlement.

8. **Fit, localization and accessibility remain deterministic**  
   Given narrow bars, multi-day intervals, English and a wider
   pseudolocalization, AXXXL Dynamic Type, RTL and both London DST transitions,
   then the documented fit priority is deterministic, digits remain readable,
   decoration stays within the complete bar, and VoiceOver exposes one complete
   semantic fast with the correct duration.

9. **Existing History behavior remains intact**  
   Given recorded, active, inferred and retained legacy intervals through
   midnight and motion, then continuous-bar geometry, one-label identity,
   midpoint placement, lanes, colours, strokes, hit targets, actions, event
   grouping, selected-day settlement, future browsing and inferred conversion
   remain unchanged.

10. **Physical scrolling remains smooth**  
   Given the BF-104 deterministic fixture with active recorded and inferred
   variants on a supported iPhone, when gentle and fast swipes are repeated in
   both directions, then native inertia remains smooth, the prior finger-lift
   hitch and date-row flash do not return, no timer-related label jump appears,
   and the duration visibly counts successive seconds throughout the motion.

11. **Scope and data remain unchanged**  
    No fast, event, setting, suppression or legacy record is added, rewritten
    or migrated by duration display. No permission, privacy, network, cloud,
    analytics or external-capability boundary changes.

## Architecture and data boundaries

### Pure duration presentation

- Use a framework-independent duration value/formatter boundary that receives
  interval kind, absolute start/end or cap, and an explicit `AppClock` instant.
- Completed items derive once from stored/projected bounds at whole-minute
  precision. Current items derive elapsed completed seconds as
  `max(0, min(now, capOrNow) - start)`.
- Reuse or deliberately consolidate `HistoryTextFormatting` rather than adding
  inconsistent ad hoc formatting in the SwiftUI label layer.
- Do not use Calendar component subtraction for elapsed duration.

### Shared clock and isolated motion-safe tick path

- History owns at most one second cadence while it is visible and active and has
  at least one current interval in its loaded visual presentation. Movement
  phase never pauses or recreates that cadence.
- Define a small injectable cadence-driver protocol whose production adapter
  emits at most one main-actor pulse per second and whose test adapter advances
  only on command. The cadence publishes a lightweight explicit `now` from
  `AppClock` to duration consumers; it does not mutate interval models.
- Extend the UI launch harness with a mandatory test-only clock controller and
  stable advance command/probe. It can arm a bounded script of exact logical
  one-second clock advances before a native gesture; the in-app test cadence
  delivers those pulses while the gesture is active and records their ordering
  against motion begin/end events. Focused UI tests therefore advance exact
  seconds and cap boundaries without XCTest sleeps or a concurrent test-process
  command. No AC2/AC3/AC5/AC6/AC7 assertion depends on wall-clock elapsed
  values. The production app exposes no clock-control UI.
- The cadence output is scoped to an isolated fixed-frame duration leaf with a
  stable interval identity. The parent continuous label descriptor, carousel,
  date rail and History presentation model do not observe per-second values.
  Existing `TemporalCarouselMovementPhase` and date-rail state are diagnostic
  inputs only, allowing tests to prove ticks occurred during each phase; they
  never gate, schedule or source a tick.
- The settled semantic card has its own isolated duration leaf only while
  details are presented. Motion-hidden detail rows do not observe ticks; their
  next presentation reads the current cadence value once.
- Sheet/scene/visibility lifecycle may stop the cadence when the timeline is no
  longer visible. Returning computes the current value once and starts one
  cadence, with no replay or duplicate task.
- The current inferred cap uses one injectable, cancellable deadline scheduled
  from its already-loaded maximum, not a second polling loop. Classification
  changes at the deadline even during motion; only timeline reprojection waits
  for settlement. An open conversion sheet keeps its own one-shot deadline
  while the underlying timeline cadence is stopped because that timeline is no
  longer visible, and fail-closes the action as defined above.

### Stable label layout

- Extend the existing one-per-interval continuous descriptor with a static
  duration role and the finite fitting-template set described above. The slot's
  metrics are keyed by locale, layout direction, Dynamic Type and formatter
  style, not by current digits; measurement stops at the first template wider
  than the complete bar.
- Historical duration strings participate in the ordinary presentation
  generation. Current duration digits are rendered by a child value whose
  frame is fixed for that generation and use monospaced digits.
- The tick path must not call `TemporalRibbonLabelProjector`, UIKit font
  measurement, label input/title resolution, lane assignment or continuous
  coordinate mapping.
- A cap transition is an explicit presentation-generation event, not ordinary
  tick work. It may increment generation, input, metrics and projection
  counters at most once after settlement; probe evidence must identify that
  cause. It still performs no persistence/query or scroll-geometry callback
  work. Day-digit changes select a premeasured leaf template or omission and do
  not increment those counters.
- Ordinary duration ticks, including ticks delivered during motion, invalidate
  only the duration leaf. Require an equatable/stable parent input boundary (or
  an equivalent narrow invalidation seam proven by instrumentation) so the
  carousel and continuous label descriptor bodies do not become per-second
  work.
- The layer remains non-sizing, non-hit-testing and accessibility-hidden in
  production. Page fragments retain all hit routing and bar geometry.

### Data, concurrency, privacy and compatibility

- `FastRecord`, inferred projection and legacy adapters remain authoritative.
  No schema or migration change is permitted.
- No detached task or timer may outlive the visible History lifecycle. One
  `@MainActor` presentation pulse is sufficient; it performs no blocking work.
- Existing post-commit invalidation remains the only response to persisted
  record/event mutations.
- Duration presentation introduces no personal-data collection, logging,
  permission, network or health interpretation.

## Dependencies and explicit decisions

- Depends on the implemented BF-104 continuous label layer and its stable
  coordinate, probe and performance boundaries.
- Preserves D-015, D-021, D-022, BR-12, BR-23, BR-24, BR-48 through BR-50 and
  BR-52.
- Supersedes BF-104/D-038 only where they require **no duration** in the
  continuous label and prohibit any live History duration. It preserves their
  ban on per-second projection, measurement, geometry and fragment ownership.
- The product decision is closed: historical values use completed minutes;
  current recorded and inferred values use completed seconds continuously while
  History is visible, including throughout all scrolling and date-rail motion.
- No separate discovery story is expected unless a bounded prototype cannot
  keep all BF-104 geometry/projection counters unchanged during ticks.

## Stable accessibility and test selectors

- Continue to scope timeline interaction under `history.day-carousel` and the
  feature container `history.carousel`.
- Continue `history.fast-label-probe.<UUID>` under `--ui-testing` for the fixed
  title/frame descriptor; it remains absent from production accessibility.
- Add a non-hit-testing UI-test-only value probe
  `history.fast-duration-probe.<UUID>` whose accessibility value is the exact
  rendered duration and whose frame is the fixed duration slot. It is absent
  from production launches and does not participate in layout.
- Continue actionable semantic rows as `history.fast.<UUID>` inside
  `history.event-info-panel` / `history.list`.
- Extend `HistoryLabelWorkProbe` or a sibling inert test probe with duration
  tick, tick-during-motion, delayed-pulse coalescing, leaf invalidation,
  parent/carousel invalidation, projection, measurement, query and
  geometry-callback counters. Tests navigate by identifiers, not duration copy.
- Use `history.inferred.start`, a new stable stale-state container
  `history.inferred.cap-reached` and `history.inferred.return-to-history` for
  the open-sheet cap journey.

## Focused verification

Before the first Xcode test command, complete the repository test preflight in
`AGENTS.md`, record the exact simulator/security model and verify no other Xcode
test process is active.

1. Add pure duration tests for completed-minute flooring, active/current
   completed seconds, negative clamping, 24-hour-plus formatting, inferred cap,
   goal changes, time-zone changes and both London DST transitions.
2. Add state tests with the required controllable cadence driver and mutable
   test `AppClock` proving one shared cadence, uninterrupted tick delivery in
   every motion phase, lifecycle stop/resume, delayed-pulse coalescing and no
   replay.
3. Extend label projection tests for the precise below-one-day and finite
   fitting day-template set, 23:59:59→1d, 99→100 and 999→1,000 leaf transitions,
   first-nonfitting omission, documented fit priority,
   stable ordinary frames and unchanged one-per-ID/midpoint behavior.
4. Extend the BF-104 label-work probe test: five settled seconds and native
   motion lasting across at least three cadence boundaries must change only the
   duration value/leaf counters. The trace must contain successive duration
   values between motion begin/end events for tracking and deceleration, while
   projection, measurement, parent/carousel invalidation and geometry counters
   remain unchanged.
   Use the armed UI-test cadence script so event ordering is deterministic and
   the test does not attempt a second XCTest command during a blocking gesture.
5. Add/extend focused History UI journeys for one completed recorded fast, one
   historical inferred interval, one active recorded fast and one current
   inferred interval. Query `history.fast-duration-probe.<UUID>` and the scoped
   semantic row; do not use visible localized duration text for navigation.
6. Exercise inferred cap transition both in History motion and with the current
   conversion sheet open; assert the stable stale-state identifiers, disabled/
   absent Start action, racing-command revalidation and no mutation. Also cover
   midnight, AXXXL, RTL,
   pseudolocalization, foreground/background and sheet presentation.
7. Run `make project`, the smallest focused unit selections and only changed
   History UI tests during story work. Run `make lint` and `make analyze` after
   source changes. Do not run the full UI suite before source freeze.

## Prototype and performance observability gate

The first bounded implementation change adds the static duration slot and one
shared controllable pulse to the existing BF-104 deterministic fixture. Capture
the same baseline/candidate diagnostics used by BF-104 plus duration counters.

Pass requires:

- content width, day stride, initial offset and selected-day centre deltas each
  no greater than 0.5 points;
- no increase in initially appeared segments beyond BF-104's accepted baseline;
- exactly one pulse owner and no timer/task per interval, fragment or label;
- stable label and duration-slot frames across second/minute/hour/day changes;
- zero label input, title, metrics, projection or parent/carousel invalidation
  increments during five settled ticks and motion-spanning ticks;
- at least three sequential completed-second duration values recorded between
  native motion begin/end events, including tracking and deceleration;
- zero duration work inside scroll-geometry callback intervals even though
  duration ticks continue while the broader motion phase is active;
- a delayed pulse jumps directly to the correct `AppClock.now` value without
  replaying intermediate seconds;
- zero History query/reload, persistence or diagnostic events caused by ticks;
- duration-leaf tick signposts complete within 2 milliseconds each on the
  configured test destination, with no new main-thread stall of 100 milliseconds
  or longer overlapping a duration tick in the retained Points of Interest/Core
  Animation trace; compare against an otherwise identical scrolling baseline
  with the cadence script armed but duration-leaf invalidation disabled;
- one separately attributed presentation-generation increment is permitted for
  a cap transition only after settlement; it must record zero SwiftData
  query/persistence work and leave all runway/scroll geometry unchanged;
- fitting day-digit transitions and first-nonfitting omission increment only
  the duration-leaf counter, including during motion.

Preserve counter snapshots and the focused `.xcresult`. If any geometry or
projection invariant fails, stop before changing the carousel architecture and
use the focused-test circuit breaker; do not trade native scrolling for live
text.

## Source-frozen integration verification

After focused evidence and independent Sol story acceptance, freeze source and
run once:

- `make build`;
- `make test-unit`;
- `make test-ui` with all four XCTest workers;
- `make verify-ui-result UI_XCRESULT=<stable-result-path>`;
- `make lint`;
- `make analyze`.

Preserve exact commands, underlying exit codes, simulator destination,
worker-clone count, stable logs and `.xcresult` paths under
`.derived-data/sprint-results/`. Any later source or test-source edit invalidates
the integration result.

## Human build check

After the independent Sol implementation gate accepts the exact source, run
`make deploy-iphone` when the configured iPhone is connected and report:

`HUMAN BUILD CHECK REQUIRED — BF-105`

On the physical device:

1. Confirm previous recorded and inferred fast durations are readable at a
   glance without opening each fast.
2. Confirm active recorded and current inferred durations advance once per
   second while settled and while a finger remains down dragging slowly.
3. Perform at least ten gentle and ten fast swipes in both directions across
   midnight; confirm native inertia remains smooth while the duration continues
   counting during tracking and deceleration.
4. Confirm no tick shifts the label, changes the bar, flashes the date row or
   causes a visible hitch; if a pulse is delayed, confirm it moves directly to
   the current second without a burst of intermediate values.
5. Repeat once at accessibility Dynamic Type and once with an inferred fast
   approaching its cap.

Do not treat deployment as a human pass. A reported hitch reopens BF-105 as
`CHANGES REQUESTED` even if automated timing/probe checks pass.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| AC1 | Completed labels show stable whole-minute duration | Pure formatter/projection tests; focused recorded/inferred History UI | Goal/time advancement; reconstructed/legacy kind; narrow fit | Unit/UI result |
| AC2 | Current recorded and inferred timeline values advance each second in settled/moving phases; presented semantic leaf matches while hidden detail does not redraw | Pure/state tests; focused active/inferred UI using duration probes | Sub-second now, negative elapsed, 24-hour crossing, hidden detail | Unit/UI `.xcresult` |
| AC3 | Successive completed-second values appear during tracking, deceleration, alignment, programmatic and date-rail motion with leaf-only invalidation | Clock/motion state matrix; motion-spanning focused UI trace | Delayed pulse, sheet/background lifecycle, scroll callback overlap | Counter/trace snapshot + result |
| AC4 | Tick boundaries do not change descriptors, frames or BF-104 geometry | Label projection/state tests; UI frame snapshots | Second/minute/hour/day boundary, locale/Dynamic Type generation | Before/after snapshot |
| AC5 | Tick path has zero projection, measurement, query, persistence, callback, parent invalidation or diagnostic work and stays within the recorded 2 ms/no-stall budget | Extended inert probe/signposts; paired baseline/candidate trace; static analysis | Five idle seconds plus ten alternating swipes | Probe/Points of Interest/Core Animation trace + analyzer log |
| AC6 | Inferred duration clamps and performs at most one separately attributed non-persisting cap transition | Pure projector/state test; focused inferred UI | Cap reached during motion; clock passes cap by several seconds | Unit/UI result + counters + persistence assertion |
| AC7 | Open conversion loses Start at cap and racing command fails closed | Injected-deadline state test; focused inferred sheet UI | Cap while sheet visible/moving History; delayed scheduler | Unit/UI result + no-mutation assertion |
| AC8 | Exact format templates, fit/localization and VoiceOver behavior are bounded and singular | Pure metrics tests; AXXXL/RTL/pseudolocalized UI | 23:59:59, 24h, 99/100 days, narrow bar, London DST | Result + screenshots |
| AC9 | Existing timeline geometry, identity, actions and journeys remain unchanged | BF-104 unit/UI regression sets; event grouping and conversion journeys | Midnight, retained legacy, future selection | Focused result bundle |
| AC10 | Physical device retains smooth inertia while seconds visibly advance throughout motion | Device checklist on Sol-accepted build | Finger-down drag, deceleration, gentle/fast reversals, active/inferred variants | Human check record |
| AC11 | No data/schema/privacy/external boundary changes | Diff/schema audit; `make analyze`; Sol review | Existing stores and offline use | Diff + analyzer + Sol verdict |

## Downstream fixture and legacy-suite impact inventory

### Fixtures and launch configuration

- Reuse `--seed-history-fast-label-layout`, `--seed-history-midnight-seam`,
  `--seed-history-midnight-seam-extended` and `--seed-inferred-fast` with their
  existing stable UUIDs and meanings.
- Add the required injectable cadence driver and UI-test-only mutable clock
  controller/advance command plus bounded armable cadence script without
  altering production `AppClock` authority. Second, motion and cap acceptance
  tests must not sleep on wall time or issue a concurrent XCTest command during
  a native gesture.
- Preserve suppression, event-grouping, active-start and legacy History seeds.

### Pure/unit suites requiring deliberate review

- `uFastTests/TemporalRibbonLabelProjectionTests.swift`: duration slot, fit
  priority, stable frame and unchanged midpoint/identity/projection counts.
- `uFastTests/HistoryTextFormattingTests.swift` and
  `ActiveFastPresentationTests.swift`: completed-minute and active-second
  consistency, long durations, DST/time-zone invariance.
- `uFastTests/TemporalHistoryPresentationTests.swift`: continuous geometry,
  midnight, lanes, fit and motion phases remain stable.
- `uFastTests/HistoryMotionStreamingTests.swift`,
  `HistoryMotionAuthorityTests.swift`, `HistoryPresentationCacheTests.swift`
  and `HistoryPresentationModelTests.swift`: one pulse never becomes motion or
  data authority and cap refresh stays coherent.
- `uFastTests/HistoryInferredClassificationTests.swift`,
  `InferredFastProjectionTests.swift`, `HistoryDataProviderTests.swift` and
  `HistoryCaloricNeighbourOrderingTests.swift`: inferred state/cap/source and
  query behavior remain unchanged except explicit duration presentation.
- Localization catalog tests deliberately cover compact completed/current
  styles and pseudolocalized width without replacing semantic copy.

### UI suites requiring deliberate review

- `uFastUITests/HistoryUITests+FastLabelJourneys.swift` and
  `HistoryUITests+VisualRegressionJourneys.swift`: replace BF-104's explicit
  no-duration assertion with stable duration-slot assertions.
- `uFastUITests/HistoryUITests+ActiveFastJourneys.swift`: active semantic
  duration, midnight continuity, stable frames and continuous motion ticks.
- `uFastUITests/InferredFastUITests.swift`: historical/current duration and cap
  behavior while preserving save/start/delete/re-enable actions.
- `uFastUITests/HistoryUITests+AccessibilityJourneys.swift`,
  `BasicJourneys.swift`, `RecordJourneys.swift` and
  `HistoryUITests+TemporalSupport.swift`: selectors, singular VoiceOver
  semantics, Dynamic Type/RTL and probe helpers.
- `HistoryEventGroupingUITests`: expected unchanged; a failure is a regression,
  not permission to broaden fixtures.

### Compatibility and unrelated work

- Existing SwiftData schema versions, release-baseline migration fixtures,
  inferred suppressions, reconstructed/previously-saved/unavailable records
  and Delete All Data behavior remain unchanged.
- No `project.yml` change is expected unless a new source file requires normal
  regeneration with `make project`; never hand-edit the Xcode project.
- Preserve unrelated worktree edits and generated result artifacts.

## Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: existing BF-104 fixed fixture and geometry counters; injected cadence/clock advance; one shared pulse with motion-phase trace and leaf-versus-parent invalidation counters; identity-derived title and duration probes; inferred cap fixture; physical-device drag/swipe checklist
- Acceptance matrix and downstream fixture/legacy-suite impact: eleven AC rows above; label projection/formatting, History motion/cache/model, recorded/active/inferred/legacy UI, inferred conversion cap, localization/accessibility and event-grouping suites inventoried
- Focused correction budget: one bounded static-slot/shared-pulse prototype, then at most three focused corrections or 25 minutes on the duration/performance surface; one unchanged-source rerun only for an explicit flake hypothesis
- Expected expensive commands: focused History unit and changed UI tests during story work; `make project`, build/lint/analyze; one source-frozen four-worker `make test-ui` plus structural result verification; device deploy/check
- Maximum rescue tier: Terra, then Sol diagnosis

## Definition of Ready

- [x] User-visible duration precision, format roles and fit priority are explicit.
- [x] Historical, active recorded and current inferred behavior is bounded.
- [x] Continuous second updates during every History motion phase, delayed-pulse
      coalescing and inferred-cap behavior are deterministic and observable.
- [x] The cadence and UI clock are injectable; open-sheet cap behavior and
      racing-command revalidation fail closed.
- [x] Exact current formatting, finite premeasured day templates and overflow
      omission are bounded and observable without motion-time regeneration.
- [x] BF-104 label identity, geometry, native scrolling and performance
      boundaries are preserved.
- [x] Accessibility, localization, lifecycle, persistence and privacy boundaries
      are explicit.
- [x] Every acceptance criterion maps to a test surface and artifact.
- [x] Downstream fixtures, legacy suites and stable selectors are inventoried.
- [x] Prototype, correction budget, source-freeze gate and physical-device check
      are explicit.
- [x] Independent Sol readiness gate returns `READY` for the revised
      continuous-motion contract.

## Sol readiness gate

Sol gate: **READY** — `gpt-5.6-sol`, medium reasoning, for the user-directed
continuous-motion timer revision. The earlier verdict for motion suspension is
superseded.

The gate found continuous seconds during motion explicit and compatible with
D-021/D-022 because cadence never observes or controls scrolling authority. The
eleven acceptance criteria cover settled and moving duration, fixed geometry,
performance, inferred caps, localization, accessibility, regression behavior
and unchanged data boundaries. The pre-armed in-app cadence script provides
deterministic ordering against native tracking/deceleration without concurrent
XCTest commands or wall-time assertions, while leaf, parent, motion, callback,
cap, query and persistence counters provide attributable evidence.

The stable parent boundary, independently observing fixed-frame duration leaf,
premeasured fitting templates, clean overflow omission and motion-hidden detail
rows form a feasible architecture. The paired baseline/candidate trace,
2-millisecond leaf budget, 100-millisecond stall comparison and physical-device
checks make isolated invalidation and smoothness prototype acceptance gates
rather than assumed implementation facts.

Recommended initial implementer: Luna xhigh. Split required: no. Missing
evidence or contradictions: none. Required changes: none.
