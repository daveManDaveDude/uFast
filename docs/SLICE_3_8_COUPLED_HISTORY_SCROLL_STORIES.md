# Slice 3.8 — Coupled History date rail

**Sprint status:** Delivered 23 July 2026
**Production status:** Complete
**Story order:** OW-380 → OW-381 → OW-382 → OW-383 → OW-384 → OW-385

## Outcome

Make the upper History date rail feel mechanically connected to the lower
temporal carousel.

When the user drags or flicks the lower carousel, the day chips above it move
continuously in the same temporal direction and at the corresponding
fractional day progress. A fast lower flick should make dates visibly travel
through the upper rail throughout tracking and deceleration, rather than
waiting for the lower carousel to settle and then snapping the rail.

This is a presentation refinement of the delivered Slice 3.7 analog carousel.
It does not introduce a continuously selectable fractional date.

## Post-delivery amendment — D-019

On 23 July 2026, the user approved read-only future History browsing on both
surfaces. D-019 supersedes this delivered slice only where it names Today as
the maximum selectable or previewable display day. Today now opens centered in
a bounded 400-day-past and 400-day-future Calendar-derived buffer. Future days
may settle as read-only viewing context, while marks, empty-space add, direct
entry and contextual repair remain non-actionable and perform no writes. The
native picker remains capped at Today.

## Post-delivery amendment — D-020

On 24 July 2026, the user approved continuous flush lower pages using a
26-local-hour viewport: the selected day plus one hour of context at each edge.
The carousel timeline has no repeated page-side border, radius or horizontal
inset, so adjacent pages render as one uninterrupted strip rather than cards
placed against each other.
The structured timeline-detail card is hidden, non-actionable and excluded from
accessibility during either surface's live motion, lower deceleration and
alignment, then restored for the settled selected page without collapsing its
reserved layout space. Calendar-derived London clock-change pages retain their
actual 25- or 27-hour elapsed duration.

## Post-delivery amendment — D-021

On 24 July 2026, the user removed lower-timeline day snapping. Calendar days
remain stable touching render segments, but native inertia may settle at any
fractional time offset. The center local day drives the settled heading and
date rail; the structured detail card is filtered only after settlement using
the exact visible start and end instants. Fractional position remains transient
presentation state and performs no persistence writes.

## Post-delivery amendment — D-022

During lower-carousel motion, the visible month/year heading, selected-day
heading and decorative follower rail use the local-calendar day at the viewport
centre. At an exact midnight seam, the entering day is presented; reversal
restores the prior day immediately. This is presentation state only: the
settled shared date, native picker, real rail selection, structured detail,
editor/repair targets and VoiceOver selection remain unchanged until native
idle commits one centered day. Coupling remains geometry- and phase-driven with
no polling, timer, display-link or custom physics. Midnight markers use the
Calendar-derived segment boundary, including DST days.

## Interaction contract

### One motion, two coordinated surfaces

- The lower temporal carousel remains the gesture owner when the drag starts
  over temporal detail.
- During lower-carousel tracking, deceleration and native target alignment, the
  upper date rail follows the same normalized day-space progress in real time.
- One lower-page width maps to one upper-chip stride even though the two
  surfaces have different physical widths and spacing.
- Direction reversals are reflected immediately in both surfaces.
- A fast multi-day flick makes dates pass continuously through the upper rail;
  it must not collapse into a single post-settlement jump.
- The upper rail does not synthesize an independent inertial gesture while it
  is following the lower carousel.

### Transient preview versus selected date

- Coupled fractional progress is transient presentation state only.
- The existing shared selected local-calendar date changes only when the lower
  carousel resolves a valid centered day under the Slice 3.7 settlement rules.
- The selected chip, month heading, native date picker, structured detail,
  direct-add target and contextual repair target continue to represent the
  settled selected date.
- Passing chips may move beneath a quiet fixed center reference, but they are
  not announced as selected and do not become editor targets during motion.
