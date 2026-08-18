# BF-101 — Bound manual fast starts and active-start edits to 36 hours

**Slice:** Fasting loop reliability  
**Priority:** P0  
**Status:** Ready  
**Story type:** Product bug fix

## User outcome

As a user, I want a past-time fast start and an active-fast start correction to
be limited to the previous 36 absolute hours, so that I cannot accidentally
create a fast in the distant past while still being able to correct a missed
start.

## Why now

The current create path permits any past `Date` (`Date.distantPast` in the
editor), which exposes dates as far back as year 1. The domain service only
guards the correction path, and that guard is currently 24 hours. The UI and
domain therefore disagree, and the active-fast **Edit start time** journey is
not aligned with the requested 36-hour policy.

## Context and authoritative rules

- `PRODUCT.md` and `MVP_SCOPE.md` keep manual start, edit and backdate in the
  local-only product boundary.
- `AppClock` is the temporal authority for deterministic behavior.
- BR-03 requires one active fast; BR-12 preserves absolute instants across
  calendar and time-zone changes; BR-15 keeps copy neutral and record-based;
  BR-17 continues to reject overlapping recorded intervals.
- The current BR-16/D-010 contract says 24 hours for active-start correction and
  allows older creation. This story is the explicit requested supersession:
  both manual creation and active-fast correction use a 36-hour absolute
  window. D-004 remains a seven-day bound for the guided Catch-up flow, but its
  separate allowance for arbitrarily old manual fast entry must be amended for
  this journey. The implementation handoff must update D-004, D-010, BR-16 and
  the OW-102 contract together; the historical decisions remain visible as
  amended/superseded records rather than silently becoming contradictory.
- “Edit start time” is interpreted as the active-fast correction editor
  (`StartTimeEditor.Mode.correct`). Editing an already completed fast from
  History remains governed by its existing completed-record contract and is
  out of scope.

## In scope

- Apply one inclusive 36-hour absolute age bound to:
  - **Start at a past time** when no fast is active; and
  - **Edit start time** for the active fast.
- Keep the ordinary **Start fast** action at the injected current instant.
- Enforce the same bound in the domain service and the editor controls.
- Keep the exact lower boundary valid: `AppClock.now - 36 hours` succeeds;
  anything older fails without mutation.
- Revalidate against `AppClock.now` at save time so a stale editor or clock
  change cannot bypass the bound.
- Preserve existing conflict checks, one-active-fast behavior, historical-goal
  capture, local SwiftData persistence, retry behavior and absolute instants.
- Add focused unit, persistence/regression and UI coverage for the new bound.
- Update the affected product-rule/decision wording so the repository contract
  matches the shipped behavior.

## Out of scope

- Changing fasting-goal limits or the current goal used by an active fast.
- Limiting or rewriting existing completed fasts edited from History.
- Automatically changing, deleting or shortening an active fast that was
  created by an older build and is already more than 36 hours old.
- Changing overlap semantics, catch-up, automatic fast projection, food or
  hydration entry, permissions, networking, CloudKit or health claims.
- Adding a new fast-entry journey or changing the visual hierarchy of the
  primary **Start fast** action.

## Final user-visible behavior and edge cases

- The past-start sheet opens with a usable recent value and cannot navigate to
  year 1 or any other instant older than 36 absolute hours.
- The active correction sheet uses the same 36-hour bound and says:
  **Start time must be within the past 36 hours.**
- A future instant remains invalid and uses the existing future-time
  explanation.
- A save at exactly 36 hours succeeds. A save one second older is unavailable
  in the editor and is rejected again by the service if it reaches the save
  boundary.
- Cancelling leaves the persisted record and Today presentation unchanged.
- A conflict remains a conflict; the new age rule must not bypass the existing
  recorded-fast overlap check.
- Duplicate taps, retries and relaunch preserve one active record only.
- An active fast created before this fix with a start older than 36 hours is
  preserved and remains visible/usable. Opening its correction journey keeps
  that stored instant as the displayed draft, marks it invalid with
  **Start time must be within the past 36 hours.**, disables Save, and does not
  silently clamp or rewrite it. The user can choose an in-window replacement
  through the editor, then save it subject to normal validation, or cancel with
  no mutation. The controls must not make an out-of-range stored value appear
  to have been repaired.
- Daylight-saving and display-time-zone changes preserve the selected absolute
  instant; the 36-hour comparison is elapsed-time based, not a local-calendar
  date count.
- VoiceOver, large Dynamic Type, 12/24-hour locales and offline use retain an
  understandable purpose, selected value, validation message and actions.

## Acceptance criteria

1. **Create at the boundary**  
   Given no active fast and an injected `AppClock.now`, when the user confirms
   a start exactly 36 absolute hours before now, then one active fast is saved
   at that exact instant with the current goal captured.

2. **Reject an older create**  
   Given no active fast, when a proposed start is older than 36 absolute hours,
   then the editor does not offer a valid confirmation, the explanation is
   **Start time must be within the past 36 hours.**, and no record is created.
   If validation is reached through a stale control or direct service call, the
   domain service rejects it with no mutation.

3. **Correct at the boundary**  
   Given an active fast, when its start is changed to exactly 36 absolute hours
   before now and saved, then the same record is updated in place and its target
   recalculates from the corrected start.

