# BF-103 — Show one stable fast label across History midnight

**Slice:** History visual reliability  
**Priority:** P1 UX clarity and motion polish  
**Status:** Done 24 August 2026
**Story type:** Bounded presentation refinement

## User outcome

As a user reviewing a fast that crosses midnight, I want to see one fasting
icon and one text label for that fast, so the continuous interval reads as one
record rather than repeated day fragments.

## Why now

The severe History scrolling regression and the slow-swipe finger-lift hitch
have been fixed and accepted on a physical iPhone. During further slow-swipe
testing, the user sometimes sees a much smaller visual disturbance immediately
before native scrolling becomes idle. They suspect midnight-spanning fasts,
but explicitly report that as a hunch rather than proven evidence.

Source inspection establishes a related presentation problem without proving
that it is the residual hitch's sole cause:

- `TemporalHistoryPresentation.pageGeometry` correctly clips one absolute fast
  into page-local fragments with the same identity and lane.
- `TemporalRibbonView.intervalMarks` currently builds a complete button content
  tree for every visible page fragment.
- `intervalContinuationShowsContent` deliberately repeats content for every
  non-active continuation and for crossing active continuations, so one fast
  can show multiple fasting glyphs and labels around midnight.
- At native settlement, the selected page changes from compact motion items to
  exact settled items and page selection state changes. That broader source
  handoff is also a plausible cause of late-deceleration work.

BF-103 therefore implements the independently desired one-label presentation
and makes label ownership invariant across motion and settlement. It must not
claim that this alone fixes the intermittent frame disturbance. If the exact
same disturbance remains after BF-103 with stable ownership proven, capture it
as a separate diagnostic story rather than adding speculative scrolling work.

## Context and authoritative rules

- D-015 requires a fast to remain one absolute interval when clipped by a
  viewport or rendered across midnight.
- D-017 and D-021 require native, continuous History movement without custom
  velocity or deceleration physics.
- D-020 requires touching page segments to read as one continuous surface.
- D-022 separates transient motion presentation from settled semantic
  selection.
- BF-102 requires midnight-adjacent fragments to retain one record identity,
  lane and absolute interval.
- BR-12 preserves absolute instants through time-zone and DST changes. BR-24
  and D-033 preserve inferred-fast presentation and precedence.
- The product remains calm, local-only and accessible. Visual decoration must
  not become a second semantic fast or a persistence concept.

## Product decision

One absolute fast owns at most one visible fasting glyph and one visible text
label across all of its page-local History fragments.

The fragment containing the fast's original start is the stable visual content
owner. That ownership derives only from the original absolute interval and the
Calendar/TimeZone page boundary. It must not depend on the selected page,
movement phase, scroll direction, viewport centre, exact-versus-motion source,
or whether the fragment is currently onscreen.

Continuation fragments retain the same bar colour, stroke, lane, identity and
seam treatment, but render no fasting glyph, text or continuation-edge marker.
Existing width-aware truncation may still apply within the owner fragment, and
a continuation-only viewport may show the unlabelled continuous bar while the
settled semantic panel supplies the complete fast description.

This changes presentation only. It does not split, merge, move, shorten,
lengthen, infer, persist or reclassify a fast.

## In scope

- Introduce a pure, deterministic visual-content ownership rule for clipped
  interval fragments.
- Render the fasting glyph and text only in the original-start fragment for
  recorded, active, inferred/automatic and retained legacy interval kinds.
- Keep ownership identical for exact settled and compact moving projections.
- Remove selection- or movement-dependent content ownership from page-local
  interval rendering.
- Preserve seamless coloured fragments, lane allocation, hit geometry,
  interval activation and the settled semantic information panel.
- Extend the existing midnight fixture and pure temporal tests to prove exact
  one-owner behavior across ordinary midnight, both London DST transitions,
  RTL and movement/settlement source changes.