- On settlement, the visual rail position reconciles exactly to the selected
  day without a second animation, bounce or visible correction.
- D-019 supersedes the original Today display boundary: bounded future chips
  are valid read-only viewing targets, never editor or write targets.

### Direct upper-rail interaction

- Manual upper-rail scrolling remains continuous and inertial.
- Manually scrolling the upper rail alone does not move or select the lower
  carousel, preserving the delivered Slice 3.7 contract.
- Tapping a chip, using Previous/Next, choosing a native-picker date or using
  an accessibility day action deliberately aligns both surfaces.
- Only one horizontal surface owns live motion at a time. Automatic
  keep-visible alignment pauses while either surface is directly manipulated.
- A lower-carousel gesture beginning after upper-rail inertia has ended may
  take ownership cleanly; no two-way feedback loop or competing velocity is
  permitted.

### Interruption and content changes

- Presenting a sheet, changing tabs, backgrounding the app, changing Dynamic
  Type or invalidating History data ends coupled preview state and resolves to
  one valid selected day.
- Buffer extension or recycling preserves the same visible day-space position
  without a chip flash, identity change or offset jump.
- Empty and dense temporal pages may change lower-page height without changing
  horizontal coupling.
- Drawing, gesture and coupling code never creates drafts, proposals or
  repository writes.

## Technical direction

Model coupling in normalized calendar-day space rather than copying raw pixels:

- expose lower-carousel progress as a stable day index plus fractional progress
  between adjacent stable day identities;
- map that progress to the upper rail using its measured chip stride and actual
  layout direction;
- preserve `Calendar`-derived day identities across month, year, leap-day and
  Europe/London DST boundaries;
- distinguish lower-user-driven, lower-decelerating, lower-aligning,
  upper-user-driven, deliberate-programmatic and settled ownership;
- prevent rail updates caused by lower motion from feeding back into lower
  selection or alignment;
- publish high-frequency visual progress separately from low-frequency
  selected-date state;
- coalesce only redundant render updates, never visible motion;
- prefer native SwiftUI scroll geometry and scroll positioning available at
  the iOS 26 deployment target.

Prototype at OW-380 before choosing between:

1. directly positioning the real upper scroll view from shared day-space
   progress; or
2. using a presentation-only rail layer while the lower carousel moves, then
   reconciling the real interactive rail at settlement.

Choose the smallest native approach that remains frame-stable, accessible and
free of feedback loops. Custom velocity or deceleration physics require a new
explicit decision.

## Non-negotiable boundaries

Do not change:

- persistence schemas, migrations, record semantics or ordering;
- reconstruction extraction, the eight-hour threshold, suppression or range
  rules;
- proposal review, Accept/Adjust/Leave unknown, atomic save or rollback;
- D-013, BR-17, invalidation or provenance meanings;
- timeline absolute-window mapping or existing-mark precedence;
- saved fast identity across midnight;
- the settled-only meaning of the shared selected History date;
- direct entry, Today or future-entry restrictions;
- HealthKit, analytics, scoring, coaching, reminders, accounts or cloud.

Never derive day progress by dividing elapsed seconds by 86,400. Stable
neighbours and page identity use `Calendar` and `TimeZone`; the fractional
component describes layout progress between those identities, including London
spring gaps and repeated hours.

## Accessibility and motion contract

- VoiceOver exposes the settled selected date and structured rows, not every
  passing chip or fractional offset.
- The moving rail is decorative during lower-carousel motion. Accessibility
  focus must not chase visual chips or emit repeated announcements.
- Previous/Next, date chips, native picker and adjustable selected-date actions
  remain complete navigation alternatives.
- Switch Control and Full Keyboard Access can use the settled interactive rail
  without needing a drag.
- Reduce Motion retains direct coupled translation because it communicates
  position, but removes decorative easing, overshoot and secondary
  reconciliation animation.
- Dynamic Type may change chip width; coupling must use measured layout rather
  than a hard-coded stride.
