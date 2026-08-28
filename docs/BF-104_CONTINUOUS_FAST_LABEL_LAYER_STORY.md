# BF-104 — Render fast labels once on the continuous History timeline

**Slice:** History visual reliability  
**Priority:** P1 UX clarity and motion performance  
**Status:** Ready 27 August 2026  
**Story type:** Bounded presentation architecture refinement

## User outcome

As a user reviewing History, I want every fasting interval to have one short,
predictably positioned label, so recorded, inferred and active fasts remain easy
to distinguish without labels moving or appearing offset around midnight.

## Why now

Physical-device evidence in `Screenshot 2026-08-27 at 10.00.10.png` shows that
the active-fast label can appear visually offset within an interval that crosses
midnight. The screenshot is diagnostic evidence outside the repository and must
not become a test dependency.

BF-103 removed duplicate labels by assigning visual content to a page-local
fragment. Its amended rule prefers the fragment containing the interval's
original start and transfers the label to the first continuation when that
fragment is too narrow. Subsequent changes added kind-specific minimum widths,
compact/full variants and a live active-duration line. The resulting behavior
is deterministic in isolated fragment tests, but the design still makes a
single interval label depend on calendar-tile ownership, midnight width,
continuation fallback and settled-versus-motion rendering.

The current implementation therefore performs substantially more work than the
user-visible requirement needs:

- `TemporalHistoryCarousel` constructs a `TemporalRibbonView` for every lazy
  local-day segment and changes the selected segment between motion and exact
  interval sources at settlement.
- Every `TemporalRibbonView` independently clips all supplied intervals and
  decides whether one of its fragments owns or inherits visual content.
- `TemporalRibbonContentGeometry` calculates an original-start owner and a
  Calendar-derived first-continuation fallback using fragment and page widths.
- `TemporalRibbonView` supports compact, regular and continuation-width label
  treatments, while `ActiveFastRibbonDurationLabel` owns state and wakes once
  per second when History is settled.

Midnight remains an important Calendar boundary for grid and bar geometry, but
it must no longer be a label-placement boundary. This story preserves native
free scrolling and the proven page-local bar rendering while moving visual
labels to one continuous coordinate space.

## Context and authoritative rules

- PRODUCT principles require calm, honest presentation and distinguishable
  user-recorded and inferred fasts.
- BR-03 preserves one active fast; BR-12 preserves absolute instants through
  time-zone and daylight-saving changes.
- BR-24 and BR-52 preserve recorded-fast precedence over inferred candidates.
- BR-48 requires inferred intervals to remain explicitly identifiable without
  relying on colour alone.
- D-015 says one fast remains one absolute interval when clipped by a viewport
  or rendered across midnight.
- D-021 requires a native, free-scrolling continuous History timeline made from
  touching local-calendar segments. Twenty-four local hours occupy 24/26 of the
  viewport, and DST geometry uses actual local-day duration.
- D-022 permits native scroll geometry and phase observation, but prohibits
  custom velocity, physics, timers and display-link sampling for motion state.
- BF-102 preserves coherent exact and motion projections after active-fast
  changes.
- BF-103's page-fragment content-owner and first-continuation fallback decision
  is superseded by this story only for visual glyph/text placement. Its one
  semantic fast, continuous bar, stable identity, lane, hit geometry and
  accessibility outcomes remain authoritative.

## Product decision

One absolute fasting interval owns at most one visual fasting glyph and one
short visual label in the complete continuous History scroll content. A
calendar tile never owns, inherits or repositions that content.

The three ordinary visual labels are exactly:

- recorded/persisted fast: **Fast**;
- inferred fast, including an inference currently in progress: **Inferred fast**;
- active recorded fast: **Active fast**.

Capitalization follows localized sentence-case source strings. The structured
information panel and accessibility description retain the existing complete
recorded, inferred/in-progress, source, duration, goal and provenance copy.
Legacy retained records keep their existing semantic provenance. The exhaustive
visual mapping is:

