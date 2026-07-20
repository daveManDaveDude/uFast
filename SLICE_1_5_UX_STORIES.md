# Slice 1.5 — Fasting experience

**Status:** Done 20 July 2026  
**Accepted direction:** 20 July 2026  
**Gate:** Do not begin Slice 2 until OW-150 through OW-155 are Done.

## Outcome

Make the already-functional fasting loop feel calm, coherent and recognisably
uFast, using the repository mockups as the visual direction. This slice changes
presentation and interaction hierarchy without changing the meaning,
persistence or integrity of fasting records.

The slice succeeds when a new user can set a goal and complete a fast without
help, the current fasting state and next action are immediately apparent, and
the same visual language can be reused by Slice 2.

The implemented foundation and the refinements accepted during visual QA are
summarised for future work in `UX_STYLE_GUIDE.md`.

## Shared visual contract

### Reference hierarchy

Use the following composite mockups as the visual brief:

1. `images/ChatGPT Image Jul 18, 2026 at 11_09_46 AM.png` — primary reference
   for goal choice, fast-start confirmation, branded typography, colour and
   window imagery.
2. `images/ChatGPT Image Jul 18, 2026 at 11_09_35 AM.png` and
   `images/ChatGPT Image Jul 18, 2026 at 11_09_41 AM.png` — primary reference
   for Today, the active-fast hero, card composition and action hierarchy.
3. `images/ChatGPT Image Jul 18, 2026 at 11_09_53 AM.png` — reference for calm
   absence, timeline and reconstructed-history compositions; no catch-up
   behaviour enters this slice.
4. `images/ChatGPT Image Jul 18, 2026 at 11_09_59 AM.png` — reference for
   information cards and restrained charts; no HealthKit or reflection
   behaviour enters this slice.
5. `images/ChatGPT Image Jul 18, 2026 at 11_10_05 AM.png` — reference for
   selection cards and quick actions; photo and AI features remain out of scope.

Where the mockups disagree, prefer the first two references, then the product
principles and native iOS behaviour. They are visual concepts, not pixel-perfect
specifications or shippable assets.

### Visual language

- Use a warm ivory semantic background rather than a clinical pure-white
  canvas.
- Use deep evergreen for primary text and actions, with sage, sky blue and
  restrained apricot as supporting semantic accents.
- Use the system sans-serif design consistently for display text, controls,
  body copy, dates and compact data, varying size and weight to preserve
  hierarchy. Do not add a third-party font dependency.
- Use generous whitespace, soft rounded surfaces, fine borders and restrained
  tonal fills. Avoid heavy shadows, glass effects on every surface and dense
  stacks of default controls.
- Nature and open-window motifs may be purpose-made SwiftUI shapes, symbols or
  local vector/raster assets. They are decorative and must never be the only way
  state or meaning is communicated.
- Use an **illustrated information card** for calm, non-interactive empty or
  explanatory states: one rounded tonal surface may combine restrained
  decorative artwork, a concise native heading and one short supporting
  message. Place text over a deliberately quiet area of the artwork, keep the
  words sufficient without the image, and do not use this pattern for actions,
  warnings, forms or dense data.
- Every screen has one dominant action. Correction, destructive and maintenance
  actions remain discoverable but visually subordinate.
- Use native controls where they provide important accessibility and locale
  behaviour, including date pickers, confirmation dialogs and tab navigation.
- Support light and dark appearances, increased contrast, Reduce Motion,
  VoiceOver and accessibility Dynamic Type without removing critical content.
- Retain meaningful accessibility identifiers used by the UI tests unless a
  story explicitly replaces them and updates the tests in the same change.

### Content language

- Use **uFast** as the product name. “Open Window” appears only inside the
  reference images and is not adopted by this slice.
- Describe recorded behaviour: **fast**, **fasting goal**, **started**, **target**
  and **recorded fast**.
- Do not claim a biological fasting state, health outcome or certainty that is
  not present in the stored record.
- Do not add praise, coaching, streaks, guilt, urgency or body-shaming language.
- Do not request a name or personalise greetings in this slice.

