# History timeline UX improvement sprint

**Status:** Ready for autonomous implementation  
**Target agent:** Luna 5.6  
**Scope:** History calendar timeline only  
**Assets:** Already created by Codex; Luna must integrate them, not regenerate or redesign them

## Run goal

Refine the settled History calendar so its two-hour rules reach the bottom of
the timeline and food, caloric-drink and non-caloric-drink markers can all be
read and selected in the same two-hour window, including when every category
is a counted group. Use one compact rounded-square marker language, preserve
single-event times, keep grouped counts legible, and leave fasting, persistence,
scrolling and event-editing behaviour unchanged.

## User-visible outcome

At rest, the History timeline must:

- draw every two-local-hour vertical rule from below the time-label band to the
  bottom edge of the calendar surface;
- show food, caloric drink and non-caloric drink in three deterministic vertical
  sublanes when they share a two-hour window;
- show all three at once when each sublane contains a group with a count;
- use the same compact rounded-square silhouette for all three categories;
- retain orange for caloric drink and blue for non-caloric water;
- use slightly smaller marker tiles and count badges than the current build;
- keep a single event's local time visible beneath its marker;
- keep a grouped event's count visible without crossing either of its two-hour
  boundary rules; and
- retain at least a 44-by-44-point interactive target even when the visible
  marker is smaller.

The existing semantic information panel remains the precise, full-size action
surface. Motion, settlement, editors, add-event constraints and automatic-fast
semantics must continue to work as they do now.

## Supplied icon assets

Codex has generated, chroma-keyed, alpha-validated and scaled these project
assets:

- `uFast/Resources/Assets.xcassets/HistoryCaloricDrink.imageset`
  - complete orange rounded-square drink tile;
  - warm-white glass with a straw;
  - 32 px, 64 px and 96 px sources for 1x, 2x and 3x.
- `uFast/Resources/Assets.xcassets/HistoryNonCaloricDrink.imageset`
  - complete blue rounded-square plain-water tile;
  - warm-white glass without a straw;
  - 32 px, 64 px and 96 px sources for 1x, 2x and 3x.

These are complete marker tiles, not standalone glyph masks. Render them at
their intended compact visual size with aspect fit. Do not tint them, add a
second coloured background, crop away their transparent breathing room, trace
them into a new asset, or ask ImageGen for replacements. Keep the existing
food fork-and-knife symbol, but place it in the same rounded-square dimensions
and corner treatment as the supplied drink tiles.

The image-generation source prompts are recorded at the end of this document.

## Read before editing

Read these files completely:

