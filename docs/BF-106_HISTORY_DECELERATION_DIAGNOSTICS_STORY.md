# BF-106 — Isolate History deceleration jitter

**Slice:** History visual reliability  
**Priority:** P1  
**Status:** Ready — independent Astra discovery-readiness gate, 5 September 2026  
**Type:** Bounded discovery and verification harness; no production optimisation

## User outcome and why now

Identify the work or positional transition responsible for the slight jitter
as the horizontal History timeline slows, so the next change targets an
observed cause and can be compared on the user's iPhone 17 Pro Max.

The user reports full battery and Low Power Mode off. The current review is in
[HISTORY_DECELERATION_PERFORMANCE_REVIEW.md](HISTORY_DECELERATION_PERFORMANCE_REVIEW.md).
Do not assume the duration-label change caused the issue.

## Rules, scope and boundaries

Read `PRODUCT.md`, `docs/MVP_SCOPE.md`, `DOMAIN_RULES.md`, D-018 through D-023,
D-038 and BF-104/BF-105. Preserve native continuous scrolling, exact fractional
settlement, local-calendar/DST identity, continuous labels, live duration
seconds, singular settled accessibility, and local-only data.

In scope: reproducible synthetic fixture/gesture protocol, explicit phase and
work instrumentation, paired device measurements, source/build attribution,
and one next implementation contract. Temporary profiling variants may suppress
one visual workload for diagnosis, but must stay isolated from release builds
and must never be reported as a completed product fix.

Out of scope: changing production scroll physics, arbitrary smoothing,
throttling fractional progress, pausing seconds, broad caches, asynchronous
persistence refactors, product semantics, migration, remote telemetry or
collecting/exporting the user's health records. Use synthetic local data in
an isolated test installation; never run reset/seed arguments on the user's
normal installed app or store.

## Reproduction and observability contract

1. Record device model, OS/app build, source manifest (HEAD, tracked diff and
   hashes of untracked source), configuration/optimisation, display settings,
   thermal state, battery/Low Power Mode, locale, time zone, Dynamic Type and
   Reduce Motion. Preserve existing work; build old-source comparisons from
   an isolated copy with separate build output. A known previous installed
   build must not be inferred from HEAD alone.
2. Begin with the existing `seedHistoryFastLabelLayout` and
   `seedHistoryMidnightSeam` launch configurations, fixed
   `2026-08-27T09:00:00Z`, `en_GB`, Europe/London. Record exact selected window,
   viewport and fixture arguments. Add deterministic dense/runway-extension
   data only if the baseline needs that stressor; freeze its contents/counts.
3. Run a lower-timeline gentle release in each direction with room before the
   loaded edge. Record coordinates as fractions of `history.day-carousel`,
   gesture duration/velocity where controllable and the same start window.
   Require observed native deceleration; a scripted drag that ends directly at
   idle is not evidence of this symptom. Capture fast flick/reversal, idle
   handover, and one loaded-edge crossing as separate scenarios.
4. Retain raw native phases and geometry timestamps without changing production
   phase coalescing. The existing presentation phase intentionally coalesces
   tracking/deceleration, so it is insufficient to locate native deceleration
   precisely. Separate the final 500 ms before native idle (or the complete
   deceleration if shorter) from the first 250 ms after idle. Do not add a
   display-link sampler or use per-frame accessibility queries to measure time.
5. Instrument fraction delivery/follower updates, chip-window preparation,
   label inputs/metrics/projection, page event/lane preparation, runway
   publication, exact-window fetch/projection and settlement reconciliation.
   Use bounded buffers/signposts; defer formatting/export until capture ends.
   Existing test probes append formatted trace strings per callback, so also
   measure with those verbose probes disabled. Do not mistake observer cost
   for production cost.
6. Profile a release-equivalent build on the reported device using SwiftUI,
   Time Profiler and animation hitches. Record missed frame deadlines/hitch
   duration by phase and raw frame timing, alongside content-offset, chip,
   label and page alignment evidence. Distinguish a slow frame from a spatial
   jump. Record the instrument/template/version and export procedure.
7. Use three paired blocks, each with ten alternating gentle swipes, fixed
   start conditions and one warm-up swipe excluded. Compare the frozen
   baseline with at most two single-variable diagnostic variants, selected
   from the review's hypotheses. Keep native input and observers identical.
   Repeat a case only for a recorded hypothesis or environment discrepancy.
   If no safe previous-source build exists, record historical attribution as
   unknown and use same-source diagnostic variants; do not claim a regression.

Physical input is repeatable by protocol, not guaranteed bit-for-bit
deterministic. Deterministic geometry replay and unit tests verify the
instrumentation; native device measurements establish the symptom.

## Acceptance criteria

1. **Reproducible baseline:** the manifest, fixture, gesture recipe and actual
   deceleration intervals are retained for the reported device. If the device
   is unavailable, record a blocked physical gate; simulator work cannot
   satisfy this criterion.
2. **Trustworthy observation:** instrumentation distinguishes fractional motion,
   coarse input generations and native idle; fixed replay verifies phase
   segmentation/counter attribution and bounded buffer behaviour. Normal
   launches emit no profiling records or new periodic work.
3. **Classified evidence:** each paired block reports frame/hitch measurements
   for the tail and idle transition separately, geometry continuity and
   expensive work attribution. Record `reproduced`, `not reproduced` or
   `inconclusive`, with artifacts. Non-reproduction is an honest discovery
   outcome, not permission to claim the symptom fixed.