### Behavioural invariants

- Existing `FastRecord`, `FastingGoal`, `AppClock`, conflict checking and
  SwiftData semantics remain authoritative.
- Presentation changes must not create, end, edit, delete, infer or repair a
  record without the explicit action already required by Slice 1.
- Timer ticks and visual progress remain derived; they are never persisted.
- Goal changes do not rewrite completed records or active start times.
- All manual fasting behaviour remains local, offline and permission-free.

---

## OW-150 Establish the uFast visual foundation and app shell

**Epic:** E0 Product foundation  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user moving through uFast, I want screens and controls to feel like one calm
product, so that I can understand hierarchy and actions without relearning the
interface on every screen.

### Why now

All later Slice 1.5 stories need shared primitives. Establishing semantic roles
first prevents each screen from inventing a slightly different approximation of
the mockups and gives Slice 2 a tested foundation.

### In scope

- Create semantic colour, typography, spacing, corner-radius and surface roles
  sufficient for Slice 1.5.
- Create reusable primary, secondary and destructive action treatments.
- Create reusable card, screen background, section heading and compact
  brand-mark treatments where they reduce duplication.
- Apply the foundation to the app shell, tab bar, screen background and existing
  placeholders without changing the destination set or navigation semantics.
- Add representative SwiftUI previews for the shared styles in light, dark and
  accessibility-size configurations.
- Document each semantic role and intended use in code comments or a short
  repository design-foundation document.

### Out of scope

- Redesigning a complete feature screen; those changes belong to OW-151 through
  OW-155.
- Changing tab destinations, adding navigation destinations or implementing
  placeholder features.
- A public component package, third-party design system or custom font.
- Extracting illustrations or UI fragments from the composite reference images.
- Animation beyond subtle system transitions needed by a shared component.

### Product rules

BR-12 and BR-15. D-007, D-008 and D-012.

### Acceptance criteria

- Given any Slice 1.5 screen, when it uses a background, primary action,
  secondary action, card or display heading, then it obtains that appearance
  from a named semantic role or reusable component rather than a screen-local
  colour or duplicated style.
- Given the app in light appearance, when any primary destination is shown, then
  the canvas reads as warm ivory, primary text/actions read as deep evergreen,
  and supporting accents follow the restrained sage, sky and apricot palette.
- Given dark appearance, when the same destinations are shown, then all content
  remains legible, surfaces remain distinguishable and the visual hierarchy is
  equivalent without forcing light appearance.
- Given increased contrast, when cards and actions appear, then their boundaries
  and labels remain distinguishable without relying on a shadow.
- Given accessibility Dynamic Type, when display headings and buttons wrap, then
  critical copy remains visible and controls retain at least a 44-by-44-point
  interaction target.
- Given VoiceOver, when decorative motifs are encountered, then they are ignored;
  icons that convey meaning have useful labels and no action relies on colour or
  decoration alone.
- Given Reduce Motion, when state or navigation changes, then no bespoke
  non-essential motion is required to understand the result.
- Given the existing navigation UI tests, when they run, then the same
  destinations and accessibility identifiers remain operable.

### States and edge cases

- Light, dark and increased-contrast appearances.
- Small through accessibility text sizes.
- Narrow iPhone width and content wrapping.
- Reduce Motion and VoiceOver.
- Placeholder, empty and error content using the same shell.

### Data and privacy

No data model, persistence, permission, analytics or network change.

### Design and content

Follow the shared visual contract. Use semantic names based on purpose, such as
canvas, primary action and supporting surface, rather than names tied to one
screen or literal colour value.

### Dependencies

- D-012 accepted.
- Existing `ScreenLayout`, `RootTabView` and SwiftUI app shell.

### Verification

- Unit-test any non-trivial style-selection logic; do not test raw SwiftUI
  constants for their own sake.
- Retain and run navigation UI tests.
- Manually compare the shell and component previews with the primary reference
  images in light, dark, increased-contrast and accessibility text settings.
- Run `make build`, `make test`, `make lint` and `make format`.

### Done when

