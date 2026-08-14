# OW-L101 Lock Screen contract and prototype evidence

**Accepted:** 8 August 2026  
**Prototype scheme:** `uFastLockScreenPrototypeHost`  
**Production capability:** enabled by OW-L102

## Accepted contract

The authoritative value remains the active user-recorded `FastRecord` in the
app's local SwiftData store. The widget projection is disposable presentation
state and cannot create or mutate fasting history.

| State | Visible content | Elapsed precision | Hidden content |
| --- | --- | --- | --- |
| Prototype valid, privacy-redacted | uFast, Elapsed, progress, percentage | Completed total hours and minutes | Seconds, target, goal-reached state, record identifier |
| Prototype valid, authenticated | uFast, Elapsed, progress, percentage, target or Goal time reached | Counting seconds from the absolute start | Record identifier |
| OW-L102 operative fallback, any Lock Screen state | uFast, Elapsed, progress, percentage | Completed total hours and minutes | Seconds, target, goal-reached state, record identifier |
| Always-On/reduced luminance | Same or less than privacy-redacted | Completed total hours and minutes | Same as privacy-redacted |
| No active projection | No active fast, Open uFast | None | Previous duration and next goal |
| Missing, unreadable, corrupt or incompatible | No active fast, Open uFast | None | All projected values |
| Start in the future or invalid target | No active fast, Open uFast | None | All projected values |
| Projection for an ended record pending convergence | Treat as derived stale content; the app clears after its successful commit and requests reload | Never authoritative | No mutation controls |

The OS may apply a stricter placeholder when the user disables Lock Screen
widget data. VoiceOver receives one value when focus lands on elapsed time; the
system timer is not a recurring live-region announcement.

## Projection and lifecycle

- App Group: `group.com.davidmcgrath.uFast.widgets`.
- File: `active-fast-widget-projection.json`.
- Protection: `NSFileProtectionCompleteUntilFirstUserAuthentication`. This
  allows use after the first unlock while failing closed before first unlock
  following a restart.
- Fields: schema version, active record UUID, absolute start, absolute target,
  captured 8–24 whole-hour goal and generation date only.
- Writes use Foundation's atomic file replacement. OW-L102 must invoke write or
  clear after the authoritative SwiftData save returns successfully, then ask
  WidgetKit to reload. Failed/cancelled persistence does neither. Projection or
  reload failure is logged/presented independently and never rolls back data.
- Generation age is diagnostic only. Validation rejects incompatible schema,
  corrupt or missing required fields, invalid goal, target mismatch, target not
  after start and any future start.
- Delete All Data must clear the projection only after the deletion transaction
  succeeds. If clearing then fails, invalidation metadata defined by OW-L102
  must prevent disclosure; the current OW-L101 prototype does not integrate
  production deletion.
- OW-L102 writes `active-fast-widget-projection.invalidated` with the same file
  protection if removing the projection fails after a committed end or deletion.
  The extension treats that marker as no active projection. A later successful
  active projection write removes the marker only after its JSON file is safely
  written, so a failed cleanup fails closed rather than revealing old elapsed
  time.

## Precision and platform evidence

The production widget uses a current WidgetKit timeline entry with a
target-date reload policy. Its elapsed value uses SwiftUI's system timer format
with minute precision, so completed hours/minutes continue to advance without
app execution, persistence or per-second timeline entries. A system
`ProgressView(timerInterval:countsDown:)` keeps the clamped track moving and
the target-date reload lets the displayed percentage converge at 100% without
persisting ticks. The isolated prototype retains its authenticated-seconds
branch as evidence for the later physical-device decision.

The production branch deliberately uses the accepted OW-L101 fallback and
renders completed hours/minutes in every Lock Screen state. It exposes no
target or goal-reached state. Because WidgetKit owns rendering and refresh, the
repository cannot prove from simulator compilation that privacy redaction
transitions consistently on hardware; the fallback avoids inferring lock state.

No authenticated Lock Screen observation was completed during this run. The
connected test iPhone was initially locked and iOS correctly denied remote
prototype launch; a later unlocked launch succeeded, but placing and exercising
the Lock Screen widget requires direct device interaction. P1 is nevertheless
resolved rather than left implementation-changing: the accepted fallback is
operative for OW-L102. The production Lock Screen widget must show
hours/minutes at all times and seconds remain in the unlocked app. A later
physical-device result may restore authenticated widget seconds only through an
explicit update to D-028; it is not an open OW-L102 assumption.

## Visual mapping

The accessory rectangular prototype preserves Today's information order:
identity, elapsed label, monospaced elapsed value, adjacent percentage and a
thick rounded clamped progress track. It uses semantic system foreground and
container roles so WidgetKit can preserve contrast, tint and reduced-luminance
behavior. Botanical artwork, controls and the in-app card geometry are omitted
because they compete with essential content in this family.

## Deterministic evidence

- `ActiveFastWidgetProjectionTests` cover exact encoded fields, schema/goal/
  target/future validation, age-independent validity, corrupt/missing files and
  idempotent clearing.
- `LockScreenFastPresentationTests` cover privacy content, precision, neutral
  failure mapping, parity with Today's clamped progress, London DST and display
  time-zone formatting.
- The isolated prototype host can write valid, future, corrupt and no-active
  states to the protected App Group file and request a reload.
- The prototype built and signed for an iPhone 17 Pro Max on iOS 26, Xcode
  provisioned both host and widget for the accepted App Group, and installation
  and unlocked launch succeeded. No Lock Screen content or redaction
  observation is claimed because the widget was not manually placed.
- The production `uFast` target embeds the `uFastLockScreenWidget` extension and
  shares only the accepted App Group projection entitlement after project
  generation.

## Physical-device evidence required to reconsider the fallback

The following is not required to begin OW-L102 with the operative hours/minutes
fallback. It must pass before changing D-028 to expose authenticated seconds:

- [ ] Locked with widget data enabled: only protected matrix content is shown.
- [ ] Authentication transition: seconds appear and count without app execution.
- [ ] Locked elapsed remains truthfully minute-current for a sustained interval.
- [ ] Widget data disabled: OS placeholder reveals no projected values.
- [ ] Always-On reduced luminance: essential content is legible and motion-free.
- [ ] Restart before first unlock: protected file is unreadable and state is neutral.
- [ ] After first unlock/relock: file is readable with the selected protection.
- [ ] File attributes and JSON fields match this contract.
- [ ] VoiceOver reads one coherent protected/authenticated value without repeated announcements.

Screenshots belong in `docs/images/ow-l101-device-evidence/` with device model,
iOS build, privacy setting and observation recorded here. No device screenshots
were fabricated or inferred during implementation.