- Right-to-left layout direction must preserve chronological meaning and
  native gesture direction.
- Light, dark and increased-contrast appearances retain a clear settled
  selection and quiet center reference without relying on colour alone.

---

## OW-380 — Approve and prototype coupled motion

**Status:** Done 23 July 2026

**Verification:** D-018 records the approved contract and the selected
presentation-only follower prototype. Narrow-iPhone slow and fast coupling,
native deceleration, exact settlement, Today resistance and interruption were
verified without custom velocity or deceleration physics.

### Scope

- Prototype real-time lower-to-upper coupling on a narrow iPhone.
- Compare direct real-scroll positioning with a presentation-only follower
  layer.
- Verify slow drag, reversal, short flick, fast multi-day flick and Today
  resistance.
- Inspect frame pacing, chip identity, center-reference clarity and
  interruption behavior.
- Record the approved interaction and implementation approach in
  `DECISIONS.md` before production implementation.

### Acceptance criteria

- The upper rail visibly follows every meaningful lower-carousel movement,
  including native deceleration.
- Multi-day velocity is preserved visually instead of becoming a final snap.
- The prototype identifies exactly which state is visual preview and which is
  the settled selected date.
- Settlement produces no second animation, bounce or feedback loop.
- VoiceOver does not chase passing chips.
- The chosen approach is viable with native iOS 26 APIs and does not introduce
  custom deceleration physics.

---

## OW-381 — Establish deterministic coupled-scroll primitives

**Status:** Done 23 July 2026

**Verification:** Deterministic tests cover normalized forward, backward,
reversal and multi-day progress; measured lower/upper strides; exclusive
ownership; stale, future and out-of-buffer rejection; rebasing; interruption;
and Calendar-derived month, year, leap-day and Europe/London DST neighbours.

### Scope

- Add a SwiftUI-independent representation of stable day-space progress.
- Resolve adjacent day identities and fractional progress without 24-hour
  arithmetic.
- Model one active motion owner and explicit transition rules.
- Define reconciliation from preview progress to settled selection.
- Define bounded-buffer rebasing that preserves visible progress.

### Acceptance criteria

- Unit tests cover forward, backward, reversal and multi-day progress.
- Month, year, leap-day and Europe/London DST neighbours remain correct.
- Mapping the same day-space progress through different measured strides
  produces equivalent visible dates.
- Rebase and buffer expansion preserve the previewed center identity and
  fractional progress.
- Invalid, future, stale or out-of-buffer progress cannot become selection.
- State transitions cannot recursively align either surface.

---

## OW-382 — Couple the upper rail to lower-carousel motion

**Status:** Done 23 July 2026

**Verification:** Native lower scroll geometry drives a decorative follower
rail throughout tracking, deceleration and target alignment. Stable adjacent
day identities plus fractional layout progress reconcile to the settled
interactive rail before preview is removed, with timeline actions suppressed
until motion resolves.

### Scope

- Publish continuous lower-carousel geometry during tracking, deceleration and
  target alignment.
- Render matching continuous motion in the upper date rail.
- Preserve stable chip identity while dates enter and leave the viewport.
- Reconcile to the selected chip exactly once at settlement.
- Keep lower timeline interactions disabled under existing movement rules.

### Acceptance criteria

- Slow lower drags move both surfaces continuously and proportionally.
- Reversals change both directions in the same frame without a jump.
- Fast flicks visibly carry multiple dates through the rail.
- Week, month and year crossings do not rebuild, flash or snap the rail.
- Today clamping never exposes a future date as selected or actionable.
- Dense-page height changes do not disturb horizontal rail motion.
- Coupling performs no repository access or writes.

---

## OW-383 — Preserve deliberate rail and date-control behavior

**Status:** Done 23 July 2026

**Verification:** Focused UI tests preserve independent manual rail scrolling,
chip/Previous/Next synchronization, multi-day flick settlement, year-boundary
alignment and Today clamping. Deliberate commands interrupt stale preview and
remain the only two-surface synchronization path.