The shared roles are documented, previews cover their meaningful variants, the
app shell uses them and all acceptance criteria and repository Definition of
Done pass.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-151 Introduce uFast and choose a fasting goal

**Epic:** E0 Product foundation  
**Priority:** P0  
**Status:** Done 20 July 2026  
**Also completes:** OW-001 Minimal onboarding and product promise

### User story

As a new user, I want a brief, reassuring introduction and an understandable
goal choice, so that I know what uFast does and can begin without instruction.

### Why now

The current first launch is a generic picker and does not deliver OW-001's
product promise. This is the first real application of the visual foundation
and the beginning of the complete fasting journey.

### In scope

- Present the product name, a concise promise and a restrained open-window or
  nature motif on first launch.
- State that uFast is a calm, private way to record fasting and that the goal can
  be changed later.
- Present all whole-hour choices from 8 through 24 with 12 selected by default.
- Make the selected goal visually obvious without relying on colour alone.
- Keep **Continue** as the one primary action and save through the existing
  local settings behaviour.
- Preserve retry behaviour when saving fails.

### Out of scope

- Multiple onboarding pages, carousel navigation or permission requests.
- Asking for a name, demographic, weight, target outcome or notification choice.
- Recommending a goal or explaining health effects associated with a duration.
- Changing goal range, persistence or completed-onboarding semantics.

### Product rules

BR-01, BR-02, BR-05 and BR-15. D-002, D-006, D-008 and D-012.

### Acceptance criteria

- Given first launch, when onboarding appears, then **uFast** and the promise
  **A calm, private companion for recording your fasts.** are visible before or
  alongside the goal choice without requiring horizontal paging.
- Given first launch, when no choice has been changed, then 12 hours is selected,
  its selected state is visible by shape/icon and label rather than colour alone,
  and **Continue** is available.
- Given the goal control, when the user explores it, then every whole hour from
  8 through 24 is available and no value is described as better, easier or
  healthier.
- Given a selected goal, when **Continue** succeeds, then the same settings
  record behaviour from OW-002 is used and the user arrives at Today.
- Given a save failure, when **Continue** is tapped, then onboarding remains
  available, the selected value is retained and the calm retry message is
  visible.
- Given relaunch after successful onboarding, then onboarding is not shown again
  and the saved goal remains selected in Settings.
- Given VoiceOver, then the introduction has a logical reading order, the goal
  control announces its purpose/value/selected state and **Continue** is
  unambiguous.
- Given accessibility Dynamic Type or a narrow screen, then the promise, all
  critical choice information and **Continue** remain available without clipped
  text or horizontal scrolling.
- Given dark or increased-contrast appearance, then the chosen state and primary
  action remain unmistakable.

### States and edge cases

- Default and changed selection.
- Save success and simulated save failure.
- Relaunch before and after completion.
- 8-, 12-, 16- and 24-hour choices.
- VoiceOver, dark appearance and accessibility text sizes.

### Data and privacy

Writes only the existing local goal and onboarding-completed value. Requests no
permission and collects no identity, health history or analytics.

### Design and content

The goal-choice screen in `11_09_46 AM.png` is the primary composition
reference. Use uFast branding and the exact promise above. A scrollable vertical
choice treatment is acceptable; a compact native picker is acceptable only if
the selected value and full range remain immediately understandable and the
screen retains the reference hierarchy.

### Dependencies

- OW-150.
- Existing OW-002 behaviour and tests.

### Verification

- Extend goal UI tests for promise copy, default selection, range, persistence
  and save failure.
- Add previews for default, maximum goal, error and accessibility-size states.
- Manually check VoiceOver, dark mode, increased contrast and 8/12/16/24 hours.
- Run `make build`, `make test`, `make lint` and `make format`.

### Done when

OW-001's product promise and OW-002's goal behaviour are delivered in the new
visual language and all acceptance criteria and repository Definition of Done
pass.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-152 Make the ready-to-fast Today state calm and obvious

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user who is not currently fasting, I want Today to show my state and one
obvious way to begin, so that starting a fast feels effortless.

### Why now

The generic empty-state treatment makes the product feel unfinished and gives
the current goal more emphasis than the user's next action.

