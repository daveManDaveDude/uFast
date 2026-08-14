# Ready stories

These stories are refined in backlog order after D-002, D-007 and the local
persistence choice are accepted and OW-000 establishes the repository. A story
marked **Ready** has no known material product question; a story marked **Draft**
is preparation for later refinement and must not be implemented as if ready.

The shared visual contract and implementation-ready Slice 1.5 stories OW-150
through OW-155 are maintained in `SLICE_1_5_UX_STORIES.md`.

The refined Slice 2 contract and stories OW-201 through OW-205 are maintained
in `SLICE_2_TODAY_STORIES.md`. They remain Draft until its six decisions are
accepted in `DECISIONS.md`.

The sprint-ready WidgetKit and ActivityKit review-hardening stories WS-101
through WS-103 are maintained in
`docs/WIDGET_SYSTEM_SURFACE_REVIEW_STORIES.md`. They implement the current
surface contract in D-031 without adding or redesigning a widget family or
Dynamic Island region.

## OW-002 Set a fasting goal

**Epic:** E0 Product foundation  
**Priority:** P0  
**Status:** Done 19 July 2026

### User story

As a new or returning user, I want to choose a fasting goal of at least 8 hours, so that the timer reflects the routine I intend to follow.

### Why now

The goal is required before the first complete fasting loop can be tested.

### In scope

- Default the first-use choice to 12 hours.
- Offer whole-hour choices from 8 through 24.
- Save the choice on device.
- Allow the choice to be changed in Settings.
- Update the active fast's target presentation without changing its start time.
- Preserve completed fast durations and their historical goal.

### Out of scope

- Different goals by weekday.
- Goals below 8 hours or above 24 hours.
- Coaching or recommendation of a goal.

### Product rules

BR-01, BR-02 and BR-05.

### Acceptance criteria

- Given a first launch, when the goal step appears, then 12 hours is selected by default and Continue is available.
- Given a user selects 16 hours and continues, when the app is relaunched, then 16 hours remains selected.
- Given an active fast and a change from 16 to 14 hours, when the user returns to Today, then the target time reflects 14 hours and the start time is unchanged.
- Given a completed fast created under a 16-hour goal, when the current goal changes, then that fast retains its recorded 16-hour historical goal.
- Given any goal-control interaction, then VoiceOver announces the value and selected state and the control works at large Dynamic Type sizes.

### Verification

- Unit-test minimum, maximum, persistence and historical-goal behaviour.
- UI-test first-use selection and Settings change.
- Manually check 8, 12, 16 and 24 hours with large Dynamic Type.

## OW-101 Start a fast now

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 19 July 2026

### User story

As a user who has finished eating, I want to start a fast with one obvious action, so that I can see its progress without remembering the exact time.

### In scope

- Show Start fast as the primary action when no fast is active.
- Use the current instant as the start time.
- Persist one active fast.
- Immediately update Today with an active-fast confirmation, goal and target time.
- Make repeated taps idempotent.

### Out of scope

- Automatic start from a meal.
- Backdated start, which belongs to OW-102.
- Continuously updating elapsed time and progress, which belong to OW-103.
- Live Activity, which belongs to OW-106.

### Product rules

BR-02, BR-03 and BR-05.

### Acceptance criteria

- Given no active fast, when Start fast is tapped, then one active fast is saved with a start time matching the current instant within one second.
- Given the fast was saved, when Today renders, then it confirms a fast is active and shows the selected goal and target time.
- Given the app is terminated and relaunched, then the same active fast continues from its stored start time.
- Given an active fast already exists, when the start action is triggered again through any race or duplicate event, then no second active fast is created.
- Given persistence fails, then the UI does not pretend the fast started and offers a calm retry state.

### Verification

- Unit-test creation and the single-active-fast invariant using an injectable clock.
- UI-test start and relaunch.
- Test duplicate taps and simulated persistence failure.

## OW-102 Start or correct with a past time

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 19 July 2026
**Updated:** 19 July 2026 — active-start correction is limited to 24 hours

### User story

As a user who did not start my fast at the moment I finished eating, I want to
start it with a past time or correct its start time, so that the record matches
what I know happened.

### Why now

Manual correction makes the first fasting loop useful after a missed action and
establishes the editable active-fast boundary needed by later end, history and
catch-up stories.

### Context

- Product principles: honest over impressive; useful after absence; one obvious
  next action.
- MVP scope: manual start, edit and backdate of fasts; unknown time remains
  unknown.
- Decisions: D-001 manual fast start, D-004 seven-day guided catch-up horizon
  and D-010 active-start correction window.
- Existing boundaries: `AppClock`, `FastRecord` and local SwiftData persistence.

### In scope

- When no fast is active, offer **Start at a past time** as a secondary action to
  **Start fast**.
- When a fast is active, offer **Edit start time**.
- Let the user select a local calendar date and time no later than the current
  instant supplied by `AppClock`. When correcting an existing active fast, limit
  the saved start to the preceding 24 absolute hours.
- Initialise a new past-time selection to the current date and time; initialise
  a correction to the active fast's stored start time.
- On confirmation, create one active fast or update the existing active fast in
  place, then recalculate its target from the corrected start and current goal.
- For a newly backdated fast, capture the current fasting goal as its historical
  goal. When correcting an existing fast, preserve its identifier and captured
  historical goal.
- Permit an older manually chosen start when creating a new backdated fast;
  D-004's seven-day limit applies to the later guided catch-up flow, not manual
  entry. BR-16 separately limits correction of an existing active fast.
- Save only after explicit confirmation; cancelling leaves persisted data
  unchanged.

### Out of scope

- Correcting an active fast's goal or end time.
- Ending a fast, which belongs to OW-104.
- Editing or deleting a completed fast, which belongs to OW-105.
- Detecting overlaps with completed history before completed-fast history exists.
- Inferring a start from food or hydration events.
- Guided reconstruction of unknown periods.

### Product rules

BR-02, BR-03, BR-05, BR-12 and BR-16. BR-04 becomes applicable when an end
boundary is introduced by OW-104.

### Acceptance criteria

- Given no active fast, when the user chooses **Start at a past time**, selects a
  time earlier than now and confirms, then exactly one active fast is saved with
  that start instant and the current goal captured.
- Given an active fast, when the user chooses **Edit start time**, selects a
  different past time and confirms, then the same record is updated, its target
  reflects the corrected start and no second active fast is created.
- Given an active fast start correction exactly 24 hours before `AppClock.now`,
  confirmation succeeds; given a correction more than 24 hours before now,
  confirmation is unavailable and the explanation says **Start time must be
  within the past 24 hours.**
- Given an active fast whose start is being edited, when the editor opens, then
  it shows the stored start date and time rather than the current time.
- Given either editor, when the user attempts to select a future instant, then
  the control does not move beyond the current time; if a future value reaches
  save validation after a clock change or other edge case, confirmation is
  unavailable and an accessible explanation says the start time cannot be in
  the future.
- Given a proposed change, when the user cancels, then the stored fast and the
  Today presentation remain unchanged.
- Given a save failure, when the user confirms, then the editor remains available
  with the selected value, the existing record is unchanged, and a calm retry
  message is shown.
