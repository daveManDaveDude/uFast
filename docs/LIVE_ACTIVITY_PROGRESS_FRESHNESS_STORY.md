# LA-101 — Keep Live Activity goal progress truthful while suspended

**Epic:** Lock Screen fasting surface reliability  
**Priority:** P1  
**Status:** Ready  
**Estimate:** 3 points  
**Prepared:** 13 August 2026  
**Depends on:** OW-L105, D-029, D-030 and the in-progress WS-102 privacy fix

## User story

As a user glancing at an active fast on the Lock Screen, I want every displayed
progress value to remain current while uFast is suspended, so that the elapsed
timer, progress track and supporting copy do not contradict one another.

## Why now

Physical-device evidence shows a Live Activity with **Elapsed 6:56:17** for a
16-hour goal while its copy still says **5 percent of 16-hour goal**. Six hours
and 56 minutes is about 43% of that goal, so the fixed label is materially stale.
Opening uFast from the Live Activity and returning to the Lock Screen refreshes
the label, but a glanceable system surface must not require that workaround.

## Confirmed cause

- `ActiveFastActivityTimerView` uses `Text(contentState.startDate, style: .timer)`;
  iOS advances that text without executing uFast.
- The visual track uses `ProgressView(timerInterval:countsDown:)`; iOS advances
  that date-relative progress while the app and extension are suspended.
- `ActiveFastActivityDetailView` separately calls
  `ActiveFastActivityPresentation.make(... now: .now)` and renders the resulting
  integer with ordinary `Text`. That integer is captured when SwiftUI archives
  the Live Activity view and has no supported clock-driven input afterward.
- Foreground reconciliation creates content with a new `generatedAt` date and
  calls `Activity.update`. That content update re-evaluates the view, explaining
  why tapping the activity makes the percentage catch up.

Relevant implementation seams:

- `LockScreenWidget/Widget/ActiveFastActivityWidget.swift`
- `LockScreenShared/ActiveFastActivityProjection.swift`
- `uFast/Domain/ActivityKitLiveActivityClient.swift`
- `uFast/Domain/ActiveFastLiveActivityCoordinator.swift`
- `uFastTests/ActiveFastActivityProjectionTests.swift`

## Platform constraint and settled fallback

Live Activities do not receive WidgetKit timelines. Dynamic content changes come
from an app `Activity.update` call or an ActivityKit push notification. uFast has
no server and BR-40 forbids timer polling, background restart chains and APNs.
Public date-relative SwiftUI primitives can keep a timer and progress track
moving, but an ordinary percentage `Text` is not date-relative.

Luna must first perform a narrowly time-boxed check of the iOS 26 public SwiftUI
date-relative `ProgressView` APIs already supported by the deployment target:

1. If a public, system-rendered current-value label displays a numeric percentage
   and remains correct on a physical iPhone with uFast suspended, use it.
2. Otherwise apply the settled fallback: remove the time-varying numeric
   percentage from the Live Activity and replace it with stable goal context,
   such as **16-hour goal**, while retaining the system-driven elapsed timer,
   date-relative progress track and target time.

The fallback is part of this Ready story and does not require another product
decision. A stale numeric percentage must never be retained merely to preserve
the prior layout. Do not simulate freshness with `Timer`, `TimelineView`, app
background modes, repeated `Activity.update` calls, APNs or a server.

## In scope

- Make the Lock Screen Live Activity internally consistent while uFast is
  foregrounded, backgrounded, suspended or terminated.
- Keep the date-relative elapsed timer and progress track as the visual sources
  of time-varying truth.
- Use a genuinely system-driven numeric percentage only if physical-device
  evidence proves it remains current without app or extension execution.
- Otherwise replace every fixed visual percentage in the Lock Screen Live
  Activity with stable goal copy that cannot become stale.
- Remove stale percentage values from the visible, non-redacted VoiceOver
  summary. Preserve one coherent, non-recurring accessibility experience using
  system-driven semantics where reliable and stable goal/target context
  elsewhere.
- Preserve privacy redaction from WS-102: redacted accessibility exposes only
  **uFast. Opens uFast.**
- Preserve the existing Dynamic Island compact, minimal and expanded regions.
  Their date-relative circular progress must continue to advance.
- Update the OW-L105 presentation/allowed-content wording and any accepted
  decision text that currently promises a continuously current numeric Live
  Activity percentage if the settled fallback is used. Do not change the
  WidgetKit percentage contract; WS-101 handles widget timeline freshness.

## Out of scope

- Changing the authoritative `FastRecord`, goal calculation, target instant,
  ActivityKit content schema or Live Activity lifecycle policy.
- Adding network access, remote push, background tasks or modes, notifications,
  polling, per-minute/per-second persistence, timers in the extension or a
  server dependency.
- Adding a Live Activity timeline; ActivityKit does not use WidgetKit timelines.
- Redesigning the Live Activity, adding a widget family or changing the
  Dynamic Island region inventory.
- Changing the Today progress view or Home/Lock Screen widgets.
- Automatically claiming **Goal time reached** without a legitimate app
  execution observing the target under the existing contract.

## Product rules

BR-28, BR-33, BR-34, BR-36 and BR-40 through BR-42. Preserve D-029 and D-030's
local-only, disposable and non-authoritative ActivityKit lifecycle.

## Acceptance criteria