### In scope

- Replace the generic inactive `ContentUnavailableView` with a branded Today
  composition.
- Make **Start fast** the sole primary action.
- Show the current goal and the resulting target time before starting, based on
  `AppClock.now`, without creating a record or promising an outcome.
- Keep **Start at a past time** discoverable as a visually secondary action.
- Retain start success, duplicate-tap safety and calm retry behaviour.
- Retain any post-completion **Fast recorded.** feedback long enough to be
  perceivable without turning it into celebration or a modal interruption.

### Out of scope

- Food, hydration, greetings by name, weather or personalised coaching.
- Automatically starting a fast.
- Changing the goal from Today.
- A multi-step start-confirmation flow.
- Persisting the preview target or adding animation that delays starting.

### Product rules

BR-02, BR-03, BR-05, BR-12 and BR-15.

### Acceptance criteria

- Given no active fast, when Today appears, then the user can identify that no
  fast is running, see the current goal and see **Start fast** as the single
  dominant action without scrolling at a standard iPhone text size.
- Given no active fast, when Today appears, then a preview target derived from
  the current instant and goal is displayed in the current locale/time zone and
  is not persisted.
- Given the inactive screen, when **Start fast** is tapped, then the existing
  OW-101 behaviour creates exactly one active fast and Today transitions directly
  to the active composition.
- Given duplicate rapid taps, then at most one record exists and no duplicate
  visual feedback is shown.
- Given a start failure, then the screen remains inactive, does not show an
  active timer and presents the existing calm retry action/message in context.
- Given **Start at a past time**, when it is activated, then the existing focused
  editor opens and cancellation leaves the inactive composition unchanged.
- Given a fast was just ended, when the inactive state returns, then **Fast
  recorded.** is perceivable visually and announced to assistive technology,
  while **Start fast** remains available.
- Given VoiceOver, then state, goal, target, primary action, secondary action and
  any error are encountered in a logical order.
- Given accessibility Dynamic Type, then **Start fast** and **Start at a past
  time** remain operable and critical content does not overlap decorative
  imagery or the tab bar.

### States and edge cases

- First inactive visit, ordinary inactive state and just-completed state.
- 8- and 24-hour goal target previews crossing midnight or a DST boundary.
- Start success, duplicate tap and simulated failure.
- Light, dark, increased contrast, VoiceOver and accessibility text.

### Data and privacy

Reads the existing local goal and current time. Starts a record only after the
existing explicit action. No new persistence, permission, network or analytics.

### Design and content

Use the left-hand Today screens in `11_09_35 AM.png` and `11_09_41 AM.png` for
spacing, warm palette and card hierarchy, but do not add food or drink actions
before Slice 2. The inactive hero may use a calm window/daylight motif and must
not imply biological state.

### Dependencies

- OW-150.
- Existing OW-101 and OW-102 behaviour.

### Verification

- Update FastStart UI tests for the new composition without weakening record,
  relaunch, duplicate-tap or failure assertions.
- Unit-test target-preview derivation if it introduces presentation logic.
- Add previews for ordinary, just-completed, error and accessibility-size states.
- Manually check midnight, DST, 12/24-hour locale, VoiceOver and dark mode.
- Run `make build`, `make test`, `make lint` and `make format`.

### Done when

The inactive Today state communicates state, goal, target and next action at a
glance while preserving all Slice 1 start behaviour and passing the repository
Definition of Done.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-153 Make an active fast glanceable and honest

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user with an active fast, I want to understand elapsed time, progress,
started time and target at a glance, so that I do not have to interpret a stack
of labels.

### Why now

The active state contains the correct facts but lacks the visual hierarchy that
makes the timer the centre of the experience.

### In scope

- Make the elapsed timer the active screen's visual hero.
- Present clamped visual progress, the goal and the target as one coherent
  composition while keeping the full elapsed value visible beyond the goal.
- Show the recorded start time and provide a subordinate edit affordance.
- Keep **End fast** as the one primary action and **End at a past time** as a
  subordinate action.