- Given a start instant around a daylight-saving or time-zone change, when it is
  saved, relaunched and displayed in the current locale, then the same absolute
  instant is preserved.
- Given VoiceOver or a large Dynamic Type size, when the editor is used, then the
  purpose, selected date and time, validation state, Cancel and confirmation
  actions remain understandable and operable without truncating critical text.

### States and edge cases

- Empty: the secondary past-time action is shown only when no fast is active.
- Active: editing changes the existing record rather than replacing it.
- Duplicate/interrupted confirmation: the single-active-fast invariant holds and
  a relaunch shows either the previous saved value or the one confirmed value,
  never a duplicate.
- Future value: invalid even if it becomes possible through a time-zone, clock or
  accessibility-adjustment edge case; validate again when saving.
- Correction limit: exactly 24 absolute hours ago is valid; an older correction
  is rejected without changing the stored active fast. New backdated creation
  remains able to use an older explicitly chosen instant.
- Precision: persist the exact instant produced by the date/time control; do not
  silently move it to a meal, goal boundary or another inferred time.
- Offline: all behavior remains available without connectivity.

### Data and privacy

- Reads the current goal, active fast and injected current time.
- Creates or updates one app-owned `FastRecord` in the local SwiftData store.
- Requests no system permission, performs no network access and does not infer
  missing health history.
- Deletion and completed-record retention remain owned by later stories.

### Design and content

- Keep **Start fast** as the sole primary action; **Start at a past time** is
  visually secondary.
- Use a focused sheet or equivalent modal editor with the title **Start time**,
  controls labelled **Date** and **Time**, and actions **Cancel** and **Start
  fast** or **Save** according to context.
- Use the validation copy **Start time can’t be in the future.**
- For an active correction beyond the allowed window, use **Start time must be
  within the past 24 hours.**
- After saving, return to Today; do not add praise, warnings, streak language or
  claims about biological fasting state.

### Dependencies

- OW-002 completed.
- OW-101 supplies active-fast creation, single-record enforcement, persistence
  failure handling and clock injection.
- D-010 establishes the correction window; no schema or architecture decision is
  required.

### Verification

- Unit-test older past creation, in-place correction, the exact 24-hour
  correction boundary, too-old and future rejection, captured-goal preservation,
  cancellation and the single-active-fast invariant with an injected clock.
- Persistence-test relaunch and simulated save failure.
- UI-test the inactive secondary action, active edit path, initial values,
  cancellation and future validation.
- Test fixtures immediately before and after both London daylight-saving changes
  and a display time-zone change.
- Manually check VoiceOver, large accessibility text, 12/24-hour locale display
  and offline use.
- Run `make build`, `make test` and `make lint`.

### Done when

All acceptance criteria and the repository Definition of Done pass, with no
duplicate active fast and no silent change to a user-selected instant.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

## OW-103 See elapsed time, progress and target

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Done 19 July 2026
**Updated:** 19 July 2026 — active timer now shows and refreshes seconds

### User story

As a user with an active fast, I want to see how long it has been running, its
progress toward my goal and its target time, so that I can understand the record
at a glance.

### Why now

This completes the observable half of the basic start-and-watch loop after
OW-102 makes the active start boundary honest and correctable.

### Context

- OW-101 owns creating one active fast and showing a minimal confirmation with
  goal and target.
- OW-102 owns selecting and correcting the active fast's start instant.
- The shipped boundaries are `AppClock`, `FastRecord`, `FastingGoal`, local
  SwiftData queries and the active/inactive states in `TodayGoalView`.
- OW-103 owns the continuously updating elapsed value, accessible progress
  treatment and calm reached-target state on Today, without writing timer ticks.
- OW-104 owns ending the fast; OW-106 owns Lock Screen and Dynamic Island
  presentation.

### In scope

- Derive elapsed duration, target and progress from the persisted start instant,
  current fasting goal and injected `AppClock`; do not persist derived values or
  timer ticks.
- Show active elapsed time to completed-second precision.
- Use compact elapsed copy that remains understandable beyond 24 hours, including
  days when applicable.
- Truncate elapsed time to completed whole seconds rather than rounding up. Use a
  stable `HH:MM:SS` timer below 24 hours and add a day component from 24 hours
  onward so seconds remain visible for multi-day fasts.
- Show the current goal and target date/time. Format the target using the current
  locale and time zone while preserving its absolute instant.
- Show a standard linear progress treatment from zero to the goal. Clamp its
  visual fill between zero and 100 percent while keeping the full elapsed value
  visible after the target.
- Derive progress from the exact absolute duration rather than the truncated
  display seconds, so the visual value remains continuous and deterministic.
- Refresh at least once per second while Today is visible and immediately on
  initial display, app foregrounding, relaunch, goal change or start correction.
- Use the neutral state copy **Goal time reached** at and beyond the target; do
  not celebrate, warn, shame or imply a biological state.
- If the device clock is earlier than the stored start, show zero visual progress
  and the explanation **Elapsed time isn’t available while the recorded start is
  in the future.** Do not rewrite the stored record.
- Provide a coherent VoiceOver summary and accessible labels/values for elapsed,
  goal, target and progress.
- Give the progress control an accessibility value based on its clamped whole
  percentage, followed by the goal; for example, **50 percent of 12-hour goal**.
  The separate elapsed value continues to expose the full duration beyond the
  target.

### Out of scope

- Ending a fast or editing and deleting completed fasts.
- Notifications, alarms or reminders at the target time.
- Live Activity, widgets or Apple Watch.
- Persisting derived elapsed/progress values.
- Coaching, celebration, streaks or biological-stage claims.

### Product rules

BR-02, BR-05, BR-12 and BR-15.

### Acceptance criteria

- Given an active fast started at a known instant, when Today appears at a fixed
  injected time, then elapsed whole seconds, current goal, target time and
  progress are derived deterministically from the stored start.
- Given an active fast has run for less than one minute, when Today appears, then
  elapsed includes its completed seconds and progress remains at its correctly
  derived exact value.
- Given Today remains visible, when clock time advances, then elapsed time and
  progress refresh at least once per second without writing timer ticks or other
  derived state to persistence.
- Given the app is backgrounded across the target or relaunched later, when Today
  becomes active, then the display immediately catches up from the stored start
  and injected current time.
- Given the current goal changes or the start time is corrected, when Today
  refreshes, then target and progress use the new values while the stored start
  remains the source of elapsed time.
- Given elapsed time exactly meets or exceeds the goal, then the visual progress
  is capped at 100 percent, the full elapsed time remains visible and Today shows
  **Goal time reached** without celebratory or warning language.
- Given the device clock is earlier than the stored start, when Today renders,
  then visual progress is zero, the inaccessible elapsed value is not fabricated,
  the explanatory copy is shown and the stored fast is unchanged.
- Given a daylight-saving or display time-zone change, then elapsed duration is
  based on absolute instants while the target is formatted for the current locale
  and time zone.
- Given VoiceOver, Reduce Motion, increased contrast or an accessibility Dynamic
  Type size, then elapsed, goal, target, progress and reached-target state remain
  understandable and operable without relying on animation, color or truncation.

