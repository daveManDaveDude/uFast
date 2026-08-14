# History streaming continuity

**Story:** HS-101  
**Status:** Ready  
**Prepared:** 12 August 2026  
**Priority:** P0 UX correctness  
**Estimate:** 8 points  
**Product decisions:** D-015 through D-024  
**Product rules:** BR-12, BR-17, BR-22 through BR-26

## User story

As a user browsing the calendar, I want recorded and derived history to remain
visible for the whole scroll, even when I move quickly across months or years,
so that History feels continuous and trustworthy.

## Why now

The calendar currently has two different data horizons:

- `TemporalDayBuffer` initially supplies hundreds of scrollable calendar days
  and can add more days after settlement.
- `HistoryMotionWindow` supplies visual history for only seven calendar days on
  either side of the last settled selection.

Every moving day page is rendered from `motionHistoryPresentation`. A fast
flick can therefore enter a valid calendar page that has no corresponding
motion data. Events and fast intervals disappear while the scroll remains in
motion, then return after native scrolling becomes idle and `reloadHistory`
fetches around the newly settled day. This is a loading-boundary defect, not an
empty-history state and not a `LazyHStack` recycling defect.

The fix must not fetch every complete record at launch. A person may have years
of local food, hydration and fasting history, and the settled editor/detail
surface needs richer data than the moving visual ribbon.

## Outcome

History uses a progressively loaded visual runway. A date is made scrollable
only after its compact motion presentation is ready. More calendar-day chunks
are loaded ahead of the viewport and published atomically with their dates.
Consequently, an unloaded date can never become a visible carousel page and
already visible history is never replaced by an empty presentation during a
load, retry or stale-result race.

The exact settled window continues to use the existing authoritative range
query, automatic-fast derivation and editor snapshots. Motion-time data is a
separate compact, read-only projection containing only what the ribbon needs to
draw.

## Selected implementation approach

### 1. Establish a loaded-coverage invariant

Introduce a History motion store/coordinator with one published immutable
snapshot containing:

- a contiguous range of loaded local-calendar days;
- the exact ordered dates that the carousel may scroll through;
- compact interval and event render primitives for that coverage;
- the calendar and time-zone identity used to build it;
- a data revision/generation; and
- loading state for a preceding or following extension.

The coordinator must enforce this invariant:

> Every date supplied to `TemporalHistoryCarousel.dates` has a complete motion
> projection for its 26-local-hour visual window. Dates and render data are
> published in the same state change; neither may lead the other.

“Complete” includes a legitimately empty day. Loaded-empty and not-loaded must
be distinct states. The UI must never translate not-loaded into “no history.”

The future bound remains Today + 1 local-calendar day under D-023. Past
coverage has no product horizon and can extend for as many years as the local
store contains.

### 2. Load compact calendar chunks, not full History screens

Add a background-safe range loader, backed by an independent SwiftData
`ModelContext`/model actor, that returns Sendable value snapshots. It must not
pass SwiftData model objects across isolation boundaries.

Use calendar arithmetic for every chunk boundary. The initial runway extends
120 calendar days on each side of its target, capped at the existing future
bound; opening on Today therefore loads 120 past days through Tomorrow. When
the viewport centre comes within 30 days of a loaded edge, request the next
120-day chunk in that direction. Keep these policy values in one internal
configuration type so they can be benchmarked and tuned without changing
product semantics.

Each chunk query includes:

- food and hydration events in the chunk's visual coverage;
- recorded fasts intersecting that coverage;
- the nearest caloric event before and after the coverage, as required by
  BR-24; and
- the one-hour context on either side required by the continuous 26-hour page
  treatment.

Project the result into minimal motion primitives. A motion event must retain
only stable identity, occurrence instant, visual family/category and the state
needed for its mark or group badge. A motion interval must retain only stable
identity, absolute start/end, presentation kind and the state needed to draw
it. Do not retain food descriptions, nutrition fields, hydration editor data,
settings snapshots or SwiftData records in the motion cache.

Chunk seams must be invisible. Deduplicate primitives by stable identity, and
derive crossing automatic fasts from the real caloric neighbours rather than
from a chunk edge. Recorded-fast precedence remains identical to the settled
presentation. The same event or interval must not flash, duplicate or change
kind when adjacent chunks join.

### 3. Prefetch from coarse geometry without disturbing native scrolling

Use the existing scroll-geometry observation to calculate distance from loaded
coverage, but publish a prefetch intent only when a threshold is crossed.
Geometry-frame handling must remain O(1) and must not query SwiftData, rebuild
arrays, derive automatic history or broadly mutate parent view state on every
frame.

