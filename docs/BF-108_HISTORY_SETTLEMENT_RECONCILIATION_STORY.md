# BF-108 — Keep settled History reconciliation off the first presentation frame

**Slice:** History visual reliability  
**Priority:** P1  
**Status:** Done — implementation, independent Sol acceptance, full regression
verification, physical capture and connected-device deployment completed 9
September 2026
**Type:** Bounded History presentation performance implementation

## User outcome and why now

When the lower History timeline slows to a stop on the user's iPhone 17 Pro
Max, the final frame should settle without the visible pause or jump currently
reported. The exact settled date, records and actions must still appear after
the native scroll reaches its final fractional position.

BF-106's lean correlated physical capture found a `116.682208ms` Core
Animation hitch duration overlapping native idle. The raw timeline shows the
settlement callback starting about `50µs` after idle, performing exact-window
fetch/projection for `7.830ms`, then publishing a new snapshot and continuing
page/follower preparation for about `53.7ms`. Geometry remained continuous and
there was no post-idle offset callback. The evidence implicates the
settlement-triggered snapshot/view rebuild, not fractional follower work; BF-107
therefore remains Draft.

Evidence and source path are recorded in
[BF-106 findings](BF-106_HISTORY_DECELERATION_DIAGNOSTIC_FINDINGS.md), with the
captured frame data in the retained BF-106 artifacts. This story does not claim
that BF-105 caused the regression.

## Authoritative rules and boundaries

Preserve PRODUCT's calm local-first interaction, DOMAIN_RULES' exact record
instants and local-calendar identity, and D-018/D-021/D-022/D-023's continuous
native motion, exact fractional settlement, settled-only actions and singular
presentation ownership. Preserve D-038 continuous label placement and the
BF-104/BF-105 label, clock and duration contracts.

The lower native carousel remains the owner of direct manipulation,
deceleration and final geometry. The upper rail remains decorative while the
lower surface moves, and settled accessibility/actions continue to use the
exact final visible window.

## Scope

In scope:

- Reduce or defer the synchronous settlement-triggered data/presentation
  replacement that blocks the first frame at native idle.
- Coalesce redundant settlement refreshes so one final visible window produces
  one authoritative reconciliation, with stale work unable to overwrite a
  newer settled window.
- Keep all SwiftData access and observable model mutation on the repository's
  existing safe execution boundary; do not introduce an unowned background
  model context.
- Add deterministic tests for ordering, coalescing and latest-window behavior,
  plus focused UI and physical performance evidence.

Out of scope:

- Native scroll physics, deceleration, snapping, fractional progress,
  throttling, pixel quantisation or display-link sampling.
- Fraction-only follower preparation; that is BF-107 and remains Draft.
- Broad cache rewrites, label-generation changes, page-lane redesign,
  persistence schema/migration changes, cloud sync, telemetry or health-data
  export.
- Hiding the problem by disabling live durations, actions, accessibility or
  settled details.

## Required behavior

After a lower-timeline release:

1. Native motion and final fractional geometry remain unchanged.
2. The first settled presentation frame is not blocked by the avoidable
   synchronous snapshot/view rebuild identified by BF-106.
3. The exact final visible interval is reconciled once after settlement and is
   reflected in the selected date, records, details, actions and upper-rail
   settled state.
4. If another release, reversal, interruption, lifecycle event or invalidation
   supersedes a pending reconciliation, the newest valid settled window wins;
   stale work cannot publish stale records or move geometry.
5. Empty, fetch-error, future/read-only, DST, midnight-seam, active-fast and
   mutation journeys retain their existing semantics.

## Acceptance criteria

### AC1 — Boundary frame improvement

Given the frozen BF-106 dense fixture on the iPhone 17 Pro Max in a
release-equivalent, source-frozen BF-108 candidate build, when one additional
gentle lower-timeline release is profiled with the native idle marker, the
implementation must have zero Core Animation lifetime records with
`hitch-duration > 33.34ms` overlapping the native-idle-to-`250ms` post-idle
window. It must also introduce no new `>33.34ms` hitch in the final `500ms`
native-deceleration tail. The single candidate trace contains one measured
gentle natural release using BF-106's fixed start conditions and trace setup;
no warm-up or repeated swipe is required for this reduced gate.

The captured BF-106 baseline is `116.682208ms` at the boundary, so this is a
predeclared device threshold rather than a post-hoc comparison. This revised
criterion deliberately requires one additional candidate capture rather than
the previously specified three paired predecessor/candidate blocks. The
retained BF-106 capture remains historical comparator evidence, not a same-day
paired control; this single-release gate therefore establishes a focused
reproduction check on the target device, not broad statistical device
coverage. A missing native boundary, dropped event, incomplete post-idle
window or unexplained hitch makes the capture inconclusive or failed; it is
not an outlier to hide.

### AC2 — Exact settled semantics and ordering