### States and edge cases

- Active below goal, exactly at goal and beyond goal.
- Foreground, background/resume and process relaunch.
- Goal change and corrected start while active.
- Less than one minute, multi-day elapsed duration and a device clock earlier than
  the stored start.
- The OW-101 failed-start state remains inactive and continues to show its retry
  action; OW-103 adds no competing error state when no fast was saved.
- Offline operation, with no permission request, network access or write for
  derived display state.

### Data and privacy

- Reads one active fast, the current goal, injected time and locale/time-zone
  formatting context.
- Writes no new health or timer data and requests no permission or connectivity.

### Design and content

- Keep the active-fast information together as one readable section on Today.
- Present elapsed time as the primary value, with goal, target and progress as
  supporting information.
- A standard linear progress view is preferred so Reduce Motion requires no
  special animation behavior and system accessibility semantics remain available.
- Refresh may use a second-periodic `TimelineView` or an equivalent injected,
  testable boundary. Rendering must also derive immediately from `AppClock.now`
  rather than waiting for the first periodic tick.
- The combined VoiceOver summary should follow the order: active state, elapsed,
  goal, target and reached-target state when applicable.
- Describe the user's record only. Do not say or imply that the user is in a
  verified physiological fasting state.

### Dependencies

- OW-101 and OW-102 completed.
- Existing `FastRecord.targetDate(currentGoal:)` and `AppClock` remain the source
  boundaries. The shipped app-level clock injection and `--fixed-now` UI-test
  fixture are available; implementation should add a pure presentation model or
  formatter so duration and progress do not depend on SwiftUI.
- D-009 establishes second-level active-timer precision; no schema migration,
  network dependency or architecture decision is required.

### Verification

- Unit-test elapsed seconds, target and progress derivation with an injected
  clock, including sub-second truncation, under-one-minute, exact-target,
  over-target, multi-day, clock rollback and daylight-saving cases.
- Unit-test that visual progress clamps from zero through one and that presentation
  derivation performs no persistence write.
- UI-test initial active display, visible second-level count-up, reached-target
  copy, relaunch and foreground catch-up with deterministic `--fixed-now` launch
  fixtures; relaunch with an advanced fixed instant rather than making tests wait
  in real time.
- Manually check VoiceOver, large text, Reduce Motion, 12/24-hour locales and
  background/foreground transitions.
- Run `make build`, `make test` and `make lint`.

### Done when

All acceptance criteria and the repository Definition of Done pass, with elapsed
and progress derived from the stored instant rather than persisted timer state.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change against the shipped OW-102 seams.
- [x] Acceptance criteria are final and observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

## OW-104 End now or at a past time

**Epic:** E1 Fasting loop
**Priority:** P0
**Status:** Done 19 July 2026
**Updated:** 19 July 2026 — end-now and past-time completion implemented

### User story

As a user with an active fast, I want to end it now or at the time I finished, so
that my record reflects the interval I intended to log.

### Why now

Ending completes the first manual fasting loop and turns the active record into
completed local history for OW-105 to display, edit and delete.

### Context

- OW-101 creates one persisted active `FastRecord` and owns failed-start retry.
- OW-102 corrects its start instant.
- OW-103 presents elapsed time, current goal, target and progress.
- The shipped `FastRecord` captured a goal when it was created, while active-fast
  presentation follows the current goal. Completing the fast must atomically set
  its end instant and replace the captured goal with the goal applicable at
  completion so BR-05 remains true.
- OW-104 sets the active record's end instant without creating a replacement.
- OW-105 will own completed history, later correction and deletion.
- A later caloric-event story will prompt before ending under BR-08; no event
  silently ends a fast in this story.

### In scope

- Offer **End fast** as the obvious primary action while a fast is active. Tapping
  it opens a confirmation dialog titled **End this fast?** with the explanation
  **This will record the end time as now.** and actions **Cancel** and **End
  fast**.
- Read `AppClock.now` when the dialog's confirming **End fast** action is tapped,
  not when the dialog first opens.
- Offer **End at a past time** as a visually secondary action. It opens a focused
  sheet titled **End time**, with controls labelled **Date** and **Time**, and
  actions **Cancel** and **End fast**.
- Initialise the past-time editor to `AppClock.now`. Save only after explicit
  confirmation; cancelling leaves the active fast and Today presentation
  unchanged.
- Require an end instant after the stored start and no later than the injected
  current instant; validate again when saving.
- Complete the existing active record in place and preserve its identifier and
  exact start instant.
- Capture the current fasting goal as the completed record's historical goal so
  later goal changes do not rewrite the completed fast.
- Make duplicate or interrupted end events idempotent.
- On save success, return Today to its normal inactive state and show **Fast
  recorded.** alongside the start actions for the lifetime of the current Today
  view. This confirmation is presentation state, is cleared by starting another
  fast, and is not persisted across relaunch.
- If ending now fails to save, keep the original fast active and show **Your fast
  couldn’t be ended. Please try again.** near the end actions.
- If a past-time save fails, keep the editor open with the selected value, leave
  the persisted fast unchanged and show **Your end time couldn’t be saved. Please
  try again.**
- If `AppClock.now` is at or before the stored start, make the primary end action
  unavailable and explain **This fast can’t end until after its recorded start
  time.** The user can correct the start through OW-102.

### Out of scope

- Editing or deleting a completed fast after save.
- Starting the next fast as part of the end flow.
- Automatically creating a food or hydration event.
- Automatically ending because a goal was reached or a caloric event exists.
- Notifications, Live Activity dismissal and completed-history presentation.
- Celebration, streaks, coaching or biological claims.
- Persisting the post-save **Fast recorded.** presentation.

### Product rules

BR-02, BR-03, BR-04, BR-05, BR-08, BR-12 and BR-15.

### Acceptance criteria

- Given one active fast, when the user taps the primary **End fast**, then no data
  changes until they confirm **End fast** in the dialog.
- Given the confirmation dialog is open, when the user confirms at a fixed
  injected time, then that same record is saved with the confirmation-time clock
  instant as its end, its duration is positive, its historical goal is the
  current goal and no active fast remains.
- Given the confirmation dialog is open, when the user cancels, then the active
  record and Today presentation remain unchanged.
- Given an active fast, when the user chooses a valid past end after its start and
  confirms, then the exact selected instant is saved on the existing record.
- Given the selected end is at or before the start, or later than now, then save is
  unavailable and the editor respectively shows **End time must be after the
  start time.** or **End time can’t be in the future.**
- Given the current goal changed while the fast was active, when it is completed,
  then the goal currently presented for that active fast becomes its immutable
  historical goal.
- Given an end action is delivered twice, then one record is completed once and no
  duplicate completed or active record is created; the repeated delivery is a
  no-op.
- Given end-now persistence fails, then Today continues to show the active fast
  with its original boundaries and current goal, shows the calm retry message and
  does not show **Fast recorded.**
- Given a past-time save fails, then the editor remains available with its
  selected value, the original active record is unchanged and the retry message
  is accessible.
- Given a successful end, then Today returns to its inactive start actions and
  shows **Fast recorded.** without praise, streak or biological-state language.