- `AGENTS.md`
- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`
- `DECISIONS.md`, especially D-020 through D-024
- `BACKLOG.md`
- `UX_STYLE_GUIDE.md`
- `SLICE_3_8_COUPLED_HISTORY_SCROLL_STORIES.md`
- `SLICE_3_9_HISTORY_INTERACTION_POLISH_STORIES.md`
- `SLICE_3_10_AUTOMATIC_FAST_HISTORY_STORIES.md`
- `SLICE_3_11_HISTORY_EVENT_GROUPING_STORIES.md`, including the OW-401
  post-delivery refinement
- this sprint document

Then inspect the current implementation and tests before changing anything:

- `uFast/Features/Foundation/TemporalRibbonView.swift`
- `uFast/Domain/TemporalEventGrouping.swift`
- `uFast/Features/Fasting/HistoryView.swift`
- `uFast/Features/Fasting/HistoryEventGroupViews.swift`
- `uFast/App/UFastApp.swift`
- `uFastTests/TemporalEventGroupingTests.swift`
- `uFastUITests/HistoryEventGroupingUITests.swift`
- `uFastUITests/HistoryUITests.swift`

The worktree may already contain intentional, uncommitted Slice 3.11 and test
runtime changes. Preserve them. Do not reset, discard or broadly rewrite
unrelated work.

## Current problems to remove

The current code has three relevant limitations:

1. `ribbonBackground` gives vertical rules a fixed height of 160 points, while
   the normal ribbon is 260 points and the accessibility ribbon is 320 points.
   The rules therefore stop above the calendar bottom. Future shading also
   uses a separate hard-coded height.
2. `eventMarkButton` has only two fixed y offsets: food at 136 and every drink
   at 190. Caloric and non-caloric drinks therefore collide in one two-hour
   window.
3. `TemporalEventGrouping` groups by `food` versus `hydration`. A caloric drink
   and non-caloric drink in the same bucket can become one mixed hydration
   marker, so the presentation model cannot show the three requested visual
   categories independently.

Fix those causes. Do not patch individual fixture positions or add arbitrary
per-record offsets.

## Approved presentation contract

### 1. Three presentation categories

Introduce a SwiftUI-independent presentation category with exactly these
values:

- food;
- caloric drink; and
- non-caloric drink.

Keep `TemporalEventFamily` or an equivalent typed editor-routing distinction
for food versus hydration. Presentation category and storage/editor family are
different responsibilities.

Grouping remains presentation-only and deterministic:

- group events only when they share presentation category and the same local
  two-hour bucket;
- never merge caloric and non-caloric hydration into a mixed marker;
- a single stays a single, and two or more events in one category and bucket
  form a group;
- retain half-open bucket membership `[start, end)` and Calendar/TimeZone/DST
  construction; never divide epoch values by 7,200;
- include presentation category in deterministic group identity and stable UI
  identifiers so two drink groups in one bucket cannot collide;
- retain typed food/hydration member references for editor resolution; and
- retain exact member ordering by occurrence instant and stable UUID.

Recommended stable identifier category components are `food`,
`caloric-drink` and `non-caloric-drink`. Update focused tests and call sites
consistently; do not keep ambiguous hydration-only group identifiers when both
drink categories can coexist.

When a grouped hydration member is reclassified, refresh against its original
category as well as its bucket and family. If the original group no longer has
at least two matching members, dismiss the stale disclosure just as the
existing OW-401 contract requires.

### 2. Three compact marker sublanes

Use a deterministic top-to-bottom order:

1. food;
2. caloric drink;
3. non-caloric drink.

Create a small pure layout/metrics seam rather than scattering literal y
offsets through `TemporalRibbonView`. It must calculate the category lane,
visible tile frame, label/count placement and hit frame for normal and
accessibility Dynamic Type.

For the normal 260-point ribbon, use this target geometry unless measurement
shows a one- or two-point adjustment is needed:

- event area starts at approximately y = 122;
- each category owns a 44-point-high row;
- rows begin at approximately y = 122, 166 and 210;
- visible tile is approximately 26 by 26 points;
- the single-time label gets a separate approximately 14-point band with a
  2-point gap;
- visible content ends at or before y = 258; and
- every marker button remains at least 44 by 44 points.

The visible tile is intentionally smaller than the button. Horizontal
placement remains the midpoint of the two-hour bucket. Clamp the visible tile,
time label and count badge to the bucket's visual bounds so none crosses an
adjacent rule, including at the visible-window edges. Do not change stored
event times to achieve visual centring.

For accessibility sizes, derive or increase the ribbon height and row metrics
as needed so the three rows do not clip or overlap. Do not shrink the touch
targets. The semantic panel and disclosure remain the accessible precision
surfaces; decorative marker content may use a bounded marker-specific text
scale if necessary to stay inside its bucket.

### 3. Single and grouped marker states

Use one shared marker cell so both states fit the same lane:

- **Single:** tile plus its exact local `HH:mm`/locale-equivalent time beneath
  it; no badge.
- **Group:** tile plus a compact count badge; no individual time because the
  members have different exact times. Reserve the same total cell height so a
  state change does not move adjacent lanes.

Reduce the current count badge from its 20-point height to approximately
14–16 points and use a marker-appropriate caption font with monospaced digits.
Keep exact counts for 2–99 and `99+` visually above that. VoiceOver must still
receive the uncapped count. Keep the decorative badge hidden from
accessibility.

Prefer positioning the small badge at the tile's upper trailing area while
keeping it completely inside the bucket's horizontal bounds and its assigned
44-point row. It must not obscure the category glyph at 2x/3x rendering.

Food uses its existing fork-and-knife language in a compact rounded-square
tile. Caloric drink uses `HistoryCaloricDrink`; non-caloric drink uses
`HistoryNonCaloricDrink`. Do not render the non-caloric category as a circle or
as a standalone droplet.

### 4. Full-height two-hour rules

Remove the fixed `height: 160` rule geometry. Pass the actual surface/ribbon
height into the background calculation and draw each two-hour rule from the
existing y = 32 label clearance to the bottom edge of the calendar surface.
Use the same derived height for future read-only shading.

Preserve:

- a rule every two local-calendar hours;
- labels only at 00:00, 06:00, 12:00 and 18:00;
- the existing stronger midnight rule and six-hour hierarchy;
- local Calendar and injected TimeZone/DST behaviour;
- continuous surface clipping and page-edge behaviour; and
- the existing z-order, with rules behind fasting intervals and event tiles.

The marker tile may cover the rule behind it, but no marker tile, time label or
badge may cross the adjacent rules that bound its two-hour bucket.

### 5. Information panel and disclosure

Consume the same category-aware projected items in the visual ribbon and
semantic information panel. Do not create a second grouping calculation.

Keep the existing OW-401 interaction contract:

- singles open their existing editor directly;
- groups open the exact-times disclosure;
- disclosure members open existing food or hydration editors directly;
- Add event remains constrained to the group's bucket;
- there is no group manager or bulk delete surface; and
- successful saves/deletes refresh from committed records, while failed saves
  keep the draft and committed presentation unchanged.

Update category-aware summary and accessibility copy without changing stored
semantics. A grouped marker/row must announce exact count, category, bucket
range and caloric classification. Colour and icon alone are not sufficient.

## Required deterministic coverage

### Unit tests

Extend the pure grouping/layout tests to prove:

- two caloric and two non-caloric hydration events in the same bucket form two
  independent groups;
- food plus both drink categories in the same bucket produces three ordered
  presentation items and three unique stable identities;
- singles remain independent by category;
- half-open two-hour boundaries and spring/autumn DST behaviour are unchanged;
- a hydration reclassification changes presentation category without changing
  its typed hydration editor reference;
- normal metrics provide three non-overlapping visible rows within the ribbon;
- every interactive marker region is at least 44 by 44 points;
- single tile plus time and group tile plus badge both fit their row;
- visible marker content stays inside its two-hour rule bounds at the centre
  and clipped window edges; and
- the grid-rule height equals the derived surface height minus its top label
  clearance for both normal and accessibility ribbon heights.

### UI fixture

Add a focused, deterministic fixture/launch argument or safely extend an
existing fixture to seed one selected two-hour bucket with:

- at least two food events;
- at least two caloric drinks; and
- at least two non-caloric drinks.

Use fixed UUIDs, fixed instants, the injected clock and the existing local
SwiftData UI-test path. Each UI test establishes and resets its own state.

### UI tests

Add or update tests that, after native settlement, verify:

- three unique category group buttons exist for the same bucket and each has
  the correct exact accessibility value;
- all three buttons are enabled and hittable;
- activating each routes to the correct existing disclosure/editor family;
- reclassifying a hydration member moves it to the other visual category and
  removes or refreshes the stale original disclosure correctly;
- a single event still exposes its time and opens its editor directly;
- the three markers, counts and full-height rules are visually present in a
  retained screenshot at a normal text size;
- accessibility XXXL, increased contrast and Reduce Motion retain usable group
  actions without clipping; and
- existing motion hides/non-enables structured interactions until settlement.

Do not rely on coordinate taps to distinguish overlapping marker controls. Use
the stable category-aware accessibility identifiers.

## Verification sequence

1. Inspect the diff and confirm no unrelated user changes were overwritten.
2. Run `make format`.
3. Run `make lint`.
4. Run the focused unit tests for temporal event grouping/layout.
5. Run `make test-unit`.
6. Run `make build`.
7. Before UI tests, check for another active `xcodebuild`/Xcode test run and do
   not kill another user's process.
8. Run focused UI tests serially only for diagnosis.
9. Run exactly one full `make test-ui`; inspect its `.xcresult` and confirm
   every test ran once, none was unexpectedly skipped and all four parallel
   clones started.
10. Review retained screenshots at normal and accessibility text sizes. Check
    the asset edges at 2x/3x, the three-category collision case, count badges,
    single times, rule extent, dark appearance, increased contrast and RTL.
11. Run `git diff --check` and review the final diff for scope expansion.
12. If an iPhone is connected, deploy the verified build with
    `make deploy-iphone`.

## Definition of done

- Every acceptance item above is implemented and verified.
- Food, caloric drink and non-caloric drink can coexist as independent markers
  in one two-hour bucket, including three simultaneous counted groups.
- All visible marker silhouettes are compact rounded squares and no marker
  crosses its two-hour boundary rules.
- Single-event times and multi-event counts each fit cleanly in the shared
  marker cell.
- Two-hour rules and future shading use the real calendar surface height.
- Supplied drink assets are integrated unchanged and not regenerated.
- Existing grouping disclosure, editor, scrolling, settlement, persistence and
  automatic-fast behaviour remains green.
- Unit tests, full parallel UI tests, build, lint and formatting pass.
- No new persistence model, migration, cloud/HealthKit/AI feature or health
  claim is introduced.

## Starting prompt for Luna

```text
Implement the ready History timeline UX sprint in
HISTORY_TIMELINE_UX_IMPROVEMENT_SPRINT.md.

