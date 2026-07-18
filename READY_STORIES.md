# First ready stories

These stories become ready after D-002, D-007 and the local persistence choice are accepted and OW-000 establishes the repository.

## OW-002 Set a fasting goal

**Epic:** E0 Product foundation  
**Priority:** P0  
**Status:** Ready after minimum iOS and persistence decisions

### User story

As a new or returning user, I want to choose a fasting goal of at least 12 hours, so that the timer reflects the routine I intend to follow.

### Why now

The goal is required before the first complete fasting loop can be tested.

### In scope

- Default the first-use choice to 12 hours.
- Offer whole-hour choices from 12 through 24.
- Save the choice on device.
- Allow the choice to be changed in Settings.
- Update the active fast's target presentation without changing its start time.
- Preserve completed fast durations and their historical goal.

### Out of scope

- Different goals by weekday.
- Goals below 12 hours or above 24 hours.
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
- Manually check 12, 16 and 24 hours with large Dynamic Type.

## OW-101 Start a fast now

**Epic:** E1 Fasting loop  
**Priority:** P0  
**Status:** Ready after OW-002

### User story

As a user who has finished eating, I want to start a fast with one obvious action, so that I can see its progress without remembering the exact time.

### In scope

- Show Start fast as the primary action when no fast is active.
- Use the current instant as the start time.
- Persist one active fast.
- Immediately update Today with elapsed time, goal and target time.
- Make repeated taps idempotent.

### Out of scope

- Automatic start from a meal.
- Backdated start, which belongs to OW-102.
- Live Activity, which belongs to OW-106.

### Product rules

BR-02, BR-03 and BR-05.

### Acceptance criteria

- Given no active fast, when Start fast is tapped, then one active fast is saved with a start time matching the current instant within one second.
- Given the fast was saved, when Today renders, then it shows elapsed time, the selected goal and target time.
- Given the app is terminated and relaunched, then the same active fast continues from its stored start time.
- Given an active fast already exists, when the start action is triggered again through any race or duplicate event, then no second active fast is created.
- Given persistence fails, then the UI does not pretend the fast started and offers a calm retry state.

### Verification

- Unit-test creation and the single-active-fast invariant using an injectable clock.
- UI-test start and relaunch.
- Test duplicate taps and simulated persistence failure.

## Codex prompt

> Implement story **[ID and title]** from `docs/READY_STORIES.md`.
>
> **Goal:** Deliver the user outcome and all acceptance criteria for this story.
>
> **Context:** Read `AGENTS.md`, `docs/PRODUCT.md`, `docs/MVP_SCOPE.md`, `docs/DOMAIN_RULES.md`, `docs/DECISIONS.md` and the complete story before changing code. Inspect the existing implementation and tests first.
>
> **Constraints:** Keep the change within the story's in-scope boundary. Preserve local-first privacy, accessibility, the stated domain rules and existing architecture. Do not add photo, AI, coaching, cloud, monetisation or unrelated refactors. Flag a contradiction or material missing decision before implementing it.
>
> **Done when:** Implement the smallest coherent solution; add or update the specified tests; run the repository build, test and lint commands; review the diff against the acceptance criteria; and summarise changed files, verification results, assumptions and remaining risks.