Allow at most one request per edge and generation. Coalesce duplicate requests.
A result may extend the published snapshot only when its generation, calendar,
time zone and expected adjacent boundary still match. Discard stale results
without altering visible data.

Dates for a new chunk are appended or prepended only in the same transaction
that installs that chunk's render primitives. Preserve existing `Date` identity
and native scroll position when extending either edge. Loading must not force a
selection, snap, animation, movement-phase transition or accessibility
announcement.

An unusually fast fling may reach the end of the currently loaded runway before
the next local query completes. In that case native scrolling may resist at the
last loaded page, but that page keeps all of its history. After the extension
arrives, scrolling can continue. Showing a populated boundary briefly is
preferable to showing an unloaded blank page.

### 4. Retain traversed visual history for the History session

Retain compact motion chunks already traversed while `HistoryView` remains
alive, so reversing direction never makes records disappear or triggers a
query for the pages still in the carousel. This cache is deliberately compact
and contains no editable record payload.

Do not load intervening years for a deliberate date-picker jump. Load a new
initial runway around the requested day in the background, keep the prior
settled History presentation visible and non-interactive while the request is
pending, then atomically commit the target selection, dates and motion snapshot.
On failure, keep the prior selection and history and offer a calm retry
treatment. Do not show the requested day as an empty day.

When History disappears, its session cache may be released. Relaunch and tab
re-entry rebuild it from SwiftData; no cache is persisted and no migration is
needed.

If Instruments shows that the stress fixture exceeds the memory target below,
add settled-only eviction as a follow-up within this story: evict whole distant
chunks together with their scrollable dates, retain at least one full runway on
both sides of the exact visible interval, and preserve the exact fractional
visible instant while rebasing. Never evict or rebase during tracking,
deceleration or alignment. Do not add eviction speculatively before measuring
the compact representation.

### 5. Keep settled authority separate

The settled exact-window fetch remains the authority for:

- the structured fast list and empty state;
- event grouping and exact-time disclosure;
- food, hydration and recorded-fast editor routing;
- settings and active-fast authority; and
- mutations and post-commit recalculation.

Motion primitives are visual only and cannot open an editor while movement is
unresolved. At idle, continue to fetch the exact visible `DateInterval`,
including the nearest caloric neighbours, and replace the settled presentation
only after that complete fetch and projection succeed.

Preserve D-020 and D-021's intentional suppression of the structured detail
card during motion. HS-101 prevents visual ribbon history from disappearing; it
does not make settled controls actionable during a moving scroll.

### 6. Make mutation, environment and failure handling atomic

After a successful food, hydration or fast mutation, increment the History data
revision. Rebuild the current exact window and any cached motion chunks whose
visual coverage can be affected. Caloric mutations must also invalidate the
adjacent automatic-gap projection on both sides. Install replacements
atomically; do not clear working presentations first.

Locale-only changes may reformat settled copy without refetching. A calendar or
time-zone change invalidates local-day chunk boundaries; build a replacement
runway around the preserved absolute visible/selected instant and swap it only
when complete. Continue to preserve stored absolute instants under BR-12.

If an initial motion load fails, show a calm unavailable/retry state rather
than an empty-history claim. If an extension fails, retain the loaded runway,
record the retryable edge failure and allow settled History inside that runway
to remain fully usable. Never clear `historyPresentation` or motion data merely
because a speculative extension failed.

## In scope

- Replace the fixed `HistoryMotionWindow.dayRadius == 7` snapshot with the
  progressively loaded motion coordinator and compact chunk projection.
- Make the carousel's scrollable dates and loaded motion coverage one atomic
  state boundary.
- Add threshold-based asynchronous prefetch, request coalescing, generation
  checks and stale-result rejection.
- Preserve visible data on extension, exact-fetch and retry failures.
- Support direct jumps without loading all intervening dates.
- Add deterministic fixtures, unit tests, parallel-safe UI tests and a measured
  ten-year performance check.
- Remove obsolete fixed-window code and tests after equivalent coverage exists.

## Out of scope

- Changing the temporal ribbon design, 26-hour page geometry, native inertia,
  free fractional settlement or coupled date-rail behavior.
- Showing structured detail or enabling edit/add actions during motion.
- Persisting derived automatic fasts, day pages, cache entries or selected
  dates.
- Adding a historical retention limit, deleting old records or rewriting user
  history.
- Statistics, search, import/export, cloud sync, telemetry or networking.
- Custom velocity/deceleration physics or a timer/display-link scroll sampler.
- A persistence schema migration.

## Product and domain rules

- BR-12: Calendar and time-zone changes preserve absolute instants.
- BR-17: Recorded fast overlap and half-open interval behavior remain
  unchanged.
- BR-22 and BR-23: Automatic fasts still derive from consecutive saved caloric
  events and are never persisted.