| Existing interval kind/state | Visual label | Existing glyph policy | Notes |
| --- | --- | --- | --- |
| `.recorded` | **Fast** | `moon.stars.fill` | Persisted user-recorded completed fast |
| `.active` | **Active fast** | `moon.stars.fill` | Persisted user-recorded active fast; no duration line |
| `.automatic` | **Inferred fast** | `moon.fill` | Retained derived automatic projection; semantic legacy copy remains authoritative |
| `.inferred`, historical | **Inferred fast** | `moon.fill` | Existing sky treatment and conversion action remain |
| `.inferred`, in progress | **Inferred fast** | `moon.fill` | Removes visual `Inferred fast in progress`/`Est. now`; semantic in-progress copy remains |
| `.previouslySaved`, including unavailable `HistoryVisibleFastItem` mapped to this ribbon kind | **Fast** | `archivebox` | Existing semantic unavailable/previously-saved copy remains |
| `.reconstructed` | **Fast** | `wand.and.stars` | Existing semantic reconstructed provenance remains |
| `.needsReview` | **Fast** | `exclamationmark.triangle` | Existing semantic needs-review warning remains |
| `.unknown` | no fasting text | `questionmark.circle` | Unknown is not labelled as a fast; existing unknown-period semantics remain |

This table is exhaustive for `TemporalRibbonIntervalItem.Kind`. The story does
not change glyphs, colour, stroke or semantic titles. Only the ordinary visual
text inside the timeline is collapsed to the three labels.

The label's centre is the geometric midpoint of the complete projected bar in
continuous day space: `(projectedStartX + projectedEndX) / 2`. It is not the
midpoint of a page fragment, visible viewport or selected day. Each endpoint is
mapped through its owning local-calendar day using that day's actual duration,
then into the day runway using the measured day stride. This keeps the visual
centre correct across ordinary midnight and both DST transitions.

The label is part of the scroll content, not a viewport overlay. Native scrolling
moves it without per-frame label state, viewport clamping or a follower
calculation. The label layer is decorative, accessibility-hidden in production,
non-hit-testing and excluded from scroll-content sizing. If the complete
projected bar is too narrow for its localized label plus bounded padding, the
text is omitted; the fasting glyph may remain only when it fits. The label is
never transferred to another day, scaled to an
unreadable size or made sticky to the viewport. A continuation-only viewport
may therefore show an unlabelled bar, with full meaning retained in the settled
information panel and semantic accessibility representation.

Active-fast duration is not rendered inside the timeline bar. History already
exposes duration in the settled information panel and accessibility value, and
Today remains the glanceable live-duration surface. The active bar and label
use the coherent History projection current at activation/refresh; History does
not run a per-second label timer.

## In scope

- Add a pure continuous day-space coordinate resolver for interval endpoints.
- Add a pure label projector that produces zero or one label descriptor per
  stable interval identity.
- Render one label layer inside the horizontal scroll content and above the
  page-local interval bars.
- Keep page-local interval fragments responsible only for bar fill, outline,
  corner/seam geometry, lane and interaction hit area.
- Use one coherent compact visual interval source for every calendar segment
  and label through tracking, deceleration, alignment, programmatic movement
  and settlement. Exact settled data remains authoritative for the information
  panel and actions.
- Remove visual-content ownership, first-continuation fallback, kind-specific
  compact/regular label layout and the History active-duration timer when they
  become obsolete.
- Localize and test the three short visual label strings without changing
  semantic titles or accessibility descriptions.
- Update BF-103's completion record or `DECISIONS.md` with the smallest explicit
  supersession note so a clean-context implementation does not restore fragment
  ownership later.
- Add deterministic pure, state-level and focused UI coverage, followed by a
  physical-device scrolling check.

## Out of scope

- Replacing the native `ScrollView`/`LazyHStack`, custom scroll physics,
  snapping, velocity thresholds, display links or gesture handling.
- Making labels follow or clamp to the visible viewport.
- Rewriting History streaming, runway loading, date-rail coupling, settled
  selection, event grouping, future shading or the structured information
  panel.
- Changing fast start/end boundaries, inference, overlap precedence, lanes,
  colours, strokes, event semantics, editors or direct History entry.
- Adding a live duration to another History surface.
- Persistence entities, migration, CloudKit, network access, analytics,
  health interpretation or external capabilities.

## Final user-visible behavior and edge cases