- Given the app is terminated after a successful end and relaunched, then the fast
  remains completed, Start fast is available again and the session-only **Fast
  recorded.** message is absent.
- Given the device clock is at or before the stored start, then end now is
  unavailable, the accessible explanation is shown and the stored fast is not
  rewritten.
- Given a daylight-saving or display time-zone change, then the saved end remains
  the same absolute instant and is formatted in the current locale.

### States and edge cases

- Active below, exactly at and beyond the current goal.
- End now, valid past end, end equal to start, end before start and future end.
- Device clock earlier than the stored start, where end now cannot produce a valid
  interval.
- Duplicate taps, interruption during save and persistence failure.
- Goal changed during the active interval.
- VoiceOver, large Dynamic Type, 12/24-hour locales and offline operation.
- The end-now dialog can be presented more than once, but only the first
  successful confirmation can mutate the active record.

### Data and privacy

- Reads the active fast, current goal and injected current time.
- Atomically updates the end instant and historical goal on one app-owned
  `FastRecord` in the local SwiftData store.
- Requests no permission, performs no network access and infers no missing event.

### Design and content

- Keep the OW-103 active-fast information together and place the primary **End
  fast** with that section. **Edit start time** and **End at a past time** remain
  secondary.
- The confirmation dialog protects against an accidental irreversible end before
  OW-105 ships without forcing every end through a full date/time editor.
- Reuse OW-102's date/time editor structure and accessibility treatment, with end
  boundary labels and validation.
- The **Fast recorded.** message is a neutral acknowledgement, not a celebration.
- OW-106 is later in the backlog and owns Live Activity start/update/dismissal;
  OW-104 adds no ActivityKit dependency.

### Dependencies

- OW-101, OW-102 and OW-103 completed.
- Existing app-level `AppClock` injection, SwiftData query refresh and simulated
  persistence-failure fixture remain available.
- Implementation will add an in-place completion mutation and repository/service
  boundary. The existing SwiftData fields are sufficient; no schema migration is
  required.
- No new product or architecture decision is required.

### Verification

- Unit-test end-now, past end, boundary validation, goal capture, duplicate events
  and persistence failure with an injected clock.
- Persistence-test in-place completion, rollback after simulated save failure and
  relaunch.
- UI-test dialog confirmation and cancellation, past-time initial value and
  validation, successful inactive state and session confirmation, both failure
  paths, duplicate interaction and relaunch.
- Add fixtures around both London daylight-saving changes and a display time-zone
  change.
- Manually check VoiceOver, large text, 12/24-hour locales and offline use.
- Run `make build`, `make test` and `make lint`.

### Done when

All acceptance criteria and the repository Definition of Done pass, with one
existing record completed atomically and no invalid or duplicate interval.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are final and observable.
- [x] Relevant states and rules are defined.
- [x] Privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

## OW-105 View, edit and delete completed fasts

**Epic:** E1 Fasting loop
**Priority:** P0
**Status:** Done 19 July 2026
**Updated:** 19 July 2026 — completed-fast history, correction and deletion implemented

### User story

As a user who has recorded fasts, I want to review completed records and correct
or remove one when I made a mistake, so that my local history reflects what I
know happened.

### Why now

OW-104 creates the first completed fast. History makes that record visible and
gives the user a recovery path for an accidental end or an incorrect boundary
before later catch-up and reconstruction flows build on completed data.

### Context

- OW-104 completes one `FastRecord` in place with immutable historical goal
  capture.
- The History tab currently contains a placeholder.
- OW-105 owns listing completed fasts, editing their start and end boundaries and
  deleting an app-owned completed record.
- Active-fast start correction remains on Today under OW-102. Active-fast ending
  remains under OW-104.
- Reconstructed provenance and invalidation do not exist yet; OW-304 and OW-305
  will extend history after recorded-fast history is established.
- D-011 and BR-17 reject overlapping recorded fasts while allowing touching
  boundaries. OW-105 is the first story that can expose completed history to the
  existing backdated-start and active-start-correction paths, so it owns the
  shared conflict check across those paths and completed-fast editing.

### In scope

- Replace the History placeholder with completed `FastRecord` values only.
- Sort records by end instant, newest first. Use the identifier's stable string
  representation ascending as a deterministic secondary order when end instants
  are equal.
- Show each record's local start and end date/time, full elapsed duration and
  captured historical goal. Duration uses OW-103's completed-whole-minute
  formatter while remaining fully visible beyond the goal. Describe it as a
  recorded fast, not a verified biological state.
- Provide an empty state titled **No completed fasts** with the explanation
  **Completed fasts will appear here.** Do not add a competing start action; Today
  remains the obvious place to begin a fast.
- Selecting a row opens a focused editor titled **Edit fast**. Initialise all
  controls from the stored record and label the local calendar controls **Start
  date**, **Start time**, **End date** and **End time**.
- Save edited boundaries on the same record and preserve its identifier and
  historical goal.
- Require start to be before end and require both selected instants to be no later
  than `AppClock.now`; validate again when saving.
- Reject an edited interval that overlaps any other completed or active recorded
  fast. Exclude the selected record itself by identifier. Compare absolute
  half-open intervals so an end exactly equal to another start is valid.
- Add one shared domain conflict checker and enforce it when creating or
  correcting an active fast as well as when editing a completed fast. Treat an
  active interval as open-ended and exclude that active record when correcting
  its own start.
- When a proposed interval conflicts, leave every stored record unchanged, make
  confirmation unavailable and show the accessible explanation **This fast
  overlaps another recorded fast.**
- Apply validation in deterministic order: structural start-before-end rules,
  future-boundary rules, then conflict rules. Show the first applicable
  explanation and re-evaluate after either boundary changes.
- Save only after explicit **Save**. **Cancel** leaves the persisted record and
  list presentation unchanged.
- Offer **Delete fast** from the editor as a destructive secondary action. Require
  a confirmation dialog titled **Delete this fast?** with the explanation **This
  removes the record from this device.** and actions **Cancel** and **Delete
  fast**.
- On successful deletion, dismiss the editor and remove the row. If the final row
  is deleted, show the empty state.
- On edit failure, keep the editor open with the proposed values, leave the stored
  record unchanged and show **Your changes couldn’t be saved. Please try again.**
- On delete failure, keep the editor and stored record available and show **This
  fast couldn’t be deleted. Please try again.**
- Keep all behavior available offline with no permission request or network
  dependency.

### Out of scope

- Editing an active fast from History.
- Changing a completed fast's captured historical goal.
- Creating a new completed fast directly from History.
- Grouping or summarising records by day, week or goal attainment.
- Charts, trends, streaks, coaching or biological-stage claims.
- Search, filters, export, bulk deletion or pagination.
- Reconstructed-fast provenance and invalidation, which belong to OW-304 and
  OW-305.
- Undo after confirmed deletion.
- Automatically moving, shortening, merging or deleting either side of a
  conflict.

### Product rules

BR-02, BR-04, BR-05, BR-11, BR-12, BR-15 and BR-17. BR-11 becomes behaviorally
applicable after reconstructed records exist; this story must not pre-empt or
silently simulate that later invalidation workflow.