- Visually distinguish before-target and reached-target states without praise,
  urgency, animation dependency or biological claims.
- Preserve once-per-second refresh, foreground refresh, locale formatting,
  current-goal projection and all existing accessible values.

### Out of scope

- Live Activity, widgets, notifications or Dynamic Island.
- Biological phases, achievements, streaks, confetti or coaching.
- A new persisted status or progress field.
- Automatically ending at the target.
- Changing the active fast's captured historical goal.

### Product rules

BR-02, BR-03, BR-05, BR-12 and BR-15. D-009.

### Acceptance criteria

- Given an active fast below its target, when Today appears, then the elapsed
  timer is the most prominent content and the user can identify start, current
  goal, target and **End fast** without entering another screen.
- Given the timer is below 24 hours, then completed-second `HH:MM:SS` precision
  remains visible; given 24 hours or more, the existing day-inclusive format
  remains fully visible.
- Given progress below, at or above the goal, then visual fill remains clamped
  from zero through 100 percent while elapsed time continues honestly beyond the
  goal.
- Given elapsed time reaches the goal, then **Goal time reached** is visible and
  no congratulatory, warning, streak or biological-state copy appears.
- Given the current goal changes in Settings, then the active composition updates
  its goal, target and progress while preserving the start instant.
- Given the app backgrounds and returns, then elapsed, progress and target
  immediately reflect `AppClock.now` without writing timer ticks.
- Given **Edit start time**, then the existing correction flow opens from the
  displayed recorded start and successful correction updates the composition
  without replacing the record.
- Given **End fast** is unavailable because the current time is not after the
  stored start, then the explanation remains visible and accessible and the
  visual treatment does not imply that ending succeeded.
- Given VoiceOver, then a coherent summary announces active state, elapsed, goal,
  progress and target; edit and end actions remain separately discoverable.
- Given accessibility Dynamic Type, then the timer remains understandable,
  labels do not overlap, actions remain operable and decorative scenery yields
  space before critical content is clipped.
- Given increased contrast or colour-vision differences, then progress and
  reached-target state remain understandable through text and structure rather
  than colour alone.

### States and edge cases

- Just started, in progress, exactly reached and beyond target.
- Multi-day elapsed duration.
- Stored future start anomaly.
- Goal change and corrected start.
- Foregrounding and relaunch.
- Light, dark, VoiceOver, increased contrast and accessibility text.

### Data and privacy

Reads existing local fast and goal data. Derived presentation remains ephemeral.
No new persistence, permission, network or analytics.

### Design and content

The centre screen in `11_09_35 AM.png` and `11_09_41 AM.png` is the primary
composition reference. The landscape/window treatment may be simplified to
protect text legibility and accessibility. Do not include **How are you
feeling?**, **You've got this.** or any other coaching copy from the mockup.

### Dependencies

- OW-150.
- Existing OW-103 presentation logic and tests.

### Verification

- Preserve ActiveFastPresentation tests for elapsed, progress, reached state and
  time anomalies.
- Update active-fast UI tests for hierarchy without weakening semantic value,
  relaunch or refresh assertions.
- Add previews for just-started, half-progress, reached, beyond-target,
  unavailable-elapsed and accessibility-size states.
- Manually compare standard-size active composition with the primary mockups;
  check VoiceOver, Reduce Motion, increased contrast, dark mode and DST.
- Run `make build`, `make test`, `make lint` and `make format`.

### Done when

The active state is glanceable at standard size and remains complete at
accessibility sizes, with all OW-103 semantics and repository Definition of Done
passing.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-154 Refine fasting corrections, completion and feedback

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a user correcting or completing a fast, I want focused, consistent controls
and clear outcomes, so that I can change the record confidently without losing
context.

### Why now

Start, end and completed-record editors are functionally safe but visually feel
like unrelated system forms. They need a consistent supporting experience
without replacing reliable native date and confirmation controls.

### In scope

- Apply the Slice 1.5 foundation to start-time, end-time and completed-fast
  editors.
- State editor purpose, currently selected boundary and any constraint in a
  consistent hierarchy.