Given a settled visible window, when reconciliation completes, the selected
date, month heading, records, details, actions and upper rail represent that
exact window. Given two settlements or a reversal in quick succession, only
the newest valid window may become authoritative. Focused tests prove one
reconciliation per final window, no stale publication and the existing safe
last-complete-projection behavior on fetch failure.

### AC3 — Continuous native ownership

Given any gentle release, fast flick, reversal, loaded-edge crossing or
interruption, native deceleration remains continuous and can stop at an
arbitrary fractional position. The settled update introduces no second
animation, offset correction, geometry discontinuity or post-idle geometry
callback. The real rail, Previous/Next, picker, future boundary and settled
accessibility actions retain their existing ownership and timing.

### AC4 — Regression and state coverage

Given empty history, active and completed fasts, hydration/food records,
midnight and DST boundaries, future read-only selection, Reduce Motion, RTL,
AXXXL/Dynamic Type and a committed mutation, existing content, labels,
durations, exact record boundaries, persisted data and accessibility remain
correct after relaunch where persistence is part of the journey.

### AC5 — Verification and scope safety

Focused tests, build, lint and static analysis pass. The physical evidence
retains the source manifest, device/build settings, raw native markers,
geometry continuity, boundary frame table and exported artifacts. No diagnostic
source is active in a normal launch, and no unrelated production behavior is
changed.

## Architecture and data boundaries

The primary boundary is the `HistoryView` settled-window callback in
`uFast/Features/Fasting/HistoryView+Presentation.swift`, which currently calls
`HistoryPresentationModel.reloadHistory(in:)`. The reload and exact projection
implementation is in
`uFast/Application/HistoryPresentationModel+Data.swift`. The lower carousel's
movement and geometry ownership is in
`uFast/Features/Foundation/TemporalHistoryCarousel.swift` and must remain
unchanged unless a narrowly proven ordering hook is required.

The implementation may choose the smallest safe scheduling/coalescing design,
but it must preserve the exact settled interval and existing main-actor/
SwiftData safety. The settlement boundary must be represented by a main-actor
coordinator with an injected deterministic scheduler and an injectable settled
projection source. The callback may publish the geometry-derived settled
window, but it must enqueue reconciliation instead of synchronously fetching,
projecting and replacing the observable snapshot on the first idle callback.

The coordinator's window identity is the exact `TemporalRibbonWindow`
identity: interval start, interval end and selected local day. A duplicate
request for the same identity and invalidation generation coalesces. A newer
window, reversal, interruption or lifecycle invalidation supersedes the older
request; a same-window mutation/invalidation advances the generation and is a
fresh request. Every publication checks its request generation and window
identity, so stale work can only be discarded and can never change selection,
geometry or records. A failed fetch or projection retains the last complete
projection. All source access and observable mutation remain on the existing
main-actor/SwiftData boundary; no unowned background model context is allowed.

Focused tests must observe typed, test-only events for scheduled, started,
coalesced, superseded, failed, stale-discarded and published outcomes, each
including the window identity and request generation. These diagnostics remain
opt-in and test-only; they are not part of the product solution. No persistent
data or schema changes are allowed.

## Dependencies and decisions

- BF-106 supplies the correlated baseline, fixture, source/build identity,
  native phase markers and the `33.34ms` frame threshold. Its formal AC3
  matrix remains incomplete, but the single correlated sample is sufficient to
  scope this Draft implementation story.
- BF-107 remains Draft because BF-106 did not implicate fractional follower
  preparation.
- The change must not be attributed to BF-105 without a matched prior-build
  comparison; historical attribution remains unknown.
- No product decision changes D-018, D-021, D-022, D-023 or D-038. D-038 must
  be independently reviewed and promoted from Proposed to Accepted before the
  BF-108 implementation gate; BF-108 must preserve its label ownership and
  duration-leaf boundaries.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| AC1 | No boundary hitch over `33.34ms`; no tail regression in one additional candidate trace | BF-106 physical protocol with Animation Hitches/Core Animation lifetime export | Thermal/foreground discrepancy, no native idle, dropped events, incomplete window, unexplained hitch | One additional candidate raw trace plus retained BF-106 baseline, frame-lifetime exports, manifest and analysis table |
| AC2 | Exact final window publishes once and newest settlement wins | Focused model/coordinator tests; History navigation UI journeys | Reversal, interruption, same-window invalidation, fetch failure, stale task | Unit result, focused UI result, typed reconciliation-event snapshot |
| AC3 | Native fractional geometry remains continuous with no second animation | Existing motion/geometry tests and focused physical capture | Flick, loaded edge, seam, future boundary, Reduce Motion | Unit/UI result and raw geometry timeline |
| AC4 | Existing content, actions, labels, durations, persistence and AX remain correct | Temporal presentation, label/duration, History navigation, active-fast and accessibility suites | Empty, DST/midnight, RTL, AXXXL, mutation and relaunch | Focused result bundles and integration result |
| AC5 | Build/static checks pass and diagnostics stay opt-in | `make build`, `make lint`, `make analyze`, source review | Normal launch without diagnostic flags | Logs, result bundles, source diff and manifest |

