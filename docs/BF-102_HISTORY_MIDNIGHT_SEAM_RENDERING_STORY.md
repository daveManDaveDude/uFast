# BF-102 — Keep an edited active fast continuous across History midnight

**Slice:** History visual reliability  
**Priority:** P0 UX correctness  
**Status:** Ready  
**Story type:** Regression bug fix

## User outcome

As a user who corrects an active fast's start into the previous day, I want
History to show the same complete fast on both sides of midnight immediately,
so that scrolling cannot make half of the active interval disappear.

## Why now

The earlier BF-102 attempt did not fix the reported defect. The user has now
provided a repeatable journey and two screenshots captured at approximately
08:40 on Sunday 16 August 2026 with an active fast corrected to start at 21:00
on Saturday 15 August:

- `Screenshot 2026-08-16 at 08.40.15.png` shows only the post-midnight portion
  while History is positioned on 16 August.
- `Screenshot 2026-08-16 at 08.41.01.png` shows only the pre-midnight portion
  while History is positioned on 15 August.

The structured History row still describes one active fast starting at 21:00,
so the saved record is present. Adding a non-caloric drink after midnight makes
the visual defect disappear without changing the fast. That control case is a
required part of the reproduction: it indicates that an event-triggered History
refresh may be reconciling presentation state that the active-start correction
left stale. The implementation must prove the cause rather than assume that
page clipping or corner geometry is solely responsible.

Any existing unaccepted BF-102 source or test changes in the working tree are
prior-attempt evidence, not an accepted solution. Preserve useful work only
where it satisfies this revised contract.

## Context and authoritative rules

- D-015 says a fast remains one absolute interval when clipped by a viewport or
  rendered across midnight.
- D-021 gives History one free-scrolling, continuous time window assembled from
  touching local-calendar day segments. Settled detail uses the exact visible
  interval.
- D-022 separates transient moving presentation from the low-frequency settled
  selection; it does not permit those projections to disagree about records.
- BR-03 permits only one active fast. BR-12 preserves its absolute instants
  across time-zone and DST changes. BR-24 presents a user-recorded fast whenever
  it intersects the exact settled visible interval.
- BF-101 defines the 36-hour bound for active-start correction. BF-102 consumes
  a successful correction and does not change its validation policy.
- History remains local-only and read-only for fast creation under BR-25 and
  BR-26. No record may be inferred, split, duplicated or rewritten to repair a
  presentation defect.

## Deterministic reproduction

Use an injected `AppClock`, Europe/London calendar/time zone and an empty,
onboarded local store:

1. Fix now at Sunday 16 August 2026, 08:40 local time.
2. On Today, start one active fast at now.
3. Use **Edit start time** and successfully change that same fast's start to
   Saturday 15 August 2026, 21:00.
4. Open History without adding or editing any food or drink.
5. Settle the free-scrolling timeline with the midnight seam visible, then move
   far enough in each direction to view the 15 August and 16 August fragments.
6. Observe the same active-fast identifier, stored start and elapsed duration
   through deterministic semantic/test state as well as screenshots.
7. As a control, add a non-caloric water entry at a valid instant after midnight
   without ending the active fast, return to the same History positions and
   compare the result.

The regression is reproduced when either side of the 21:00-to-08:40 interval is
absent before the drink mutation, the visible half changes with scroll position,
or the pre-drink and post-drink presentations differ even though both contain
the same active-fast record. A screenshot alone is supporting evidence, not the
only assertion.

## In scope

- Prove which presentation becomes stale after the Today active-start mutation:
  the exact settled snapshot, compact motion snapshot/chunks, page source
  selection, or their invalidation/publication boundary.
- Make a successful active-start correction visible consistently in every
  already-created History projection before the user can observe History.
- Keep settled and motion sources coherent for the same record identifier,
  start, active end at injected `now`, lane and interval kind.
- Render the crossing active fast as complementary adjacent fragments of one
  interval, with neither page depending on a food or hydration event to become
  correct.
- Add deterministic state-level and UI regression coverage for the exact
  start/edit/open-History journey and the post-midnight non-caloric-drink control.
- Retain focused clipping/finite-geometry tests only where they protect the
  demonstrated failure surface.

## Out of scope

- Redesigning the History timeline, page width, free scrolling, inertia, date
  rail, event grouping, future shading or label cadence.
- Changing the 36-hour start policy, fast overlap rules, active-fast duration,
  drink classification or caloric-event prompts.
