# uFast user-controlled automatic Live Activities

**Stories:** OW-L106 to OW-L109  
**Status:** OW-L106 through OW-L108 delivered in source; OW-L109 release evidence pending
**Prepared:** Updated 10 August 2026
**Milestone:** Roadmap 1 — Lock Screen fasting surface  
**Decision:** D-030; BR-33 through BR-40  
**Baseline:** Delivered OW-L101 through OW-L105

## Outcome

A person can make one informed, reversible choice to have uFast show Live
Activities automatically. When enabled, uFast requests one activity after a
fast is successfully saved. If a longer fast is still active after that
activity's eight-hour window, uFast may request a new activity only when the
person later opens or genuinely reactivates the app.

The feature remains optional, local-only and subordinate to the authoritative
`FastRecord`. It never schedules a launch, chains activities in the background,
uses notification permission, or treats ActivityKit state as evidence that a
fast started or ended.

## Apple-aligned product rationale

Apple's Live Activities HIG says Live Activities may begin automatically at an
appropriate point in an ongoing task, but unexpected appearances can be
surprising and the app should make them easy to turn off. Apple also identifies
Live Activities as best suited to bounded activities of no more than eight
hours and warns that their prominent system placement can expose sensitive
content.

uFast therefore adopts a higher-trust product contract:

- automatic behavior is off until one explicit in-app choice;
- the offer occurs in context, after a fast has successfully started;
- the offer and Settings copy describe what appears and where;
- the choice is reversible and a current activity is easy to hide;
- longer-fast continuation occurs only after the person foregrounds uFast;
- a new request is never described as extending the previous activity;
- no request loop, scheduled background work, APNs or notification alert is
  introduced; and
- the existing privacy-sensitive, innocuous system-surface content remains
  unchanged.

This is an app preference, not a custom imitation of an Apple permission alert.
ActivityKit availability remains controlled by the person's iPhone setting and
checked through `ActivityAuthorizationInfo.areActivitiesEnabled`.

## Settled user-facing copy

### One-time offer

**Title:** **See your fast at a glance?**

**Message:**

> uFast can automatically show elapsed time, goal progress and target on the
> Lock Screen and Dynamic Island when you start a fast. Each Live Activity stays
> active for up to 8 hours. If your fast continues, uFast can show a new one the
> next time you open the app. You can hide it or turn this off at any time in
> Settings.

**Actions:**

- **Show Automatically**
- **Not Now**

The offer is presented only after the active fast is visible. **Not Now** is a
complete, pressure-free choice: the offer never repeats, the fast continues and
the person can enable the setting later.

### Settings

**Section:** **Live Activities**

**Toggle:** **Automatically show Live Activities**

**Supporting copy:**

> Show elapsed time, goal progress and target on the Lock Screen and Dynamic
> Island when a fast starts. Each Live Activity stays active for up to 8 hours.
> If your fast is still active, uFast can show a new one the next time you open
> the app.

**Control explanation:**

> Turn this off to hide the current Live Activity and prevent new ones. You can
> also choose Hide for this fast without changing the setting for future fasts.

When the system setting is disabled, retain the existing calm status:
**Live Activities are turned off for uFast in iPhone Settings.** Do not require
the person to change it and do not block any fasting feature.

### Today controls

- No running activity and automatic behavior off: **Show Live Activity**.
- Running activity: **Hide for this fast**.
- Current fast suppressed or an automatic request is not eligible: **Show Live
  Activity again** remains available as an explicit override.
- Manual Show or Show again uses the delivered OW-L105 visibility disclosure,
  clears per-fast suppression only after confirmation and requests at most one
  activity.

## Settled state model

### Global preference

Use a migration-safe local three-state value:

- `notAsked`: behaves as off and is eligible for the one-time contextual offer;
- `enabled`: permits committed-start and foreground-continuation requests; and
- `disabled`: behaves as off and never presents the one-time offer again.

Unknown or corrupt values fail closed to `disabled`. Delete All Data removes the
preference with the other app-created settings. Reinstall or the app's existing
fully confirmed data reset may return to `notAsked` because no prior choice
remains on that installation.

### Per-fast lifecycle state

Retain only presentation metadata required to prevent duplicates and honour
control:

- active record identifier;
- last successful ActivityKit request date and identifier;
- whether a request is currently in flight;
- last known running/ended/dismissed state when ActivityKit supplies it;
- whether the person chose **Hide for this fast**; and
- last automatic attempt outcome needed to prevent an immediate retry loop.