Read every authoritative document and current implementation/test seam named
there before editing. Preserve all intentional uncommitted work in the shared
worktree. The two drink icon image sets have already been created by Codex in
Assets.xcassets; integrate them exactly as supplied and do not regenerate,
redesign, tint or double-background them.

Deliver the complete sprint, not only the visual patch: make grouping
category-aware so food, caloric drinks and non-caloric drinks can form three
independent counted markers in one local two-hour bucket; implement three
compact non-overlapping marker lanes with single-time and grouped-count states;
extend every two-hour rule and future shading to the derived calendar bottom;
preserve 44-point hit targets, accessibility, DST, settled-only interaction,
OW-401 disclosure/editor behaviour and automatic-fast semantics; add the
required deterministic unit/UI coverage; then run the full verification
sequence, including one full four-worker UI suite and xcresult inspection.

Work autonomously through safe in-scope implementation and verification. Stop
only for a genuine product contradiction, an external permission requirement,
or a blocker that cannot be resolved from the repository. Report changed
files, test results, screenshot review findings and any residual risk.
```

## Image-generation record

Codex used the built-in ImageGen path, generated each asset separately against
a flat `#ff00ff` chroma-key background, removed that background locally with
the standard soft-matte/despill helper, validated alpha, then produced the
catalogue's 1x/2x/3x PNGs.

### Caloric-drink prompt

```text
Create a compact warm-orange rounded-square iOS History marker, visually
compatible with the uFast food marker. Centre one unmistakable warm-white
drinking glass with a straw. Use a simple bold, vector-like silhouette,
generous padding and strong contrast that remains legible around 18–24 points.
No food, bottle, coffee handle, droplet, cutlery, text, badge, shadow, gloss,
texture, 3D or photorealism. Put the complete tile on a perfectly flat solid
#ff00ff chroma-key background, using no magenta in the subject.
```

### Non-caloric-water prompt

```text
Create the exact same rounded-square shape, corner radius, visual weight,
padding and glyph scale as the caloric-drink marker, but use a calm muted blue
tile and a warm-white plain-water glass without a straw. Show one simple water
line. Use a bold, vector-like silhouette that remains legible around 18–24
points. No bottle, coffee handle, standalone droplet, cutlery, fruit, text,
badge, shadow, gloss, texture, 3D or photorealism. Put the complete tile on a
perfectly flat solid #ff00ff chroma-key background, using no magenta in the
subject.
```