- Refreshing History by fabricating an event, duplicating the active fast,
  persisting page fragments or querying SwiftData from geometry callbacks.
- Broad cache, loader or persistence rewrites not required by the proven
  invalidation/publication cause.
- New schema, migration, network, CloudKit, analytics, health interpretation or
  external capability work.

## Final user-visible behavior and edge cases

- Immediately after the successful start correction, History shows one
  continuous active interval from 15 August at 21:00 through injected `now` on
  16 August at 08:40. Internally clipped page fragments share one identity and
  meet at local midnight without a gap, overlap, false end-cap or lane change.
- Settling or scrolling to either side of midnight never makes the other
  relevant fragment stale or changes the interval's start, active end, kind or
  elapsed duration.
- Adding a non-caloric drink after midnight adds its marker but does not repair,
  move, resize or otherwise change the already-correct fast.
- Switching Today → History repeatedly, leaving History pre-instantiated in the
  tab hierarchy, backgrounding/foregrounding and re-entering History do not
  restore an older pre-correction projection.
- A cancelled or failed start correction leaves the prior active-fast
  presentation unchanged. A successful correction publishes only the committed
  value; no intermediate draft appears in History.
- A correction that remains within one local day continues to update History
  without regression. A corrected interval touching midnight uses half-open
  intersection rules and is neither duplicated nor lost.
- London DST boundaries use Calendar-derived local midnights while retaining
  the same absolute active-fast instants.
- VoiceOver and structured detail expose one active fast, not one semantic item
  per clipped page. Dynamic Type, Reduce Motion, increased contrast, 12/24-hour
  locales and RTL remain usable.
- Saved data remains unchanged except for the user-requested start correction
  and, in the explicit control case, the user-added drink.

## Acceptance criteria

1. **The reported journey is fixed before any event mutation**  
   Given the deterministic reproduction through a real start and successful
   **Edit start time** action, when History first becomes observable, then the
   active fast is rendered from 15 August 21:00 through 16 August 08:40 with
   both midnight-adjacent fragments present and one stable record identifier.

2. **Both History positions use the committed interval**  
   Given the corrected fast and no post-midnight event, when the timeline
   settles on each side of midnight and reverses direction, then every visible
   fragment derives from the same committed start and injected active end; no
   fragment disappears, uses the pre-correction start, changes lane or acquires
   a false rounded boundary.

3. **Settled and motion projections reconcile atomically**  
   Given History presentation state that was created before the correction,
   when the correction commits while Today is selected and History is then
   opened, then no renderable state combines an old motion primitive with a new
   settled primitive (or the reverse). Dates and their compact projections are
   published coherently, and a failed refresh retains the last complete truth
   rather than a mixed or empty timeline.

4. **A drink is not a repair trigger**  
   Given the already-correct pre-drink History presentation, when a non-caloric
   water entry is saved after midnight without ending the active fast, then its
   marker appears and the fast's identifier, start, active end, lane and
   midnight continuity remain unchanged. The same journey without that drink
   already passes.

5. **Mutation outcomes are honest**  
   Given a cancelled or failed active-start correction, when History is opened,
   then it continues to show the previously committed interval. Given a
   successful correction, History never exposes the draft or the superseded
   start after the successful outcome is available.

6. **Temporal boundary coverage**  
   Given starts before midnight, exactly at midnight, wholly within one day and
   across both London DST transitions, when the same mutation and History
   journey runs, then half-open intersection, actual local-day duration and
   absolute-instant identity remain correct without duplication or loss.

7. **Accessibility and scope preservation**  
   Given VoiceOver, accessibility Dynamic Type, Reduce Motion, increased
   contrast, 12/24-hour locales or RTL, then History exposes one understandable
   active fast and operable navigation without relying on colour. No schema,
   stored-fragment, event-semantic, privacy or external-capability change is
   introduced.

## Architecture and data boundaries

- `FastStartService` and the active-fast repository remain the write authority.
  The fix begins only after a successful committed correction and must not alter
  BF-101 validation or mutation semantics.
- `HistoryPresentationSnapshot` remains the exact settled authority;
  `HistoryMotionSnapshot`/`HistoryMotionPresentation` remains the compact moving
  authority. A lifecycle/invalidation mechanism may coordinate them, but one
  source must not silently remain at the pre-correction record revision.
- `HistoryView` tab activation, exact reload, motion-runway creation and loaded-
  chunk refresh are the primary investigation boundary. The discriminator that
  a History drink save currently clears the bug must be traced through that
  path before changing temporal geometry.