- Retain native locale-aware date/time controls and existing validation order.
- Keep cancel and confirm actions in predictable navigation positions.
- Make validation and retry messages visible in context without relying on red
  alone.
- Refine end-now confirmation and the return to inactive Today so completion is
  clear but neutral.
- Keep delete visually distinct and destructive with explicit confirmation.

### Out of scope

- Changing validation rules, correction limits, conflicts or date precision.
- A custom calendar/time wheel.
- Undo, autosave, haptics as the only feedback or celebration.
- Editing historical goal or creating completed records directly from History.

### Product rules

BR-03, BR-04, BR-05, BR-12, BR-15, BR-16 and BR-17.

### Acceptance criteria

- Given any fasting editor, when it opens, then its title, selected value,
  cancellation action, confirmation action and relevant constraints are
  understandable before saving.
- Given a valid boundary change, when it is confirmed, then the existing domain
  operation succeeds, the editor dismisses and the presenting screen reflects
  the saved record.
- Given an invalid future, ordering, age or conflict value, then confirmation is
  unavailable and the existing exact explanation is visible, announced and
  associated with the controls without colour being the sole indicator.
- Given a save failure, then the editor remains open, selected values remain
  intact, the stored record remains unchanged and the calm retry message is
  visible.
- Given cancellation from any editor, then no persisted value changes and the
  presenting screen retains its prior state.
- Given **End fast** from the active screen, when the confirmation dialog
  appears, then **Cancel**, **End fast** and the meaning of ending now remain
  explicit.
- Given ending succeeds, then the active composition disappears, the inactive
  Today state appears and **Fast recorded.** is perceivable and accessible
  without celebratory language or an additional blocking screen.
- Given delete is offered in the completed editor, then it remains visually
  separate from Save and no record is removed until destructive confirmation.
- Given VoiceOver or accessibility Dynamic Type, then date values, validation,
  Cancel, confirm and Delete remain understandable and operable.
- Given 12- or 24-hour locale, time-zone change or DST fixture, then displayed
  controls change format appropriately while exact stored instants remain
  unchanged.

### States and edge cases

- Create/correct start and end-at-past-time.
- End-now confirmation and successful completion.
- Completed-fast edit and delete confirmation.
- Every existing validation and simulated save/delete failure.
- Cancellation, DST, locale, VoiceOver and accessibility text.

### Data and privacy

No new data. Existing explicit mutations and rollback behaviour remain intact.
No permission, network or analytics.

### Design and content

Use the reference mockups' focused editors, fine borders and strong action
hierarchy, while retaining native controls. Error iconography may support a
message but never replace it. Do not use a large illustration when it would
push boundary controls or validation off screen.

### Dependencies

- OW-150, OW-152 and OW-153.
- Existing OW-102, OW-104 and OW-105 behaviour and tests.

### Verification

- Run all start, end and history editor UI tests, updating selectors only where
  the visual composition requires it.
- Add previews for each editor's ordinary, validation, save-failure and
  accessibility-size state.
- Manually check VoiceOver focus order, keyboard/date-picker interaction,
  12/24-hour locales, DST, dark mode and increased contrast.
- Run `make build`, `make test`, `make lint` and `make format`.

### Done when

All fasting mutations remain safe and deterministic, their supporting UI is
visually coherent, and all acceptance criteria and repository Definition of
Done pass.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

---

## OW-155 Make history and settings coherent and pass the UX quality gate

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 20 July 2026

### User story

As a returning user, I want History and Settings to use the same calm hierarchy
as Today, so that the complete fasting loop feels trustworthy and finished.

### Why now

History currently resembles raw record output and Settings is a default form.
This final story closes Slice 1.5, verifies the journey as a whole and prevents
Slice 2 from beginning on an unstable visual foundation.

### In scope

- Redesign empty and populated History using the shared foundation.
- Make duration the row's primary value while preserving start, end and
  historical goal as honest supporting information.
- Keep newest-ended-first ordering and row-to-editor behaviour.
- Refine Settings goal presentation using the same selection language as
  onboarding while preserving immediate local save and rollback.
