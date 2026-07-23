# Slice 3.7 — Analog History scrolling

**Sprint status:** OW-370 through OW-375 done
**Production status:** Delivered and verified 23 July 2026
**Story order:** OW-370 → OW-371 → OW-372 → OW-373 → OW-374 → OW-375

## Outcome

Make horizontal History browsing feel directly connected to the user's finger
instead of behaving like a one-day command.

The recommended interpretation of **analog scroll** is:

- the temporal day carousel moves continuously, pixel for pixel, during a drag;
- adjacent days are visibly connected rather than replaced after a gesture;
- native deceleration can carry the carousel across more than one day;
- the carousel settles on a local-calendar day after motion ends;
- the month heading, date navigator, native picker, timeline and accessibility
  detail still resolve to one selected date;
- taps, editing and repair actions operate only on the settled selected day.

This retains the deterministic day-based interaction contract while making the
motion itself continuous and physical. It does not restore free panning inside
one day's absolute-time ribbon.

## Why this is a separate slice

Slice 3.6 deliberately gave the temporal detail's horizontal gesture to
one-day paging. Replacing the gesture with a continuously moving carousel
changes interaction physics, selection timing and synchronization ownership.
It should be approved and tested as its own presentation slice rather than
quietly changing the completed Slice 3.6 contract.

The existing behavior remains safe while this slice is only proposed.

## Proposed interaction contract

### Direct manipulation and momentum

- A horizontal drag over temporal detail moves the carousel continuously with
  the finger; there is no threshold-triggered content swap.
- The previous and next day pages are visible as they enter the viewport.
- Release uses native-feeling deceleration. A slow release normally settles on
  the nearest day; a faster flick may travel across several days.
- Resting positions align to whole day pages. Fractional page position is
  transient presentation state, never a selected date or stored value.
- The Today boundary may resist or rebound but never selects a future day.
- Screen-edge navigation gestures retain precedence.

### One deterministic selection

- The centered day is the selected local-calendar day.
- As the center crosses into another page, the shared transient selection may
  update once to that page; fractional drag distance never becomes a date.
- While the user is dragging or the carousel is decelerating, synchronization
  updates must not issue a competing programmatic recenter.
- A chip tap, native date-picker jump, Previous/Next button or accessibility
  action scrolls the carousel to the requested day.
- A carousel-originated selection updates the month heading, date chips,
  picker, semantic detail and contextual actions without a feedback loop.
- Programmatic jumps use restrained animation, or no travel animation under
  Reduce Motion.

### Stable calendar rail

The compact date navigator becomes a stable, continuous date rail rather than
being replaced with a newly generated week whenever selection changes.

- Manual chip-rail scrolling remains continuous and inertial.
- Crossing a week, month or year boundary does not rebuild visible chips or
  jump the rail.
- The selected chip remains visually and semantically distinct.
- Tapping a chip selects that day and brings the temporal carousel to it.
- Automatic keep-visible behavior pauses while the user is manipulating either
  horizontal surface.
- The native date picker remains the efficient long-distance jump control.

### Safe interaction while moving

- Existing marks remain buttons on settled pages.
- Empty-timeline tap-to-add, existing-mark activation and contextual repair
  actions are ignored or disabled while carousel motion is unresolved.
- When motion settles, hit testing and timestamp mapping use only the centered
  page's actual `TemporalRibbonWindow`.
- Scrolling never generates proposals, creates drafts or coordinates a
  repository write.

## Technical direction

Prefer native SwiftUI scrolling and deceleration over hand-authored velocity
curves:

- use a horizontal `ScrollView` with a lazy, day-keyed layout and aligned
  resting targets;
- keep enough stable local-calendar days around the viewport for momentum
  without constructing unbounded history;
- extend or recycle the day buffer at safe edges without changing visible
  identity or offset;
- derive every day identifier and neighbour with `Calendar` and `TimeZone`;
- isolate centered-day resolution, bounded-buffer expansion and synchronization
  decisions in SwiftUI-independent primitives where practical;
- make user-driven, decelerating and programmatic movement explicit states;
- do not persist scroll offset, centered page, selected date or velocity.