### Acceptance criteria

- Given no completed fast exists, when History appears, then it shows **No
  completed fasts** and no active fast or start action is presented there.
- Given multiple completed fasts, when History appears, then each appears once in
  newest-ended-first order with its local start, end, full duration and historical
  goal.
- Given an active fast and completed history both exist, when History appears,
  then only completed records are listed and the active record remains unchanged.
- Given two completed records have the same end instant, when History appears,
  then their identifier strings provide a deterministic ascending secondary
  order that remains stable across relaunch.
- Given a completed fast, when its editor opens, then the controls show that
  record's exact stored start and end values rather than the current time.
- Given valid corrected boundaries, when the user saves, then the same record is
  updated in place, its identifier and historical goal are preserved and its row
  reflects the new instants and duration.
- Given start is equal to or later than end, then Save is unavailable and the
  accessible explanation says **Start time must be before end time.**
- Given a selected start or end is later than `AppClock.now`, then Save is
  unavailable and the accessible explanation identifies the affected boundary
  with **Start time can’t be in the future.** or **End time can’t be in the
  future.**
- Given edited boundaries overlap another completed fast, then Save is
  unavailable, **This fast overlaps another recorded fast.** is shown and neither
  record changes.
- Given edited boundaries overlap the active fast, then Save is unavailable, the
  same conflict explanation is shown and both records remain unchanged.
- Given an edited boundary exactly touches another recorded fast without
  overlapping it, when the user saves, then the edit succeeds.
- Given completed history exists, when a backdated active start or active-start
  correction would overlap it, then confirmation is unavailable, the same
  conflict explanation is shown and no record changes.
- Given a backdated active start or correction exactly equals the end of the
  latest completed fast, when the user confirms, then the active record is saved
  because touching boundaries do not conflict.
- Given proposed edits, when the user cancels, then the persisted record and
  History row remain unchanged.
- Given an edit save fails, then the editor retains the proposed values, the
  stored record and row retain their previous values and the calm retry message is
  shown.
- Given the user chooses **Delete fast**, then no deletion occurs before they
  confirm **Delete fast** in the dialog.
- Given deletion is confirmed and succeeds, then that record is removed locally,
  other records are unchanged and relaunch does not restore it.
- Given the user cancels the delete confirmation, then the editor remains open
  and no record changes.
- Given deletion fails, then the row and editor remain available and the retry
  message is shown.
- Given a daylight-saving or display time-zone change, then stored start and end
  instants remain unchanged while History and the editor format them in the
  current locale and time zone.
- Given VoiceOver or an accessibility Dynamic Type size, then list order, record
  summaries, editor purpose, boundary values, validation, Cancel, Save and Delete
  remain understandable and operable without relying on color or truncating
  critical text.
- Given the device is offline or system health permissions are unavailable, then
  listing, editing and deleting app-owned completed records remain fully usable.

### States and edge cases

- Empty, one record and multiple records.
- Active record present alongside completed records.
- Same-day and multi-day completed fasts.
- Records immediately before and after both London daylight-saving transitions.
- Equal end instants requiring deterministic ordering.
- Boundary edit equal to end, after end, in the future, overlapping another
  completed fast, overlapping the active fast and exactly touching either.
- Backdated active creation and active-start correction overlapping or touching
  completed history.
- Edit cancellation, edit save failure, delete cancellation and delete failure.
- Relaunch after edit and deletion.
- VoiceOver, accessibility text sizes, 12/24-hour locales and offline use.
- A persisted invalid record from an older build is not silently repaired. Keep
  it visible as recorded, allow deletion or an edit that resolves the conflict,
  and prevent saving boundaries that remain invalid.

### Data and privacy

- Reads app-owned completed `FastRecord` values and the injected current time.
- Updates or deletes exactly one selected local record after explicit
  confirmation.
- Requests no permission, performs no network access and does not infer missing
  history.

### Design and content

- Use the existing History tab and a standard list so Dynamic Type, VoiceOver and
  system navigation behavior remain predictable.
- Each row should have one coherent VoiceOver summary in chronological order:
  recorded fast, start, end, duration and goal.
- Reuse the focused date/time structure established by OW-102 and OW-104.
- Keep deletion visually distinct from Save and require confirmation; do not use
  guilt, warning about lost progress or irreversible-health language.
- Reuse the completed whole-minute formatter established alongside OW-103; the
  active timer's second-level formatter remains specific to Today.

### Dependencies

- OW-104 completed and has established atomic in-place completion and historical
  goal capture.
- `FastRecord`, SwiftData local persistence, app-level `AppClock` injection and
  simulated failure fixtures remain available.
- History navigation already exists.
- A repository/service boundary will be needed for deterministic update, delete
  and rollback tests.
- Editing or deleting a completed record must not share the active-fast mutation
  path; repository operations should require the selected completed identifier
  and revalidate its completed state before saving.
- The conflict checker remains a domain value/service independent of SwiftUI and
  SwiftData. Repository queries supply the other recorded intervals, and mutation
  services revalidate immediately before save.

### Resolved product decision

- D-011 and BR-17 reject overlaps between all saved fasts, including future
  reconstructed records.
- Intervals are half-open: `[start, end)`. An active fast is `[start, infinity)`
  until completed. Therefore `first.end == second.start` is allowed.
- Existing conflicts remain honest historical data: show them, never infer a
  repair, and permit only deletion or an edit that leaves the selected interval
  valid and non-conflicting.

### Verification

- Unit-test sorting, duration formatting, boundary validation, identity and
  historical-goal preservation with an injected clock.
- Unit-test the shared conflict checker for disjoint, containing, contained,
  partial-overlap, equal, touching and active-open-ended intervals, always
  excluding the selected record by identifier.
- Persistence-test edit and deletion round trips plus rollback after simulated
  failures.
- UI-test empty and populated History, editor initial values, edit and delete
  cancellation, validation, overlap rejection, touching success, failure and
  relaunch.
- Regression-test backdated active creation and active-start correction against
  completed history, including overlap rejection and touching success.
- Test fixtures around both London daylight-saving changes and a display
  time-zone change.
- Manually check VoiceOver, large text, 12/24-hour locales and offline use.
- Run `make build`, `make test` and `make lint` once refined and implemented.

### Done when

All acceptance criteria and the repository Definition of Done pass, with edits
and confirmed deletions affecting only the selected completed local record.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Scope is one coherent, reviewable change.
- [x] Acceptance criteria are final and observable.
- [x] Core states, privacy and accessibility are covered.
- [x] Dependencies and verification are known.
- [x] No material product question remains unresolved.

## OW-106 Active-fast Live Activity

**Epic:** E5 Glanceability and quality
**Priority:** P1
**Status:** Superseded 8 August 2026 by D-029 and OW-L105
**Updated:** 8 August 2026 — retained as historical refinement only; do not
implement this contract

> D-029 and OW-L105 settled and delivered the explicit per-fast baseline. D-030
> later accepts a reversible automatic preference, one-time contextual offer,
> committed-start request and foreground continuation for longer fasts. The
> current implementation-ready refinement is OW-L106 through OW-L109 in
> `docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md`. This older OW-106 remains
> historical and must not be implemented directly.