1. Given a newly requested Live Activity below goal, when uFast is backgrounded
   and then suspended for long enough to cross at least two whole-percentage
   boundaries, then no visible numeric or spoken percentage remains at its
   request-time value while the elapsed timer and progress track advance.
2. Given a public system-driven percentage treatment is selected, when it is
   observed on a physical iPhone with uFast suspended, then it agrees with
   `floor(clamp((now - start) / (target - start), 0...1) * 100)` at each sampled
   boundary without an `Activity.update` call or app/extension execution.
3. Given that physical proof cannot be produced, then the Live Activity shows no
   time-varying numeric percentage and instead shows stable goal context such as
   **16-hour goal**; the date-relative progress track remains visible and moving.
4. Given the screenshot scenario of a 16-hour goal at approximately 6 hours 56
   minutes elapsed, then the Live Activity cannot present **5 percent** or any
   other request-time percentage alongside the current timer.
5. Given uFast is reopened from the Live Activity and foreground reconciliation
   runs, then the layout remains semantically consistent and does not depend on
   that foreground event to repair misleading copy.
6. Given VoiceOver focuses the visible Live Activity after time has advanced,
   then it does not announce a captured request-time percentage. It exposes
   current system-driven time/progress semantics where supported plus stable
   goal/target context, without recurring announcements.
7. Given privacy redaction is active, then VoiceOver exposes only **uFast. Opens
   uFast.**, with no elapsed, percentage, goal, target or reached-state detail.
8. Given progress is before start, at target or beyond target, then the visual
   track remains clamped from 0% through 100%, elapsed continues truthfully, and
   no celebration, warning, biological claim or progress above 100% appears.
9. Inspection proves the fix adds no timer/polling loop, background mode,
   WidgetKit timeline for the Live Activity, APNs, server, network request,
   persisted tick or repeated scheduled `Activity.update` call.
10. The compact, minimal and expanded Dynamic Island presentations still build,
    deep-link to `ufast://fast/current` and retain their system-driven progress.

## States and edge cases

- New fast, backdated fast and a corrected start or changed goal after commit.
- Below goal, exact target and beyond goal.
- Foreground, background, suspended and terminated app states.
- Privacy visible/redacted and Always-On reduced luminance.
- 8-hour and 24-hour goals, London daylight-saving boundaries and display
  time-zone changes; calculations continue to use absolute instants.
- Activity dismissal or the eight-hour system ending remains independent of the
  authoritative fast and is unchanged by this story.

## Data and privacy

This story changes presentation only. It adds no stored field, permission,
telemetry, identifier, network traffic or health data. Existing ActivityKit
content remains the validated local start, target, whole-hour goal, record
identifier, schema version and generation date.

## Design and content

- Preserve **uFast** and **Elapsed** as the primary hierarchy.
- Preserve the existing system-driven timer, calm progress track and target.
- If the fallback is used, prefer the stable copy **[n]-hour goal** in the space
  that currently contains **[n] percent of [goal]-hour goal**. It communicates
  the denominator without pretending to be a live numerator.
- Meaning must not depend on color or the Dynamic Island being present.
- Do not add **fast** or **fasting** to system-surface copy.

## Implementation guidance

- Keep the pure projection percentage calculation for deterministic domain and
  validation tests; the bug is the use of its sampled value as indefinitely live
  Lock Screen text.
- Separate stable Live Activity detail/summary copy from sampled presentation
  fields so a future foreground content update cannot reintroduce a frozen
  percentage accidentally.
- Prefer a small pure helper for fallback detail and accessibility copy, with
  injected locale/time zone where formatting is involved.
- Coordinate with the current WS-102 edits in
  `ActiveFastActivityWidget.swift` and `ActiveFastActivityProjection.swift`.
  Preserve those privacy changes and do not revert unrelated work.

## Verification

- Add unit tests for the stable fallback detail and visible/redacted
  accessibility summaries at below-goal, target and beyond-goal instants.
- Add a regression test proving request-time presentation data cannot produce a
  visual or accessibility percentage in the fallback Live Activity detail.
- Preserve existing projection math, validation, lifecycle and reconciliation
  tests.
- Use an ActivityKit preview to review 8-, 16- and 24-hour layouts, including
  compact widths and large accessibility text.
- Required physical-device regression:
  1. start or backdate a 16-hour fast;
  2. show its Live Activity and record the initial state;
  3. background uFast and leave it suspended across two whole-percentage
     boundaries;
  4. capture the Lock Screen before reopening uFast;
  5. confirm the timer and track advance and that no stale percentage is visual
     or spoken;
  6. tap through to uFast, return to the Lock Screen and confirm no semantic
     repair was necessary.
- Run `make project`, `make format`, `make build`, `make test-unit`, `make lint`
  and the full parallel `make test-ui` suite. Before `make test-ui`, verify no
  other `xcodebuild` test run is active; inspect the `.xcresult` for every test
  exactly once and all four worker clones.
- If a configured iPhone is connected, deploy the verified build with
  `make deploy-iphone`.

## Done when

The Live Activity never contradicts its advancing elapsed timer and progress
track with a captured percentage, the suspended-device regression passes, the
WS-102 privacy behavior is preserved, affected product documentation is honest,
and the repository Definition of Done passes.

## Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable correction.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] The public-API feasibility branch has a settled fallback, so no material
  product question remains unresolved.
