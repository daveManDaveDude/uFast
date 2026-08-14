# CR-201 — Close release metadata and derived-surface integrity gaps

**Status:** Ready 14 August 2026  
**Priority:** P1 (one P1 packaging finding and two P2 integrity findings)  
**Estimate:** 3 points  
**Milestone:** Launch and stabilise  
**Depends on:** Delivered History motion loading and Live Activity reconciliation

## User story

As a uFast user installing and using the release build, I want its embedded
widget and derived fasting surfaces to agree with the containing app and its
authoritative local state, so that the archive is accepted and background
presentation never contradicts the app when time or fast authority is
ambiguous.

## Review findings

This story closes three independent code-review findings in one bounded
release-hardening change:

1. `LockScreenWidget/Widget/Info.plist` hard-codes the extension short version
   as `1.0` while the containing app derives `1.0.0` from
   `MARKETING_VERSION`. App Store validation requires the embedded extension's
   short version to match its containing app.
2. `SwiftDataHistoryMotionRangeLoader` builds background motion snapshots with
   `Date.now`, while settled History uses the `AppClock` injected into
   `HistoryView`. A fixed or otherwise controlled clock can therefore produce
   two answers for the same active fast.
3. `ActiveFastLiveActivityCoordinator.reconcile()` returns immediately when
   active-fast resolution throws. Existing ActivityKit records and lifecycle
   metadata can then continue presenting one record even though local fast
   authority is ambiguous.

All three findings concern derived or packaging state. The story changes no
valid fasting record, History rule, consent choice, widget content, or Live
Activity eligibility policy.

## Outcome

The widget extension derives its short version from the same project setting
as the app. Every History presentation created for one motion load uses an
explicit reference instant supplied from the view's injected clock. Live
Activity reconciliation treats an active-fast resolution error like a
fail-closed authority state: it ends every derived ActivityKit record it can
observe and clears lifecycle metadata while leaving all SwiftData records
untouched.

## In scope

- Replace the widget extension's literal `CFBundleShortVersionString` with
  `$(MARKETING_VERSION)` in its source Info.plist.
- Verify the generated archive/build settings resolve the app and embedded
  widget to the same short version. Keep `project.yml` as the authoritative
  marketing-version setting.
- Add an explicit `referenceNow: Date` input to the History motion range load
  boundary and use it for `HistoryPresentationBuilder.build`.
- Capture the reference instant from `HistoryView.clock.now` before starting
  asynchronous initial, extension, and refresh work, then pass that value into
  the loader. A refresh of several retained chunks uses one captured instant
  for every chunk in that replacement transaction.
- Keep `SwiftDataHistoryMotionRangeLoader` background-safe: pass a `Date`, not
  an `AppClock` existential or SwiftUI state, across the actor boundary.
- On any error from `resolveActiveFast()` during `reconcile()`, query the
  current ActivityKit records, attempt to end all of them with the existing
  immediate cleanup path, and clear all Live Activity lifecycle metadata.
- Preserve the existing non-throwing, idempotent reconciliation result and
  ActivityKit failure isolation.
- Add focused regression tests for resolved version values, injected History
  time, multi-chunk time consistency, and ambiguous-authority cleanup.

## Out of scope

- Changing `MARKETING_VERSION`, release numbering policy, bundle identifiers,
  signing, entitlements, or widget families.
- Changing `CFBundleVersion` under this review finding unless separate archive
  evidence establishes a requirement.
- Passing `Date.now`, `SystemAppClock`, or a newly created clock as a default
  inside the motion loader.
- Changing active-fast visibility, automatic-fast derivation, calendar/DST
  behavior, motion coverage, chunk seams, caching, scrolling, or failure UI.
- Choosing an authoritative fast when two or more active rows exist.
- Deleting, completing, merging, editing, or otherwise repairing ambiguous
  `FastRecord` rows.
- Starting a replacement Live Activity after ambiguity, changing automatic
  consent or per-fast suppression, or changing widget projection state.
- New user-facing alerts, diagnostics, telemetry, networking, or persistence
  schema changes.

## Acceptance criteria

1. Given `MARKETING_VERSION` is `1.0.0`, when the app and widget build settings
   and processed Info.plists are inspected, both resolve
   `CFBundleShortVersionString` to `1.0.0`; the widget source plist contains no
   literal short version.
2. Given a future active-fast start relative to a fixed injected clock but a
   past start relative to the host wall clock, when settled History and the
   initial motion runway are built, both use the fixed instant and agree on
   whether the active fast is visible.
3. Given the host wall clock differs from `--fixed-now`, when a preceding or
   following motion chunk loads, its presentation is built with the explicit
   injected reference instant and contains no direct `Date.now` dependency.