- The supplied scenario—recorded fast ending at 17:55, food at 17:55, caloric
  drink at 19:54 and active fast beginning at 20:26—shows one **Fast** label and
  one **Active fast** label centred on their respective complete bars. Midnight
  does not move either label or create a fallback label.
- A recorded fast crossing midnight has one **Fast** label. Both page fragments
  remain visually continuous and activate the same interval.
- A projected inferred interval has one **Inferred fast** label whether it is
  historical or still in progress. Its sky colour and semantic copy remain.
- An active fast has one **Active fast** label and no duration inside the bar.
- Tracking, slow deceleration, reversal, programmatic alignment and transition
  to native idle do not transfer, duplicate, recreate or re-centre a label.
- A fast starting or ending exactly at midnight uses half-open interval
  semantics for bars, but label placement does not branch on midnight.
- On Europe/London spring-forward and autumn-fallback days, the label remains at
  the geometric centre of the rendered bar rather than assuming 86,400 seconds.
- RTL mirrors the complete visual coordinate system without changing interval
  identity, chronological bounds or the one-label invariant.
- A narrow fast may display only its bar or glyph. It never borrows space from a
  continuation tile or overlaps another interval/event lane.
- A multi-day continuation-only viewport may show an unlabelled bar. The settled
  semantic information panel still contains one actionable fast.
- Dynamic Type may increase the width required to show text. Omission is calm
  and deterministic; shrinking below the accepted readability threshold or
  crossing the bar boundary is not permitted.
- VoiceOver continues to expose one semantic fast item with the existing stable
  identifier and complete description. Decorative bars and visual labels do
  not become additional accessibility elements.

## Acceptance criteria

1. **One continuous label projection per interval**  
   Given any complete set of page-local fragments for one interval, when visual
   labels are projected, then at most one descriptor with that stable interval
   ID is produced, and no page fragment owns or inherits label content.

2. **Three calm visual labels**  
   Given recorded, inferred historical, inferred in-progress and active fasts,
   when their bars are wide enough, then their visual labels are respectively
   **Fast**, **Inferred fast**, **Inferred fast** and **Active fast**. No duration,
   source, goal, `Est. now` or other variable copy appears inside a timeline bar;
   complete semantic copy remains unchanged.

3. **Placement is independent of midnight and tiles**  
   Given the supplied 26 August scenario and ordinary crossing-fast fixtures,
   when the timeline is rendered, then each label centre equals the geometric
   midpoint of its complete projected bar within a bounded pixel tolerance.
   Partitioning the same interval into different page fragments produces the
   same global label coordinate.

4. **Placement is motion- and source-invariant**  
   Given tracking, deceleration, alignment, programmatic movement and settled
   phases, when the same interval remains available, then its label identity,
   title, lane and content coordinate do not change because of movement phase,
   selected day or exact-versus-motion presentation handoff. The selected page
   does not replace visual intervals at idle.

5. **No label-driven high-frequency work**  
   Given a visible active fast while History is idle or moving, when time and
   native scroll geometry advance, then no label timer, repeating task,
   formatter, interval projection or label-position state mutation runs from a
   scroll-geometry callback or once-per-second History loop. Native scrolling
   alone transports the already-projected label views.

6. **Bars, interaction and semantics remain correct**  
   Given any fragment of a recorded, inferred, active or retained legacy fast,
   when it is shown or activated, then its absolute bounds, ID, kind, lane,
   colour, stroke, caps, continuation seam, hit target and action are unchanged.
   The settled information panel and VoiceOver contain exactly one semantic
   fast with existing complete detail.

7. **Narrow, DST, RTL and accessibility behavior is deterministic**  
   Given an interval narrower than its localized label, a multi-day interval,
   a start/end exactly at midnight, both London DST transitions, RTL and
   accessibility Dynamic Type, then label projection remains finite and
   bounded, never changes the interval geometry, never transfers to another
   tile and never clips unreadable text outside the complete bar.

8. **Native scrolling performance is preserved**  
   Given the deterministic midnight fixture and the supplied 26 August
   scenario on the supported iPhone-sized surface, when repeated gentle and
   fast swipes are performed in both directions, then the accepted native
   inertia remains, the earlier finger-lift hitch and date-row flash do not
   return, and no label jump, duplicate or idle-time owner transfer is visible.
   Instrumented comparison must show no new label-related main-thread work on
   scroll geometry callbacks and no repeating History label wake-up.