This metadata is not fasting history or analytics. Clear it when the fast ends,
the active record is deleted or Delete All Data succeeds.

### Automatic request eligibility

On a successful fast start or genuine app foreground transition, an automatic
request is eligible only when all conditions are true:

1. the global preference is `enabled`;
2. one valid authoritative active `FastRecord` exists;
3. ActivityKit is supported and `areActivitiesEnabled` is true;
4. no matching activity is pending or active;
5. no request is in flight;
6. **Hide for this fast** suppression is absent; and
7. either no activity has successfully been requested for this fast, or at
   least eight absolute hours have elapsed since the last successful request.

Make at most one automatic attempt during one foreground activation. A failed
attempt may be retried on a later distinct foreground activation or explicitly
by the person, but never loops in the same activation.

If ActivityKit explicitly reports a person-dismissed activity before the prior
eight-hour window ends, do not immediately recreate it. The global setting
still permits a later foreground continuation after that window because the
one-time and Settings copy disclosed that behavior. **Hide for this fast** or
turning the global setting off is the unambiguous suppression path and must be
prominent in Today.

## Lifecycle ordering

The authoritative transaction always wins:

1. Persist the global preference or `FastRecord` mutation.
2. Publish or clear the existing WidgetKit projection as already required.
3. Request, update or end ActivityKit state.
4. Report a calm status only when useful; never roll back persisted state due
   to ActivityKit failure.

Enabling the setting while a fast is already active may request one activity
after the setting commit. Disabling it commits the preference first, then ends
matching activities immediately. If ending fails, the setting remains off and
the existing non-blocking hide failure copy is shown.

Starting at a past time is eligible under the same preference. The activity may
truthfully begin with elapsed time already greater than eight hours or beyond
the goal; its own maximum active lifetime still begins when requested.

## Scope retained from OW-L105

- One matching activity at a time, deterministic duplicate cleanup and request
  coalescing.
- The local `FastRecord` remains authoritative.
- ActivityKit failure never changes fasting persistence.
- Existing allowed content, privacy-sensitive modifiers, Dynamic Island
  layouts, accessibility summaries and `ufast://fast/current` route.
- Immediate dismissal after successful fast end, active deletion or Delete All
  Data.
- No account, analytics, networking, APNs, notification permission, alerts,
  sounds, background task, scheduled launch or mutation control in the Live
  Activity.
- The user-added WidgetKit widget remains the durable long-fast surface.

---

## OW-L106 — Add informed consent and reversible Settings control

**Priority:** P0  
**Status:** Delivered in source 9 August 2026
**Estimate:** 5 points  
**Depends on:** Delivered OW-L105; D-030; BR-37 and BR-39

### User story

As a privacy-conscious user, I want uFast to explain automatic Live Activities
once and remember my choice, so that nothing starts automatically until I have
understood what will appear and I can change my mind at any time.

### In scope

- Add the migration-safe `notAsked`/`enabled`/`disabled` preference to the one
  authoritative `AppSettingsRecord`; do not create a second settings authority.
- Preserve existing data and default every existing installation to `notAsked`,
  which behaves as off.
- After the first successful eligible normal or backdated start, present the
  settled one-time offer only after Today visibly confirms the active fast.
- Do not present the offer when ActivityKit is unsupported or system-disabled;
  keep `notAsked` so a later eligible start can offer after availability changes.
- **Show Automatically** commits `enabled`, then uses the delivered coordinator
  to request the current activity. If the preference save fails, do not request
  and show a calm settings-save error. If ActivityKit fails after the preference
  commits, retain `enabled`, keep the fast active and show the existing request
  failure copy.
- **Not Now** commits `disabled`, makes no request and never prompts again.
- Add the settled Settings section, toggle, supporting copy and stable
  accessibility identifiers.
- Enabling from Settings while a valid fast is active may request one activity
  after the setting commits. Disabling commits `disabled`, ends matching
  activities and prevents automatic requests.
- Rename the in-app removal control to **Hide for this fast** and record
  per-fast suppression without changing the global preference.
- Keep the existing manual Show/Show again paths available when automatic
  behavior is off or suppressed.

### Out of scope

- Wiring automatic requests into future fast starts beyond the accepted offer.
- Foreground continuation after an eight-hour window.
- Notification permission, APNs, remote starts or scheduled background work.
- Any change to Live Activity system-surface content.

### Acceptance criteria

1. Given an existing or new installation with no automatic choice, the setting
   behaves as off and no Live Activity starts automatically before consent.
2. Given `notAsked`, when an eligible fast commits and Today shows it, the offer
   appears once with the exact settled copy and actions.