- Perform a focused physical-device slow-swipe check around a crossing fast
  after technical acceptance.

## Out of scope

- Custom scroll physics, velocity thresholds, display links, timers, snapping
  or gesture replacement.
- A broad rewrite of `TemporalHistoryCarousel`, History streaming, motion
  runway loading, exact presentation building or date-rail behavior.
- Claiming that repeated labels are the proven root cause of the remaining
  intermittent frame disturbance.
- Changing interval colour, provenance copy, duration calculation, event
  grouping, grid cadence, future shading, editors or direct History entry.
- Persisted page fragments, schema changes, migration, network access,
  analytics, health claims or external capabilities.

## Final user-visible behavior and edge cases

- A fast from 21:00 through 08:40 is drawn continuously across midnight with
  one fasting glyph and one text label on its 21:00 start fragment. The
  post-midnight fragment has no duplicate fasting glyph, label or continuation
  marker.
- Slow movement, deceleration, native alignment and settlement do not move,
  duplicate, hide and recreate, or otherwise transfer the label between page
  fragments.
- Reversing direction around midnight preserves the same owner and does not
  change the interval's identity, lane, colour, corners or absolute bounds.
- A fast starting exactly at midnight has the following local day as its one
  owner under half-open interval semantics.
- A fast wholly inside one local day continues to show one glyph and label.
- A multi-day fast still has one owner at its original start; later
  continuation-only viewports may show the bar without repeated content.
- Very narrow owner fragments retain existing bounded width/truncation rules;
  content must not overflow into another interval, event lane or page.
- Active-fast end projection may advance, but the owner remains fixed at the
  original start page. Completed and inferred-fast ownership is equally stable.
- Europe/London 23- and 25-hour days use Calendar-derived page boundaries.
- RTL mirrors geometry without changing the chronological owner.
- The settled semantic information panel exposes one actionable fast with its
  existing accessibility label and identifier. Decorative page fragments do
  not create duplicate VoiceOver items.

## Acceptance criteria

1. **Exactly one visual content owner**  
   Given the complete page-fragment projection for a fast, then exactly the
   fragment containing the original start owns the fasting glyph/text content
   and every continuation fragment is content-free. A viewport that excludes
   that owner correctly contains zero visible content owners, never a promoted
   replacement or duplicate.

2. **Midnight remains visually continuous**  
   Given the BF-102 21:00-to-08:40 Europe/London fixture, when both sides of
   midnight are visible, then both fragments retain one identity, lane, colour
   and complementary seam geometry while only the start fragment contains the
   fasting glyph and label; the continuation fragment contains no continuation
   marker.

3. **Ownership is motion-invariant**  
   Given the same interval through tracking, deceleration, lower alignment,
   programmatic movement and settlement, and through compact-motion versus
   exact-settled item sources, then ownership does not change and settlement
   does not transfer or recreate content on another fragment.

4. **Kinds and temporal edges remain correct**  
   Given recorded, active, inferred/automatic and retained legacy intervals,
   including a start exactly at midnight, a single-day interval, a multi-day
   interval and both London DST transitions, then each interval has at most one
   owner with unchanged absolute bounds, provenance, lane and half-open
   intersection behavior.

5. **Accessibility and interaction remain singular**  
   Given a settled crossing fast, then the semantic panel contains one fast
   item with its existing identifier, label and action. Fragment decoration is
   not separately announced; tapping the owner or a continuation fragment
   resolves the same interval action when interaction is allowed.

6. **Scrolling regressions are not reintroduced**  
   Given the deterministic midnight fixture, when the user performs repeated
   slow swipes in both directions, then the previously fixed finger-lift hitch
   remains absent, the top date row does not flash an incorrect date, and no
   icon/label duplication or ownership swap is visible immediately before
   idle. If a residual frame disturbance remains with these invariants intact,
   BF-103 records it as separate diagnostic evidence rather than widening this
   implementation.