### User story

As a user with an active fast, I want a calm glanceable view on the Lock Screen
and Dynamic Island where supported, so that I can see the recorded fast without
opening the app.

### Why now

The app can start, present and end a fast. A Live Activity adds the MVP's
glanceable system presentation without becoming a second fasting record or
making ActivityKit availability part of the manual fasting loop.

### Context

- OW-101 through OW-104 own starting, presenting and completing the persisted
  fast. OW-103 defines elapsed, goal, target and neutral reached-target
  presentation.
- ActivityKit and WidgetKit are not yet present. `project.yml` currently defines
  only the app and test targets, so implementation requires a widget extension,
  shared activity attributes and generated-project changes.
- The Live Activity is a projection of one active local record, never a second
  source of fasting history.
- The app is local-first and has no account, server or push-notification
  infrastructure. Remote ActivityKit pushes are therefore outside this story.
- System availability, user settings and dismissal can prevent a Live Activity
  from appearing. That must never block or roll back starting, correcting or
  ending a fast.
- Live Activities are visible outside the unlocked app and may expose information
  to casual observers. The content and default-on behavior require an explicit
  privacy decision before this story becomes Sprint Ready.
- ActivityKit can advance a system timer without per-second app work, but an
  arbitrary copy change at the target instant is not a guaranteed background
  execution trigger. Keep elapsed and target useful without requiring uFast to
  run at that instant; show **Goal time reached** after any later legitimate
  update observes that the target has passed.
- A person or the system can dismiss or end an activity independently of the
  local fast. Persist only minimal local presentation metadata needed to avoid
  unexpectedly recreating a dismissed activity for the same active record.

### Proposed in scope

- Add a WidgetKit extension containing the Lock Screen, compact, minimal and
  expanded Dynamic Island presentations required by the system.
- Add a small `LiveActivityClient` behind a protocol with request, list, update
  and end operations so orchestration is unit-testable without ActivityKit.
- Keep the immutable activity attributes to the `FastRecord` identifier. Put the
  mutable absolute start, target and current goal hours in content state so start
  correction and goal changes update the existing activity.
- Keep encoded activity content comfortably below ActivityKit's 4 KB content
  state limit. Do not copy history, notes, food, hydration, weight, steps or any
  other health data into the activity.
- Derive elapsed time from absolute start and current time using a system timer
  presentation so counting does not require persisted ticks, per-second app
  execution, networking or repeated ActivityKit updates.
- Use innocuous neutral content: **uFast**, **Elapsed**, the timer and **Target**
  with a local time. Do not display food, weight, a fasting-stage label,
  coaching, celebration, streaks or biological claims.
- Continue showing elapsed and target beyond the goal without requiring
  background execution. After a valid update or reconciliation observes
  `now >= target`, it may additionally show **Goal time reached**.
- Add an in-app control that makes the activity easy to turn off. The final
  location, default and enable flow depend on the open start-policy decision.
  Turning it off ends any matching activity without ending or editing the fast.
- Start at most one Live Activity after an explicitly started or backdated fast
  is successfully persisted, subject to the accepted privacy/default behavior.
- Update the existing Live Activity after a successful active-start correction
  or current-goal change. Never start a second activity for the same active fast.
- End the matching Live Activity only after OW-104 successfully completes the
  fast. A persistence failure leaves the activity showing the still-active
  record. The final Lock Screen dismissal policy depends on the open dismissal
  decision.
- On app launch or foregrounding, reconcile ActivityKit activities with local
  persistence: end activities for completed or missing records, update one
  activity matching the active record and end duplicates. Retain the matching
  activity with the lexicographically smallest ActivityKit identifier as the
  deterministic winner.
- Record that an activity was started for the active record. If it later becomes
  dismissed or system-ended, do not automatically recreate it for that same fast.
  An explicit in-app **Show on Lock Screen** action may start it again.
- Tapping the Lock Screen, compact, minimal or expanded presentation opens uFast
  directly on Today. No end, edit or goal-changing control is included.
- Treat ActivityKit unavailable, disabled, dismissed or failed states as
  non-blocking. If the user asks to manage the activity, show:
  **Live Activities aren’t available on this iPhone.** when unsupported,
  **Live Activities are turned off in iPhone Settings.** when system-disabled,
  or **The Lock Screen activity couldn’t be started. Please try again.** after a
  request failure.
- Keep all operation on-device. Use no APNs token, remote start, push update,
  account, analytics or network dependency.

### Proposed out of scope

- Remote start, push updates, broadcast channels or any server.
- Notifications or alerts when the goal time is reached.
- Background tasks or timer-driven app launches solely to change Live Activity
  copy at the target instant.
- An interactive **End fast** control in the Live Activity.
- Widgets outside the Live Activity, Apple Watch app or watchOS-specific feature
  work.
- Showing food, hydration, nutrition, weight, steps or reconstructed history.
- Persisting timer ticks or treating ActivityKit state as fasting history.
- Custom animation beyond system timer and presentation transitions.
- Treating a missing, dismissed or system-ended Live Activity as evidence that
  the local fast ended.

### Candidate acceptance criteria

- Given a fast is successfully started and Live Activities are available and
  enabled, when the accepted start policy permits it, then exactly one activity
  begins for that active record after persistence succeeds.
- Given starting or backdating a fast fails to persist, then no Live Activity is
  requested.
- Given the fast has started, when the Live Activity appears, then its Lock
  Screen, compact, minimal and expanded presentations show an innocuous
  glanceable elapsed timer and target derived from the same absolute instants as
  Today.
- Given time advances while uFast is not running, then the displayed timer
  advances without persisted ticks, background polling, remote pushes or network
  access.
- Given elapsed reaches or exceeds the target while uFast is not running, then
  elapsed continues and the target remains visible without requiring a
  notification or background launch.
- Given any later legitimate update observes that the target has passed, then
  the activity may show **Goal time reached** without celebration, warning or
  physiological claims.
- Given the active start or current goal changes successfully, then the one
  matching activity receives the new absolute state and no duplicate activity is
  created; given persistence fails, the activity retains its previous state.
- Given ending the fast succeeds, then its activity is ended promptly; given
  persistence fails, the activity is not ended and the active record remains its
  source of truth.
- Given the user turns off or explicitly hides the Live Activity, then every
  matching activity ends and the active `FastRecord` remains unchanged.
- Given Live Activities are disabled, unavailable, dismissed or a request fails,
  then the fasting operation still succeeds locally and no retry loop, permission
  pressure or misleading in-app active state appears.
- Given the app relaunches with a matching activity, an orphaned activity or
  duplicate activities, then reconciliation respectively updates, ends or
  deduplicates ActivityKit state without changing local fasting records.
- Given an activity for the current fast was dismissed or system-ended, when the
  app foregrounds, then reconciliation does not unexpectedly recreate it; when
  the user explicitly chooses **Show on Lock Screen**, one new matching activity
  may begin.
- Given the Live Activity is tapped, then uFast opens to Today.
- Given a London daylight-saving transition or display time-zone change, then the
  activity and Today retain the same start and target instants while system
  presentations use the current locale and time zone.