### Scope

- Retain independent manual upper-rail scrolling.
- Preserve chip tap, Previous/Next, date picker and accessibility actions.
- Coordinate motion ownership and cancel stale automatic alignment.
- Make long-distance jumps deterministic without animating every intervening
  chip.
- Keep month heading, picker and contextual actions bound to settled
  selection.

### Acceptance criteria

- Manually scrolling the rail does not move or select the timeline.
- Tapping a chip aligns both surfaces without bounce.
- Previous/Next and adjustable actions move exactly one calendar day.
- Native-picker jumps resolve both surfaces to the chosen day with no feedback
  loop.
- A deliberate action during stale deceleration cannot commit the stale target.
- Month heading and repair/add targets never follow fractional preview state.

---

## OW-384 — Complete accessibility, resilience and performance

**Status:** Done 23 July 2026

**Verification:** Preview is presentation-only, accessibility-hidden and
non-interactive. Dynamic Type uses measured chip geometry; Reduce Motion keeps
positional coupling without secondary reconciliation animation. Sheets, tab
changes, backgrounding, content invalidation and Dynamic Type changes end
preview deterministically. Light/dark, increased contrast, accessibility text,
en_GB, en_US and RTL layouts were checked on iPhone 16e.

### Scope

- Verify VoiceOver, Switch Control, Full Keyboard Access and Dynamic Type.
- Verify Reduce Motion, increased contrast, light/dark and right-to-left layout.
- Handle sheets, tab changes, backgrounding and data invalidation during
  coupled motion.
- Profile a fast multi-day flick on a narrow supported iPhone and dense
  fixtures.
- Remove unnecessary high-frequency view invalidation.

### Acceptance criteria

- Passing chips create no VoiceOver announcement storm or focus movement.
- Equivalent settled controls remain reachable and correctly labelled.
- Accessibility chip widths remain fluidly coupled and unclipped.
- Interruption resolves to one valid selected day without residual offset.
- No visible dropped-frame pattern, blank rail region or delayed catch-up
  occurs under production fixtures.
- Reduce Motion removes secondary travel effects while retaining positional
  coupling.
- RTL and both supported locale presentations preserve chronological clarity.

---

## OW-385 — Complete the coupled-scroll quality gate

**Status:** Done 23 July 2026

**Verification:** The complete unit and UI suites plus build, formatting,
project generation, lint and whitespace gates pass. Simulator screenshots and
the coupled-motion recording are retained under `artifacts/`. The final diff
contains no persistence, reconstruction, direct-entry or Today semantic
change.

### Acceptance criteria

- Hands-on simulator testing covers slow drag, held partial drag, reversal,
  cancellation, short flick and fast multi-day flick in both directions.
- Week, month, year, leap-day and Today boundaries pass.
- en_GB, en_US, right-to-left layout and Europe/London spring/autumn DST pass.
- Empty days and dense fast/food/drink pages remain visually synchronized.
- Existing mark activation, empty-timeline add, cancellation, failed-save
  retention and contextual proposal review still pass after settlement.
- VoiceOver-equivalent controls, accessibility text sizes, Reduce Motion,
  increased contrast and dark appearance pass.
- Deterministic unit and UI tests cover OW-381 through OW-384.
- Principal coupled-motion states are captured for visual review.
- `make format`, `make project`, `make build`, `make test-unit`,
  `make test-ui`, `make lint` and `git diff --check` pass.
- The diff confirms no persistence, reconstruction, direct-entry or Today
  semantic change.

## Planning assumptions

- The requested “days whizzing by” effect applies to the upper date rail while
  the lower temporal carousel owns motion.
- Visual preview may be fractional; selection remains a whole settled
  local-calendar date.
- The month heading remains settled during motion to avoid rapid text churn.
- Manual upper-rail scrolling remains independent and does not drag the lower
  carousel.
- This slice is presentation-only.