If native aligned scrolling cannot produce multi-day momentum without unstable
selection or accessibility regressions, stop at OW-370 and approve a revised
interaction before introducing custom physics.

## Non-negotiable boundaries

Do not change:

- persistence schemas, migrations, record semantics or stored ordering;
- the transient-only meaning of selected History date;
- timeline absolute-window mapping or existing-mark precedence;
- historical editor validation, D-013, BR-17, invalidation or provenance;
- reconstruction extraction, eight-hour threshold, suppression or range edges;
- Accept, Adjust, Leave unknown, final atomic save or rollback;
- saved fast identity across midnight;
- Today journeys or future historical-entry restrictions;
- HealthKit, analytics, scoring, coaching, reminders, accounts or cloud.

Calendar movement must never add 24 hours. A page remains one local-calendar
day even when Europe/London contains a spring gap or autumn repeated hour.

## Accessibility and motion contract

- Previous day, Next day, native picker and date-chip controls remain complete
  alternatives to swiping.
- VoiceOver exposes a stable selected-date value and adjustable day actions; it
  does not announce fractional offsets or every animation frame.
- Switch Control and Full Keyboard Access can reach dates and timeline marks
  without performing a precision drag.
- Dynamic Type preserves usable page geometry and the explicit
  **Add at selected time** alternative.
- Reduce Motion retains direct finger tracking but removes decorative travel,
  overshoot and unnecessary programmatic animation.
- Increased contrast, light and dark appearance retain clear page and selected
  date boundaries without relying on colour alone.

---

## OW-370 — Approve the analog-scroll interaction and prototype

**Status:** Done 23 July 2026; recorded as D-017

### Scope

- Confirm that analog means continuous finger tracking plus inertial,
  multi-day movement with day-aligned resting positions.
- Prototype the temporal carousel and stable date rail with production fixtures.
- Compare slow drag, short flick and fast multi-day flick on a narrow iPhone.
- Confirm selection timing, Today boundary behavior and screen-edge gesture
  precedence.
- Record the accepted interaction in `DECISIONS.md` before production work.

### Acceptance criteria

- Live prototypes visibly track the finger rather than swapping content after
  a threshold.
- A fast flick may traverse multiple dates, while a slow drag settles
  predictably.
- The approved design states exactly when the selected date changes.
- No record, draft or proposal is created by scrolling.
- Any custom scroll physics requires explicit approval and justification.

---

## OW-371 — Establish deterministic carousel primitives

**Status:** Done 23 July 2026

### Scope

- Model movement phases: settled, user-driven, decelerating and programmatic.
- Resolve the centered local-calendar day from stable page identity.
- Add bounded day-buffer generation and safe edge expansion.
- Extend selection-source/revision handling for carousel-originated changes.
- Define when automatic keep-visible scrolling is suppressed.

### Acceptance criteria

- Unit tests cover slow/fast movement outcomes without depending on wall-clock
  timing.
- Buffer expansion preserves centered-day identity and visible order.
- Month, year, leap-day and Europe/London DST neighbours use calendar
  arithmetic.
- Programmatic synchronization cannot recursively move the carousel or rail.
- Future days cannot become centered or selected.

---

## OW-372 — Replace command paging with an analog temporal carousel

**Status:** Done 23 July 2026

### Scope

- Render adjacent temporal day pages in a lazy horizontal carousel.
- Use native continuous drag and deceleration with aligned day resting targets.
- Permit velocity to move across more than one day.
- Keep actual-window timeline drawing and interval identity unchanged.
- Remove the threshold-only one-day drag implementation.

### Acceptance criteria

- Content remains attached to the finger throughout a drag.
- Adjacent day pages enter and leave continuously with no blank flash or
  post-gesture replacement.
- Slow drag, reversal, cancellation and fast multi-day flick settle
  deterministically.
- Today resists future travel without selecting a future date.
- Empty-timeline and existing-mark gestures cannot fire accidentally in motion.
- Timeline drawing and scrolling perform no repository writes.

---

## OW-373 — Synchronize the stable date rail and History controls

**Status:** Done 23 July 2026