9. **Scope and data remain unchanged**  
   No fast, event, setting or legacy record is added, rewritten or migrated. No
   domain, persistence, privacy, permission, network or external-capability
   boundary changes.

## Architecture and data boundaries

### Continuous coordinate resolver

Introduce a pure value that maps an absolute instant into the existing History
runway coordinate space:

1. resolve the containing local day with the supplied `Calendar`/`TimeZone`;
2. find that canonical day in the ordered runway;
3. resolve the next local midnight with Calendar arithmetic;
4. compute the finite fraction through the actual day interval;
5. map `dayIndex + fraction` through the measured day stride;
6. mirror only at the final visual-coordinate boundary for RTL.

Endpoint roles are explicit. A start exactly at midnight maps to fraction zero
of the day being entered. An end exactly at midnight maps to fraction one of
the preceding runway day. In particular, an end equal to the midnight after
the final runway day is valid and maps to `days.count * dayStride`; it does not
fail merely because that midnight is not itself present in the ordered `days`
array. Starts before the first runway day, starts at the terminal midnight,
ends after the terminal midnight and all other out-of-runway inputs fail closed.

The resolver must share the same day-stride and local-day assumptions as
`TemporalContinuousTimelineGeometry`. Do not introduce a second 26-hour/page
formula or divide by 86,400. Invalid, missing or out-of-runway coordinates fail
closed and produce no label.

### Label projector

The projector consumes immutable lightweight interval primitives and returns a
stable descriptor containing interval ID, visual kind, localized short title,
lane, projected start/end and optional label/glyph placement. Lane assignment
must be extracted from or shared with the existing original-half-open-interval
lane allocator used by `TemporalHistoryPresentation.clip`; page fragments and
the continuous descriptor must never calculate lanes independently. It
deduplicates by stable identity before SwiftUI rendering.

Fit policy is pure and receives measured metrics rather than measuring text:

- label font: the existing `.caption.weight(.semibold)` visual treatment;
- horizontal content padding: 6 points on each side;
- glyph-to-text spacing: 4 points;
- full-label required width: measured glyph width + 4 + measured localized text
  width + 12 points padding;
- glyph-only required width: measured glyph width + 12 points padding;
- if complete projected width meets full-label width, show glyph and text;
- otherwise, if it meets glyph-only width, show only the glyph;
- otherwise show no decoration.

The SwiftUI/UIKit presentation adapter owns measurement and supplies an
immutable `TemporalRibbonLabelMetrics` value keyed by localized string, locale,
layout direction, Dynamic Type category and the caption-semibold font. It may
use the platform preferred-font metrics or a one-time SwiftUI measurement seam,
but it must resolve only when one of those keys changes, cache the result for
the current presentation generation and never measure from a scroll callback.
Pure tests inject explicit text/glyph widths and do not depend on platform font
rasterization.

Label projection must not depend on selected day, visible window, movement
phase, scroll direction, content offset or whether exact settled details are
currently shown.

### SwiftUI boundary

`TemporalHistoryCarousel` retains the native `ScrollView` and `LazyHStack`.
Attach the label layer to the scroll content's full coordinate space so labels
move through native compositing. The implementation must verify that the layer
does not change the scroll content size, day stride, initial alignment or lazy
runway behavior. Apply `.allowsHitTesting(false)` and production
`.accessibilityHidden(true)` to the complete overlay.

`TemporalRibbonView.intervalMarks` continues to build page-local bar buttons,
but those buttons contain no visual text/glyph tree. Visual labels remain
decorative and hidden from accessibility; every page fragment retains its
existing interval activation behavior.

Use one coherent compact visual source for every page and the label layer.
`HistoryPresentationSnapshot` remains the exact settled authority for the
information panel and action routing. If exact and compact primitives disagree
about ID, start, end, lane or kind after a committed mutation, stop at the
existing BF-102 coherence boundary rather than masking the mismatch in label
geometry.

### Data, concurrency, privacy and compatibility

