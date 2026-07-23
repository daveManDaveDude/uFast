# Slice 3.6 — Direct history navigation and repair

**Sprint status:** OW-360 through OW-365 done
**Production status:** Done 23 July 2026
**Story order:** OW-360 → OW-361 → OW-362 → OW-363 → OW-364 → OW-365

## Outcome

Make History itself the place where a user browses and repairs recent days.
The date navigator and temporal detail move together, and the separate visible
**Catch up** action is removed.

A user should be able to:

- swipe left or right to move one local-calendar day at a time;
- tap a date to move the temporal detail to that date;
- swipe the temporal detail and see the date navigator follow it;
- browse several previous days without opening a separate range form;
- tap an empty point in a completed day's temporal detail;
- confirm the selected local date and time, then choose Food or Drink;
- complete the existing historical food or drink editor;
- review eligible fasting reconstruction proposals without relearning a
  separate Catch-up interface.

This sprint changes History navigation, gesture ownership, draft presentation
and routing only. It does not change what constitutes a saved event or fast,
what is inferred, or when persistence occurs.

## Behaviour-preservation review

The requested experience is feasible without changing persistence models,
record semantics, reconstruction rules or transaction boundaries, provided the
eight-hour requirement is interpreted as the existing reviewable proposal rule.

| Request | Classification | Preserved implementation boundary |
| --- | --- | --- |
| Swipe left/right to change date | Presentation-only | One shared, transient `selectedDate`; no selected date is persisted |
| Keep date navigator and temporal detail in sync | Presentation-only | Both controls bind to the same locale/calendar-derived day selection |
| Remove the Catch up button | Navigation decision change, not domain change | Existing repair and reconstruction services remain reachable from History |
| Browse previous days from temporal detail | Presentation-only | Paging changes a viewport; it does not create a range or records |
| Tap detail to choose date/time | Presentation-only draft mapping | Geometry maps to an absolute instant; the editor confirms it before save |
| Offer Food or Drink | Presentation-only routing | Reuse existing historical editors, validation, D-013 and invalidation paths |
| Treat an 8+ hour caloric gap as a fast | Safe only as an existing proposal | It remains unsaved until Accept/Adjust/Leave unknown review and atomic save |

### Core change explicitly excluded

Automatically displaying an unreviewed gap as a saved or established **fast**,
or saving it when the second caloric event is added, would change product
semantics and trust boundaries. It would conflict with BR-09, BR-18, S3-D3 and
S3-D4.

Slice 3.6 therefore uses this wording and behaviour:

- two consecutive saved caloric events at least eight absolute hours apart may
  produce an existing **Suggested fast · Needs review** proposal;
- the proposal is visually distinct from recorded and confirmed reconstructed
  fasts;
- it does not become a `FastRecord` until the user completes the existing
  proposal review and final atomic save;
- under-eight-hour gaps, open edges, conflicts and non-caloric drinks retain all
  current handling.

If automatic recognition or saving is desired instead, stop this sprint and
refine a separate domain story before implementation.

## Interaction contract proposed for approval

### One source of date truth

`selectedDate` is the sole transient selection shared by:

1. the month heading and native date jump;
2. the compact date navigator;
3. the paged temporal detail;
4. the structured accessibility detail;
5. a pending add-event draft.

Selecting or paging any one updates the others. Programmatic synchronisation
must not animate a second competing movement or create feedback loops.

### Gesture ownership

The current ribbon internally scrolls horizontally, which conflicts with using
the same gesture to change days. Slice 3.6 gives the primary horizontal gesture
to day paging:

- a deliberate horizontal swipe over the temporal detail changes one day;
- the temporal content for a day fits its page rather than owning a second
  free-scrolling horizontal surface;
- date chips may scroll to keep the selected date visible, but a chip tap
  selects exactly one day;
- native back gestures and sheet gestures retain precedence at screen edges;
- Reduce Motion replaces travel animation with a restrained selection change.

This is a visual geometry change only. The evening-to-evening absolute-time
window, DST honesty and single-record interval identity remain unchanged.

### Direct historical entry

Tapping an empty part of a completed-day timeline creates an in-memory pending
instant derived from the page's actual absolute-time window.

The app then:

1. presents the selected unambiguous local date and time;
2. lets the user adjust it with native date/time controls;
3. offers **Food**, **Drink** and **Cancel**;
4. opens the existing full historical editor;
5. creates no record until that editor's existing Save action succeeds.

Tapping an existing event or interval continues to open its existing detail or
editor. Event hit targets take precedence over the empty-canvas add gesture.
Today and future instants are not historical-entry targets; Today continues to
use the Today journey.

On a repeated autumn hour, the confirmation must distinguish the two absolute
instants with GMT/BST context where needed. On a missing spring hour, geometry
must never produce a nonexistent local time.

### Reconstruction entry without a Catch up button

History exposes proposal review contextually after confirmed caloric evidence
exists, using neutral copy such as **Review suggested fasting periods**. It is
not a persistent badge, score or claim that a fast occurred.