### Scope

- Replace week-rebuilding chip data with a stable, extendable date rail.
- Synchronize the centered page, chip highlight, month heading and native
  picker.
- Pause automatic recentering during direct manipulation and deceleration.
- Restore deliberate synchronization when motion settles or an external control
  selects a date.
- Preserve direct entry and contextual review on the settled day.

### Acceptance criteria

- Fast travel across week, month and year boundaries produces no chip jump.
- Swiping the carousel updates heading, chip and picker exactly once per
  centered day.
- Manually scrolling the date rail does not move the timeline until a date is
  selected.
- Chip tap and picker jump bring both surfaces to the same date without bounce
  or a second animation.
- Repair and add actions always use the settled selected date.

---

## OW-374 — Complete accessible and resilient analog interaction

**Status:** Done 23 July 2026

### Scope

- Verify VoiceOver, Switch Control, Full Keyboard Access and Dynamic Type.
- Tune Reduce Motion, increased contrast, light and dark appearances.
- Validate interruption by sheets, tab changes, app backgrounding and data
  invalidation while moving.
- Confirm performance on dense days and older supported iPhones.

### Acceptance criteria

- Equivalent buttons and native controls can perform every navigation outcome.
- VoiceOver announces stable dates rather than fractional movement.
- Reduce Motion keeps direct manipulation but removes excess travel effects.
- Leaving or backgrounding mid-drag returns to one deterministic selected day.
- Dense pages remain responsive and preserve mark hit targets.
- No clipping or ambiguous selection occurs at accessibility sizes.

---

## OW-375 — Complete the analog-scroll quality gate

**Status:** Done 23 July 2026

### Acceptance criteria

- Hands-on simulator testing covers slow drags, reversals, short flicks and
  fast multi-day flicks in both directions.
- Week, month, year, leap-day and Today boundaries pass.
- en_GB, en_US and Europe/London spring/autumn DST pass.
- Empty days and dense fast/food/drink days remain clear while moving.
- Existing mark activation, empty-timeline add, cancellation, failed-save draft
  retention and contextual proposal review still pass after settling.
- Light, dark, increased contrast, Reduce Motion and accessibility sizes pass.
- Deterministic unit and UI tests cover OW-371 through OW-374.
- `make format`, `make project`, `make build`, `make test-unit`,
  `make test-ui`, `make lint` and `git diff --check` pass.
- The diff confirms no persistence, reconstruction or Today semantic change.

### Delivery verification

- Native SwiftUI finger tracking, unrestricted multi-day inertia and
  day-aligned settlement were verified on narrow iPhone simulators. Slow and
  fast gestures, reversal, Today clamping, year-boundary synchronization and
  deliberate date controls resolve to one local-calendar selected day.
- The stable bounded day buffer and settlement primitives use `Calendar`
  neighbours. Unit coverage includes month, year, leap-day and Europe/London
  spring-gap and repeated-hour behavior.
- The selected carousel page measures its own height, so empty and dense
  fast/food/drink pages remain unclipped. Timeline and repair actions stay
  disabled until user-driven or inertial movement settles.
- Structured event rows, adjustable selected-date actions, Previous/Next,
  date chips, the native picker and **Add at selected time** provide
  non-precision alternatives. Dark appearance, en_US accessibility text with
  Reduce Motion, and en_GB presentation were captured and reviewed.
- Final automation passed: 147 unit tests and 59 UI tests, followed by
  SwiftFormat, SwiftLint with zero violations, and `git diff --check`.
- The diff changes presentation, synchronization, documentation and tests
  only. Persistence schemas, record semantics, reconstruction rules,
  proposal atomicity and Today behavior are unchanged.

## Planning assumptions

- “Analog” describes continuous movement and momentum, not a continuously
  selectable fractional date.
- Day-aligned resting positions are required so date/time editing and contextual
  repair retain one unambiguous selected day.
- Fast gestures may cross multiple days.
- The native date picker remains the long-distance jump mechanism; the carousel
  is optimized for nearby History browsing.
- Slice 3.7 is presentation-only unless OW-370 exposes a contract change that
  requires separate approval.