- `TemporalHistoryCarousel` may select settled versus motion primitives by
  movement state, but both inputs must represent the same committed active fast.
  `TemporalHistoryPresentation` and `TemporalRibbonView` remain responsible for
  pure clipping and page-local drawing after coherent inputs are supplied.
- Prefer an existing post-commit revision/refresh boundary over direct
  cross-feature model coupling. Do not pass SwiftData model objects between
  features or perform persistence work from high-frequency scroll callbacks.
- No SwiftData schema, migration, permission, privacy disclosure or network
  change is expected. If the proven cause requires a broader application-wide
  invalidation contract, stop at the smallest explicit boundary and request a
  follow-on story rather than hiding that expansion here.

## Dependencies and explicit decisions

- BF-101 must have delivered the successful previous-day active-start
  correction used by this story.
- D-015 and D-021 through D-024 remain unchanged.
- The two supplied screenshots are diagnostic evidence stored outside the
  repository; deterministic fixtures and assertions must not depend on those
  files being available during test execution.
- The prior BF-102 attempt is not an accepted dependency. Its broad geometry
  changes and tests must be evaluated against this reproduction and removed or
  narrowed if they do not address the stale-projection cause.
- No product decision is open: committed active-fast edits must be reflected in
  History without requiring a second, unrelated mutation.

## Focused verification

- Add a pure/state-level test that primes pre-correction settled and motion
  History state, commits a changed active start crossing midnight, performs the
  production invalidation/activation transition and proves both sources contain
  the same identifier and revised interval before rendering.
- Add a focused UI test with fixed 16 August 2026 08:40 Europe/London time that
  performs Start fast → Edit start time to 15 August 21:00 → History, settles on
  both sides of midnight, and asserts semantic identity plus bounded non-zero
  frames for both complementary fragments. Retain screenshots for human visual
  comparison.
- In the same deterministic fixture or a separate control, add non-caloric
  water after midnight, return to the same offsets and assert that only the
  marker set changes.
- Cover cancelled/failed correction and one successful same-day correction at
  the smallest service/presentation boundary. Retain existing DST and clipping
  tests as regressions; add new cases only where the corrected invalidation path
  needs them.
- Manually repeat the supplied journey on an iPhone-sized surface in both scroll
  directions and check VoiceOver, large Dynamic Type, Reduce Motion, increased
  contrast, RTL and 12/24-hour display.
- The story worker runs focused unit tests and the new/changed History UI tests
  after the repository Xcode preflight. At the source-frozen integration gate,
  run `make build`, `make test-unit`, the single full parallel `make test-ui`
  suite with `.xcresult` verification, and `make lint`; do not run an early full
  UI suite during story correction.

## Execution profile

Execution profile:
- Uncertainty: medium
- Initial implementer: Luna xhigh
- Deterministic reproduction and observability: fixed Europe/London clock; real
  start/edit/tab journey; stable active-fast ID and interval values in settled
  and motion state; two seam positions; pre/post non-caloric-drink control;
  semantic assertions plus retained screenshots
- Focused correction budget: one diagnostic pass to prove the stale authority,
  then at most three focused corrections on this acceptance surface or 25
  minutes without a proven root cause; only one unchanged-source flake rerun
- Expected expensive commands: focused History UI test during story work; one
  source-frozen `make build`, `make test-unit`, `make test-ui`, UI result
  verification and `make lint` at integration
- Maximum rescue tier: Sol diagnosis

## Definition of Ready

- [x] The exact start/edit/open-History journey and fixed local instants are
      deterministic.
- [x] Both failure screenshots and the post-midnight-drink discriminator are
      translated into independently testable criteria.
- [x] The story separates committed data correctness, settled/motion coherence
      and pure page clipping without assuming the previous root cause.
- [x] Scope excludes fast policy, persistence schema, event semantics and a
      History interaction redesign.
- [x] Failure, cancellation, DST, accessibility and local-only boundaries are
      explicit.
- [x] Sol readiness gate has returned an explicit `READY` verdict for this
      revised contract.

## Sol readiness gate

Sol gate: **READY** — `gpt-5.6-sol`, medium reasoning. Sol found one coherent
regression outcome with deterministic reproduction, bounded diagnostic and
correction budgets, observable settled/motion coherence, the post-midnight
drink control, and explicit architecture, accessibility, privacy and local-only
boundaries. Root cause is intentionally unproven but is not a readiness blocker
because the first diagnostic pass is finite. No split or document changes were
required; BF-101 remains the explicit execution dependency.