4. **Bounded next decision:** select at most one proven optimisation surface,
   or record no justified change. If selected, the follow-on contract includes
   a replayable failing work/geometry invariant, exact affected boundaries,
   baseline measurements, a numeric device threshold set before implementation,
   repeatability allowance and negative/regression gates. Update BF-107 only
   if follower work is justified; otherwise leave it Draft. Historical regression
   attribution is separate and requires a matched prior-build comparison.
5. **Preserved behaviour and handoff:** diagnostics do not change scrolling,
   stores, clocks, action availability, labels or accessibility. Retain focused
   checks for changed harness/source and the final evidence summary; all
   temporary variants are removed or compile/launch-gated before acceptance.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | Manifest/recipe produces observed native deceleration | Existing History navigation/label fixture support; physical Pro Max | No deceleration or wrong build/device | Manifest, gesture recipe, trace |
| 2 | Correct phase segmentation and bounded diagnostics; production off | Focused pure instrumentation tests plus `TemporalHistoryPresentationTests` | Phase coalescing, truncated trace, no native idle, disabled diagnostics | Focused result, counter export, source review |
| 3 | Paired phase-specific timing and position results with explicit outcome | Instruments device capture, synthetic fixture | Tick, seam, loaded edge, cold versus warm | Three paired blocks, raw traces, analysis table |
| 4 | One testable next contract or evidence-backed no-change decision | Astra-authored follow-on planning artifact | No reproduction, conflicting attribution | Decision and predeclared threshold |
| 5 | Same semantics and release behaviour | Affected History motion/navigation/label tests; build/lint/analyze | RTL, DST, Reduce Motion, AXXXL, interruption | Focused results and source-frozen integration packet |

Stable selectors: `history.day-carousel` for lower swipes,
`temporal.date-navigator` for the independent control case,
`history.selected-date`, `history.month-heading`, `history.previous-day`,
`history.next-day`, `history.add-at-selected-time`,
`history.fast-label-probe.<UUID>` and `history.fast-label-layout-snapshot`.
Reuse existing semantic wait helpers; query geometry probes only outside timed
capture. Any new test-only consolidated counter probe uses
`history.scroll-performance-snapshot` and never receives hit testing.

## Fixture and legacy-suite impact

No domain invariant changes. Reuse BF-104/BF-105 label and midnight fixtures;
retain active/inferred/completed duration data and fixed-clock semantics.
Affected inventory: `TemporalHistoryPresentationTests`,
`TemporalRibbonLabelProjectionTests`, `BF105HistoryDurationTests`,
`HistoryMotionAuthorityTests`, `HistoryMotionStreamingTests`,
`HistoryPresentationCacheTests`, `HistoryUITests+NavigationJourneys`,
`HistoryUITests+ActiveFastJourneys`, `HistoryUITests+FastLabelJourneys` and
`HistoryUITests+AccessibilityJourneys`. Run only the portions touched by
diagnostics during discovery; do not rewrite fixture expectations to make
gestures pass. Persistent records, inferred suppression and editor routes
remain unchanged.

## Verification and execution

Complete repository Xcode preflight before test commands. Focused pure checks
precede changed UI tests. Build, `make lint` and `make analyze` apply if harness
or source changes. Any retained UI test changes require the repository's full
four-worker `make test-ui` once after source freeze and independent technical
review, followed by `make verify-ui-result UI_XCRESULT=<actual path>`. A
document-only outcome does not require a full suite. Physical profiling is
separate from the parallel UI correctness suite and must not overlap it.
Store logs/results/traces under `.derived-data/sprint-results/BF-106/` and a
concise durable findings document under `docs/` without raw personal data.

Execution profile:
- Uncertainty: high about the cause; bounded discovery output.
- Initial implementer: Luna xhigh under the existing execution workflow;
  authoring/readiness review uses Astra by explicit user override.
- Deterministic reproduction and observability: fixed synthetic state and
  geometry replay; recorded native-device protocol, not assumed identical
  gestures or simulator smoothness.
- Acceptance matrix and downstream fixture/legacy-suite impact: above.
- Focused correction budget: one baseline and at most two hypothesis variants;
  at most three failed focused corrections or 25 minutes without proven cause;
  one unchanged-source flake check. Return inconclusive evidence rather than
  extending into production trial-and-error fixes.
- Expected expensive commands: focused harness tests, build/lint/analyze if
  source changes, device profiling; one source-frozen UI suite only if required.
- Maximum rescue tier: Terra rescue, then read-only Sol diagnosis under the
  future implementation workflow; this does not change the user's Astra
  authoring/readiness override for these planning artifacts.

## Definition of Ready and review

- Discovery output is finite and permits an honest negative result.
- Physical baseline, phase-aware metrics and one follow-on decision are explicit.
- Native physics, persistence, privacy, clock and accessibility boundaries hold.
- No production fix is bundled with unresolved investigation.
- Astra readiness gate: **READY**, 5 September 2026, read-only
  `astra_scroll_review` (`gpt-6-astra`, high). No required corrections. The
  gate accepted the finite discovery outcome, raw-native-phase observation,
  observer-effect control, isolated synthetic store, paired measurements and
  explicit separation from a production fix. This is story readiness, not
  implementation or physical-performance acceptance.
- Sol not used for story writing/readiness, per the user's explicit
  instruction. Future implementation acceptance is separate.
