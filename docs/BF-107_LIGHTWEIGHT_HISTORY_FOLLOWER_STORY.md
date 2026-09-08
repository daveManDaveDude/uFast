# BF-107 — Keep fractional History follower updates lightweight

**Slice:** History visual reliability  
**Priority:** P1  
**Status:** Draft — depends on BF-106 device evidence  
**Author:** Astra, 5 September 2026

## User outcome and context

Reduce avoidable presentation work while the lower History timeline slows,
preserving its continuously coupled date rail and exact native resting position.
The leading source-level opportunity is in `TemporalDateNavigator.coupledFollower`:
fractional preview evaluations search the complete date array, allocate the
same bounded date window and prepare chips whose content has not changed.

See [the review](HISTORY_DECELERATION_PERFORMANCE_REVIEW.md) and
[BF-106](BF-106_HISTORY_DECELERATION_DIAGNOSTICS_STORY.md). The reported symptom
has not been profiled on the user's iPhone 17 Pro Max. This candidate is **not
ready for implement-sprint** until discovery proves the surface matters and
sets the physical performance threshold. Do not claim the last fix caused it.

## Authoritative rules and scope

Preserve PRODUCT's calm local-first interaction, DOMAIN_RULES' absolute record
instants, D-018/D-021's native fractional motion and exclusive ownership,
D-022/D-023's settled action semantics and BF-104/BF-105 label/clock contracts.
Do not resolve unrelated historical heading behaviour or amend D-038's existing
review status as part of this work.

In scope: a generation-scoped follower chip window/index and a narrow
fractional-offset rendering boundary. Reuse stable chip values while only the
fraction changes. Rebuild on actual window/day identities or relevant
environment/presentation inputs, not on each fractional value. Use supported
SwiftUI composition and existing calendar/day-space types.

Out of scope: native scroll implementation, deceleration speed, snapping,
position throttling or pixel quantisation; lower ribbon/page or label caches;
settlement fetch scheduling; direct-rail geometry snapshot changes; persisted
schema/data; inferred-fast rules; disabling live durations; broad refactoring.
Other proven costs require a separate story.

## Proposed acceptance criteria

1. **Fraction-only path:** for 1,000 valid changing fractions with unchanged
   leading/trailing dates and generation, follower offset changes according to
   the existing measured-stride equation. After initial preparation there are
   zero full-runway searches, window-array rebuilds or chip text/calendar
   preparations caused by fraction-only updates. Do not assert zero SwiftUI
   rendering or framework layout work.
2. **Correct invalidation:** entering another adjacent-day pair, reversing at
   its seam, extending/rebasing the runway, or changing locale/calendar/time
   zone/layout direction, Dynamic Type, selection/style inputs or measured chip
   geometry produces current chip content and correct offset. A cached window
   never outlives its input generation; invalid/missing adjacency produces the
   existing safe absence of preview, never a stale chip or crash.
3. **Continuous ownership:** native lower scrolling remains free to stop at an
   arbitrary fraction. Selection/actions remain settled-only; follower chips
   remain decorative, non-hit-testable and absent from VoiceOver. Real rail,
   Previous/Next, picker, future boundary and interruption behaviour remain
   unchanged. Reconciliation introduces no second animation or position jump.
4. **Device improvement:** meet the phase-specific numeric threshold and
   repeatability allowance selected and recorded by BF-106 **before source
   implementation**. Compare the same manifest/fixtures across three paired
   blocks; retain raw tail/idle traces. Require no geometry discontinuity or
   regression in the separate idle transition, seam and loaded-edge controls.
   Threshold and baseline are deliberately unresolved; this keeps the story
   Draft. A work-counter reduction alone does not prove the user jitter fixed.
5. **Regression safety:** label identity, duration progression, exact record
   boundaries, page stride/content extent, persisted data and independent
   manual rail semantics remain unchanged. Pass focused regressions and the
   repository integration gate; record the user's physical-device check.

## Architecture and data boundaries

Likely boundaries: `TemporalDateNavigator.swift`, narrowly related
`TemporalRibbonSupport.swift` presentation state, and existing pure temporal
progress types/tests if an indexed window value is needed. Keep frequently
changing preview reads in the follower leaf; do not move them into History's
parent or back into the lower carousel. Do not pass SwiftData models to a
background task. Cache only disposable immutable presentation values, scoped
to the visible History generation; no persistent or globally growing cache.