- Given activity content is inspected, then it contains only the record
  identifier, start, target and goal hours and remains below 4 KB.
- Given VoiceOver, increased contrast, Reduce Motion, Always-On reduced luminance
  or supported Dynamic Type behavior, then essential elapsed and target meaning
  remains understandable without relying on animation or color.

### States and edge cases identified

- ActivityKit available and enabled, disabled, unavailable, request failure,
  user-dismissed, stale and system-ended.
- App active, backgrounded, terminated and relaunched.
- Active record with no activity, one matching activity, orphaned activity and
  duplicate activities, plus a dismissed/system-ended marker for the active
  record.
- Start now, older backdated start, corrected start, changed goal, target reached
  and successful or failed end.
- Devices with and without Dynamic Island, Lock Screen, Always-On and dark/light
  appearances.
- Multi-hour and multi-day active fasts, even though system guidance says Live
  Activities are best suited to shorter or medium-duration tasks. System ending
  the activity never ends the fast and does not trigger an automatic restart
  loop.
- Time-zone and daylight-saving changes preserve absolute instants.

### Data and privacy

- The Live Activity may expose fasting status, elapsed time and goal/target while
  the device is locked.
- Activity attributes contain only the local `FastRecord` identifier. Dynamic
  content contains only start, target and whole-hour goal values required for
  rendering.
- A local preference and per-active-record presentation marker may record whether
  the user enabled, hid or dismissed the activity. Neither is fasting history,
  analytics or a source for changing a `FastRecord`.
- No health permission, APNs token, server, analytics or network access is used.
- Ending, dismissal or reconciliation changes ActivityKit state only; local
  fasting records remain authoritative.

### Proposed design and content

- Reuse OW-103 terminology and neutral state copy so Today and the Live Activity
  describe the same record consistently.
- Prioritise elapsed time in Lock Screen and expanded presentations, with target
  secondary. Compact uses the timer plus a restrained uFast mark; minimal uses
  the timer alone when legible and otherwise the mark with an accessible elapsed
  label.
- Avoid decorative motion and alerts. Use system text/timer behavior so reduced
  motion and Always-On handling remain predictable.
- Keep Lock Screen copy innocuous and concise. Do not use **Fasting**, food,
  weight, stage or health-outcome language in the system presentation.
- Use one coherent VoiceOver summary: **uFast, elapsed [duration], target
  [time]**, adding **Goal time reached** only when the current state contains it.
- Make **Show on Lock Screen** or **Hide from Lock Screen** secondary to the
  primary fasting action on Today. A persistent setting may also be required by
  the accepted start policy.
- End the Dynamic Island presentation as soon as completion succeeds. The final
  Lock Screen dismissal timing remains part of the open privacy decision.

### Dependencies

- OW-101 through OW-104 completed.
- D-007 establishes iOS 26.0 as the minimum.
- `project.yml` must add the extension and app-extension dependency and must be
  regenerated rather than hand-editing the Xcode project.
- Shared activity attributes and a pure presentation model must be available to
  both the app and widget extension without importing persistence into the
  extension.
- An ActivityKit protocol boundary, lifecycle coordinator and deterministic fake
  are required for unit tests; real framework coverage belongs in integration
  and device checks.
- App settings need local fields for the accepted display preference and minimal
  dismissal/suppression metadata. Any model change requires an explicit SwiftData
  migration or a separate local settings store that preserves existing data.
- The app target needs the Live Activities Info.plist capability and a Today deep
  link used by every presentation.
- A physical supported iPhone is required for final Lock Screen and Dynamic
  Island verification.

### Required product decisions

1. **Default behavior and privacy:** Should a Live Activity start automatically
   after the user's explicit **Start fast** action, or only after a separate
   opt-in?
   - **Recommended:** default off. Offer **Show active fast on Lock Screen** as a
     persistent local setting and **Show on Lock Screen** for the current fast.
     Enabling either clearly explains that elapsed and target will be visible
     while the device is locked.
   - Alternative: start automatically after every successfully persisted fast,
     with an easy **Hide from Lock Screen** control. This is lower friction but
     weaker under private-by-default because the first activity can appear before
     the user has reviewed the exposure.
2. **Completed dismissal:** After a successful end, should the final Lock Screen
   state disappear immediately or remain briefly?
   - **Recommended:** immediate dismissal. There is no completion action in the
     activity, History is available in-app and fasting information remains
     visible for less time.
   - Alternative: retain a neutral final state for 15 minutes. This offers a
     glanceable acknowledgement but extends Lock Screen exposure and adds little
     utility before OW-105 History.

### Verification

- Unit-test request/update/end/reconciliation orchestration using a fake
  ActivityKit client, including disabled, failure, orphan, duplicate,
  dismissed/system-ended and explicit-restart states.
- Unit-test ordering so persistence success precedes request/update/end and every
  persistence failure leaves ActivityKit unchanged.
- Unit-test deterministic duplicate retention and the local suppression marker
  without changing any `FastRecord`.
- Snapshot or preview-test Lock Screen, compact, minimal and expanded
  presentations below goal, at goal, beyond goal, in stale/system-ended
  conditions and at accessibility sizes.
- Integration-test successful start, correction, goal update and end without
  allowing ActivityKit failure to change persistence outcomes.
- Test absolute time behavior across London daylight-saving transitions and a
  display time-zone change.
- Manually test supported and unsupported devices, disabled Live Activities,
  user dismissal, relaunch, dark/light mode, Always-On, VoiceOver and offline
  operation.
- Run `make project`, `make build`, `make test` and `make lint` once refined and
  implemented.

### Done when

All final acceptance criteria and the repository Definition of Done pass, with
one optional system projection of the active local record, no unexpected
recreation after dismissal and no ActivityKit failure affecting fasting data.

### Definition of Ready check

- [x] Outcome and user are clear.
- [x] Proposed scope is coherent and bounded to active-fast glanceability.
- [ ] Acceptance criteria become final after privacy/default and dismissal
  behavior are accepted.
- [x] Core lifecycle, failure, privacy and accessibility states are identified.
- [x] Architecture dependencies and verification are known.
- [ ] Two product decisions remain unresolved.

## OW-107 Optional fasting target reminder

**Epic:** E5 Glanceability and quality
**Priority:** P1
**Status:** Discovery — not in current MVP scope
**Added:** 19 July 2026

### Candidate user story

As a user who chooses reminders, I want one calm notification when my recorded
fast reaches its goal time, so that I can return to the app without repeatedly
checking it.

### Why consider it

The original product brief mentioned optional fasting reminders, but the
subsequent MVP scope deliberately omitted notifications. OW-103 and OW-106 also
exclude target alerts. This discovery captures the smallest coherent reminder
behavior without silently moving it into the MVP.

### Context

- The active record, current goal and absolute target already exist in OW-103.
- OW-106 provides a glanceable but non-alerting Live Activity and must remain
  useful when notifications are denied.
- A notification is visible outside the app and may reveal fasting information.
  It therefore requires explicit user choice and innocuous copy.