- `FastRecord`, inferred projection and legacy compatibility remain the data
  authorities. No presentation coordinate or label descriptor is persisted.
- Projection is synchronous pure work over already-loaded lightweight values;
  no SwiftData query, task, actor hop or formatter runs from high-frequency
  geometry callbacks.
- Successful post-commit History invalidation remains responsible for updating
  compact and exact data.
- There is no migration, permission, privacy-disclosure, analytics, networking
  or health-data impact.
- Existing local records and older legacy records remain visible and actionable.

## Dependencies and explicit decisions

- Depends on accepted D-015, D-021, D-022 and the BF-102 exact/motion coherence
  boundary.
- Supersedes BF-103 only where it assigns visual content to an original-start
  page fragment or first continuation. BF-103's continuous bar, stable identity,
  singular semantics, accessibility and physical-motion regression protections
  remain.
- The screenshot is evidence, not a repository fixture.
- The product decision is closed for this story: visual labels use the three
  short strings above, active duration leaves the timeline bar, geometric
  midpoint is the stable anchor, and labels do not follow the viewport.
- If a continuous content overlay cannot preserve the native content size and
  lazy scrolling within the numerical prototype gates below, stop before broad
  carousel changes and request a follow-on design decision. Do not fall back to
  page ownership.

## Stable accessibility and test selectors

- Continue to scope timeline interaction under `history.day-carousel` and the
  feature container `history.carousel`.
- Continue to use `history.selected-date`, `history.previous-day` and
  `history.next-day` for settlement/navigation.
- Continue to identify actionable bars with
  `history.active-fast.<UUID>` and `history.interval.<UUID>`.
- The real decorative label remains accessibility-hidden in production. Under
  the existing `--ui-testing` launch gate only, mirror its resolved frame and
  title into one transparent, non-hit-testing diagnostic accessibility element
  with identifier `history.fast-label-probe.<UUID>`. This probe is absent from
  production launches, has the exact resolved label frame, and must not wrap,
  resize or contribute to scroll layout. UI tests query the probe; they do not
  make the production decoration a VoiceOver element.
- Continue to use the existing semantic information-panel identifiers for
  action and accessibility assertions. Visible localized strings are supporting
  copy assertions, not primary navigation selectors.

## Focused verification

Before the first Xcode test, complete the repository test preflight in
`AGENTS.md`, record the exact simulator and security model, and ensure no other
Xcode/UI suite is active.

1. Add pure coordinate tests for ordinary days, both London DST transitions,
   exact midnight, runway edges, RTL, invalid input and finite geometry.
2. Add pure label-projection tests for exact one-per-ID behavior, all three
   short labels, geometric centring, narrow intervals, multi-day intervals and
   independence from arbitrary page partitioning.
3. Add a phase/source matrix proving that the visual interval and label
   descriptors are identical through `.userDriven`, `.decelerating`,
   `.aligning`, `.programmatic` and `.settled` behavior.
4. Add a state-level regression proving that a committed active-fast correction
   updates the shared compact visual primitive before History becomes visible,
   while exact semantic detail remains coherent.
5. Update the BF-102/BF-103 midnight UI journeys to assert one stable label
   descriptor and unchanged bar/action identity without relying primarily on
   localized text.
6. Add launch flag `--seed-history-fast-label-layout` and the supplied fixed
   Europe/London scenario: 27 August 2026 10:00 now,
   recorded fast 25 August 20:42 to 26 August 17:55, food at 17:55, caloric
   drink at 19:54 and active fast from 26 August 20:26. Assert bounded bar and
   label frames before/after slow movement in both directions.
7. Retain AXXXL, RTL, 12-hour locale and Reduce Motion History variants.
8. Run `make project`, the smallest focused unit selection and only the changed
   History UI tests during story work. Run `make lint` and `make analyze` after
   source changes.

The new fixture uses these stable identities:

| Record | UUID |
| --- | --- |
| Recorded fast | `10400000-0000-0000-0000-000000000001` |
| Active fast | `10400000-0000-0000-0000-000000000002` |
| Food at 17:55 | `10400000-0000-0000-0000-000000000010` |
| Caloric drink at 19:54 | `10400000-0000-0000-0000-000000000011` |