- BR-24: Every visual or settled window includes the nearest caloric neighbour
  beyond each edge and gives recorded fasts presentation precedence.
- BR-25: Motion loading cannot create a fast or another write path.
- BR-26: All behavior remains local, offline and SwiftData-backed without
  CloudKit.
- D-015 through D-023 continue to govern temporal geometry, accessibility,
  native motion, fractional settlement, future browsing and Today eligibility.

No new product decision is required if implementation preserves this contract.
If the platform cannot atomically extend dates and data without changing native
scroll geometry, stop and record evidence before choosing a custom scrolling
implementation or changing D-017/D-021.

## Acceptance criteria

1. Given motion data is loaded through day N, when day N is present in the
   carousel, then all recorded fasts, automatic fasts and food/hydration marks
   belonging to its visual window are present throughout tracking,
   deceleration, alignment and settlement.
2. Given a fast flick travels beyond the former seven-day motion radius, then
   history remains visible continuously and does not disappear and repopulate
   at idle.
3. Given repeated backward scrolling crosses at least five chunk boundaries,
   then each extension appears without a jump, snap, duplicate, selection
   churn, empty frame or loss of already visible history.
4. Given the user immediately reverses direction after several extensions,
   then previously traversed pages render from memory and remain populated.
5. Given a page truly has no records, then it renders the legitimate empty
   ribbon state; given a page is not loaded, then that page is not exposed as a
   scrollable date and is never described as empty.
6. Given an automatic fast crosses a chunk boundary or either edge of a 26-hour
   page, then it is rendered once with the same absolute boundaries and
   recorded-fast precedence as the exact settled projection.
7. Given London spring-forward or fall-back history, then chunk coverage,
   prefetch thresholds, visual context and settlement use calendar days and the
   correct 23- or 25-hour elapsed day; no event is lost or duplicated.
8. Given an extension request is slow or fails, then the current loaded page
   and its history remain visible and usable at rest; retry cannot publish an
   empty replacement or a stale generation.
9. Given the date picker selects a day ten years earlier, then History does not
   fetch every intervening record. It commits the requested day only after a
   complete target runway is ready, and failure preserves the prior view.
10. Given a successful caloric event add, edit, delete or reclassification,
    then affected cached automatic intervals on both sides are refreshed after
    commit, while cancelled or failed mutations change no settled or cached
    presentation.
11. Given a locale change, time-zone change, background interruption, sheet
    presentation or Dynamic Type change, then no stale async result can replace
    a newer History generation and native motion terminates under the existing
    coordination rules.
12. Given VoiceOver, Switch Control, Reduce Motion or an accessibility Dynamic
    Type size, then passing motion pages remain decorative, the last settled
    semantic selection remains stable, and all existing button, date-picker
    and structured-list alternatives remain operable.
13. Given offline mode, then initial loading, extension, direct jumps, retries
    and editing continue to use only the local store and request no permission
    or network access.

## Performance contract

Create a deterministic stress fixture containing ten years of history, 25
food/hydration events per day, two recorded fasts per week and automatic gaps
crossing ordinary, month, year and DST boundaries.

The implementation is acceptable when measurement demonstrates:

- History launch fetches only the initial runway plus required neighbours, not
  the ten-year store.
- A direct ten-year jump fetches only the target runway plus required
  neighbours, not intervening years.
- Range queries run off the main actor and publish at chunk granularity.
- Scroll-geometry callbacks perform no persistence query, projection, sorting
  or per-frame array rebuild.
- One edge/generation has at most one in-flight request, with duplicate intents
  coalesced.
- Compact motion cache growth is proportional to traversed visual primitives,
  not full model payload; the ten-year fixture adds no more than 50 MB while
  traversing the full range in one History session.
- Instruments shows no main-thread stall of 100 ms or more attributable to
  range fetching/projection and no sustained frame hitch when a prefetched
  chunk is installed.

If the measured cache exceeds 50 MB, implement the settled-only eviction path
defined above and repeat the full continuity suite in both scroll directions.
Do not weaken the no-unloaded-page invariant to meet the memory target.

## States and edge cases

- First launch with no history: loaded-empty pages are valid and stable.
- Sparse multi-year history: automatic intervals crossing long empty spans use
  real saved boundary events and are not manufactured from chunk edges.
- Dense same-instant events: stable identifier ordering and grouping remain
  deterministic across chunks.
- Active fast: its visual interval continues through `clock.now`; periodic
  display updates do not refetch historical chunks each second.
- Future context: tomorrow remains fully read-only and no later date is loaded.
- Store error: retain last complete published state; never relabel unavailable
  data as no history.
- Concurrent request completion: only the matching generation and adjacent
  chunk may extend coverage.