7. **Scope and data remain unchanged**  
   No fast, event, settings or legacy record is added, rewritten or migrated;
   no domain rule, persistence boundary, privacy behavior or external
   capability changes.

## Architecture and data boundaries

- Keep clipping, lane assignment and page-local finite geometry in the pure
  temporal presentation layer. Content ownership should be a pure value derived
  from `TemporalIntervalSegment` original/visible bounds and the owning page
  interval, not SwiftUI view state.
- `TemporalRibbonView` consumes that value. It must not infer ownership from
  `isSelectedPage`, movement state or a global query over rendered views.
- `TemporalHistoryCarousel` continues to choose exact versus motion items and
  own native phase transitions. BF-103 may remove now-obsolete content-only
  phase plumbing but must not change scroll physics or settlement authority.
- `HistoryPresentationSnapshot` and `HistoryMotionPresentation` must preserve
  the same interval ID and original start. If a focused test finds they do not,
  stop and route that discrepancy through the existing History coherence
  boundary rather than masking it in drawing code.
- `FastRecord`, inferred projections and SwiftData remain authoritative for
  intervals. No schema, migration, new cache or persisted visual owner is
  permitted.
- No privacy, permission, networking or health-data impact is expected.

## Dependencies and downstream impact

- Depends on the accepted BF-102 midnight continuity behavior and the retained
  slow-swipe lift-off fix in `TemporalCarouselMovementPhase` and
  `TemporalHistoryCarousel`.
- Preserve the current accessibility selector correction that uses native root
  tab labels until MNT-014 owns real tab identifiers.
- Update deliberately where their repeated-content assumptions change:
  `TemporalHistoryPresentationTests.testLiveIntervalContinuationKeepsAdjacentPageBackgroundSeamless`
  and the midnight fragment/geometry tests near it.
- Retain and run the BF-102 fixture and journeys in
  `HistoryUITests+ActiveFastJourneys.swift`, including
  `testHistoryMidnightSeamRemainsContinuousWhenViewportMovesBothDirections`
  and the Dynamic Type/RTL/12-hour accessibility variants.
- Review `HistoryUITests+BasicJourneys.swift`,
  `HistoryUITests+RecordJourneys.swift`,
  `HistoryUITests+AccessibilityJourneys.swift`,
  `HistoryUITests+TemporalSupport.swift`, `HistoryMotionStreamingTests`,
  `HistoryPresentationCacheTests` and `HistoryDataProviderTests` for assumptions
  about fragment counts, labels, first-match selectors or exact/motion parity.
- Event-grouping fixtures, food/drink editors and Today behavior are expected
  to be unchanged; any failure there is a regression, not a fixture update.

## Focused verification and human check

- Add pure tests for one owner across adjacent and multi-day fragments,
  start-at-midnight, single-day, active-end advancement, spring-forward,
  autumn-fallback and RTL geometry.
- Add a pure phase/source matrix proving owner equality for `.userDriven`,
  `.decelerating`, `.aligning`, `.programmatic` and `.settled` inputs without
  broadening the accepted movement-phase contract.
- Run the existing focused History presentation, motion streaming, cache and
  BF-102 midnight UI selections. UI assertions must use
  `history.day-carousel`, `history.selected-date`, the existing interval/active
  fast identifiers and semantic panel identifiers; do not introduce visible
  label selectors for content whose copy may localize.
- Retain render attachments at settled midnight, after a slow swipe in each
  direction, AXXXL, RTL and 12-hour locale. Screenshots support but do not
  replace pure ownership and semantic assertions.
- Run `make project`, focused units/UI, `make test-unit`, `make build`,
  `make lint` and `make analyze`. Run the full four-worker UI suite only at a
  source-frozen integration gate and verify its `.xcresult` structurally.
