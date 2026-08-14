# Clean-context Luna prompt for OW-L106 through OW-L109

You are working in the `uFast` repository. Implement **OW-L106 through OW-L109
— user-controlled automatic Live Activities** completely. Use the xhigh/highest
reasoning setting and work evidence-first. Do not reopen settled product choices.

Start by reading, in full:

- `AGENTS.md`
- `PRODUCT.md`
- `MVP_SCOPE.md`
- `DOMAIN_RULES.md`, especially BR-33 through BR-40
- `DECISIONS.md`, especially D-028, D-029 and D-030
- `ROADMAP.md`
- `BACKLOG.md`
- `docs/OW_LOCK_SCREEN_STORIES.md` for the delivered OW-L101 through OW-L105
  baseline
- `docs/OW_LIVE_ACTIVITY_AUTOMATION_STORIES.md` for the complete, controlling
  OW-L106 through OW-L109 contracts
- `READY_STORIES.md` only as historical context; its old OW-106 is superseded

Then inspect the implementation, tests and repository status before editing.
The worktree may contain user changes from the delivered Live Activity work.
Preserve them, do not revert unrelated changes, and do not assume every dirty
file is yours.

Understand before changing anything:

- the authoritative `FastRecord` start, backdate, correction, end, deletion and
  Delete All Data transactions;
- `AppSettingsRecord`, its migration path and existing settings save failures;
- the ActivityKit coordinator, request coalescing, reconciliation, lifecycle
  metadata, disclosure, Today controls and failure copy delivered by OW-L105;
- WidgetKit projection ordering and the `ufast://fast/current` route;
- app scene-phase handling and what constitutes a genuine transition to active;
- deterministic `AppClock`, fixtures, accessibility identifiers and current
  unit/UI test conventions; and
- current Apple target versions and ActivityKit availability boundaries.

## Settled behavior — implement exactly

- Automatic behavior uses one migration-safe local tri-state preference:
  `notAsked`, `enabled`, `disabled`. `notAsked` behaves as off. Unknown or
  corrupt persisted values fail closed to `disabled`.
- Existing installations migrate without data loss to `notAsked`.
- Present the one-time offer only after the first eligible fast successfully
  commits and Today visibly shows it. Never offer before save, after a failed or
  cancelled start, or while ActivityKit is unsupported/system-disabled.
- Use the exact offer, Settings and Today copy in the controlling story file.
  **Not Now** is final and never nags again. Settings remains available.
- **Show Automatically** persists `enabled` before requesting. **Not Now**
  persists `disabled` and requests nothing.
- The Settings toggle is **Automatically show Live Activities**. Enabling it
  during a valid active fast may request once after the setting commits.
  Disabling it commits first, ends matching activities and prevents new ones.
- Rename removal to **Hide for this fast**. It suppresses automatic requests for
  only the current fast and does not change the global preference or fast.
- Manual **Show Live Activity** / **Show Live Activity again** remains available
  and retains the OW-L105 disclosure. A confirmed manual request may clear
  current-fast suppression.
- With `enabled`, request at most one activity after a normal or backdated fast
  successfully commits and after the WidgetKit projection is published.
- On a genuine later foreground activation, reconcile/update/deduplicate first.
  If no matching activity runs and all eligibility rules pass, request at most
  one continuation. It is eligible only when no successful request exists for
  the fast or at least eight absolute hours have passed since the last one.
- A continuation starts a new ActivityKit lifetime at request time but displays
  truthful elapsed duration from the original `FastRecord.startDate`. Thus a
  fast opened at hour 17 can show 17 hours elapsed in a newly requested activity.
- Do not immediately recreate a person-dismissed activity inside its prior
  eight-hour window. A later foreground after the window may continue unless
  the person chose **Hide for this fast** or disabled the setting.
- Make no more than one automatic attempt per foreground activation. A failed
  attempt may retry on a later distinct activation or manual action, never in a
  same-activation loop.
- Never add timers, background tasks, scheduled launches, notification
  permission, alerts, sounds, APNs, networking or remote starts.
- ActivityKit failure never rolls back a preference or fasting transaction.
  The local `FastRecord` remains authoritative and the user-added widget remains
  the durable longer-fast surface.
- Preserve OW-L105 system content, privacy-sensitive modifiers, accessibility,
  deep link, duplicate cleanup and immediate successful-end/delete cleanup.

Implement the stories sequentially and keep each story independently reviewable:

1. **OW-L106:** preference migration, one-time informed offer, Settings control,
   Hide for this fast and exact accessible copy.
2. **OW-L107:** automatic request after a committed normal/backdated fast.
3. **OW-L108:** deterministic foreground reconciliation and eight-hour
   continuation policy.
4. **OW-L109:** privacy, metadata/review notes, automated verification and
   feasible physical-device evidence.

Do not change the existing 1.0 submission metadata or privacy statements to
claim a feature absent from that submitted binary. Prepare/update the release
materials for the binary that actually contains this feature, as OW-L109
requires. Keep App Review notes factual and use the template in the story file.

## Engineering and test expectations

- Keep policy and eligibility logic outside SwiftUI and ActivityKit where
  practical, behind testable boundaries.
- Inject `AppClock`; never make eight-hour tests depend on wall-clock time.
- Persist only the minimal local preference/lifecycle metadata defined in the
  story. Delete All Data must clear it.
- Cover migration, exact once-only offer behavior, save/request/end failures,
  normal and backdated starts, duplicate coalescing, global off, per-fast hide,
  manual override, dismissal, unsupported/system-disabled ActivityKit,
  foreground at 7:59/8:00/17 hours, scene churn, ended/deleted fasts and relaunch.
- Give every new interactive or asserted UI element a stable accessibility
  identifier. Keep UI tests independent and safe under four workers.
- Do not weaken existing Live Activity, WidgetKit, fasting, persistence,
  accessibility or privacy tests.

Before the full UI suite, verify that no other `xcodebuild` or Xcode test run is
active; never kill another person's run. Run only one `make test-ui` invocation.

Complete verification in this order, fixing failures caused by the work:

1. `make project` if `project.yml` changes
2. `make format`
3. `make build`
4. `make test-unit`
5. `make test-ui`
6. inspect the `.xcresult` to confirm every UI test ran exactly once and all
   four simulator clones started
7. `make lint`

When a configured iPhone is connected, run `make deploy-iphone` and execute the
OW-L109 physical matrix. Clearly distinguish observed device behavior from
inference; do not claim an eight-hour, dismissal, Always-On or Dynamic Island
result that was not actually observed.

Review the final diff for preserved data, authority ordering, accidental scope
expansion, privacy, accessibility and exact copy. Do not commit, push, create a
PR or alter App Store Connect. Finish with:

- stories completed and key behavior delivered;
- files materially changed;
- migration and failure behavior;
- commands/tests run with exact results;
- physical-device observations and any unobserved release gates;
- App Review/privacy material prepared; and
- any genuine blocker or residual risk.