- Local notification delivery is controlled by the system. uFast cannot promise
  exact delivery, and denial must not block any manual feature.
- Eating-window start and end reminders require a separate eating-window model
  that is not present in current MVP scope. This candidate is limited to one
  active-fast target reminder.

### Proposed in scope

- Add a local setting titled **Fasting target reminder**, default off.
- Request notification authorization contextually only when the user turns the
  setting on. Do not request it during onboarding or fast start.
- Explain before the system prompt: **uFast can remind you when your recorded
  fast reaches its goal time. Notifications may be visible on your Lock
  Screen.**
- After a fast is successfully persisted, schedule at most one local notification
  for its current absolute target if the setting is enabled and the target is in
  the future.
- Use a stable request identifier derived from the active `FastRecord` identifier
  so scheduling is idempotent.
- After a successful active-start correction or goal change, replace the pending
  request with one at the new target. Persistence failure leaves the existing
  request unchanged.
- After a successful end, cancel the matching pending request. End persistence
  failure leaves it scheduled because the fast remains active.
- Turning the setting off cancels every uFast fasting-target request without
  changing any fast.
- On launch or foreground, reconcile pending requests with the one active local
  record: remove orphaned and duplicate requests, update a mismatched future
  target and schedule nothing for a target already reached.
- Use one neutral notification:
  - Title: **Goal time reached**
  - Body: **Open uFast to review your recorded fast.**
- Tapping the notification opens uFast on Today.
- Keep scheduling entirely on-device. Use no remote push, account, server,
  analytics or background polling.

### Proposed out of scope

- Eating-window start reminders, eating-window end reminders or a recurring
  daily schedule.
- Configurable offsets, repeated alerts, snooze, escalation or missed-goal
  warnings.
- Sounds other than the system default, critical alerts or Time Sensitive
  interruption level.
- Automatically ending a fast or creating an event when the notification fires
  or is tapped.
- Requesting permission before the user enables the feature.
- Remote notification registration, APNs tokens, broadcast updates or a server.
- Coaching, celebration, streaks, biological-stage language or health claims.

### Candidate acceptance criteria

- Given reminders have never been enabled, when the app launches or a fast
  starts, then no notification permission prompt appears and no request is
  scheduled.
- Given the user turns on **Fasting target reminder**, when the explanatory step
  is confirmed, then uFast requests alert authorization once in context.
- Given authorization succeeds and a future-target fast is successfully saved,
  then exactly one local request is scheduled for that record's absolute target.
- Given authorization is denied, provisional, restricted or later revoked, then
  manual fasting remains fully usable and Settings shows an honest non-blocking
  status.
- Given the active start or current goal changes successfully, then the one
  pending request moves to the new target; given persistence fails, its previous
  schedule remains unchanged.
- Given the fast ends successfully or reminders are turned off, then its pending
  request is removed; given end persistence fails, the request remains.
- Given the target is already reached when reminders are enabled or reconciled,
  then no immediate or retroactive notification is scheduled.
- Given scheduling is delivered twice or reconciliation finds duplicates, then
  only one request remains for the active record.
- Given an orphaned request exists with no matching active fast, when
  reconciliation runs, then it is removed without changing fasting history.
- Given the notification is delivered, then it uses the exact neutral title and
  body, makes no biological claim and tapping it opens Today.
- Given a daylight-saving or time-zone change, then the request retains the same
  absolute target instant and the app does not duplicate it.
- Given the device is offline, then authorization-state handling, scheduling,
  cancellation and manual fasting remain usable without network access.

### States and edge cases

- Not determined, not requested, authorized, denied and revoked authorization.
- Setting off and on, including enabling during an active fast.
- Target in the future, exactly now and already passed.
- Start now, backdated start, corrected start, goal change and successful or
  failed end.
- Duplicate scheduling callback, orphaned request and relaunch reconciliation.
- System delivery delay, device reboot, Focus mode and notification summary.
- London daylight-saving transitions, display time-zone changes and offline use.
- VoiceOver, large Dynamic Type and clear permission-purpose copy.

### Data and privacy

- Stores one local reminder preference and system notification requests keyed by
  local fast identifiers.
- Notification content is visible outside the unlocked app and intentionally
  avoids duration, food, weight, detailed health data and physiological claims.
- Reads no HealthKit data, uses no remote push and sends no data off-device.
- Notification state is never a source of fasting history.

### Proposed architecture

- Add a `FastingReminderClient` protocol for authorization state, request,
  pending-request listing and cancellation.
- Keep orchestration behind a main-actor service that receives `AppClock`, the
  active record and current goal; test it with a deterministic fake.
- Sequence side effects after persistence success, matching OW-106. Reconciliation
  may change notification requests but never a `FastRecord`.
- Use the same Today deep link as OW-106 if that story establishes it first.

### Required product decisions

1. **MVP scope:** Move one optional target reminder into MVP, or retain it after
   MVP? Recommended: keep it post-MVP until the core manual/history loop,
   accessibility and privacy work are complete.
2. **Permission and default:** If included, should it be a default-off persistent
   setting with contextual permission? Recommended: yes, because notification
   content can be visible on the Lock Screen.
3. **Reminder shape:** Is one notification exactly at the active target enough,
   or are configurable offsets/eating-window reminders required? Recommended:
   one target notification; broader scheduling needs a separate story and
   eating-window model.

### Preliminary verification

- Unit-test authorization, idempotent scheduling, rescheduling, cancellation and
  reconciliation with an injected clock and fake client.
- Integration-test that persistence success precedes notification changes and
  every persistence failure leaves the existing schedule unchanged.
- UI-test contextual permission education, denied/revoked states, setting
  changes, neutral copy and Today deep link.
- Test both London daylight-saving transitions and a display time-zone change.
- Manually test Focus, notification summary, Lock Screen previews, VoiceOver and
  offline operation on a physical iPhone.
- Run `make project`, `make build`, `make test` and `make lint` after the story is
  accepted and implemented.

### Definition of Ready check

- [x] Candidate outcome and user are clear.
- [x] The smallest reminder shape is identified.
- [ ] MVP inclusion is accepted.
- [ ] Permission/default and reminder-shape decisions are accepted.
- [x] Privacy, lifecycle and architecture risks are identified.
- [ ] Acceptance criteria become final after the decisions above.

## Codex prompt

> Implement story **[ID and title]** from `READY_STORIES.md`.
>
> **Goal:** Deliver the user outcome and all acceptance criteria for this story.
>
> **Context:** Read `AGENTS.md`, `PRODUCT.md`, `MVP_SCOPE.md`, `DOMAIN_RULES.md`, `DECISIONS.md` and the complete story before changing code. Inspect the existing implementation and tests first.
>
> **Constraints:** Keep the change within the story's in-scope boundary. Preserve local-first privacy, accessibility, the stated domain rules and existing architecture. Do not add photo, AI, coaching, cloud, monetisation or unrelated refactors. Flag a contradiction or material missing decision before implementing it.
>
> **Done when:** Implement the smallest coherent solution; add or update the specified tests; run the repository build, test and lint commands; review the diff against the acceptance criteria; and summarise changed files, verification results, assumptions and remaining risks.