- After independent Sol technical acceptance, build and deploy that exact
  source to dave's iPhone. Human check: perform at least ten gentle swipes
  around a midnight-spanning fast in both directions; confirm one glyph/label,
  no owner transfer, no top-row flash and no return of the finger-lift hitch.
  Record any remaining pre-idle frame disturbance separately with the visible
  interval position and whether the owner fragment was onscreen.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| 1 | One and only one fragment owns visual content | Pure temporal presentation tests | three-page interval; owner outside viewport | Focused test log/result |
| 2 | Crossing fragments meet while only start fragment is labelled | Pure geometry + BF-102 History UI | reverse direction at midnight | `.xcresult` + render attachments |
| 3 | Owner is unchanged by phase or source | Pure phase/source matrix | compact/exact arrays with same ID/start | Focused test result |
| 4 | All interval kinds and calendar edges retain bounds/provenance | Unit/presentation tests | midnight equality, both DST transitions, RTL | Focused test result |
| 5 | One semantic item; every fragment activates the same interval | Focused History UI/accessibility | continuation-only viewport, AXXXL | `.xcresult` + accessibility tree |
| 6 | Existing motion fixes remain and no visible owner swap occurs | Existing motion tests + physical iPhone check | ten slow swipes each direction | Test result + human record |
| 7 | No persistence/domain/privacy change | Diff, analyzer and repository gates | dirty-worktree scope audit | Sol verdict + command logs |

## Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: BF-102 fixed London fixture;
  pure original-start owner invariant across page fragments, phases and sources;
  semantic item count; retained render attachments; bounded physical slow-swipe
  checklist for the non-deterministic residual frame observation
- Acceptance matrix and downstream fixture/legacy-suite impact: temporal
  geometry/continuation tests, History exact/motion/cache tests, BF-102 midnight
  UI and accessibility variants, full four-worker integration suite
- Focused correction budget: one baseline diagnostic confirming current
  duplicate ownership, then at most three focused corrections or 25 minutes on
  the ownership/rendering surface; one unchanged-source flake rerun only
- Expected expensive commands: focused History UI, full units/build/lint/
  analyzer, then one source-frozen four-worker UI integration run
- Maximum rescue tier: Terra, then Sol diagnosis

## Definition of Ready

- [x] The user's one-glyph/one-label product decision is explicit.
- [x] Stable original-start ownership is independent of movement and selection.
- [x] The midnight hunch is recorded as plausible but unproven, not embedded as
      a false root-cause claim.
- [x] Every criterion has deterministic technical observability, with the
      intermittent frame observation isolated to a bounded human check.
- [x] Existing fixtures, legacy suites, accessibility selectors, data and
      scrolling boundaries are inventoried.
- [x] Sol readiness gate has returned `READY` for this bounded story.

## Sol readiness gate

Sol gate: **READY** — `gpt-5.6-sol`, medium reasoning. Sol found the one-label
product decision explicit, the pure original-start ownership boundary
architecturally appropriate, the acceptance matrix and downstream fixture
inventory complete, and the medium-uncertainty Luna execution profile bounded.
No discovery split is required: duplicate fragment content and stable ownership
are deterministic, while the unproven residual frame disturbance remains a
physical-device regression check and separate follow-up only if it persists.
Continuation-only viewports correctly have no visible owner, and programmatic
motion is included in the all-phase invariant. No document changes were
required for readiness beyond recording those clarifications and this verdict.

## Completion record

- Human validation: **PASSED** — the user confirmed the committed History
  baseline and the follow-up removal of the post-midnight continuation marker
  on a physical device.
- Final behavior: one fasting icon and label on the original-start fragment;
  continuation fragments retain only the continuous bar and seam geometry.
- Focused temporal tests: 58/58 passed.
- Focused midnight UI journeys: 2/2 passed.
- Lint and build: passed.
- Final four-worker UI integration: 116/117 passed across four clones; the
  single Fasting Goal alert-timing failure was outside BF-103 and quarantined
  by the independent Sol integration gate.
