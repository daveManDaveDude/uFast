# Ready stories

These stories are refined in backlog order after D-002, D-007 and the local
persistence choice are accepted and OW-000 establishes the repository. A story
marked **Ready** has no known material product question; a story marked **Draft**
is preparation for later refinement and must not be implemented as if ready.

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
**Status:** Ready after OW-101

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
- Decisions: D-001 manual fast start and D-004 seven-day guided catch-up horizon.
- Existing boundaries: `AppClock`, `FastRecord` and local SwiftData persistence.

### In scope

- When no fast is active, offer **Start at a past time** as a secondary action to
  **Start fast**.
- When a fast is active, offer **Edit start time**.
- Let the user select a local calendar date and time no later than the current
  instant supplied by `AppClock`.
- Initialise a new past-time selection to the current date and time; initialise
  a correction to the active fast's stored start time.
- On confirmation, create one active fast or update the existing active fast in
  place, then recalculate its target from the corrected start and current goal.
- For a newly backdated fast, capture the current fasting goal as its historical
  goal. When correcting an existing fast, preserve its identifier and captured
  historical goal.
- Permit an older manually chosen start; D-004's seven-day limit applies to the
  later guided catch-up flow, not manual entry.
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

BR-02, BR-03, BR-05 and BR-12. BR-04 becomes applicable when an end boundary is
introduced by OW-104.

### Acceptance criteria

- Given no active fast, when the user chooses **Start at a past time**, selects a
  time earlier than now and confirms, then exactly one active fast is saved with
  that start instant and the current goal captured.
- Given an active fast, when the user chooses **Edit start time**, selects a
  different past time and confirms, then the same record is updated, its target
  reflects the corrected start and no second active fast is created.
- Given an active fast whose start is being edited, when the editor opens, then
  it shows the stored start date and time rather than the current time.
- Given either editor, when the user attempts to select a future instant, then
  confirmation is unavailable and an accessible explanation says the start time
  cannot be in the future.
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
- After saving, return to Today; do not add praise, warnings, streak language or
  claims about biological fasting state.

### Dependencies

- OW-002 completed.
- OW-101 supplies active-fast creation, single-record enforcement, persistence
  failure handling and clock injection.
- No new product or architecture decision is required.

### Verification

- Unit-test past creation, in-place correction, captured-goal preservation,
  future rejection, cancellation and the single-active-fast invariant with an
  injected clock.
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
**Status:** Draft — prepared for refinement after OW-101

### User story

As a user with an active fast, I want to see how long it has been running, its
progress toward my goal and its target time, so that I can understand the record
at a glance.

### Why now

This completes the observable half of the basic start-and-watch loop after
OW-101 proves active-fast creation and persistence.

### Context and story boundary

- OW-101 owns creating one active fast and showing a minimal confirmation with
  goal and target.
- OW-102 owns selecting and correcting the active fast's start instant.
- OW-103 will own the continuously updating elapsed value, accessible progress
  treatment and calm reached-target state on Today.
- OW-104 will own ending the fast; OW-106 will own Lock Screen and Dynamic Island
  presentation.
- Relevant rules: BR-02, BR-05, BR-12 and BR-15.

### Provisional in scope

- Derive elapsed duration from `AppClock.now` and the persisted start instant;
  do not persist timer ticks.
- Show the current goal and absolute target date/time derived from start plus goal.
- Present progress toward the goal without implying biological status or failure.
- Refresh while Today is visible and immediately after foregrounding, relaunch,
  a goal change or an OW-102 start-time correction.
- Remain useful and calm after elapsed time reaches or exceeds the goal.
- Provide one coherent VoiceOver summary in addition to accessible individual
  controls or values.

### Provisional out of scope

- Ending, editing or deleting a completed fast.
- Notifications, alarms or reminders at the target time.
- Live Activity, widgets or Apple Watch.
- Persisting derived elapsed/progress values.
- Coaching, celebration, streaks or biological-stage claims.

### Candidate acceptance criteria

- Given an active fast started at a known instant, when Today appears at a fixed
  injected time, then elapsed time, current goal and target time are derived
  deterministically from the stored start.
- Given Today remains visible, when clock time advances, then elapsed time and
  progress update without writing timer ticks to persistence.
- Given the app is backgrounded across the target or relaunched later, when Today
  becomes active, then the display catches up from the stored start and current
  time.
- Given the current goal changes or the start time is corrected, when Today
  refreshes, then target and progress use the new values while the stored start
  remains the source of elapsed time.
- Given elapsed time meets or exceeds the goal, then progress remains readable
  and accessible, does not wrap or become negative, and uses neutral language.
- Given a daylight-saving or display time-zone change, then elapsed duration is
  based on absolute instants while the target is formatted for the current locale.

### States and edge cases identified for refinement

- Active below goal, exactly at goal and beyond goal.
- Foreground, background/resume and process relaunch.
- Goal change and corrected start while active.
- Very short elapsed duration, multi-day elapsed duration and a device clock that
  moves earlier than the stored start.
- VoiceOver, Reduce Motion, high contrast and large Dynamic Type.
- Offline operation and no writes for derived display state.

### Data and privacy

- Reads one active fast, the current goal, injected time and locale/time-zone
  formatting context.
- Writes no new health or timer data and requests no permission or connectivity.

### Refinement questions after OW-101

- Confirm the elapsed display precision and refresh cadence based on the shipped
  Today architecture, including whether seconds add value or visual pressure.
- Choose the smallest accessible progress treatment and define its exact
  VoiceOver value, Reduce Motion behavior and appearance beyond 100 percent.
- Define exact neutral copy at and beyond the target.
- Decide the safe presentation for the rare case where device time is earlier
  than the stored start, without rewriting the record.
- Confirm whether OW-101's shipped persistence-error boundary exposes any state
  OW-103 must represent.

### Preliminary verification plan

- Unit-test elapsed, target and progress derivation with an injected clock,
  including exact-target, over-target, clock rollback and daylight-saving cases.
- UI-test initial active display and foreground catch-up with deterministic launch
  fixtures; avoid tests that wait in real time.
- Manually check VoiceOver, large text, Reduce Motion, 12/24-hour locales and
  background/foreground transitions.
- Run `make build`, `make test` and `make lint` once refined and implemented.

### Definition of Ready check

- [x] Outcome and user are clear.
- [ ] Scope is one coherent, reviewable change after inspecting OW-101.
- [ ] Acceptance criteria are final and observable.
- [x] Relevant states and rules are identified.
- [x] Privacy implications are covered; accessibility treatment needs refinement.
- [ ] Dependencies and final verification mechanics are known.
- [ ] No material product question remains unresolved.

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
