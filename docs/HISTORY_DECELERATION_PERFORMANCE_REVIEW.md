# History deceleration performance review

**Reviewer/author:** Astra, 5 September 2026. Independent read-only Astra source
review also performed; user explicitly overrides the Sol story-authoring gate.

## Finding

There are credible opportunities to reduce History presentation work. Source
inspection does **not** establish which causes the reported slight jitter, or
whether BF-105 introduced it. Measure the final part of native deceleration
separately from the first settled update before choosing a fix.

The user observes this when scrolling the lower History timeline horizontally
on an **iPhone 17 Pro Max**, full battery, Low Power Mode off. OS version, app
build, accessibility settings and reproducible record/window remain unrecorded.

Reviewed baseline: `5e7eed1c1a4fb2eb44fa252dd5170652aa940cae` plus the existing
uncommitted BF-105 changes and untracked duration files. This is a source review,
not an Instruments capture or physical-device reproduction. No source, tests,
project configuration or existing decision edits were changed by this review.

## Ranked opportunities

| Surface | Source evidence | Improvement to investigate | Attribution and limit |
| --- | --- | --- | --- |
| Continuous follower rail | `TemporalDateNavigator.coupledFollower` performs `dates.firstIndex`, makes an array of up to 18 dates and calls `followerChip` on fractional preview evaluations; chips perform calendar checks and weekday formatting | Prepare an indexed, stable chip window on day/environment changes; keep fractional movement to offset updates in a narrow observation boundary | Existing committed code; relevant body traced to `140abd7a`, 10 August. Actual SwiftUI evaluation frequency and frame cost need measurement |
| Direct rail geometry | `dateChipGeometry` emits a dictionary of chip positions; `onPreferenceChange` writes the dictionary to `@State`, although `settleManualRail` consumes it only at idle | Keep settlement-only geometry in a non-observed snapshot; preserve selected-chip anchor observation separately | Existing code. Mainly direct upper-rail scrolling; lower-timeline relevance may be limited to reconciliation. Do not treat as the primary reproduction |
| Label generation | `TemporalContinuousDaySpaceResolver.coordinate` calls `isValid`, which walks all adjacent days with Calendar, and then searches the days for each endpoint. BF-105 `durationTemplateWidths` projects endpoints again to find maximum bar widths | Validate/index immutable day space once per generation; reuse projected bounds between fit preparation and descriptor projection | Resolver predates BF-105 (`a06a7fd1`, 28 August); BF-105 adds callers. O(intervals × days) calendar validation is a scaling risk during generation, **not proven per-frame work** |
| Lazy page preparation | Each `daySegment` receives the full motion arrays. `groupedEventPresentation` maps all events. `pageGeometry` calls `clip`, which sorts inputs then calls `laneAssignments`, which sorts again | Reuse generation-scoped lane/order information and bounded page input when measurements show page creation is expensive | Existing path; newly appearing pages and growing history are likely stress cases. Preserve global lane assignment before page clipping |
| Transition to idle | `setMovementPhase(.settled)` calls `settleVisibleGeometry`; `onSettledVisibleWindow` synchronously calls `model.reloadHistory`, fetching SwiftData and producing exact presentation. Selection/follower reconciliation follows; BF-105 may also consume a pending cap transition | Measure fetch, exact projection, layout and follower handover individually; only then choose deduplication, ordering or asynchronous preparation | Source proves synchronous work, not duplicate loading or a hitch. A last-frame/idle jump must not be confused with continuous deceleration |

`TemporalRibbonLabelLayer.updateProjectionIfNeeded` also resolves/localizes
inputs before its generation equality guard. A cheap input-generation guard
could avoid repeated preparation when multiple input notifications describe
one effective generation. This belongs with label preparation if that surface
is measured, not automatically with the follower work.

## What the latest change improves

The working diff removes `TimelineView(.periodic(..., by: 1))` around History
details, returns the cached live presentation, uses loaded motion intervals,
and passes a stable pulse reference to duration leaves. These changes are
consistent with reducing broad clock-driven work. The new one-second leaf
updates and duration-template preparation remain profiling candidates, but a
timer's presence alone is not evidence of jitter.

The carousel geometry snapshot is already a **non-observable reference** stored
in `@State`. Writing `geometrySnapshot.geometry` is not the same as publishing a
value-type `@State` change every frame. The fractional preview is already read
by a separate follower overlay. Preserve these successful isolation boundaries.
Do not throttle positional updates, quantise the offset, add snapping, change
native physics, or pause the required duration clock to conceal the symptom.

## Evidence gap

BF-104/BF-105 tests verify projection counts, label geometry, identity and clock
isolation. BF-105's written performance gate includes a two-millisecond leaf
budget and no new 100-millisecond stall overlapping a tick. Those protections
do not establish smoothness across short frame deadlines in the deceleration
tail, nor detect a purely positional discontinuity with no long stall.

The inspected `BF-105-final-layout/ribbon-summary.json` records two passing
tests on an iPhone 17 Pro **simulator**, iOS 26.0.1. It is historical functional
evidence, not a current-source performance pass or a Pro Max device comparison.
No new build or tests were run for this document-only review.

Use SwiftUI Update Groups/cause-and-effect, Time Profiler and animation hitch
tracks to distinguish unnecessary updates, expensive work and missed render
deadlines. Apple describes these instruments in
[Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)
and [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/).
Record actual frame deadlines/refresh behaviour; do not assume a fixed refresh
rate from the phone model or use average FPS as the sole result.

## Action

- [BF-106](BF-106_HISTORY_DECELERATION_DIAGNOSTICS_STORY.md) establishes a
  bounded device baseline, isolates the responsible surface and defines a
  measurable implementation contract.
- [BF-107](BF-107_LIGHTWEIGHT_HISTORY_FOLLOWER_STORY.md) captures the leading
  bounded implementation candidate: eliminate repeated follower preparation
  on fraction-only updates. It remains Draft until the first story supports
  this choice and freezes the physical acceptance threshold.

If profiling instead identifies label generation, page materialization or
settlement as the important cost, keep BF-107 Draft and write/refine a separate
bounded story for that proven surface. Do not bundle all five opportunities
into one speculative rewrite. Attribution to the last fix requires a matched
source/build/data comparison; commit history alone cannot answer it.

The 8 September 2026 lean iPhone 17 Pro Max capture now identifies settlement
as the important cost surface for this report: a `116.682208ms` Core Animation
frame hitch overlaps the native idle boundary, while the raw timeline shows
the synchronous exact-window reconciliation immediately after idle. This is a
diagnostic baseline, not permission to edit production code. Keep BF-107 Draft
and scope the next implementation story to reducing or deferring the
settlement-triggered snapshot/view rebuild, with the captured frame boundary,
no-offset-jump invariant and a predeclared device threshold as gates.