The first implementation scope is a one-completed-day review range derived from
the selected day. This is already valid under the existing one-to-seven-day
domain contract and still permits outside-range caloric neighbours. The existing
range selector and multi-day review implementation remain in the codebase but
lose their standalone History button.

No proposal is generated during timeline drawing. Generation begins only when
the user opens review, and all existing review, conflict and atomic-save rules
remain in force.

## Non-negotiable boundaries

Preserve all Slice 1–3.5 data and behaviour except the intentionally replaced
History entry/navigation presentation.

Do not change:

- persistence schema, migrations or record meanings;
- food or hydration caloric semantics;
- the absolute eight-hour proposal threshold;
- consecutive-boundary extraction or range-edge rules;
- BR-17 conflict handling or D-013 active-fast handling;
- Accept, Adjust and Leave unknown meanings;
- final-review atomicity, rollback or invalidation;
- provenance meanings or ordering;
- saved fast identity across midnight or day pages;
- the one-to-seven-day `CatchUpRange` domain limit;
- Today entry behaviour;
- HealthKit, analytics, scoring, coaching, reminders or cloud behaviour.

Blank days remain neutral. Browsing a date does not start a repair session,
mark it incomplete or imply a missing fast.

## UK, locale and accessibility contract

- Derive page boundaries and date movement from injected `Calendar` and
  `TimeZone`; never add 24 hours to move one local-calendar day.
- Respect locale first weekday, day–month order and 12/24-hour formatting.
- Test Europe/London spring and autumn transitions and month/year boundaries.
- Map a tap through the actual absolute window, not a hardcoded 24-hour scale.
- Keep the selected day visible without relying on colour.
- Give every swipe action equivalent buttons, date controls and VoiceOver
  adjustable actions.
- Provide a structured chronological alternative to the temporal page.
- At accessibility sizes, preserve event selection and an explicit
  **Add at selected time** alternative to precise canvas tapping.
- Use at least 44-point interactive targets and distinguish existing marks from
  empty add targets.

---

## OW-360 — Approve the direct-history interaction contract

**Status:** Done 23 July 2026; recorded as D-016

### Scope

- Confirm day paging owns the temporal detail's horizontal gesture.
- Confirm the visible Catch up button is removed.
- Confirm direct additions are limited to completed days.
- Confirm 8+ hour gaps remain reviewable proposals, not automatic fast records.
- Confirm contextual proposal review initially uses the selected completed day.
- Record the accepted interaction in `DECISIONS.md`.

### Acceptance criteria

- Every requested interaction is classified as presentation-only or explicitly
  identified as a decision change.
- No production implementation begins before explicit approval.
- Any request to auto-save or present inferred gaps as confirmed fasts is moved
  to a separate domain story.

---

## OW-361 — Establish synchronised day-paging primitives

**Status:** Done 23 July 2026

### Scope

- Add a SwiftUI-independent day selection/page coordinator where practical.
- Add deterministic previous/next local-day mapping.
- Add tap-position-to-absolute-instant mapping for an actual ribbon window.
- Define event/interval hit precedence and empty-canvas selection.
- Prevent selection feedback loops between date chips, pager and date picker.

### Acceptance criteria

- Chip tap, pager swipe, VoiceOver action and native date jump converge on one
  selected local day.
- Swiping across month/year and London DST boundaries selects the correct day.
- Spring gaps produce no nonexistent time; autumn repeated times remain
  distinct absolute instants.
- Page geometry and inverse tap mapping are deterministic at narrow/wide sizes.
- No record is mutated by navigation or selection.

### Tests

- Previous/next day across month, year, leap day and GMT/BST boundaries.
- Selection synchronisation without recursive updates.
- Tap mapping at window start, midnight, repeated hour and window end.
- Event hit priority over the empty-canvas action.
- 12/24-hour and en_GB/en_US confirmation summaries.

---

## OW-362 — Make History a swipeable date experience

**Status:** Done 23 July 2026

### Scope

- Remove the visible Catch up action row and its History identifier.
- Replace the internally scrolling ribbon with one-day paged temporal detail.
- Keep the date navigator selected chip and visible range synchronised.
- Retain the native month/date jump.
- Keep existing record disclosure below or within the selected day without
  turning History into a dashboard.

### Acceptance criteria

- A left/right swipe changes exactly one local-calendar day.
- Tapping a date changes the temporal page to the same day.
- Swiping the temporal page updates the selected chip and month heading.
- Several previous days can be browsed using only the temporal detail.
- Blank pages are calm and neutral.
- Recorded, reconstructed, adjusted, Needs review and unknown records retain
  their existing detail destinations and actions.
- The page has no visible Catch up button.

---

## OW-363 — Add food or drink from temporal detail

**Status:** Done 23 July 2026

### Scope

- Add empty-canvas tap selection for completed days.
- Show a native confirmation of selected date/time before category selection.
- Route Food and Drink into the existing historical editors.
- Preserve historical favourite editor behaviour and explicit occurrence time.
- Refresh the same selected day after a successful save.