3. Given the start fails or is cancelled, no offer appears, no preference changes
   and no ActivityKit request occurs.
4. Given **Show Automatically**, `enabled` persists before one request is made;
   the fast remains authoritative if the request fails.
5. Given **Not Now**, `disabled` persists, no request occurs, the offer never
   repeats on later starts or launches and Settings can still enable it.
6. Given ActivityKit is disabled or unsupported at the first start, no offer or
   pressure appears and the normal fasting journey remains complete.
7. Given the Settings toggle is enabled with an active fast, one activity is
   requested after the setting commits; with no active fast, no activity is
   requested.
8. Given the toggle is disabled, any matching activity is asked to end
   immediately, later automatic requests are blocked and an end failure does not
   turn the preference back on.
9. Given **Hide for this fast**, the activity ends and the current fast is
   suppressed while the global enabled setting remains unchanged for later
   fasts.
10. VoiceOver reads the toggle, current state, supporting explanation and offer
    actions coherently at accessibility text sizes without relying on color.
11. Migration, relaunch, offline use and Delete All Data preserve or clear the
    preference exactly as specified without losing any existing record.

### Verification

- Unit-test preference decoding, unknown-value fail-closed behavior, migration,
  save failure and Delete All Data.
- Unit-test enable/disable request/end ordering and per-fast suppression.
- UI-test Show Automatically, Not Now, no-repeat, Settings reversal, disabled
  ActivityKit and accessibility identifiers with isolated fixed-clock fixtures.
- Inspect copy in light/dark mode, largest supported Dynamic Type and VoiceOver.

### Done when

No automatic activity can start before the informed choice; either choice is
stable, reversible and pressure-free; and the existing fast remains correct
through every preference or ActivityKit failure.

---

## OW-L107 — Automatically start after a committed fast

**Priority:** P0  
**Status:** Delivered in source 9 August 2026
**Estimate:** 5 points  
**Depends on:** OW-L106; BR-36 through BR-40

### User story

As a user who enabled automatic Live Activities, I want one to appear after I
successfully start a fast, so that I receive the glanceable surface I chose
without another confirmation every time.

### In scope

- After a successful normal or backdated `FastRecord` commit and existing widget
  publication, evaluate the settled automatic eligibility rules.
- Request exactly one matching activity when the preference is enabled and no
  suppression or running match exists.
- Re-resolve the active record from persistence; never trust stale view state.
- Coalesce repeated callbacks and preserve deterministic duplicate cleanup.
- Keep manual Show/Show again available after disabled, unavailable or failed
  automatic attempts.
- Record successful request time separately from failed attempt time so a
  failure cannot masquerade as an eight-hour activity window.
- Use no alert configuration, sound, haptic, push or notification permission.

### Out of scope

- Starting an activity before or concurrently with the `FastRecord` commit.
- Foreground continuation after a successful activity's eight-hour window.
- Background launch, APNs, scheduled retry or per-second update.

### Acceptance criteria

1. Given `enabled`, ActivityKit available and no active fast, when Start fast
   commits, the widget publishes and exactly one Live Activity request follows.
2. Given the same conditions for a backdated active start, the request uses the
   authoritative older start while its ActivityKit lifetime begins now.
3. Given `notAsked` or `disabled`, starting a fast makes no automatic request;
   `notAsked` follows OW-L106's one-time offer instead.
4. Given persistence fails or is cancelled, no widget or ActivityKit state
   pretends the fast started.
5. Given ActivityKit is disabled, unsupported or the request fails, the fast and
   widget still succeed and no immediate automatic retry loop occurs.
6. Given duplicate start callbacks or rapid scene changes, one request is in
   flight and no duplicate activity is created.
7. Given an activity already matches the active record, the coordinator updates
   or retains it rather than requesting another.
8. Given the target is already reached at request time, elapsed remains based on
   the original start and the neutral reached state contains no medical claim,
   warning or celebration.
9. Activity content and persistence remain within OW-L105's privacy, size,
   accessibility and local-only boundaries.

### Verification

- Unit-test all preference/availability/persistence combinations, request
  ordering, coalescing, duplicates, backdated starts and already-reached goals.
- Integration-test Start now and Start at a past time with the existing
  SwiftData and widget paths.
- UI-test one enabled automatic start and one disabled start without relying on
  simulator ActivityKit UI.

### Done when

Every eligible committed start requests one activity, every ineligible or failed
path remains a complete local fasting journey, and no duplicate or premature
request is possible.

---

## OW-L108 — Continue a longer fast on foreground activation