Stable UI selectors are existing identifiers: `history.day-carousel`,
`history.selected-date`, `history.month-heading`,
`temporal.date-navigator`, `history.previous-day`, `history.next-day` and
`history.scroll-performance-snapshot`. Tests must scope queries to the relevant
scroll view or navigation container and use semantic waits.

## Downstream fixtures and legacy-suite impact

Reuse `seedBF106BusyHistory` for the performance gate and the existing fixed
clock, label-layout, midnight-seam, active-fast, inferred-fast and mutation
fixtures. Focused coverage should include the relevant portions of
`TemporalHistoryPresentationTests`, `HistoryScrollDiagnosticsTests`,
`BF106BusyHistoryFixtureTests`, `HistoryUITests+NavigationJourneys`,
`HistoryUITests+ActiveFastJourneys`, `HistoryUITests+FastLabelJourneys`,
`HistoryUITests+VisualRegressionJourneys`, accessibility journeys,
`BF105HistoryDurationTests` and label-projection tests. Existing persistence
and editor journeys remain required because settled details and actions depend
on the refreshed presentation.

No fixture expectation may be broadened to accommodate uncontrolled gestures.
No normal installed app data may be reset, seeded, uninstalled or inspected.

## Verification and human check

Complete the repository test preflight before Xcode commands. Run the smallest
pure/coordinator tests first, then changed UI tests. Run `make build`,
`make lint` and `make analyze` for source changes. After the source is frozen,
run one four-worker `make test-ui`, verify its result with
`make verify-ui-result UI_XCRESULT=<path>`, and obtain an independent Sol
integration decision. Do not use the UI suite as a smoothness benchmark.

Deploy the Sol-accepted build to the connected iPhone with
`make deploy-iphone`, then request a human check covering: one gentle release
in each direction, fast flick and reversal, loaded edge, midnight seam,
duration tick, final idle handover, exact selected date/details and a relaunch.
The human check is separate from Sol acceptance.

## Execution profile

- **Uncertainty:** medium; the presentation stall is measured, but the safest
  scheduling/coalescing boundary must preserve exact settled semantics.
- **Initial implementer:** Luna xhigh.
- **Deterministic reproduction and observability:** frozen BF-106 busy fixture,
  fixed instant `2026-08-27T09:00:00Z`, `en_GB`, Europe/London, Light mode,
  native phase markers, Core Animation lifetime export and exact-window
  ordering counters.
- **Acceptance matrix and downstream impact:** defined above; no migration or
  domain invariant change is expected.
- **Focused correction budget:** three failed corrections on one acceptance
  surface or 25 minutes without a proven cause; one unchanged-source flake
  check; then the implement-sprint circuit breaker.
- **Expected expensive commands:** focused unit/UI tests, build, lint,
  analyze, one source-frozen four-worker UI suite, device deployment and one
  additional candidate physical trace.
- **Maximum rescue tier:** one bounded Terra rescue, then read-only Sol
  diagnosis if the root cause or boundary remains unresolved.

## Completion record

BF-108 is complete. The accepted implementation and verification record is:

- AC1: one additional candidate Animation Hitches capture passed the declared
  `33.34ms` boundary and tail thresholds, with native markers, frame-lifetime
  export and geometry continuity evidence retained.
- AC2–AC4: focused coordinator/model coverage and the complete four-worker UI
  suite passed (`150/150`, `0` skipped, `0` failed, every test exactly once).
- AC5: build, lint, static analysis and source-freeze checks passed; the
  independent Sol integration gate returned `ACCEPTED`.
- The Sol-accepted build was installed on the connected iPhone. The final
  launch was deferred only because the device was locked at deployment time;
  this does not leave an implementation or test blocker.

Evidence:

- [full UI result](/Users/david/uFast/.derived-data/sprint-results/BF-108/integration-correction-01/full-ui.xcresult)
- [full UI log](/Users/david/uFast/.derived-data/sprint-results/BF-108/integration-correction-01/full-ui.log)
- [physical analysis](/Users/david/uFast/.derived-data/sprint-results/BF-108/physical-final/one-candidate-manual-04/physical-analysis.md)
- [corrected source freeze](/Users/david/uFast/.derived-data/sprint-results/BF-108/integration-correction-01/source-freeze-id.txt)

## Definition of Ready (historical)

This story is **Draft** until an independent Sol readiness gate confirms that
the threshold, scheduling boundary, latest-window ordering, fixture impact and
negative paths are implementable without changing native motion or settled
semantics. It must remain separate from BF-107. Once Sol returns `READY`, the
story may be promoted and run through `$implement-sprint`; until then, no
production implementation should start.

**Sol gate:** READY — 8 September 2026. D-038 was independently reviewed and
accepted; the implementation contract and revised single-capture AC1
accounting are now explicit.