### Acceptance criteria

- Tapping an existing mark opens its existing detail and never starts an add.
- Tapping empty detail selects a deterministic instant and displays it before
  category choice.
- Cancel at any stage creates no record.
- Food remains caloric; hydration classification remains explicit.
- D-013, validation, failure retry, deletion and affected-history invalidation
  are unchanged.
- No drawing or gesture code coordinates repository saves.
- VoiceOver and accessibility-size users can choose the same date/time without
  precision tapping.

---

## OW-364 — Surface existing reconstruction review contextually

**Status:** Done 23 July 2026

### Scope

- Expose neutral proposal-review entry from the selected completed day when the
  user chooses to review fasting history.
- Reuse the existing one-day `CatchUpRange`, generation, review and final atomic
  save.
- Present eligible gaps as **Suggested fast · Needs review** until saved.
- Keep confirmed reconstructed fasts visually and textually distinct.

### Acceptance criteria

- Exactly eight hours and longer follows the existing proposal generator.
- Under-eight-hour, non-caloric, edge-insufficient, conflict and suppressed-pair
  outcomes remain unchanged.
- No gap is displayed as a confirmed fast before final review save.
- Accept, Adjust and Leave unknown remain required for every proposal.
- Cancellation and failure write nothing; final save remains atomic.
- Saved results refresh in the same selected-day History context.

---

## OW-365 — Complete the History interaction quality gate

**Status:** Done 23 July 2026

### Acceptance criteria

- Swipe, chip tap, month jump and accessibility actions remain synchronised.
- Direct food/drink creation, editing and deletion pass on empty and dense days.
- Existing fast/unknown/Needs review disclosure remains operable.
- One-day proposal review and atomic rollback pass.
- Light, dark, increased contrast, Reduce Motion and accessibility sizes pass.
- Narrow and wide iPhones pass without nested horizontal-gesture ambiguity.
- en_GB, en_US, Monday-first handling and Europe/London DST pass.
- Existing records migrate unchanged; no new migration is introduced.
- Complete unit/UI suites, formatting, project generation, build, lint and
  `git diff --check` pass.
- If exactly one iPhone is connected, repeat swipe navigation, tap-to-add and
  proposal review without resetting device data.

## Verification record — 23 July 2026

- OW-361: 13 focused temporal-presentation unit tests pass, including
  local-calendar month/year/leap/DST movement, feedback suppression, actual
  ribbon-window inverse mapping, mark precedence, spring gaps, repeated autumn
  instants and en_GB/en_US summaries.
- OW-362: focused build and UI navigation checks pass for swipe, previous/next
  buttons, date-chip selection, Today forward limit and removal of
  `history.catch-up`.
- OW-363: focused UI journeys pass for confirmed timestamp presentation, food,
  favourite drink, custom caloric/non-caloric drinks, cancellation, failed-save
  draft retention and stored historical editor date/time.
- OW-364: focused UI journeys pass for contextual suggestion disclosure,
  Accept, Adjust, Leave unknown, no premature confirmed-fast presentation and
  failed atomic-save rollback.
- Computer-use verification on an iPhone 16e simulator covered repeated
  backward/forward day navigation, live date-picker synchronisation, a
  December-to-January boundary, neutral empty days, existing fast/food/drink
  marks, empty-canvas timestamp derivation, full food and both hydration editor
  classifications, cancellation, retained failed drafts, all reconstruction
  choices, rollback, provenance disclosure, dark appearance, increased
  contrast, Reduce Motion, accessibility XXXL, structured scroll and custom
  Previous-day accessibility actions, en_GB 24-hour and en_US 12-hour output.
  Principal screenshots are in `artifacts/screenshots/slice-3-6/`.
- Hands-on testing exposed and repaired historical food/hydration editors
  clamping stored events to Today, plus the shared header clipping at maximum
  Dynamic Type. Both repairs were rerun live and the focused regression tests
  pass.
- The final gate passes: `make format`, `make project`, `make build`,
  `make test-unit` (140 tests), `make test-ui` (56 tests), `make lint` and
  `git diff --check`. One full-suite-only two-second UI wait was reproduced as
  passing in isolation, hardened to five seconds, and the complete UI target
  then passed.
- The verified build was installed and launched, without resetting device
  data, on the single iPhone reported as connected by `devicectl`.

## Approved interaction record

The following interpretations were approved on 23 July 2026 and recorded as
D-016:

1. day paging replaces free horizontal panning inside the ribbon;
2. the visible Catch up button disappears, while existing repair services are
   reached contextually from History;
3. direct add is for completed days and always confirms date/time before Save;
4. an 8+ hour caloric gap is an unsaved **Suggested fast · Needs review** until
   the existing final atomic review is completed;
5. proposal review is initially scoped to the selected completed day, with the
   existing one-to-seven-day domain capability preserved but no standalone
   History range button.

The production implementation started only after D-016 was recorded.