**Priority:** P0  
**Status:** Delivered in source 9 August 2026
**Estimate:** 8 points  
**Depends on:** OW-L106 and OW-L107

### User story

As a user who enabled automatic Live Activities, I want uFast to show a new one
when I return during a longer still-active fast, so that I can again see the full
elapsed fast without pretending the previous eight-hour activity was extended.

### In scope

- Extend cold-launch and genuine inactive/background-to-active reconciliation
  with the settled automatic eligibility algorithm.
- Reconcile, validate, update and deduplicate running activities before
  considering a new request.
- If no match runs and no activity has succeeded for the fast, request one on
  foreground when enabled and unsuppressed.
- If a previous request succeeded, permit one new request only after eight
  absolute hours from that successful request and a later foreground activation.
- Display elapsed time from the original authoritative start even when it is 17
  hours, multiple days or beyond the goal. Start the new ActivityKit lifetime at
  the new request.
- Make at most one automatic attempt per foreground activation and coalesce
  `.task`, deep-link and `scenePhase` callbacks.
- A failed automatic attempt may retry only on a later distinct foreground or
  explicit Show again; it never loops while the app remains active.
- Honour global off and **Hide for this fast** suppression. Manual Show again
  may clear suppression through the delivered disclosure path.
- Treat a reported dismissal as ineligible until the prior eight-hour window
  has elapsed; do not immediately replace something the person just removed.
- Preserve the WidgetKit widget as the uninterrupted long-fast surface.

### Out of scope

- Requesting automatically at the exact eight-hour boundary.
- Starting while the app remains backgrounded or terminated.
- Background tasks, timers, APNs, remote starts or scheduled app launches.
- Claiming one continuous ActivityKit activity across a longer fast.

### Acceptance criteria

1. Given a 16-hour active fast, enabled preference and an activity requested at
   hour 0, when uFast foregrounds at hour 7 with no running match, no automatic
   replacement is requested before the prior eight-hour window ends.
2. Given the same fast foregrounds at hour 17 with no running match and no
   suppression, exactly one new activity is requested and shows 17 hours elapsed
   from the original start.
3. Given a new activity is requested at hour 17, its next automatic eligibility
   begins eight hours after that request rather than eight hours after the fast
   began.
4. Given a matching activity is pending or active, foreground reconciliation
   updates semantic content when needed and never requests a duplicate.
5. Given `disabled`, **Hide for this fast**, no active record, invalid content or
   ActivityKit disabled, foregrounding makes no automatic request and never
   changes the fast.
6. Given the person dismisses an activity during its current eight-hour window,
   immediate later foregrounding does not recreate it; manual Show again remains
   available.
7. Given multiple active callbacks during one foreground session, at most one
   automatic request attempt occurs.
8. Given an automatic request fails, no immediate retry occurs, the status is
   non-blocking and a later distinct foreground or explicit action can retry.
9. Given the fast ends, is deleted or Delete All Data commits before a request
   completes, no replacement survives and lifecycle metadata is cleared.
10. DST, time-zone and locale changes preserve absolute elapsed time and use the
    current presentation environment.

### Verification

- Unit-test eligibility at 7:59:59, 8:00:00 and after eight hours using
  `FixedAppClock`.
- Unit-test cold launch, foreground transition coalescing, pending/running/
  ended/dismissed states, suppression, failures, deletion races and duplicates.
- UI-test foreground continuation with deterministic seeded lifecycle metadata;
  do not wait eight wall-clock hours.
- Physically verify a new foreground-requested activity on a supported iPhone
  and record separately whether the actual eight-hour system transition was
  observed.

### Done when

A longer fast can receive a truthful new activity after the person returns,
without a background chain, premature recreation, duplicate request or loss of
user control.

---

## OW-L109 — Complete the App Review and quality gate

**Priority:** P0  
**Status:** Implementation and review materials prepared; release evidence pending
**Estimate:** 5 points  
**Depends on:** OW-L106 through OW-L108

### User story

As the release owner, I want the automatic behavior, disclosure and review path
fully evidenced, so that App Review can understand the feature quickly and the
submitted metadata matches the binary exactly.

### In scope

- Audit implementation against Apple's current Live Activities HIG,
  `ActivityAuthorizationInfo`, ActivityKit lifecycle documentation and App
  Review Guidelines 2.3.1, 4.5.3 and 5.1.
- Verify the one-time offer, Settings copy, Today controls and privacy-sensitive
  presentation remain calm and consistent.