4. Given a retained runway is refreshed across two or more chunks, when the
   clock can advance between asynchronous calls, all replacement chunks use
   the one reference instant captured for that refresh transaction and merge
   into a temporally coherent presentation.
5. Given zero or exactly one authoritative active fast, when reconciliation
   runs, existing no-fast cleanup or single-fast deduplication/update behavior
   remains unchanged.
6. Given `resolveActiveFast()` throws because two or more active records exist,
   when reconciliation runs, it queries the current ActivityKit records,
   attempts to end every running or orphaned derived activity immediately,
   clears all lifecycle metadata, returns the existing reconciled outcome, and
   makes no request or update.
7. Given one or more ActivityKit end operations fail during ambiguous-authority
   cleanup, when reconciliation finishes, it remains non-throwing, attempts
   cleanup for every observed activity, clears lifecycle metadata, and never
   mutates or deletes a `FastRecord`.
8. Given ambiguous active rows before reconciliation, after cleanup both rows
   retain their identifiers, start instants, goals, active state, and all other
   persisted values; the coordinator does not select either row as authority.
9. Given the complete change, valid History motion, fixed-clock launch
   behavior, Live Activity consent/suppression, update recovery, fast-end
   races, widget display, and local-only operation retain their existing test
   results.

## Implementation notes

- Prefer `load(coverage:calendar:referenceNow:)`. Requiring the argument makes
  accidental wall-clock fallback visible at every call site.
- Capture `clock.now` on the main actor alongside the expected calendar and
  generation. Do not access the view or its clock from the detached loading
  work.
- For a multi-chunk refresh, capture once outside the loop. Independent later
  extension requests may capture a new instant because each is a distinct
  presentation transaction.
- Reuse `endAll(_:)` and `lifecycleStore.clearAll()` for authority-error cleanup
  so the no-active-fast and ambiguous-authority paths share their disposal
  semantics. Do not hide the resolver error by treating ambiguity as an
  ordinary authoritative `nil` in policy code.
- Cleanup is best-effort for ActivityKit and lifecycle metadata, matching the
  existing coordinator contract. Failure must not roll back or alter local
  fasting persistence.
- Do not hand-edit `uFast.xcodeproj`. No project regeneration is expected
  unless implementation requires a `project.yml` change.

## Verification

- Add a build-setting or processed-plist assertion that compares the app and
  embedded widget `CFBundleShortVersionString`; do not rely only on checking
  the source text.
- Extend `uFastTests/HistoryMotionStreamingTests.swift` or the nearest focused
  loader suite with a reference instant deliberately far from `Date.now` and a
  multi-chunk refresh/load assertion.
- Retain the zero/one/many authority coverage in
  `uFastTests/HistoryMotionAuthorityTests.swift`.
- Extend `uFastTests/ActiveFastLiveActivityCoordinatorTests.swift` with a
  throwing resolver, multiple seeded activities, lifecycle metadata, and
  assertions for all end attempts, metadata clearing, zero requests/updates,
  and unchanged source records or resolver-owned values.
- Add the failed-end variant and prove later activities are still attempted.
- Run the smallest focused unit tests first, then `make build`,
  `make test-unit`, `make lint`, and `make analyze`.
- If any UI test source changes, follow the repository preflight, run the
  story-specific UI test first, then the full four-worker `make test-ui` suite
  and verify its `.xcresult`. No new UI test is required when the behavior is
  fully covered below the UI seam.
- Before the first Xcode test command, complete and record the `AGENTS.md`
  preflight and do not overlap another Xcode or UI test run.

## Accessibility, privacy, and data checks

- The story adds no visible or spoken content, so existing widget and Live
  Activity accessibility copy remains unchanged.
- Fail-closed cleanup removes disposable presentation state and does not expose
  either conflicted fast as authoritative.
- No health data, analytics, network access, CloudKit, or new persisted user
  data is introduced.
- Ambiguous SwiftData rows remain available for later explicit diagnosis or
  repair; this story performs no silent history rewrite.

## Sol review focus

- Inspect both processed Info.plists or resolved build settings, not only the
  XML substitution.
- Search the production motion-loading path for remaining `Date.now` uses and
  ensure every loader call supplies a deliberate reference instant.
- Confirm a retained multi-chunk refresh captures once outside its loop.
- Force the resolver to throw and verify reconciliation still enumerates and
  ends all activities before clearing metadata.
- Reject any implementation that chooses a conflicted fast, mutates SwiftData,
  starts replacement activity state, or expands product behavior.

## Done when

The embedded widget and app resolve the same short version, settled and moving
History use the same injected temporal authority, and Live Activities cannot
survive ambiguous active-fast authority as a misleading derived truth.