Pure coordinate assertions use a tolerance of 0.5 points. Focused UI assertions
form the union of all visible page-fragment frames for an interval ID and require
the corresponding `history.fast-label-probe.<UUID>` midpoint to be within 2
points of that union's midpoint, fully within the union vertically and present
exactly once. When only part of the complete bar is on screen, the pure global
coordinate remains authoritative and the UI test asserts only the correctly
clipped presence/absence of the probe.

## Prototype and performance observability gate

The implementation worker's first bounded change is a label-layer prototype on
the deterministic fixture. Before product refactoring, capture a baseline; after
the prototype, capture the same fields through a `--ui-testing` diagnostic
snapshot and preserve both snapshots as text attachments in the focused
`.xcresult`:

- scroll content width;
- measured local-day stride;
- initial chronological content offset;
- selected-day centre in content coordinates;
- number of day segments that appeared after initial idle;
- visual label projection count and label-metrics resolution count.

Prototype pass criteria are:

- content width delta no greater than 0.5 points;
- day-stride delta no greater than 0.5 points;
- initial content-offset delta no greater than 0.5 points;
- selected-day-centre delta no greater than 0.5 points;
- initial appeared-day count no greater than baseline plus two segments;
- overlay hit testing is false and production accessibility is hidden;
- one projected label descriptor and one UI-test probe per expected fixture
  interval, with no duplicate IDs.

If any numerical invariant fails, stop the story before widening the carousel
or replacing native scrolling. The retained baseline/candidate snapshot and
focused `.xcresult` form the bounded diagnostic artifact.

For AC5, add a UI-test-only `HistoryLabelWorkProbe` at the pure projection and
metrics-resolution boundaries. It records monotonically increasing
`projectionCount` and `metricsResolutionCount`; it does not instrument SwiftUI
`body` evaluation and is compiled out or inert outside UI testing. The focused
test records counts after initial settlement, waits five seconds with a visible
active fast, then performs one controlled slow swipe and waits for settlement.
Pass requires both counts to remain unchanged during the five-second idle
window and throughout scroll geometry callbacks; one increment is permitted
only after a documented input-generation change such as locale, Dynamic Type,
runway or interval data.

Add debug signposts around label projection and metrics resolution so a retained
Points of Interest trace can prove that neither operation occurs inside the
existing scroll-geometry callback interval. AC5 passes with zero overlapping
label-work signposts and no periodic label-work signpost during the five-second
idle window.

For AC8, the automated gate retains the existing settlement timeouts and proves
one probe/no duplicate after ten scripted swipes in alternating directions. The
instrument trace must show zero label projection/measurement work during those
scroll callbacks. Native frame smoothness and the absence of the intermittent
finger-lift hitch remain a required physical-device comparison because XCTest
gesture timing is not a reliable frame-pacing threshold; the human checklist is
the acceptance artifact for that visual performance surface.

## Source-frozen integration verification

After focused evidence and independent Sol story acceptance, freeze source and
run once:

- `make build`;
- `make test-unit`;
- `make test-ui` with all four XCTest workers;
- `make verify-ui-result UI_XCRESULT=<stable-result-path>`;
- `make lint`;
- `make analyze`.

Preserve the exact commands, underlying exit codes, simulator destination,
worker-clone count, stable log paths and `.xcresult` bundle under
`.derived-data/sprint-results/`. Any later product or test-source edit invalidates
the integration result and requires a new source freeze.

## Human build check

After the independent Sol story gate accepts the exact source, run
`make deploy-iphone` when the configured iPhone is connected and report:

`HUMAN BUILD CHECK REQUIRED — BF-104`

On the physical device:

1. Reproduce the supplied 26 August timeline position.
2. Confirm the bar contains **Active fast** only, without a duration line.
3. Perform at least ten gentle swipes and ten fast swipes across midnight in
   each direction.
4. Confirm labels remain centred on their complete bars and never transfer at
   midnight or immediately before idle.
5. Confirm the top date row does not flash an incorrect date and the prior
   finger-lift hitch does not return.
6. Repeat once with an inferred fast visible and once with larger Dynamic Type.