- Give unfinished destinations a calm, coherent placeholder treatment without
  implementing their features.
- Review the complete first-launch, start, active, correction, end, history edit,
  delete and goal-change journeys on a simulator and, when connected, an iPhone.
- Resolve visual inconsistencies and accessibility regressions within the shared
  contract; do not add new product behaviour during the quality pass.

### Out of scope

- History charts, streaks, summaries, search, filters or grouped statistics.
- Starting a fast from History.
- New settings, notifications, privacy screens or data export.
- Food, hydration, catch-up, HealthKit or Live Activity.
- Pixel-perfect duplication of the mockups at the cost of native behaviour or
  accessibility.

### Product rules

BR-02, BR-05, BR-11, BR-12, BR-15 and BR-17.

### Acceptance criteria

- Given no completed fasts, when History appears, then the empty state explains
  that completed fasts will appear there, uses the shared visual language and
  does not add a competing start action.
- Given completed fasts, when History appears, then each record is a coherent
  selectable row/card whose most prominent value is duration and whose start,
  end and historical goal remain visible or available in its accessible
  summary.
- Given multiple records, then ordering, identity, edit and deletion behaviour
  remain exactly as established by OW-105.
- Given Settings, when the goal is changed, then the selected state is obvious
  without colour alone, the value saves immediately through existing behaviour
  and an active Today view updates without changing its start.
- Given a Settings save failure, then the previous goal is restored and the calm
  error remains visible and accessible.
- Given an unfinished primary destination, when selected, then it uses the uFast
  canvas and typography, clearly states that the feature is not available yet
  and presents no non-functional primary action.
- Given the complete fasting loop at standard iPhone size, then each screen has
  one dominant action, primary information is apparent without interpreting a
  default form/list, and the visual family is recognisable across onboarding,
  Today, editors, History and Settings.
- Given dark mode, increased contrast, Reduce Motion, VoiceOver and at least one
  accessibility Dynamic Type size, then every Slice 1 action and critical value
  remains understandable and operable.
- Given offline operation and relaunch, then the complete fasting loop retains
  all existing data and behaviour and no screen requests network access or a
  system permission.
- Given the six source mockups are reviewed beside the implemented core journey,
  then the build demonstrably carries their warm natural palette, editorial
  hierarchy, soft cards, generous spacing and restrained motifs while excluding
  their out-of-scope features and claims.
- Given all automated checks, then build, unit tests, UI tests, lint and format
  pass before Slice 1.5 is marked Done.

### States and edge cases

- Empty, single and multiple-record History.
- Same-day and multi-day fasts, reached and unreached historical goals.
- Goal-save success/failure with and without an active fast.
- All tabs, relaunch and offline use.
- Light/dark, increased contrast, Reduce Motion, VoiceOver and accessibility
  Dynamic Type.

### Data and privacy

Uses only existing local settings and records. No new collection, permission,
network, analytics or retention behaviour.

### Design and content

Use `11_09_53 AM.png` as a loose reference for calm timeline/list rhythm and
`11_09_59 AM.png` for information-card hierarchy. Do not copy inferred-history,
coaching, trend judgement or HealthKit content into History. Settings should
feel related to the OW-151 goal selection without replaying onboarding.

### Dependencies

- OW-150 through OW-154.
- Existing OW-002 and OW-105 behaviour.

### Verification

- Run the full unit and UI test suites.
- Add/update previews for History empty/populated, Settings ordinary/error and
  placeholder states.
- Perform a visual review beside all six mockups on the baseline simulator.
- Perform the full journey with VoiceOver and accessibility text; spot-check
  dark mode, increased contrast, Reduce Motion, 12/24-hour locale, DST fixtures
  and offline use.
- Run `make build`, `make test`, `make lint` and `make format`.
- If exactly one iPhone is connected, run `make deploy-iphone` after verification
  and exercise the first-fast journey on device.

### Done when

All OW-150 through OW-155 acceptance criteria pass, the complete fasting loop
feels coherent beside the reference images, no Slice 2 behaviour has entered the
diff, and the repository Definition of Done passes. Slice 2 may then resume.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.