Exact cache inputs must be enumerated in implementation review, including
available day identities, locale/calendar/time zone/direction, selected and
read-only styling, dimensions and accessibility size. Native transform updates
must continue at the delivered geometry cadence. No timer, new permission,
network, health data export or migration is required.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | 1,000 fractions change offset with zero repeated preparation | Focused pure follower-state tests and BF-106 instrumentation | Same pair reversed; invalid fraction | Replay/counter result and trace |
| 2 | Generation changes refresh correct content/offset | `TemporalHistoryPresentationTests` and focused new follower tests | London DST, RTL, rebase, missing neighbour, AX sizing | Unit result and input-key review |
| 3 | Continuous native settlement and singular semantics | `HistoryUITests+NavigationJourneys` and accessibility journeys | Date chip/picker, interruption, future boundary | Focused UI result and device recording |
| 4 | Predeclared device timing threshold passes | BF-106 protocol on iPhone 17 Pro Max | Idle, edge publication, seam, tick overlap | Paired raw traces and analysis |
| 5 | Existing data/labels/actions and full runtime remain valid | Label/motion/cache unit suites, focused UI then full integration | Current inferred cap, completed fast, manual rail | Result bundles, structural verifier, human record |

## Fixture inventory and verification

Reuse `seedHistoryFastLabelLayout`, `seedHistoryMidnightSeam`, the existing
fixed-clock History navigation journeys and any BF-106 frozen stress fixture.
No seed/domain expectations change. Inspect `TemporalHistoryPresentationTests`
(measured strides, RTL, seam/reversal, selection ownership, DST),
`HistoryMotionAuthorityTests`, `HistoryMotionStreamingTests`,
`HistoryPresentationCacheTests`, `TemporalRibbonLabelProjectionTests`,
`BF105HistoryDurationTests`, and History navigation, active-fast, fast-label
and accessibility UI journeys. Select focused cases based on affected paths.

Selectors: lower swipe in `history.day-carousel`; independent rail in
`temporal.date-navigator`; real chip `temporal.date.<timestamp>`; settled
`history.selected-date` and `history.month-heading`; existing previous/next,
picker and add identifiers. Reuse BF-106's test-only counter snapshot outside
timed capture; do not add accessibility elements to decorative follower chips.

Use repository test preflight and deterministic pure replay before changed UI
tests. Run build, `make lint`, `make analyze`; after acceptance/source freeze,
one four-worker `make test-ui` and `make verify-ui-result` against its stable
bundle. Do not use the parallel suite as a physical smoothness benchmark.
Deploy the verified source using the repository device workflow, then request
the human check: gentle lower-timeline release in both directions, fast flick
and reversal, midnight seam, duration tick and final idle handover on the Pro
Max. Successful deployment alone is not a human pass.

## Dependencies, execution profile and readiness

Dependency: BF-106 selects this surface, supplies frozen fixture/source
baseline and device threshold. Existing uncommitted BF-105 work must be
preserved and identified; do not treat an old result as acceptance of later
changes. No new product decision is proposed.

Execution profile:
- Uncertainty: medium for the candidate; physical relevance unresolved.
- Initial implementer: Luna xhigh after promotion to Ready; Astra authors and
  reviews readiness under the user's explicit override.
- Deterministic reproduction and observability: 1,000-fraction replay,
  generation counters and BF-106 matched device protocol.
- Acceptance matrix and fixture/legacy-suite inventory: above.
- Focused correction budget: three failed corrections or 25 minutes without
  proven cause; at most one unchanged-source flake rerun; stop on scope growth.
- Expected expensive commands: focused unit/changed UI, build/lint/analyze,
  paired device capture, one source-frozen full UI suite and device deploy.
- Maximum rescue tier: Terra, then read-only Sol diagnosis under the future
  implementation workflow; authoring/readiness remains Astra for this request.

Definition of Ready: the bounded scope, selectors, negative paths and
generation invariant are specified; BF-106 cause evidence, physical baseline,
numeric threshold and Astra readiness decision remain required. Do not start
implementation or imply acceptance until these are resolved.

Independent Astra readiness gate, 5 September 2026:
**BLOCKED for implementation; Draft capture appropriate**, read-only
`astra_scroll_review` (`gpt-6-astra`, high). No document corrections required.
The operation-count contract and boundaries are clear; BF-106 device
attribution, baseline and a predeclared numeric performance threshold are
required before promotion. Sol was not used for story authoring/readiness.