Do not begin a dependent story until the user replies `HUMAN CHECK PASSED` or
explicitly authorises a recorded skip. A reported problem reopens BF-104 as
`CHANGES REQUESTED` and requires a new Sol verdict and device deployment after
any source/test change.

## Acceptance-to-observability matrix

| AC | Observable result | Test layer/path | Negative/edge path | Artifact |
| --- | --- | --- | --- | --- |
| AC1 | Zero or one identity-derived label descriptor per absolute interval; fragments contain no label ownership | New pure label-projection tests; `TemporalHistoryPresentationTests` | Duplicate page fragments and multi-day continuation-only viewport | Focused unit log/result |
| AC2 | Exhaustive kind table maps visual copy to Fast, Inferred fast, Active fast or deliberate unknown omission; active bar contains no duration | Localization/unit tests; focused History UI | Automatic, inferred in progress, retained legacy/unavailable/unknown, narrow bar | Focused unit/UI `.xcresult` |
| AC3 | Label centre equals complete projected bar midpoint and is invariant to page partitioning | Pure continuous-coordinate and projector tests; supplied-scenario UI fixture | Start/end near or exactly at midnight | Unit result + UI render attachment |
| AC4 | Label descriptor and visual interval remain identical through all movement phases and settlement | History motion/presentation source matrix | Exact/motion arrays disagree after mutation | Focused unit result |
| AC5 | Projection/metrics probe counts remain unchanged over five idle seconds and scroll callbacks; zero overlapping/periodic label-work signposts | Focused lifecycle UI test plus Points of Interest trace and source/static-analysis assertion | Visible active fast during idle and deceleration; documented input-generation change | Probe attachment + analyzer log + trace |
| AC6 | Bar geometry, actions and one semantic panel item remain unchanged | `TemporalHistoryPresentationTests`; BF-102/BF-103 History UI and accessibility journeys | Tap continuation fragment; inferred conversion; retained legacy record | Unit/UI result bundle |
| AC7 | Finite bounded omission/placement across narrow, DST, RTL and accessibility cases | Pure geometry tests; accessibility UI variants | Both London DST transitions; AXXXL; out-of-runway endpoint | Focused results + screenshots |
| AC8 | Ten alternating scripted swipes settle with one probe/no duplicate and zero callback label work; physical device has no transfer, flash or returned lift hitch | Existing motion tests; focused UI/probe/signposts; physical-device checklist | Gentle/fast reversal around midnight and idle transition | `.xcresult`, trace, human record |
| AC9 | No persistent/domain/privacy/external change | Diff, migration/schema audit, `make analyze`, Sol review | Existing dirty worktree and legacy store paths | Diff summary + analyzer + Sol verdict |

## Downstream fixture and legacy-suite impact inventory

### Fixtures and launch configuration

- Retain `--seed-history-midnight-seam` and
  `--seed-history-midnight-seam-extended` in
  `UITestLaunchConfiguration`/`UITestSeedFixtures`.
- Add deterministic launch flag `--seed-history-fast-label-layout` with the
  fixed clock and UUID contract above for the supplied 26 August scenario; do
  not read the external screenshot at test time.
- Preserve seeded inferred-fast, active-fast and unknown-provenance journeys.

### Pure/unit suites requiring deliberate review

- `uFastTests/TemporalHistoryPresentationTests.swift`: remove fragment-owner and
  fallback assertions; retain clipping, half-open seam, lane, finite geometry,
  DST and RTL coverage; add continuous label-projection assertions.
- `uFastTests/HistoryMotionStreamingTests.swift`: exact/motion identity and
  runway continuity.
- `uFastTests/HistoryPresentationCacheTests.swift`: coherent visual primitive
  refresh and no stale active start.
- `uFastTests/HistoryMotionAuthorityTests.swift` and
  `HistoryPresentationModelTests.swift`: phase/source authority assumptions.
- `uFastTests/HistoryInferredClassificationTests.swift`: inferred historical
  versus in-progress semantics remain complete even though their visual label
  is unified.
- `uFastTests/HistoryDataProviderTests.swift` and
  `HistoryCaloricNeighbourOrderingTests.swift`: expected to remain unchanged;
  any failure is a regression, not a label-fixture update.
- Localization catalog tests must include the new/reused short visual strings
  without deleting semantic source strings.