- Update the in-app Privacy and Safety explanation and public privacy policy for
  the release that first contains automatic Live Activities. State that the
  preference and lifecycle metadata remain on device and that Live Activity
  content may be visible on system surfaces; do not claim a new data collection
  category when no data leaves the device.
- Update App Store description, screenshots or preview only if they mention or
  depict the feature. Do not modify the metadata for a different submitted
  binary.
- Prepare specific Notes for Review and a no-account test path.
- Complete migration, unit, integration, full four-worker UI, accessibility,
  privacy, offline and physical-device evidence.
- Preserve the existing non-medical positioning and innocuous external copy.

### Required Notes for Review

Use this as the factual starting point and adjust only to match the submitted
binary and observed evidence:

> uFast offers an optional ActivityKit Live Activity for an active fasting
> record. No account, notification permission, server, APNs or network access is
> used. After starting a fast, the app offers once to enable automatic Live
> Activities. The same preference is available under Settings > Live
> Activities and can be turned off at any time. Turning it off hides the current
> activity and prevents new ones; Today also offers Hide for this fast. Each
> ActivityKit activity stays active for up to eight hours. If the local fast
> remains active, the app may request a new activity only when the user later
> opens or foregrounds uFast; it does not schedule, background-chain or remotely start
> activities. The fasting record remains local and authoritative if ActivityKit
> is unavailable, disabled, dismissed or fails.
>
> To review: complete onboarding, tap Start fast, choose Show Automatically,
> and observe the Today controls. Open Settings > Live Activities to turn the
> preference off or on. No login or demo account is required.

### Acceptance criteria

1. Review notes, metadata, screenshots, public privacy policy and the submitted
   binary describe the same shipped behavior.
2. The reviewer can reach consent, automatic start, Settings reversal, Hide for
   this fast and manual Show again without an account, external service or
   undisclosed fixture.
3. No notification authorization alert, APNs entitlement, background mode,
   analytics or network request is introduced.
4. App-created preference and lifecycle metadata remain local, minimal and
   removed by Delete All Data.
5. System-surface content retains OW-L105's innocuous allowed fields and remains
   privacy-sensitive, accessible and free of medical or physiological claims.
6. Full unit, build, format/lint and four-worker UI verification passes; every UI
   test appears exactly once and all four clones start successfully.
7. Physical-device evidence covers normal automatic start, Settings off, Hide
   for this fast, manual Show again, foreground continuation, disabled system
   setting and Dynamic Island where available. Any unobserved eight-hour,
   Always-On or dismissal behavior remains explicitly pending rather than
   inferred.
8. The existing 1.0 submission record and its metadata are not altered to
   describe a feature absent from that binary.

### Verification

- Run `make project`, `make format`, `make build`, `make test-unit`, one full
  parallel `make test-ui`, inspect its `.xcresult`, then run `make lint`.
- Before the UI run, verify no other `xcodebuild` or Xcode test run is active and
  never kill another person's run.
- Deploy to a configured iPhone and record exact device/OS/state observations.
- Inspect the archive capabilities and Info.plists to confirm only intended
  ActivityKit support is present.
- Review the final diff for data authority, migration, privacy, accessibility,
  App Review clarity and accidental scope expansion.

### Done when

The submitted build and every public/reviewer statement agree, all automated
and feasible physical checks pass, and any remaining Apple-controlled lifecycle
observation is recorded as a release gate instead of being claimed.

---

## Cross-story Definition of Ready

- [x] D-030 and BR-37 through BR-40 settle consent and lifecycle behavior.
- [x] Exact one-time offer, Settings and Today copy is final.
- [x] Preference defaults, migration, deletion and suppression are defined.
- [x] Start, backdated start, long-fast continuation and eight-hour eligibility
  are observable and deterministic with `AppClock`.
- [x] Disabled, unsupported, failed, dismissed, ended and offline states remain
  usable.
- [x] Accessibility, privacy, App Review notes and physical-device gates are
  included.
- [x] No material product choice remains for Luna to invent.

## Primary Apple evidence

- Apple, [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities): appropriate automatic starts, prominent/sensitive content, easy in-app control and the eight-hour design fit.
- Apple, [ActivityAuthorizationInfo](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo): default ActivityKit availability, `areActivitiesEnabled` and the person's iPhone setting.
- Apple, [Activity](https://developer.apple.com/documentation/activitykit/activity): foreground request boundary and ActivityKit lifecycle APIs.
- Apple, [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities): eight-hour active limit and ended-content behavior.
- Apple, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): accurate metadata and review notes, no unsolicited Live Activity spam and privacy requirements.