- Rapid direction reversal: requests for opposite edges may be queued, but
  each edge remains coalesced and published only when valid.
- Calendar/time-zone change during load: discard the old result and rebuild
  boundaries from the new environment.
- Midnight while History is open: update Today/tomorrow bounds with calendar
  arithmetic without dropping the current historical runway.
- Memory pressure: release non-visible settled editor payloads first; any
  motion-cache trimming follows the settled-only invariant above.

## Data, privacy and accessibility

- Read only app-created local SwiftData records already used by History.
- Persist no cache, scroll position, projection or derived interval.
- Add no account, CloudKit, network call, analytics, diagnostic payload or
  system permission.
- Do not infer missing history or convert unavailable data into an empty day.
- Motion remains decorative and hidden from accessibility. The last settled
  day and exact structured detail remain the semantic truth until the next
  valid settlement.
- Existing contrast, future shading, minimum target sizes, VoiceOver actions,
  Reduce Motion and large-text alternatives remain unchanged.

## Implementation notes and likely files

- `uFast/Domain/TemporalHistoryPresentation.swift`: replace or narrow
  `TemporalDayBuffer` responsibilities; add deterministic loaded-coverage and
  chunk-boundary value types.
- `uFast/Persistence/HistoryDataProvider.swift`: add the isolated compact
  motion range query while preserving the exact settled provider.
- `uFast/Features/Fasting/HistoryView+Data.swift`: own generations, initial
  load, atomic extension, target jump and failure retention.
- `uFast/Features/Fasting/HistoryView.swift`: consume one atomic motion snapshot
  rather than independent `historyDates` and optional motion arrays.
- `uFast/Features/Foundation/TemporalHistoryCarousel.swift`: emit coarse
  edge-proximity intent without per-frame data work.
- `uFast/Features/Fasting/HistoryPresentationSnapshot.swift`: share domain
  derivation where correct, but keep the compact motion payload separate from
  settled editor/detail snapshots.
- `uFastTests/HistoryDataProviderTests.swift` and
  `uFastTests/TemporalHistoryPresentationTests.swift`: chunk, neighbour, DST,
  stale-generation, coalescing and loaded-coverage tests.
- `uFastUITests/HistoryUITests.swift`: multi-chunk continuity, reversal,
  direct-jump, retry and accessibility coverage using isolated launch
  fixtures.

Names are illustrative. Preserve repository conventions and split types into
focused files if that keeps the existing History components bounded.

## Verification

- Characterize the current defect first with a test whose seeded events are
  visible before, during and after a flick beyond seven days; prove it fails on
  the old fixed motion window.
- Unit-test calendar chunk construction across month/year boundaries and both
  London DST transitions.
- Unit-test the atomic invariant: no published date lacks a loaded motion tile,
  and no stale/failed request removes a complete tile.
- Unit-test request coalescing, opposing-edge requests, generation changes and
  out-of-order completion with a controllable fake loader.
- Unit-test automatic-fast derivation and recorded precedence at both chunk
  seams and visual-window edges.
- Persistence-test sparse and dense ranges, exact query bounds, neighbours and
  direct jumps with an in-memory SwiftData store.
- UI-test a fast flick beyond seven days, at least five sequential extensions,
  immediate reversal, a ten-year date-picker jump, an injected extension
  failure and relaunch. Assert committed selected state only after bounded
  waits and include `app.debugDescription` in timing-sensitive failures.
- UI-test London DST, year boundary, Reduce Motion and accessibility text using
  isolated `--ui-testing` fixtures.
- Run the ten-year Instruments/time-profiler and allocations scenario on the
  lowest-supported iPhone class or closest available simulator, and record the
  observed query count, peak cache size and main-thread stalls.
- Run `make format`, `make build`, `make test-unit`, `make lint` and one full
  `make test-ui` invocation. Inspect the `.xcresult` to confirm every test ran
  exactly once and all four clones started.
- If an iPhone is connected, deploy the verified app with
  `make deploy-iphone` under the repository Definition of Done.

## Done when

History can be scrolled continuously through multi-year dense and sparse local
fixtures without visual records disappearing, unloaded data is never presented
as empty, memory and main-thread work remain bounded by the performance
contract, all existing temporal/domain behavior is preserved, and the complete
repository quality gate passes.

## Definition of Ready check

- [x] The user outcome and observed defect are explicit.
- [x] Root cause is tied to the current code path.
- [x] Scope is one coherent, reviewable behavior change.
- [x] The loaded-coverage invariant resolves the blank-page race.
- [x] Multi-year performance and memory expectations are measurable.
- [x] Automatic-fast boundaries, mutations, DST and failures are covered.
- [x] Privacy, accessibility and offline behavior are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.