4. **Reject an older correction**  
   Given an active fast, when its proposed start is older than 36 absolute
   hours, then Save is unavailable, the same 36-hour explanation is accessible,
   and the stored start, target and identifier remain unchanged.

5. **Future and ordinary start behavior**  
   Given either past-time editor, when the user attempts a future instant, then
   the future validation remains in force. Given the primary Start fast action,
   when it succeeds, then it still records the injected current instant without
   opening the past-time editor.

6. **Persistence, conflict and retry safety**  
   Given a valid bounded start, an overlap, a duplicate confirmation, a save
   failure or a relaunch, then the existing one-active-fast, conflict, retry and
   persistence contracts hold and no second or silently altered record appears.

7. **Existing out-of-policy active records**  
   Given an active record from an older build whose start predates the new
   window, when the app launches and the correction editor is opened, then the
   record remains unchanged and the UI keeps the stored instant visible as an
   invalid draft with Save disabled and the specific 36-hour explanation;
   cancellation is safe and an in-window replacement is validated by the same
   rules without clamping the stored value on open.

8. **Stale save-time validation**  
   Given the editor opened with a value that was valid at the time, when
   `AppClock.now` advances so that the value becomes older than 36 hours before
   confirmation, then the service rejects the save, the editor remains open,
   the record is unchanged, and the specific **Start time must be within the
   past 36 hours.** explanation is shown rather than only a generic save error.

9. **Absolute-time and accessibility behavior**  
   Given a start around either London DST transition or a display time-zone
   change, when it is saved and displayed again, then the same absolute instant
   is retained. Given VoiceOver or an accessibility text size, the 36-hour
   explanation and Cancel/Save or Cancel/Start fast actions remain readable and
   operable without relying on color.

## Architecture and data boundaries

- `FastStartService` is the authoritative validation boundary. The maximum age
  must have one shared source used by creation, correction and UI validation;
  do not leave a create-only or correction-only constant.
- `StartTimeEditor` must expose a bounded selection range and mirror the
  service's exact inclusive boundary. When an older pre-fix active value is
  loaded, the editor must retain it as a displayed invalid draft while making a
  separate in-window replacement selectable; it must not let a bounded picker
  silently clamp the persisted value. UI validation is convenience; service
  validation remains final protection against stale state and clock changes.
- `ActiveFastRepository` and the existing local SwiftData adapter continue to
  create/update one `FastRecord`. No schema migration or data rewrite is
  required.
- Existing `FastConflictChecker`, historical-goal capture, post-commit
  projection and optional system-surface behavior remain unchanged.
- The implementation must preserve older stored values and must not pass
  SwiftData model objects across existing isolation boundaries.
- Product documentation must amend D-004, D-010, BR-16 and OW-102 together:
  Catch-up remains separately bounded to seven days, while both manual active
  fast creation and active-start correction use 36 absolute hours. The
  distinction from completed History editing remains explicit.

## Dependencies and explicit decisions

- OW-002 and OW-101/OW-102 are delivered and provide goals, active-fast start,
  `AppClock`, persistence failure handling and the current editor journey.
- The user request supplies the product decision to use 36 absolute hours for
  both new manual starts and active-start edits. Implementation must record it
  as an amendment/supersession of D-004's older-manual-entry allowance and
  D-010/BR-16, and update OW-102's copied contract before the story can be
  accepted.
- No new permission, network, privacy, persistence or migration decision is
  needed.
- If product direction instead intends to constrain completed-fast History
  edits, that is a separate decision and this story must remain Draft until a
  separate story is defined; this story does not assume that expansion.

## Focused verification

- Unit-test the shared boundary for now, exactly 36 hours, one second older,
  future, DST and time-zone cases for both creation and correction, including
  a clock-advance rejection after an editor opened.
- Regression-test conflicts, duplicate starts, save failure, historical-goal
  preservation and pre-existing out-of-policy active records.
- UI-test the past-start and active-edit sheets with a fixed clock, including
  the exact boundary, the disabled/invalid older value, an older pre-fix active
  record shown without clamping, specific copy, cancellation, retry and
  relaunch.
- Manually check VoiceOver, large Dynamic Type, 12/24-hour display, offline use
  and an active record older than 36 hours.
- Run the story-focused tests first, then `make build`, `make test` and
  `make lint` during implementation integration, following the repository's
  Xcode preflight and single-suite rules.

## Definition of Ready

- [x] User outcome and the 36-hour policy are explicit.
- [x] Create and active-edit scope is separated from completed History editing.
- [x] Exact-boundary, stale-state, persistence, conflict and accessibility
      behavior is observable.
- [x] Existing records are preserved and no migration is implied.
- [x] Real domain/UI boundaries and focused verification are identified.
- [x] Sol readiness gate has returned an explicit verdict.

## Sol readiness gate

Sol gate: **READY** — `gpt-5.6-sol`, medium reasoning, same reviewer after one
document-only revision cycle. Sol found the 36-hour policy supersession,
legacy active-record draft state, stale validation, architecture boundaries,
accessibility and privacy scope sufficiently explicit; no remaining changes
were required.