### UI suites requiring deliberate review

- `HistoryUITests+ActiveFastJourneys.swift`, including the coherent edited
  midnight fast and continuous seam journeys.
- `HistoryUITests+VisualRegressionJourneys.swift`: replace the late-start
  untruncated-duration assumption with the three-label/no-duration contract.
- `HistoryUITests+TemporalSupport.swift`: expose identity-derived decorative
  label frames without visible-copy selectors.
- `HistoryUITests+BasicJourneys.swift` and
  `HistoryUITests+RecordJourneys.swift`: recorded-fast label and action paths.
- `HistoryUITests+AccessibilityJourneys.swift`: exactly one semantic fast,
  decorative label hidden, Dynamic Type/RTL/12-hour/Reduce Motion coverage.
- `InferredFastUITests`: semantic in-progress and conversion copy remain
  unchanged despite the shorter timeline decoration.
- `HistoryEventGroupingUITests`: event markers, grouping and panel behavior are
  expected to remain unchanged; any failure is a regression.

### Compatibility and unrelated work

- Existing reconstructed/previously-saved/unavailable records remain supported
  by the legacy compatibility path and full semantic panel copy.
- Preserve the pre-existing untracked
  `docs/TESTFLIGHT_UI_AUDIT_2026-08-27.md`; it is unrelated user work and is not
  part of BF-104 unless separately requested.
- No project.yml or generated Xcode project change is expected unless a new
  source file requires project regeneration through `make project`.

## Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: fixed Europe/London 26/27 August scenario; pure continuous coordinate and one-label descriptor; phase/source matrix; stable identity-derived UI frames; instrumented absence of timer and scroll-callback label work; physical-device swipe checklist
- Acceptance matrix and downstream fixture/legacy-suite impact: nine AC rows above; temporal presentation, History motion/cache/authority, active/recorded/inferred UI, accessibility and event-grouping regressions inventoried above
- Focused correction budget: one bounded prototype proving that a scroll-content label layer preserves content size, day stride and lazy motion; then at most three focused corrections or 25 minutes on the label/visual-source surface; one unchanged-source flake rerun only
- Expected expensive commands: focused History UI during story work; `make project`, unit/build/lint/analyze; one source-frozen four-worker `make test-ui` plus structural `.xcresult` verification; physical-device deploy/check
- Maximum rescue tier: Terra, then Sol diagnosis

## Definition of Ready

- [x] The user-visible three-label contract is explicit.
- [x] Label placement is defined in the continuous coordinate space and is
      independent of tiles, midnight, viewport and movement phase.
- [x] Active duration removal and narrow/continuation behavior are decided.
- [x] Native scrolling, data, interaction, accessibility, persistence and
      privacy boundaries are explicit.
- [x] Every acceptance criterion has deterministic observability and a mapped
      verification artifact.
- [x] Downstream fixtures, legacy suites and stable selectors are inventoried.
- [x] The prototype/correction budget and bounded fallback decision are explicit.
- [x] Exhaustive kind mapping, measurement ownership, endpoint roles, shared
      lane authority and non-hit-testing/accessibility overlay behavior are explicit.
- [x] Prototype geometry tolerances, fixture flag/UUIDs, UI-test probe and
      repeatable label-work performance evidence are explicit.
- [x] Independent Sol readiness gate returns `READY`.

## Sol readiness gate

Sol gate: **READY** — `gpt-5.6-sol`, medium reasoning. The gate found the
product decision closed and exhaustive across every existing interval kind,
legacy and unknown treatment, glyph behavior, midpoint anchor, narrow-fit
policy and active-duration removal. All nine criteria have deterministic
observability, negative/edge coverage and named artifacts. The continuous
coordinate, terminal-midnight endpoint roles, shared lane allocator, cached
measurement seam and non-sizing/non-hit-testing/accessibility-hidden overlay
form an executable architecture boundary without persistence, concurrency,
privacy, permission or external-capability changes.

The numerical baseline/candidate prototype is the bounded first implementation
gate; a separate discovery story is not required. During implementation, a
label-projection count may increment only after an identified input-generation
change such as interval data, locale, Dynamic Type or runway extension. Scroll
geometry alone is not such a change.
